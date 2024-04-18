import
  # Nimble packages
  chronicles,
  chronos,
  libp2p/crypto/crypto,
  eth/[keys, p2p/discoveryv5/enr],
  nimcrypto/utils,

  # Nimble packages - Waku
  waku/[waku_core, waku_discv5],
  waku/waku_noise/noise_types,
  waku/node/[peer_manager, waku_node],
  waku/common/logging,

  # Local modules
  ./waku_handshake_utils

type WakuPairResult* = object
  wakuNode*: WakuNode
  wakuHandshakeResult*: HandshakeResult
  contentTopic*: string

proc wakuPair*(rng: ref HmacDrbgContext,
               node: WakuNode,
               qr, qrMessageNameTagHex: string,
               pubSubTopic: PubsubTopic
    ): Future[WakuPairResult] {.async.} =
  # Initiator static/ephemeral key initialization and commitment
  let initiatorInfo = initAgentKeysAndCommitment(rng)

  # Read the QR
  let
    qrMessageNameTag = fromHex(qrMessageNameTagHex)
    # We set the contentTopic from the content topic parameters exchanged in the QR
    contentTopic = initContentTopicFromQr(qr)

  notice "Initializing Waku pairing"

  notice "Initial information parsed from the QR", contentTopic = contentTopic,
      qrMessageNameTag = qrMessageNameTag

  var initiatorHSResult: HandshakeResult

  # Perform the handshake
  initiatorHSResult = await initiatorHandshake(rng, node, pubSubTopic,
                                               contentTopic, qr,
                                               qrMessageNameTag,
                                               initiatorInfo)
  return WakuPairResult(wakuNode: node,
                        wakuHandshakeResult: initiatorHSResult,
                        contentTopic: contentTopic)
