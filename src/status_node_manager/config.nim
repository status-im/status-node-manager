import
  # Nimble packages
  confutils/defs, confutils/std/net,
  waku/waku_core,

  # Local modules
  ./network

export
  defaultSNMRestPort, defaultAdminListenAddress,
  parseCmdArg, completeCmdArg

type
  SNMStartUpCmd* {.pure.} = enum
    noCommand,
    pair,

type
  StatusNodeManagerConfig* = object
    restEnabled* {.
      desc: "Enable the REST server"
      defaultValue: true
      name: "rest" .}: bool

    restPort* {.
      desc: "Port for the REST server"
      defaultValue: defaultSNMRestPort
      defaultValueDesc: $defaultSNMRestPortDesc
      name: "rest-port" .}: Port

    restAddress* {.
      desc: "Listening address of the REST server"
      defaultValue: defaultAdminListenAddress
      defaultValueDesc: $defaultAdminListenAddressDesc
      name: "rest-address" .}: IpAddress

    restRequestTimeout* {.
      defaultValue: 0
      defaultValueDesc: "infinite"
      desc: "The number of seconds to wait until complete REST request " &
            "will be received"
      name: "rest-request-timeout" .}: Natural

    restMaxRequestBodySize* {.
      defaultValue: 16_384
      desc: "Maximum size of REST request body (kilobytes)"
      name: "rest-max-body-size" .}: Natural

    restMaxRequestHeadersSize* {.
      defaultValue: 128
      desc: "Maximum size of REST request headers (kilobytes)"
      name: "rest-max-headers-size" .}: Natural

    case cmd* {.
      command
      defaultValue: SNMStartUpCmd.noCommand .}: SNMStartUpCmd

    of SNMStartUpCmd.noCommand:
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

    of SNMStartUpCmd.pair:
      qr* {.
        desc: "A string representation of the QR code produced by the GUI"
        name: "qr" .}: string

      qrMessageNameTag* {.
        desc: "A string representation of the initial message nametag produced" &
              "by the GUI. It is used for the initial hadnshake message"
        name: "qr-message-nametag" .}: string

      pubSubTopic* {.
        desc: "The topic to subscribe to"
        defaultValue: "/waku/2/default-waku/proto"
        name: "pubsub-topic" .}: PubsubTopic
