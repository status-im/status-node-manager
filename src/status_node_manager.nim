import
  std/[strutils, typetraits],
  confutils,
  chronos,
  libp2p/crypto/crypto,
  eth/[p2p/discoveryv5/enr],
  chronicles/[log_output, topics_registry],
  waku/[waku_core]

import status_node_manager/[
    config,
    helpers/submodule # TODO: remove me
  ]

import ../libs/waku_utils/waku_pair

proc setupLogLevel*(level: LogLevel) =
  topics_registry.setLogLevel(level)

proc doWakuPairing(config: StatusNodeManagerConfig, rng: ref HmacDrbgContext) =
  let wakuPairResult = waitFor wakuPair(rng, config.qr, config.qrMessageNameTag,
                                        config.wakuPort, config.discv5Port,
                                        config.requiredConnectedPeers,
                                        config.pubSubTopic)
  echo wakuPairResult.wakuHandshakeResult

when isMainModule:
  setupLogLevel(LogLevel.NOTICE)

  let rng = crypto.newRng()

  let conf = load StatusNodeManagerConfig

  case conf.cmd
  of SNMStartUpCmd.noCommand: echo(getWelcomeMessage()) # TODO: remove me
  of SNMStartUpCmd.pair: doWakuPairing(conf, rng)

