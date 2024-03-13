import
  # Standard library
  std/[strutils, typetraits],

  # Nimble packages
  confutils, chronos,
  chronicles/[log_output, topics_registry],
  eth/p2p/discoveryv5/enr,
  libp2p/crypto/crypto,
  presto/[route, segpath, server, client],
  waku/waku_core,

  # Local modules
  status_node_manager/[config, waku, utils],
  status_node_manager/status_node_manager_status,
  status_node_manager/rest/common,
  status_node_manager/rest/apis/waku/[types, rest_waku_calls, rest_waku_api],
  ../libs/waku_utils/waku_node

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

proc stop(snm: SNM) =
  snmStatus = SNMStatus.Stopping
  notice "Graceful shutdown"

proc installRestHandlers(restServer: RestServerRef, snm: SNM) =
  restServer.router.installWakuApiHandlers(snm.wakuHost)

proc run(snm: SNM) {.async.} =
  snmStatus = SNMStatus.Running

  if not isNil(snm.restServer):
    snm.restServer.installRestHandlers(snm)
    snm.restServer.start()

  while snmStatus == SNMStatus.Running:
    poll()

  snm.stop()

proc setupLogLevel*(level: LogLevel) =
  topics_registry.setLogLevel(level)

proc doRunStatusNodeManager*(config: StatusNodeManagerConfig,
                             rng: ref HmacDrbgContext) =
  notice "Starting Status Node Manager"

  let snm = waitFor SNM.init(rng, config)
  waitFor snm.run()

proc doWakuPairing(config: StatusNodeManagerConfig, rng: ref HmacDrbgContext) =
  var wakuClient = RestClientRef.new(initTAddress(config.restAddress,
                                                  config.restPort))

  let wakuPairRequestData = WakuPairRequestData(
    qr: config.qr,
    qrMessageNameTag: config.qrMessageNameTag,
    pubSubTopic: config.pubSubTopic
  )

  waitFor wakuPair(wakuClient, wakuPairRequestData)

when isMainModule:
  setupLogLevel(LogLevel.NOTICE)

  let rng = crypto.newRng()

  let conf = load StatusNodeManagerConfig

  case conf.cmd
  of SNMStartUpCmd.noCommand: doRunStatusNodeManager(conf, rng)
  of SNMStartUpCmd.pair: doWakuPairing(conf, rng)

