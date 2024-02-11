import
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
import ../../waku_node

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
    qr = readFile("build/data/qr.txt")
    (_, _, _, readEphemeralKey, _) = fromQr(qr)
    qrMessageNameTag = fromHex(readFile("build/data/qrMessageNametag.txt"))
    # We set the contentTopic from the content topic parameters exchanged in the QR
    contentTopic = initContentTopicFromQr(qr)

  notice "Starting `nwaku`-`js-waku` pairing example", wakuPort = wakuPort,
      discv5Port = discv5Port

  notice "Initial information parsed from the QR", contentTopic = contentTopic,
      qrMessageNameTag = qrMessageNameTag

  var
    initiatorHS = initHS(initiatorInfo, qr, true)
    initiatorHSResult: HandshakeResult

  # Start nwaku instance
  let node = await startWakuNode(rng, wakuPort, discv5Port,
                                 requiredConnectedPeers)

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
