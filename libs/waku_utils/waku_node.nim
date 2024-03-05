import
  std/[tables, sequtils],
  stew/shims/net,
  chronicles,
  chronos,
  confutils,
  libp2p/crypto/crypto,
  eth/[keys, p2p/discoveryv5/enr]

import
  waku/[waku_core, waku_node, waku_enr, waku_discv5],
  waku/factory/builder,
  waku/node/peer_manager,
  waku/common/[logging, protobuf]

proc startWakuNode*(rng: ref HmacDrbgContext,
                    wakuPort, discv5Port: uint16,
                    requiredConnectedPeers: int
    ): Future[WakuNode] {.async.} =
  let
    bootstrapNode = "enr:-P-4QGVNANzbhCI49du6Moyw98AjuMhKoOpE_Jges9JlCq-I" &
                    "CAVadktjfcNpuhQgT0g1cu86_S3nbM7eYkCsqDAQG7UBgmlkgnY0" &
                    "gmlwhI_G-a6KbXVsdGlhZGRyc7hgAC02KG5vZGUtMDEuZG8tYW1z" &
                    "My5zdGF0dXMucHJvZC5zdGF0dXNpbS5uZXQGdl8ALzYobm9kZS0w" &
                    "MS5kby1hbXMzLnN0YXR1cy5wcm9kLnN0YXR1c2ltLm5ldAYBu94D" &
                    "iXNlY3AyNTZrMaECoVyonsTGEQvVioM562Q1fjzTb_vKD152PPId" &
                    "sV7sM6SDdGNwgnZfg3VkcIIjKIV3YWt1Mg8"
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
      notice "Node is ready", connectedPeers = numConnectedPeers,
          required = requiredConnectedPeers
      break
    notice "Waiting for the node to be ready",
        connectedPeers = numConnectedPeers, required = requiredConnectedPeers
    await sleepAsync(5000)

  return node
