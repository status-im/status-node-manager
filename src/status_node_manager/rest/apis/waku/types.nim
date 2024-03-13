import waku/waku_core

type WakuPairRequestData* = object
  qr*: string
  qrMessageNameTag*: string
  pubSubTopic*: PubsubTopic
