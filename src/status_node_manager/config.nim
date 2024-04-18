import
  # Standard library
  std/[options],
  # Nimble packages
  confutils/defs, confutils/std/net,
  waku/waku_core,

  # Local modules
  ./network

from std/os import getHomeDir, `/`

export
  defaultSNMRestPort, defaultAdminListenAddress,
  parseCmdArg, completeCmdArg, `/`

const wakuHandshakeDataFilename* = "handshake_data.json"
const defaultWakuContentTopic* = "/snm/0.0.1/default/proto"
const defaultWakuPubsubTopic* = "/waku/2/default-waku/proto"

type
  SNMStartUpCmd* {.pure.} = enum
    noCommand,
    waku,

  WakuCommand* {.pure.} = enum
    pair,
    exportHandshake,
    sendMessage

type
  StatusNodeManagerConfig* = object
    dataDir* {.
      desc: "The directory where status node manager will store all data"
      defaultValue: config.defaultDataDir()
      defaultValueDesc: ""
      abbr: "d"
      name: "data-dir" .}: OutDir

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

      wakuHandshakeFile* {.
        desc: "The file to read & write the waku handshake data"
        defaultValue: config.defaultWakuHandshakeFilePath()
        name: "waku-handshake-file" .}: string

    of SNMStartUpCmd.waku:
      case wakuCmd* {.command.}: WakuCommand

      of WakuCommand.pair:
        qr* {.
          desc: "A string representation of the QR code produced by the GUI"
          name: "qr" .}: string

        qrMessageNameTag* {.
          desc: "A string representation of the initial message nametag produced" &
                "by the GUI. It is used for the initial hadnshake message"
          name: "qr-message-nametag" .}: string

        pubSubTopic* {.
          desc: "The topic to subscribe to"
          name: "pubsub-topic" .}: Option[PubsubTopic]

      of WakuCommand.exportHandshake:
        handshakeFile* {.
          desc: "The file to export the waku handshake result to"
          defaultValue: config.defaultWakuHandshakeFilePath()
          name: "handshake-file" .}: OutFile

      of WakuCommand.sendMessage:
        message* {.
          desc: "The message to send"
          name: "message" .}: string

        contentTopic* {.
          desc: "The topic to send the message to"
          name: "content-topic" .}: Option[string]

proc defaultDataDir*[Conf](config: Conf): string =
  let dataDir = when defined(windows):
    "AppData" / "Roaming" / "StatusNodeManager"
  elif defined(macosx):
    "Library" / "Application Support" / "StatusNodeManager"
  else:
    ".cache" / "StatusNodeManager"

  getHomeDir() / dataDir

proc defaultWakuHandshakeFilePath*[Conf](config: Conf): string =
  config.defaultDataDir() / "waku" / wakuHandshakeDataFilename
