import
  # Standard library
  std/[typetraits],
  presto/[client],

  # Nimble packages
  chronos, confutils, presto, metrics,
  chronicles, stew/io2,

  # Project modules
  ../config

func restValidate*(key: string, value: string): int =
  0

proc init*(T: type RestServerRef,
           ip: IpAddress,
           port: Port,
           validateFn: PatternCallback,
           config: StatusNodeManagerConfig): T =
  let
    address = initTAddress(ip, port)
    serverFlags = {HttpServerFlags.QueryCommaSeparatedArray,
                   HttpServerFlags.NotifyDisconnect}
  let
    headersTimeout =
      if config.restRequestTimeout == 0:
        chronos.InfiniteDuration
      else:
        seconds(int64(config.restRequestTimeout))
    maxHeadersSize = config.restMaxRequestHeadersSize * 1024
    maxRequestBodySize = config.restMaxRequestBodySize * 1024

  let res = RestServerRef.new(RestRouter.init(validateFn),
                              address, serverFlags = serverFlags,
                              httpHeadersTimeout = headersTimeout,
                              maxHeadersSize = maxHeadersSize,
                              maxRequestBodySize = maxRequestBodySize,
                              errorType = string)
  if res.isErr():
    notice "REST HTTP server could not be started", address = $address,
           reason = res.error()
    nil
  else:
    let server = res.get()
    notice "Starting REST HTTP server", url = "http://" & $server.localAddress()
    server

proc raiseUnknownStatusError*(resp: RestPlainResponse) {.
     noreturn, raises: [RestError].} =
  let msg = "Unknown response status error (" & $resp.status & ")"
  raise newException(RestError, msg)

template unrecognizedFieldWarning* =
  trace "JSON field not recognized by the current version of Status Node Manager. Consider upgrading",
        fieldName, typeName = typetraits.name(typeof value)
