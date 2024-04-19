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
  config: StatusNodeManagerConfig
  restServer*: RestServerRef
  wakuHost*: ref WakuHost

proc init*(T: type SNM,
           rng: ref HmacDrbgContext,
           config: StatusNodeManagerConfig): Future[SNM] {.async.} =
  # Waku node setup
  let wakuHost = await WakuHost.init(rng, config)

  # Rest server setup
  let restServer = if config.restEnabled:
    RestServerRef.init(config.restAddress, config.restPort,
                       restValidate,
                       config)
  else:
    nil

  SNM(config: config,
      restServer: restServer,
      wakuHost: newClone wakuHost)

proc stop(snm: SNM) =
  snmStatus = SNMStatus.Stopping
  notice "Graceful shutdown"

  let wakuHandshakeFile = OutFile(snm.config.wakuHandshakeFile)
  let saveRes = saveHandshakeData(snm.wakuHost.wakuHandshake, wakuHandshakeFile)
  if saveRes.isOk():
    notice "Waku handshake data saved to file", path = $saveRes.get
  else:
    warn "Failed to save handshake data to file", reason = saveRes.error()

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

  ## Ctrl+C handling
  proc controlCHandler() {.noconv.} =
    when defined(windows):
      # workaround for https://github.com/nim-lang/Nim/issues/4057
      try:
        setupForeignThreadGc()
      except Exception as exc: raiseAssert exc.msg # shouldn't happen
    notice "Shutting down after having received SIGINT"
    snmStatus = SNMStatus.Stopping
  try:
    setControlCHook(controlCHandler)
  except Exception as exc: # TODO Exception
    warn "Cannot set ctrl-c handler", msg = exc.msg

  let snm = waitFor SNM.init(rng, config)
  waitFor snm.run()

proc doWakuPairing(config: StatusNodeManagerConfig,
                   rng: ref HmacDrbgContext,
                   wakuClient: var RestClientRef) =
  let pubsubTopic = if config.pubsubTopic.isSome:
    config.pubsubTopic.get
  else:
    defaultWakuPubsubTopic

  let wakuPairRequestData = WakuPairRequestData(
    qr: config.qr,
    qrMessageNameTag: config.qrMessageNameTag,
    pubSubTopic: pubSubTopic
  )

  waitFor wakuPair(wakuClient, wakuPairRequestData)

proc doWakuHandshakeExport(config: StatusNodeManagerConfig,
                           wakuClient: var RestClientRef) =
  let requestData =
    WakuExportHandshakeRequestData(exportFile: $config.handshakeFile)
  waitFor wakuExportHandshake(wakuClient, requestData)

proc doWakuSendMessage(config: StatusNodeManagerConfig,
                       wakuClient: var RestClientRef) =
  let contentTopic = if config.contentTopic.isSome:
    config.contentTopic.get
  else:
    defaultWakuContentTopic

  let requestData = WakuSendMessageRequestData(
    message: config.message,
    contentTopic: contentTopic
  )

  waitFor wakuSendMessage(wakuClient, requestData)

proc doWakuCommand(config: StatusNodeManagerConfig, rng: ref HmacDrbgContext) =
  var wakuClient = RestClientRef.new(initTAddress(config.restAddress,
                                                  config.restPort))
  case config.wakuCmd
  of WakuCommand.pair:
    doWakuPairing(config, rng, wakuClient)
  of WakuCommand.exportHandshake:
    doWakuHandshakeExport(config, wakuClient)
  of WakuCommand.sendMessage:
    doWakuSendMessage(config, wakuClient)

when isMainModule:
  setupLogLevel(LogLevel.NOTICE)

  let rng = crypto.newRng()

  let conf = load StatusNodeManagerConfig

  case conf.cmd
  of SNMStartUpCmd.noCommand: doRunStatusNodeManager(conf, rng)
  of SNMStartUpCmd.waku: doWakuCommand(conf, rng)

