import
  # Nimble packages
  chronos,
  eth/[p2p/discoveryv5/enr],
  httputils,
  libp2p/crypto/crypto,
  metrics,
  results,
  stew/io2, stew/byteutils,

  # Nimble packages - Waku
  waku/waku_core,
  waku/utils/noise,
  waku/waku_noise/noise_types,
  waku/waku_noise/noise_handshake_processing,

  # Local modules
  ./utils

proc prepareMessage*(message: string, contentTopic: string): Result[WakuMessage, cstring] =
  let
    payload = toBytes(message)
    msg = WakuMessage(payload: toBytes(message),
                      contentTopic: contentTopic,
                      ephemeral: true,
                      timestamp: now())

  ok(msg)

proc prepareMessageWithHandshake*(message: string,
                                  contentTopic: string,
                                  hs: var HandshakeResult): Result[WakuMessage, cstring] =
  let
    byteMessage = toBytes(message)
    payload = writeMessage(hs, byteMessage, hs.nametagsOutbound)
    wakuMessage = encodePayloadV2(payload, contentTopic)

  wakuMessage
