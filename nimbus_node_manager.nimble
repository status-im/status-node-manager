# Package

version       = "0.1.0"
author        = "Emil Ivanichkov"
description   = "Nimbus Node Manager"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["nimbus_node_manager"]


# Dependencies

requires "nim >= 1.6.14",
    "waku",
    "libp2p#head",
    "unittest2 == 0.2.1",
    "confutils#head",
    "serialization",
    "untar",
    "presto",
    "stew",
    "chronos#head",
    "nimcrypto",
    "eth",
    "prompt",
    "chronicles",
    "metrics",
    "https://github.com/status-im/nim-dnsdisc",
    "web3#428b931e7c4f1284b4272bc2c11fca2bd70991cd"
