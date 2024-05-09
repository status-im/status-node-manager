import waku/waku_core

type WakuPairRequestData* = object
  qr*: string
  qrMessageNameTag*: string
  pubSubTopic*: PubsubTopic

type WakuExportHandshakeRequestData* = object
  exportFile*: string

type WakuSendMessageRequestData* = object
  message*: string
  contentTopic*: string
  noise*: bool
