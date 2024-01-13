# Package

version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "Back-end service for the Status node management GUI"
license       = "MIT or Apache License 2.0"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["status_node_manager"]

# Dependencies

requires "nim >= 1.6.14",
    "waku",
    "libp2p",
    "unittest2 >= 0.2.1",
    "confutils",
    "serialization",
    "untar",
    "presto",
    "stew",
    "chronos",
    "nimcrypto",
    "eth",
    "prompt",
    "chronicles",
    "metrics",
    "dnsdisc",
    "web3"
