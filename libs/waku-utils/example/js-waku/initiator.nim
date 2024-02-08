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
  wakuPort = 60000
  discv5Port = 9000
  requiredConnectedPeers = 2
  # Make sure it matches the publisher. Use default value
  # see spec: https://rfc.vac.dev/spec/23/
  pubSubTopic = PubsubTopic("/waku/2/default-waku/proto")

proc exampleJSWaku(rng: ref HmacDrbgContext) {.async.} =
  setupLogLevel(logging.LogLevel.NOTICE)

  var readyForFinalization = false

  ################################
  # Initiator static/ephemeral key initialization and commitment
  let initiatorInfo = initAgentKeysAndCommitment(rng)

  # Read the QR
  let
    qr = readFile("qr.txt")
    (_, _, _, readEphemeralKey, _) = fromQr(qr)
    qrMessageNameTag = fromHex(readFile("qrMessageNametag.txt"))
    # We set the contentTopic from the content topic parameters exchanged in the QR
    contentTopic = initContentTopicFromQr(qr)

  notice "Starting `nwaku`-`js-waku` pairing example", wakuPort = wakuPort,
      discv5Port = discv5Port

  notice "Initial information parsed from the QR", contentTopic = contentTopic,
      qrMessageNameTag = qrMessageNameTag

  var
    initiatorHS = initHS(initiatorInfo, qr, true)
    initiatorHSResult: HandshakeResult

  # Setup the Waku node
  let
    nodeKey = crypto.PrivateKey.random(Secp256k1, rng[]).get()
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

  let discv5Conf = WakuDiscoveryV5Config(discv5Config: none(DiscoveryConfig),
                                         address: ip, port: Port(discv5Port),
                                         privateKey: keys.PrivateKey(nodeKey.skkey),
                                         bootstrapRecords: @[bootstrapNodeEnr],
                                         autoupdateRecord: true)

  # assumes behind a firewall, so not care about being discoverable
  let wakuDiscv5 = WakuDiscoveryV5.new(node.rng, discv5Conf, some(node.enr),
                                       some(node.peerManager),
                                       node.topicSubscriptionQueue)

  await node.start()
  await node.mountRelay()
  node.peerManager.start()

  (await wakuDiscv5.start()).isOkOr:
    error "failed to start discv5", error = error
    quit(1)

  # Wait for a minimum of peers to be connected, otherwise messages wont be gossiped
  while true:
    let numConnectedPeers = node.peerManager.peerStore[
        ConnectionBook].book.values().countIt(it == Connected)
    if numConnectedPeers >= requiredConnectedPeers:
      notice "Node is ready", connectedPeers = numConnectedPeers,
          required = requiredConnectedPeers
      break
    notice "Waiting for the node to be ready",
        connectedPeers = numConnectedPeers, required = requiredConnectedPeers
    await sleepAsync(5000)

  # Perform the handshake
  initiatorHSResult = await initiatorHandshake(rng, node, pubSubTopic,
                                               contentTopic, qr,
                                               qrMessageNameTag,
                                               initiatorInfo)
  await sleepAsync(1000) # Just in case there is some kind of delay on the other side


  ## Scenario 1: Dump a lof of messages
  var
    payload: PayloadV2
    realMessage: seq[byte]
    readMessage: seq[byte]

  var i = 150
  while i > 0:
    realMessage = @[(byte)42,42,42,42]
    payload = writeMessage(initiatorHSResult, realMessage,
                           initiatorHSResult.nametagsOutbound)

    let wakuMsg = encodePayloadV2(  payload, contentTopic)
    await node.publish(some(pubSubTopic), wakuMsg.get)
    notice "Sending real message", payload=payload.messageNametag
    await sleepAsync(100)
    i = i - 1

  await sleepAsync(5000)

  ## Scenario 2: Fake lost messages
  let
    message1 = @[(byte)1, 42, 42, 42]
    payload1 = writeMessage(initiatorHSResult, message1,
                                initiatorHSResult.nametagsOutbound)
    wakuMessage1 = encodePayloadV2(payload1, contentTopic)
  notice "Sending first message"
  await node.publish(some(pubSubTopic), wakuMessage1.get)

  let
    lostMessage1 = @[(byte)1, 5, 5, 5]
    payloadLost1 = writeMessage(initiatorHSResult, lostMessage1,
                                initiatorHSResult.nametagsOutbound)
    wakuLostMessage1 = encodePayloadV2(payloadLost1, contentTopic)

  let
    lostMessage2 = @[(byte)2, 5, 5, 5]
    payloadLost2 = writeMessage(initiatorHSResult, lostMessage2,
                                initiatorHSResult.nametagsOutbound)
    wakuLostMessage2 = encodePayloadV2(payloadLost2, contentTopic)

  let
    message2 = @[(byte)2, 42, 42, 42]
    payload2 = writeMessage(initiatorHSResult, message2,
                            initiatorHSResult.nametagsOutbound)
    wakuMessage2 = encodePayloadV2(payload2, contentTopic)
  notice "Sending second message"
  await node.publish(some(pubSubTopic), wakuMessage2.get)

  let
    lostMessage3 = @[(byte)3, 5, 5, 5]
    payloadLost3 = writeMessage(initiatorHSResult, lostMessage3,
                                initiatorHSResult.nametagsOutbound)
    wakuLostMessage3 = encodePayloadV2(payloadLost3, contentTopic)

  await sleepAsync(10000)
  notice "Sending first lost message"
  await node.publish(some(pubSubTopic), wakuLostMessage1.get)

  let
    message3 = @[(byte)3, 42, 42, 42]
    payload3 = writeMessage(initiatorHSResult, message3,
                            initiatorHSResult.nametagsOutbound)
    wakuMessage3 = encodePayloadV2(payload3, contentTopic)
  notice "Sending third message"
  await node.publish(some(pubSubTopic), wakuMessage3.get)

  await sleepAsync(10000)
  notice "Sending second lost message"
  await node.publish(some(pubSubTopic), wakuLostMessage2.get)

  await sleepAsync(1000)
  notice "Sending third lost message"
  await node.publish(some(pubSubTopic), wakuLostMessage3.get)


when isMainModule:
  let rng = crypto.newRng()
  asyncSpawn exampleJSWaku(rng)
  runForever()
