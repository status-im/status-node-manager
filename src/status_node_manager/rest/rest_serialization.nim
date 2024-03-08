import
  # Standard library
  std/sets,

  # Nimble packages
  chronos, stew/byteutils,
  presto/[route, segpath, server, client],
  json_serialization,
  serialization

const ApplicationJsonMediaType* = MediaType.init("application/json")

createJsonFlavor RestJson

RestJson.useDefaultSerializationFor(
  auto
  )

type
  DecodeTypes* =
    auto

type
  EncodeTypes* =
    auto

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
