
import
  # Nimble packages
  chronos,
  eth/[p2p/discoveryv5/enr],
  libp2p/crypto/crypto,
  metrics,

  # Nimble packages - Waku
  waku/node/waku_node,
  waku/waku_noise/noise_types,

  # Local modules
  ../libs/waku_utils/waku_node

type
  WakuNodeParams* = object
    wakuPort*: uint16
    discv5Port*: uint16
    requiredConnectedPeers*: int

  WakuHost* = object
    rng*: ref HmacDrbgContext
    wakuNode*: WakuNode
    wakuHandshake*: HandshakeResult

proc init*(T: type WakuHost,
           rng: ref HmacDrbgContext,
           wakuNodeParams: WakuNodeParams): Future[WakuHost] {.async.}=
  let node = await startWakuNode(rng, wakuNodeParams.wakuPort,
                                 wakuNodeParams.discv5Port,
                                 wakuNodeParams.requiredConnectedPeers)
  T(rng: rng,
    wakuNode: node)
