import
  std/[tables, times, sequtils],
  stew/shims/net,
  chronicles,
  chronos,
  confutils,
  libp2p/crypto/crypto,
  eth/[keys, p2p/discoveryv5/enr],
  nimcrypto/utils

import
  waku/[waku_core, waku_node, waku_enr, waku_discv5],
  waku/waku_noise/[noise_types, noise_utils, noise_handshake_processing],
  waku/utils/noise,
  waku/node/peer_manager,
  waku/common/[logging, protobuf]

import ../../waku_handshake_utils

const bootstrapNode = "enr:-P-4QGVNANzbhCI49du6Moyw98AjuMhKoOpE_Jges9JlCq-I" &
                      "CAVadktjfcNpuhQgT0g1cu86_S3nbM7eYkCsqDAQG7UBgmlkgnY0" &
                      "gmlwhI_G-a6KbXVsdGlhZGRyc7hgAC02KG5vZGUtMDEuZG8tYW1z" &
                      "My5zdGF0dXMucHJvZC5zdGF0dXNpbS5uZXQGdl8ALzYobm9kZS0w" &
                      "MS5kby1hbXMzLnN0YXR1cy5wcm9kLnN0YXR1c2ltLm5ldAYBu94D" &
                      "iXNlY3AyNTZrMaECoVyonsTGEQvVioM562Q1fjzTb_vKD152PPId" &
                      "sV7sM6SDdGNwgnZfg3VkcIIjKIV3YWt1Mg8"
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

  # Setup the Waku node
  let
    nodeKey = crypto.PrivateKey.random(Secp256k1, rng[])[]
    ip = parseIpAddress("0.0.0.0")
    flags = CapabilitiesBitfield.init(lightpush = false, filter = false,
        store = false, relay = true)

  var enrBuilder = EnrBuilder.init(nodeKey)

  let recordRes = enrBuilder.build()
  let record =
    if recordRes.isErr():
      error "failed to create enr record", error = recordRes.error
      quit(QuitFailure)
    else: recordRes.get()

  var builder = WakuNodeBuilder.init()
  builder.withNodeKey(nodeKey)
  builder.withRecord(record)
  builder.withNetworkConfigurationDetails(ip, Port(wakuPort)).tryGet()
  let node = builder.build().tryGet()

  var bootstrapNodeEnr: enr.Record
  discard bootstrapNodeEnr.fromURI(bootstrapNode)

  let discv5Conf = WakuDiscoveryV5Config(
    discv5Config: none(DiscoveryConfig),
    address: ip,
    port: Port(discv5Port),
    privateKey: keys.PrivateKey(nodeKey.skkey),
    bootstrapRecords: @[bootstrapNodeEnr],
    autoupdateRecord: true,
  )

  # assumes behind a firewall, so not care about being discoverable
  let wakuDiscv5 = WakuDiscoveryV5.new(
    node.rng,
    discv5Conf,
    some(node.enr),
    some(node.peerManager),
    node.topicSubscriptionQueue,
  )

  await node.start()
  await node.mountRelay()
  node.peerManager.start()

  (await wakuDiscv5.start()).isOkOr:
    error "failed to start discv5", error = error
    quit(1)

  # wait for a minimum of peers to be connected, otherwise messages wont be gossiped
  while true:
    let numConnectedPeers = node.peerManager.peerStore[
        ConnectionBook].book.values().countIt(it == Connected)
    if numConnectedPeers >= requiredConnectedPeers:
      notice "subscriber is ready", connectedPeers = numConnectedPeers,
          required = requiredConnectedPeers
      break
    notice "waiting to be ready", connectedPeers = numConnectedPeers,
        required = requiredConnectedPeers
    await sleepAsync(5000)

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
