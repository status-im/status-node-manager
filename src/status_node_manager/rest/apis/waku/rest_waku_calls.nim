import
  # Nimble packages
  chronicles,
  presto/[route, segpath, client],
  serialization, json_serialization,
  stew/byteutils,

  # Local packages
  ./types,
  ../../common,
  ../../rest_serialization

proc wakuPairPlain*(body: WakuPairRequestData): RestPlainResponse {.
    rest, endpoint: "/waku/pair",
    meth: MethodPost.}

proc wakuPair*(client: RestClientRef, wakuPairData: WakuPairRequestData) {.async.} =
  notice "Initiating Waku Pair request..."
  let
    resp = await client.wakuPairPlain(wakuPairData)
    respMsg = string.fromBytes(resp.data)
  case resp.status:
  of 200:
    notice "Waku Pair request successful", body=respMsg
  of 400, 401, 403, 404, 500:
    notice "Waku Pair request failed", status=resp.status, body=respMsg
  else:
    raiseUnknownStatusError(resp)

