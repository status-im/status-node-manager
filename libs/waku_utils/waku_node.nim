import
  # Standard library
  std/[tables, sequtils],

  # Nimble packages
  stew/shims/net,
  chronicles, chronos, confutils,
  libp2p/crypto/crypto,
  eth/[keys, p2p/discoveryv5/enr],

  # Nimble packages - Waku
  waku/[waku_core, waku_node, waku_enr, waku_discv5],
  waku/factory/builder,
  waku/node/peer_manager,
  waku/common/[logging, protobuf]

proc startWakuNode*(rng: ref HmacDrbgContext,
                    wakuPort, discv5Port: uint16,
                    requiredConnectedPeers: int,
                    bootstrapNode: string
    ): Future[WakuNode] {.async.} =
  let
    nodeKey = crypto.PrivateKey.random(Secp256k1, rng[]).get()
    ip = parseIpAddress("0.0.0.0")
    flags = CapabilitiesBitfield.init(lightpush = false, filter = false,
                                      store = false, relay = true)

  var enrBuilder = EnrBuilder.init(nodeKey)

  let recordRes = enrBuilder.build()
  let record =
    if recordRes.isErr():
      error "failed to create enr record", error = recordRes.error
      quit(QuitFailure)
    else: recordRes.get()

  var builder = WakuNodeBuilder.init()
  builder.withNodeKey(nodeKey)
  builder.withRecord(record)
  builder.withNetworkConfigurationDetails(ip, Port(wakuPort)).tryGet()

  let node = builder.build().tryGet()
  var bootstrapNodeEnr: enr.Record
  discard bootstrapNodeEnr.fromURI(bootstrapNode)

  let discv5Conf = WakuDiscoveryV5Config(discv5Config: none(DiscoveryConfig),
                                         address: ip, port: Port(discv5Port),
                                         privateKey: keys.PrivateKey(nodeKey.skkey),
                                         bootstrapRecords: @[bootstrapNodeEnr],
                                         autoupdateRecord: true)

  # assumes behind a firewall, so not care about being discoverable
  let wakuDiscv5 = WakuDiscoveryV5.new(node.rng, discv5Conf, some(node.enr),
                                       some(node.peerManager),
                                       node.topicSubscriptionQueue)

  notice "Starting Waku Node", enr=bootstrapNode, wakuPort=wakuPort,
      discv5Port=discv5Port

  await node.start()
  await node.mountRelay()
  node.peerManager.start()

  (await wakuDiscv5.start()).isOkOr:
    error "Failed to start discv5", error = error
    quit(1)

  # Wait for a minimum of peers to be connected, otherwise messages wont be gossiped
  while true:
    let numConnectedPeers = node.peerManager.peerStore[
        ConnectionBook].book.values().countIt(it == Connected)
    if numConnectedPeers >= requiredConnectedPeers:
      notice "Waku Node is ready", connectedPeers = numConnectedPeers,
          required = requiredConnectedPeers
      break
    notice "Waiting for the waku node to be ready",
        connectedPeers = numConnectedPeers, required = requiredConnectedPeers
    await sleepAsync(5000)

  return node
