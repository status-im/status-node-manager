import
  # Nimble packages
  chronicles,
  presto/[route, segpath, server],
  stew/io2,
  serialization, json_serialization,

  # Local packages
  ./types,
  ../../[rest_constants, rest_serialization],
  ../../../waku,
  ../../../../../libs/waku_utils/waku_pair

from confutils import OutFile, `$`

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
      wakuHost.pubSubTopic = wakuPairData.pubSubTopic
      wakuHost.contentTopic = wakuPairResult.contentTopic

      notice "After pairing pubSubTopic updated: ", pubSubTopic = wakuHost.pubSubTopic
      notice "After pairing contentTopic updated: ", contentTopic = wakuHost.contentTopic

      notice "Waku pairing successful! Request fulfilled."
      return RestApiResponse.response("Successful pairing", Http200, "application/json")
    except:
      return wakuApiError(Http500, "Internal Server Error")

  router.api(MethodPost, "/waku/export/handshake"
      ) do (contentBody: Option[ContentBody]) -> RestApiResponse:
    let wakuHandshakeExportData =
      block:
        if contentBody.isNone():
          return wakuApiError(Http404, EmptyRequestBodyError)
        let dres = decodeBody(WakuExportHandshakeRequestData, contentBody.get())

        if dres.isErr():
           return wakuApiError(Http400, InvalidWakuExportHandshakeObjects)
        dres.get()
    let exportFile = OutFile(wakuHandshakeExportData.exportFile)
    try:
      let saveHandshakeRes = saveHandshakeData(wakuHost.wakuHandshake,
                                               exportFile)
      if saveHandshakeRes.isOk():
        notice "Waku Handshake Export successful! Request fulfilled."
        return RestApiResponse.response($saveHandshakeRes.get(),
                                        Http200, "application/json")
      else:
        return wakuApiError(Http500, saveHandshakeRes.error())
    except:
      return wakuApiError(Http500, "Internal Server Error")

  router.api(MethodPost, "/waku/send"
      ) do (contentBody: Option[ContentBody]) -> RestApiResponse:
    let wakuSendMessageData =
      block:
        if contentBody.isNone():
          return wakuApiError(Http404, EmptyRequestBodyError)
        let dres = decodeBody(WakuSendMessageRequestData, contentBody.get())

        if dres.isErr():
           return wakuApiError(Http400, InvalidWakuSendMessageObjects)
        dres.get()
    try:
      let wakuSendResult = wakuSendMessage(wakuHost,
                                           wakuSendMessageData.message,
                                           wakuSendMessageData.contentTopic,
                                           wakuSendMessageData.noise)

      notice "Waku message sent successfully! Request fulfilled."
      return RestApiResponse.response("Message sent successfully",
                                      Http200, "application/json")
    except:
      return wakuApiError(Http500, "Internal Server Error")
