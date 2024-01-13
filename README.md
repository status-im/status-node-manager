# Status Node Manager

The Status node manager is the back-end service for the [Nimbus node management GUI](https://github.com/status-im/nimbus-gui).
The GUI is focused to the [Nimbus consensus layer](https://nimbus.guide) at the moment, but it will eventually support other [Logos](https://logos.co) node types, such as [Nimbus EL](https://github.com/status-im/nimbus-eth1), [Fluffy](https://fluffy.guide), [Codex](https://github.com/codex-storage/nim-codex), [Waku](https://github.com/waku-org) and [Nomos](https://github.com/logos-co/nomos-node).

## Configuration

The GUI app connects to the node manager through the Waku protocol. This ensures that a persistent pairing between the two can be established without any networking configuration (i.e. the user doesn't have to specify IP addresses and ports of the running Nimbus instances) and that not even metadata regarding the connection is leaked to anyone. The locally running Nimbus node can bind its REST API and metrics port to localhost and the Status node manager can make them available to the GUI through a HTTP-over-Waku transport.

The [pairing protocol](./docs/pairing_protocol.md) is very simple: The user clicks on a "Connect to Node Manager" button in the GUI which generates a random numeric ID. The user can then simply run the command `nimbus pair <random-id>` on the host where the node manager is installed to complete the process.

## Functionality

Once configured, the node manager supports the following functionality:

  - [ ] It allows the user to manage the set of validator keys on the managed nodes (including the ability to generate and execute deposit transactions in order to create new validators).
  - [ ] It provides access to the REST APIs and metrics of the managed nodes. It delivers useful notifications, alerts and actionable diagnostic information that can help the user maintain the optimal performance of their validators.
  - [ ] It keeps track of new releases of the Nimbus consensus layer and its own command-line management utilities.
  - [ ] It can upgrade and roll-back any of the above components in zero-downtime fashion. The initial version of the zero-downtime upgrade procedure will take advantage of the "time to next action" metric of the Nimbus beacon node.
  - [ ] It can perform upgrades automatically. The user is free to enable or disable this policy and also to specify an upgrade delay period (e.g. 2 weeks) in order to allow for potential problems to be discovered by more active early adopters.
  - [ ] The user can remotely start new Nimbus nodes connected to different networks (e.g. testnets). The Status node manager then either acts as a simple supervisor for the started processes or it can leverage Systemd for the same purpose.
