import
  # Nimble packages
  chronicles,
  presto/[route, segpath, server],
  serialization, json_serialization,

  # Local packages
  ./types,
  ../../[rest_constants, rest_serialization],
  ../../../waku,
  ../../../../../libs/waku_utils/waku_pair

proc wakuApiError(status: HttpCode, msg: string): RestApiResponse =
  let data =
    block:
      var default: string
      try:
        var stream = memoryOutput()
        var writer = JsonWriter[RestJson].init(stream)
        writer.beginRecord()
        writer.writeField("message", msg)
        writer.endRecord()
        stream.getOutput(string)
      except SerializationError:
        default
      except IOError:
        default
  RestApiResponse.error(status, data, "application/json")

proc installWakuApiHandlers*(router: var RestRouter,
                             wakuHost: ref WakuHost) =
  router.api(MethodPost, "/waku/pair"
      ) do (contentBody: Option[ContentBody]) -> RestApiResponse:
    let wakuPairData =
      block:
        if contentBody.isNone():
          return wakuApiError(Http404, EmptyRequestBodyError)
        let dres = decodeBody(WakuPairRequestData, contentBody.get())

        if dres.isErr():
           return wakuApiError(Http400, InvalidWakuPairObjects)
        dres.get()
    try:
      let wakuPairResult = await wakuPair(wakuHost[].rng,
                                          wakuHost[].wakuNode,
                                          wakuPairData.qr,
                                          wakuPairData.qrMessageNameTag,
                                          wakuPairData.pubSubTopic)

      wakuHost.wakuNode = wakuPairResult.wakuNode
      wakuHost.wakuHandshake = wakuPairResult.wakuHandshakeResult

      notice "Waku pairing successful! Request fulfilled."
      return RestApiResponse.response("Successful pairing", Http200, "application/json")
    except:
      return wakuApiError(Http500, "Internal Server Error")

