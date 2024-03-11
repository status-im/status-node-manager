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
  status_node_manager/[config, waku, utils],
  status_node_manager/rest/common

type SNM* = ref object
  restServer*: RestServerRef
  wakuHost*: ref WakuHost

proc init*(T: type SNM,
           rng: ref HmacDrbgContext,
           config: StatusNodeManagerConfig): Future[SNM] {.async.} =
  # Waku node setup
  let wakuNodeParams = WakuNodeParams(wakuPort: config.wakuPort,
                                      discv5Port: config.discv5Port,
                                      requiredConnectedPeers: config.requiredConnectedPeers)
  let wakuHost = await WakuHost.init(rng, wakuNodeParams)

  # Rest server setup
  let restServer = if config.restEnabled:
    RestServerRef.init(config.restAddress, config.restPort,
                       restValidate,
                       config)
  else:
    nil

  SNM(restServer: restServer,
      wakuHost: newClone wakuHost)

proc run(snm: SNM) =
  if not isNil(snm.restServer):
    snm.restServer.start()

  runForever()

proc setupLogLevel*(level: LogLevel) =
  topics_registry.setLogLevel(level)

proc doRunStatusNodeManager(config: StatusNodeManagerConfig,
                            rng: ref HmacDrbgContext) =
  notice "Starting Status Node Manager"

  let snm = waitFor SNM.init(rng, config)
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
  of SNMStartUpCmd.noCommand: doRunStatusNodeManager(conf, rng)
  of SNMStartUpCmd.pair: doWakuPairing(conf, rng)

