import
  # Nimble packages
  stew/[byteutils], chronicles, chronos, confutils,

  # Nimble packages - Waku
  waku/waku_noise/[noise_types, noise_utils, noise_handshake_processing],
  waku/utils/noise,
  waku/[waku_core, waku_node],
  waku/common/[logging, protobuf],
  waku/node/peer_manager

type
  AgentKeysAndCommitment* = object
    staticKey*: noise_types.KeyPair
    ephemeralKey*: noise_types.KeyPair
    commitment*: seq[byte]
    committedStaticKey*: MDigest[256]

  ContentTopicInfo* = object
    applicationName*: string
    applicationVersion*: string
    shardId*: string

proc initAgentKeysAndCommitment*(rng: ref HmacDrbgContext): AgentKeysAndCommitment =
  let staticKey = genKeyPair(rng[])
  let commitment = randomSeqByte(rng[], 32)
  AgentKeysAndCommitment(staticKey: staticKey,
                         ephemeralKey: genKeyPair(rng[]),
                         commitment: commitment,
                         committedStaticKey:
                            commitPublicKey(getPublicKey(staticKey), commitment))

proc initQr*(rng: ref HmacDrbgContext, contentTopicInfo: ContentTopicInfo,
             agentInfo: AgentKeysAndCommitment
    ): tuple[qr: string, qrMessageNametag: seq[byte]] =
  let qr = toQr(contentTopicInfo.applicationName,
                contentTopicInfo.applicationVersion,
                contentTopicInfo.shardId,
                getPublicKey(agentInfo.ephemeralKey),
                agentInfo.committedStaticKey)

  let qrMessageNametag = randomSeqByte(rng[], MessageNametagLength)

  (qr, qrMessageNametag)

proc initContentTopicFromQr*(qr: string): ContentTopic =
  let (readApplicationName, readApplicationVersion, readShardId, _, _) = fromQr(qr)

  let contentTopic = "/" & readApplicationName & "/" &
                     readApplicationVersion & "/" &
                     readShardId & "/proto"
  return contentTopic

proc initHS*(agentInfo: AgentKeysAndCommitment, qr: string,
    isInitiator: bool = false): HandshakeState =
  let
    hsPattern = NoiseHandshakePatterns["WakuPairing"]
    (_, _, _, readEphemeralKey, _) = fromQr(qr)
    preMessagePKs: seq[NoisePublicKey] = @[toNoisePublicKey(readEphemeralKey)]

  initialize(hsPattern = hsPattern,
             ephemeralKey = agentInfo.ephemeralKey,
             staticKey = agentInfo.staticKey,
             prologue = qr.toBytes,
             preMessagePKs = preMessagePKs,
             initiator = isInitiator)

proc prepareHandShakeInitiatorMsg*(rng: ref HmacDrbgContext,
                                   contentTopic: string,
                                   agentInfo: AgentKeysAndCommitment,
                                   qrMessageNametag: seq[byte],
                                   agentMessageNametag: var MessageNametag,
                                   agentHS: var HandshakeState,
                                   initiatorStep: var HandshakeStepResult
    ): Result[WakuMessage, cstring] =

  ##############################
  # 1st step                   #
  #                            #
  # -> eA, eAeB   {H(sA||s)}]  #
  ##############################

  # The messageNametag for the first handshake message is randomly generated
  # and exchanged out-of-band and corresponds to qrMessageNametag

  let transportMessage = digestToSeq(agentInfo.committedStaticKey)

  # By being the handshake initiator, this agent writes a Waku2 payload v2
  # containing  handshake message and the (encrypted) transport message
  # The message is sent with a messageNametag equal to the one received through
  # the QR code
  initiatorStep = stepHandshake(rng[], agentHS,
                                transportMessage = transportMessage,
                                messageNametag = qrMessageNametag).get()

  # We prepare a Waku message from the initiators's payload2
  let wakuMsg = encodePayloadV2(initiatorStep.payload2, contentTopic)

  assert wakuMsg.isOk()
  assert wakuMsg.get().contentTopic == contentTopic

  agentMessageNametag = toMessageNametag(agentHS)

  wakuMsg

proc publishHandShakeInitiatorMsg*(node: WakuNode,
                                   pubSubTopic: PubsubTopic,
                                   contentTopic: ContentTopic,
                                   message: WakuMessage) {.async.} =
  notice "Publishing handshake initiator message", step = 1
  discard await node.publish(some(pubSubTopic), message)
  notice "Published handshake initiator message",
         step = 1,
         psTopic = pubSubTopic,
         contentTopic = contentTopic,
         payload = message.payload

proc handleHandShakeInitiatorMsg*(rng: ref HmacDrbgContext,
                                  pubSubTopic: PubsubTopic,
                                  contentTopic: ContentTopic,
                                  payload: PayloadV2,
                                  receiverStep: var HandshakeStepResult,
                                  receiverHS: var HandshakeState,
                                  receiverMessageNametag: var MessageNametag,
                                  qrMessageNametag: seq[byte]) =
  notice "Received handshake initiator message", step = 1,
         psTopic = pubSubTopic,
         contentTopic = contentTopic,
         payload = payload
  notice "Handling handshake initiator message", step = 1
  # The Receiver reads the Initiator's payloads, and returns the (decrypted) transport
  # message the Initiator sent to him
  # Note that the Receiver verifies if the received payloadv2 has the expected messageNametag set
  receiverStep = stepHandshake(rng[], receiverHS,
                               readPayloadV2 = payload,
                               messageNametag = qrMessageNametag).get()
  receiverMessageNametag = toMessageNametag(receiverHS)

proc prepareHandShakeMsg*(rng: ref HmacDrbgContext,
                          contentTopic: string,
                          agentInfo: AgentKeysAndCommitment,
                          agentMessageNametag: var MessageNametag,
                          agentHS: var HandshakeState,
                          agentStep: var HandshakeStepResult,
                          step: int
    ): Result[WakuMessage, cstring] =

  ######################      ##########################
  # 2nd step           #      # 3rd step               #
  #                    #  or  #                        #
  # <- sB, eAsB    {r} #      # -> sA, sAeB, sAsB  {s} #
  ######################      ##########################

  notice "Preparing handshake message for step:", step = step
  let transportMessage = agentInfo.commitment
  agentStep = stepHandshake(rng[], agentHS,
                            transportMessage = transportMessage,
                            messageNametag = agentMessageNametag).get()

  let wakuMsg = encodePayloadV2(agentStep.payload2, contentTopic)
  assert wakuMsg.isOk()
  assert wakuMsg.get().contentTopic == contentTopic
  agentMessageNametag = toMessageNametag(agentHS)
  wakuMsg

proc publishHandShakeMsg*(node: WakuNode,
                          pubSubTopic: PubsubTopic,
                          contentTopic: ContentTopic,
                          message: WakuMessage,
                          step: int) {.async.} =
  notice "Publishing handshake message for step:", step = step
  discard await node.publish(some(pubSubTopic), message)
  notice "Published handshake message for step:", step = step,
         psTopic = pubSubTopic,
         contentTopic = contentTopic,
         message = message

proc handleHandShakeMsg*(rng: ref HmacDrbgContext,
                         pubSubTopic: PubsubTopic,
                         contentTopic: ContentTopic,
                         step: int,
                         payload: PayloadV2,
                         initiatorStep: var HandshakeStepResult,
                         initiatorHS: var HandshakeState,
                         initiatorMessageNametag: var MessageNametag) =
  notice "Received handshake message for step:", step = step,
      psTopic = pubSubTopic, contentTopic = contentTopic, payload = payload
  notice "Handling handshake message for step:", step = step
  initiatorStep = stepHandshake(rng[], initiatorHS,
                                readPayloadV2 = payload,
                                messageNametag = initiatorMessageNametag).get()
  initiatorMessageNametag = toMessageNametag(initiatorHS)

proc initiatorHandshake*(rng: ref HmacDrbgContext, node: WakuNode,
                         pubSubTopic: PubsubTopic,
                         contentTopic: ContentTopic,
                         qr: string, qrMessageNameTag: seq[byte],
                         initiatorInfo: AgentKeysAndCommitment
    ): Future[HandshakeResult] {.async.} =
  var
    readyForFinalization = false

    initiatorMessageNametag: MessageNametag
    initiatorStep: HandshakeStepResult
    initiatorHS: HandshakeState = initHS(initiatorInfo, qr, true)

    initiatorHSResult: HandshakeResult

  let initialMessage =
    prepareHandShakeInitiatorMsg(rng, contentTopic, initiatorInfo,
                                 qrMessageNameTag, initiatorMessageNametag,
                                 initiatorHS, initiatorStep)

  proc initiatorHandshakeHandler(topic: PubsubTopic, msg: WakuMessage): Future[
      void] {.async.} =
    if msg.contentTopic == contentTopic:
      let readPayloadV2 = decodePayloadV2(msg).get()
      if readPayloadV2.messageNametag == initiatorMessageNametag:
        handleHandShakeMsg(rng, pubSubTopic, contentTopic, step = 2,
                           readPayloadV2, initiatorStep, initiatorHS,
                           initiatorMessageNametag)

        let handShakeMsgStep3 = prepareHandShakeMsg(rng, contentTopic,
                                                    initiatorInfo,
                                                    initiatorMessageNametag,
                                                    initiatorHS,
                                                    initiatorStep, step = 3)
        await publishHandShakeMsg(node, pubSubTopic, contentTopic,
                                  handShakeMsgStep3.get(), 3)
        readyForFinalization = true

  node.subscribe((kind: PubsubSub, topic: pubsubTopic),
                 some(initiatorHandshakeHandler))

  await publishHandShakeInitiatorMsg(node, pubSubTopic, contentTopic,
                                     initialMessage.get())

  while true:
    if readyForFinalization:
      node.unsubscribe((kind: PubsubSub, topic: pubsubTopic))

      notice "Finalizing handshake"
      initiatorHSResult = finalizeHandshake(initiatorHS)
      notice "Handshake finalized successfully"
      break
    await sleepAsync(2000)

  return initiatorHSResult
