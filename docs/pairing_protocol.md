# Status Node Manager Pairing Protocol

## Introduction

This documents provides a high-level outline of the pairing protocol that is used to establish a persistent connection between the Nimbus GUI app and the Status node manager. The connection can be established even when both of the endpoints lack public IP addresses and can be maintained without re-configuration even after arbitrary changes to their physical locations. These properties are achieved through the use of the [Waku2 communication protocol](https://rfc.vac.dev/spec/10/).

## Pairing procedure

The protocol involves the following steps:

1) The user initiates the pairing procedure in the GUI app.
2) The app generates a 64-bit random number `P`.
3) Using this number and a key derivation function `kdf(x, salt)`, the app derives a Waku topic name `T = kdf(P, TOPIC_SALT)` and a handshake key `HS = kdf(P, HANDSHAKE_KEY_SALT)`. `TOPIC_SALT` and `HANDSHAKE_KEY_SALT` are protocol constants.
4) The app connects to the Waku network using identity key `APP_IDENTITY` and starts listening for messages sent to the `T` topic.
5) The user enters the same number on the machine where the Status node manager is running and the node manager is able to derive the same values for `T` and `HS`.
6) The node manager connects to the Waku network using identity key `NODE_MANAGER_IDENTITY` and sends a message `HELLO_APP = encrypt(HS, node_manager_identity)` to the `T` topic.
7) The app receives the `HELLO_APP` messages and successfully decrypts it using `HS`. The app persists `NODE_MANAGER_IDENTITY` in its local storage.
8) The app responds by sending the message `HELLO_NODE_MANAGER = encrypt(HS, app_identity)` on the `T` topic.
9) The node manager receives the `HELLO_NODE_MANAGER` message and successfully decrypts it using `HS`. The node manager persists `APP_IDENTITY` in its local storage.
10) The node manager tries to establish a [Waku Noise Session](https://rfc.vac.dev/spec/37/) using the app identity key. The app accepts the session.
11) On every consecutive start-up, both sides immediately try to establish noise sessions with all of their persisted counterparties. Incoming sessions from known counterparties are accepted.
