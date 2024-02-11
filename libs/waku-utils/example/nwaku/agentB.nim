import
  stew/shims/net,
  chronicles,
  chronos,
  confutils,
  libp2p/crypto/crypto,
  eth/[keys, p2p/discoveryv5/enr]

import
  waku/[waku_core, waku_node, waku_enr, waku_discv5],
  waku/waku_noise/[noise_types, noise_utils, noise_handshake_processing],
  waku/utils/noise,
  waku/node/peer_manager,
  waku/common/[logging, protobuf]

import ../../waku_handshake_utils
import ../../waku_node

const
  wakuPort = 50000
  discv5Port = 8000
  requiredConnectedPeers = 2
  # Make sure it matches the publisher. Use default value
  # see spec: https://rfc.vac.dev/spec/23/
  pubSubTopic = PubsubTopic("/waku/2/default-waku/proto")

proc exampleNwakuAgentB(rng: ref HmacDrbgContext) {.async.} =
  setupLogLevel(logging.LogLevel.NOTICE)

  var readyForFinalization = false

  let agentBInfo = initAgentKeysAndCommitment(rng)
  let r = agentBInfo.commitment

  #########################
  # Content Topic information
  let contentTopicInfo = ContentTopicInfo(
    applicationName: "waku-noise-sessions",
    applicationVersion: "0.1",
    shardId: "10", )

  let (qr, qrMessageNametag) = initQr(rng, contentTopicInfo, agentBInfo)
  writeFile("build/data/qr.txt", qr)
  writeFile("build/data/qrMessageNametag.txt", qrMessageNametag)

  # We set the contentTopic from the content topic parameters exchanged in the QR
  let contentTopic = initContentTopicFromQr(qr)

  notice "Starting `nwaku`-`nwaku` pairing example. Agent A",
      wakuPort = wakuPort, discv5Port = discv5Port

  notice "Initial information parsed from the QR", contentTopic = contentTopic,
      qrMessageNameTag = qrMessageNameTag

  var
    agentBHS = initHS(agentBInfo, qr)
    agentBStep: HandshakeStepResult
    wakuMsg: Result[WakuMessage, cstring]
    readPayloadV2: PayloadV2
    agentBMessageNametag: MessageNametag
    agentBHSResult: HandshakeResult

  # Start nwaku instance
  let node = await startWakuNode(rng, wakuPort, discv5Port,
                                 requiredConnectedPeers)

  # Make sure it matches the publisher. Use default value
  # see spec: https://rfc.vac.dev/spec/23/
  let pubSubTopic = PubsubTopic("/waku/2/default-waku/proto")
  var step2Nametag: MessageNametag
  proc handler(topic: PubsubTopic, msg: WakuMessage): Future[void] {.async, gcsafe.} =
    # let payloadStr = string.fromBytes(msg.payload)
    if msg.contentTopic == contentTopic:
      readPayloadV2 = decodePayloadV2(msg).get()
      if readPayloadV2.messageNametag == qrMessageNametag:
        handleHandShakeInitiatorMsg(rng, pubSubTopic, contentTopic, readPayloadV2,
                                    agentBStep, agentBHS, agentBMessageNametag,
                                    qrMessageNametag)
        step2Nametag = agentBMessageNametag
        wakuMsg = prepareHandShakeMsg(rng, contentTopic, agentBInfo,
                                      agentBMessageNametag, agentBHS,
                                      agentBStep,
                                      step = 2)
        await publishHandShakeMsg(node, pubSubTopic, contentTopic,
                                  wakuMsg.get(), step = 2)

        agentBMessageNametag = toMessageNametag(agentBHS)
      elif readPayloadV2.messageNametag == agentBMessageNametag:
        handleHandShakeMsg(rng, pubSubTopic, contentTopic, step = 3, readPayloadV2,
                           agentBStep, agentBHS, agentBMessageNametag)
        readyForFinalization = true

  node.subscribe((kind: PubsubSub, topic: pubsubTopic), some(handler))

  var handshakeFinalized = false
  while true:
    if readyForFinalization:
      notice "Finalizing handshake"
      agentBHSResult = finalizeHandshake(agentBHS)
      notice "Handshake finalized successfully"
      handshakeFinalized = true
      break
    await sleepAsync(5000)

  if handshakeFinalized:
    proc realMessageHandler(topic: PubsubTopic, msg: WakuMessage
        ): Future[void] {.async.} =
      if msg.contentTopic == contentTopic:
        readPayloadV2 = decodePayloadV2(msg).get()
        notice "Received real message", payload = readPayloadV2,
                                        pubsubTopic = pubsubTopic,
                                        contentTopic = msg.contentTopic,
                                        timestamp = msg.timestamp
        let readMessage = readMessage(agentBHSResult, readPayloadV2,
                                      agentBHSResult.nametagsInbound).get()
        echo readMessage

    node.subscribe((kind: PubsubSub, topic: pubsubTopic), some(realMessageHandler))

when isMainModule:
  let rng = crypto.newRng()
  asyncSpawn exampleNwakuAgentB(rng)
  runForever()
