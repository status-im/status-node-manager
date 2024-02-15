import
  options,
  confutils/defs

import waku/waku_core

type
  SNMStartUpCmd* {.pure.} = enum
    noCommand,
    pair,

type
  StatusNodeManagerConfig* = object
    case cmd* {.
      command
      defaultValue: SNMStartUpCmd.noCommand .}: SNMStartUpCmd

    of SNMStartUpCmd.noCommand:
      discard

    of SNMStartUpCmd.pair:
      qr* {.
        desc: "A string representation of the QR code produced by the GUI"
        name: "qr" .}: string

      qrMessageNameTag* {.
        desc: "A string representation of the initial message nametag produced" &
              "by the GUI. It is used for the initial hadnshake message"
        name: "qr-message-nametag" .}: string

      wakuPort* {.
        desc: "The port to use for the Waku node"
        defaultValue: 60000
        name: "waku-port" .}: uint16

      discv5Port* {.
        desc: "The port to use for the Discv5"
        defaultValue: 9999
        name: "discv5-port" .}: uint16

      requiredConnectedPeers* {.
        desc: "The number of peers to connect to before starting the Waku node"
        defaultValue: 2
        name: "required-connected-peers" .}: int

      pubSubTopic* {.
        desc: "The topic to subscribe to"
        defaultValue: "/waku/2/default-waku/proto"
        name: "pubsub-topic" .}: PubsubTopic
