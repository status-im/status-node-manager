import
  chronicles,
  chronos,
  libp2p/crypto/crypto,
  eth/[keys, p2p/discoveryv5/enr],
  nimcrypto/utils

import
  waku/[waku_core, waku_discv5],
  waku/waku_noise/noise_types,
  waku/node/[peer_manager, waku_node],
  waku/common/logging

import ./waku_handshake_utils
import ./waku_node

type WakuPairResult* = object
  wakuNode*: WakuNode
  wakuHandshakeResult*: HandshakeResult

proc wakuPair*(rng: ref HmacDrbgContext, qr, qrMessageNameTagHex: string,
               wakuPort, discv5Port: uint16,
               requiredConnectedPeers: int,
               pubSubTopic: PubsubTopic
    ): Future[WakuPairResult] {.async.} =
  # Initiator static/ephemeral key initialization and commitment
  let initiatorInfo = initAgentKeysAndCommitment(rng)

  # Read the QR
  let
    qrMessageNameTag = fromHex(qrMessageNameTagHex)
    # We set the contentTopic from the content topic parameters exchanged in the QR
    contentTopic = initContentTopicFromQr(qr)

  notice "Initializing Waku pairing", wakuPort = wakuPort,
      discv5Port = discv5Port

  notice "Initial information parsed from the QR", contentTopic = contentTopic,
      qrMessageNameTag = qrMessageNameTag

  var initiatorHSResult: HandshakeResult

  # Start nwaku instance
  let node = await startWakuNode(rng, wakuPort, discv5Port,
                                 requiredConnectedPeers)

  # Perform the handshake
  initiatorHSResult = await initiatorHandshake(rng, node, pubSubTopic,
                                               contentTopic, qr,
                                               qrMessageNameTag,
                                               initiatorInfo)
  return WakuPairResult(wakuNode: node,
                        wakuHandshakeResult: initiatorHSResult)