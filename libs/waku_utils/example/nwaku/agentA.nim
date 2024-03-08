import
  # Nimble packages
  chronicles,
  chronos,
  confutils,
  libp2p/crypto/crypto,
  eth/[keys, p2p/discoveryv5/enr],

  # Nimble packages - Waku
  waku/[waku_core, waku_node, waku_enr, waku_discv5],
  waku/waku_noise/[noise_types, noise_handshake_processing],
  waku/utils/noise,
  waku/node/peer_manager,
  waku/common/[logging, protobuf],

  # Local modules
  ../../waku_handshake_utils,
  ../../waku_node

const
  wakuPort = 60000
  discv5Port = 9000
  requiredConnectedPeers = 2
  # Make sure it matches the publisher. Use default value
  # see spec: https://rfc.vac.dev/spec/23/
  pubSubTopic = PubsubTopic("/waku/2/default-waku/proto")

proc exampleNwakuAgentA(rng: ref HmacDrbgContext) {.async.} =
  setupLogLevel(logging.LogLevel.NOTICE)
  # agentA static/ephemeral key initialization and commitment
  let agentAInfo = initAgentKeysAndCommitment(rng)

  # Read the QR
  let
    qr = readFile("build/data/qr.txt")
    qrMessageNameTag = cast[seq[byte]](readFile("build/data/qrMessageNametag.txt"))
    # We set the contentTopic from the content topic parameters exchanged in the QR
    contentTopic = initContentTopicFromQr(qr)

  notice "Starting `nwaku`-`nwaku` pairing example. Agent A",
      wakuPort = wakuPort, discv5Port = discv5Port

  notice "Initial information parsed from the QR", contentTopic = contentTopic,
      qrMessageNameTag = qrMessageNameTag

  var agentAHSResult: HandshakeResult

  # Start nwaku instance
  let node = await startWakuNode(rng, wakuPort, discv5Port,
                                 requiredConnectedPeers)

  # Perform the handshake
  agentAHSResult = await initiatorHandshake(rng, node, pubSubTopic, contentTopic,
                                            qr, qrMessageNameTag, agentAInfo)

  await sleepAsync(1000) # Just in case there is some kind of delay on the other side

  ## Fake lost messages
  let
    message1 = @[(byte)1, 42, 42, 42]
    payload1 = writeMessage(agentAHSResult, message1,
                            agentAHSResult.nametagsOutbound)
    wakuMessage1 = encodePayloadV2(payload1, contentTopic)
  notice "Sending first message"
  discard await node.publish(some(pubSubTopic), wakuMessage1.get)

  let
    lostMessage1 = @[(byte)1, 5, 5, 5]
    payloadLost1 = writeMessage(agentAHSResult, lostMessage1,
                                agentAHSResult.nametagsOutbound)
    wakuLostMessage1 = encodePayloadV2(payloadLost1, contentTopic)

  let
    lostMessage2 = @[(byte)2, 5, 5, 5]
    payloadLost2 = writeMessage(agentAHSResult, lostMessage2,
                                agentAHSResult.nametagsOutbound)
    wakuLostMessage2 = encodePayloadV2(payloadLost2, contentTopic)

  let
    message2 = @[(byte)2, 42, 42, 42]
    payload2 = writeMessage(agentAHSResult, message2,
                            agentAHSResult.nametagsOutbound)
    wakuMessage2 = encodePayloadV2(payload2, contentTopic)
  notice "Sending second message"
  discard await node.publish(some(pubSubTopic), wakuMessage2.get)

  let
    lostMessage3 = @[(byte)3, 5, 5, 5]
    payloadLost3 = writeMessage(agentAHSResult, lostMessage3,
                                agentAHSResult.nametagsOutbound)
    wakuLostMessage3 = encodePayloadV2(payloadLost3, contentTopic)

  await sleepAsync(10000)
  notice "Sending first lost message"
  discard await node.publish(some(pubSubTopic), wakuLostMessage1.get)

  let
    message3 = @[(byte)3, 42, 42, 42]
    payload3 = writeMessage(agentAHSResult, message3,
                            agentAHSResult.nametagsOutbound)
    wakuMessage3 = encodePayloadV2(payload3, contentTopic)
  notice "Sending third message"
  discard await node.publish(some(pubSubTopic), wakuMessage3.get)

  await sleepAsync(10000)
  notice "Sending second lost message"
  discard await node.publish(some(pubSubTopic), wakuLostMessage2.get)

  await sleepAsync(1000)
  notice "Sending third lost message"
  discard await node.publish(some(pubSubTopic), wakuLostMessage3.get)

when isMainModule:
  let rng = crypto.newRng()
  asyncSpawn exampleNwakuAgentA(rng)
  runForever()
