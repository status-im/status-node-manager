import
  std/json,

  confutils, chronos,
  libp2p/crypto/crypto,
  presto/[route, segpath, server, client],
  serialization, json_serialization,
  sequtils,
  stew/byteutils,
  testutils/unittests,
  # unittest,

  ../src/status_node_manager,
  ../src/status_node_manager/[config, utils, waku],
  ../src/status_node_manager/status_node_manager_status,
  ../src/status_node_manager/rest/common,
  ../src/status_node_manager/rest/apis/waku/[
    rest_waku_api,
    rest_waku_calls,
    types
  ]

const wakuApiPort = 13100

proc startSNM(rng: ref HmacDrbgContext) =
  let conf = try: StatusNodeManagerConfig.load(cmdLine = mapIt([
    "--rest=true",
    "--rest-address=127.0.0.1",
    "--rest-port=" & $wakuApiPort,
  ], it))
  except:
    quit 1

  doRunStatusNodeManager(conf, rng)

proc runTest(wakuApiPort: Port) {.async.} =
  let client = RestClientRef.new(initTAddress("127.0.0.1", wakuApiPort))

  suite "Waku API tests":
    const testRequestData = WakuPairRequestData(
      qr: "testQr",
      qrMessageNameTag: "testQrMessageNameTag",
      pubSubTopic: "testPubSubTopic",
    )

    asyncTest "Server side is not complete, so request with correct data, it should return 500 error.":
      let
        response = await client.wakuPairPlain(testRequestData)
        responseJson = Json.decode(response.data, JsonNode)
      check:
        response.status == 500
        responseJson["message"].getStr() == "Internal Server Error"

proc delayedTests() {.async.} =
  while snmStatus != SNMStatus.Running:
    await sleepAsync(1.seconds)

  await sleepAsync(2.seconds)

  let deadline = sleepAsync(10.minutes)
  await runTest(Port(wakuApiPort)) or deadline

  snmStatus = SNMStatus.Stopping

proc main() {.async.} =
  let rng = HmacDrbgContext.new()

  asyncSpawn delayedTests()

  startSNM(rng)

waitFor main()
