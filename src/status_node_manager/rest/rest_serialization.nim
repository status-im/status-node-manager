import
  # Standard library
  std/[sets, strformat],

  # Nimble packages
  chronos,
  presto/[route, segpath, server, client],
  json_serialization,
  nimcrypto,
  serialization,
  stew/byteutils,
  waku/waku_noise/noise_types,

  # Local modules
  ./apis/waku/types,
  ./common

const ApplicationJsonMediaType* = MediaType.init("application/json")

createJsonFlavor RestJson

RestJson.useDefaultSerializationFor(
  WakuPairRequestData,
  WakuExportHandshakeRequestData,
  HandshakeResult,
  CipherState,
  )

type
  DecodeTypes* =
    WakuPairRequestData |
    WakuExportHandshakeRequestData |
    HandshakeResult |
    CipherState |
    MDigest[256]

type
  EncodeTypes* =
    WakuPairRequestData |
    WakuExportHandshakeRequestData |
    HandshakeResult |
    CipherState |
    MDigest[256]

proc writeValue*(writer: var JsonWriter[RestJson], value: MessageNametagBuffer)
    {.raises: [IOError].} =
  writer.beginRecord()
  writer.writeField("buffer", value.buffer)
  writer.writeField("counter", value.counter)
  if value.secret.isSome():
    writer.writeField("secret", value.secret.get())
  writer.endRecord()

proc writeValue*(writer: var JsonWriter[RestJson], value: MDigest[256])
    {.raises: [IOError].} =
  writer.beginRecord()
  writer.writeField("data", value.data)
  writer.endRecord()

proc readValue*(reader: var JsonReader[RestJson], value: var MessageNametagBuffer)
    {.raises: [SerializationError, IOError].} =
  var
    buffer = none(array[MessageNametagBufferSize, MessageNametag])
    counter = none(uint64)
    secret = none(array[MessageNametagSecretLength, byte])

  var keys = initHashSet[string]()
  for fieldName in readObjectFields(reader):
    # Check for reapeated keys
    if keys.containsOrIncl(fieldName):
      let err = try: fmt"Multiple `{fieldName}` fields found"
                except CatchableError: "Multiple fields with the same name found"
      reader.raiseUnexpectedField(err, "FilterWakuMessage")

    case fieldName
    of "buffer":
      buffer = some(reader.readValue(array[MessageNametagBufferSize, MessageNametag]))
    of "counter":
      counter = some(reader.readValue(uint64))
    of "secret":
      secret = some(reader.readValue(array[MessageNametagSecretLength, byte]))
    else:
      unrecognizedFieldWarning()

  value = MessageNametagBuffer(
    buffer: buffer.get(),
    counter: counter.get(),
    secret: secret,
  )

proc readValue*(reader: var JsonReader[RestJson], value: var MDigest[256])
    {.raises: [SerializationError, IOError].} =
  var
    data = none(array[256 div 8, byte])
  var keys = initHashSet[string]()
  for fieldName in readObjectFields(reader):
    if keys.containsOrIncl(fieldName):
      let err = try: fmt"Multiple `{fieldName}` fields found"
                except CatchableError: "Multiple fields with the same name found"
      reader.raiseUnexpectedField(err, "FilterWakuMessage")

    case fieldName
    of "data":
      data = some(reader.readValue(array[256 div 8, byte]))
    else:
      unrecognizedFieldWarning()

  value = MDigest[256](
    data: data.get(),
  )

proc jsonResponsePlain*(t: typedesc[RestApiResponse],
                        data: auto): RestApiResponse =
  let res =
    block:
      var default: seq[byte]
      try:
        var stream = memoryOutput()
        var writer = JsonWriter[RestJson].init(stream)
        writer.writeValue(data)
        stream.getOutput(seq[byte])
      except SerializationError:
        default
      except IOError:
        default
  RestApiResponse.response(res, Http200, "application/json")

proc encodeBytes*[T: EncodeTypes](value: T,
                                  contentType: string): RestResult[seq[byte]] =
  case contentType
  of "application/json":
    let data =
      block:
        try:
          var stream = memoryOutput()
          var writer = JsonWriter[RestJson].init(stream)
          writer.writeValue(value)
          stream.getOutput(seq[byte])
        except IOError:
          return err("Input/output error")
        except SerializationError:
          return err("Serialization error")
    ok(data)
  else:
    err("Content-Type not supported")

proc decodeBytes*[T: DecodeTypes](t: typedesc[T],
                                  value: openArray[byte],
                                  contentType: Opt[ContentTypeData]
    ): RestResult[T] =

  let mediaType =
    if contentType.isNone():
      ApplicationJsonMediaType
    else:
      if isWildCard(contentType.get().mediaType):
        return err("Incorrect Content-Type")
      contentType.get().mediaType

  if mediaType == ApplicationJsonMediaType:
    try:
      ok RestJson.decode(value, T,
                         requireAllFields = true,
                         allowUnknownFields = true)
    except SerializationError as exc:
      debug "Failed to deserialize REST JSON data",
            err = exc.formatMsg("<data>"),
            data = string.fromBytes(value)
      err("Serialization error")
  else:
    err("Content-Type not supported")

proc decodeBody*[T](t: typedesc[T],
                    body: ContentBody): Result[T, cstring] =
  if body.contentType != ApplicationJsonMediaType:
    return err("Unsupported content type")
  let data =
    try:
      RestJson.decode(body.data, T,
                      requireAllFields = true,
                      allowUnknownFields = true)
    except SerializationError as exc:
      debug "Failed to deserialize REST JSON data",
            err = exc.formatMsg("<data>"),
            data = string.fromBytes(body.data)
      return err("Unable to deserialize data")
    except CatchableError:
      return err("Unexpected deserialization error")
  ok(data)
