import
  # Standard library
  std/[strutils, typetraits],

  # Nimble packages
  confutils, chronos,
  chronicles/[log_output, topics_registry],
  eth/p2p/discoveryv5/enr,
  libp2p/crypto/crypto,
  presto,
  waku/waku_core,

  # Local modules
  status_node_manager/[config, rest/common],
  ../libs/waku_utils/waku_pair

type SNM* = ref object
  restServer*: RestServerRef

proc init*(T: type SNM,
           config: StatusNodeManagerConfig): SNM =

  let restServer = if config.restEnabled:
    RestServerRef.init(config.restAddress, config.restPort,
                       restValidate,
                       config)
  else:
    nil

  SNM(restServer: restServer)

proc run(snm: SNM) =
  if not isNil(snm.restServer):
    snm.restServer.start()

  runForever()

proc setupLogLevel*(level: LogLevel) =
  topics_registry.setLogLevel(level)

proc doRunStatusNodeManager(config: StatusNodeManagerConfig) =
  notice "Starting Status Node Manager"

  let snm = SNM.init(config)
  snm.run()

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
  of SNMStartUpCmd.noCommand: doRunStatusNodeManager(conf)
  of SNMStartUpCmd.pair: doWakuPairing(conf, rng)

