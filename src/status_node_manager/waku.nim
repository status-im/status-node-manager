
import
  # Standard library
  std/os,

  # Nimble packages
  chronos, chronicles,
  eth/[p2p/discoveryv5/enr],
  httputils,
  libp2p/crypto/crypto,
  metrics,
  results,
  serialization, json_serialization,
  stew/io2,

  # Nimble packages - Waku
  waku/node/waku_node,
  waku/waku_noise/noise_types,

  # Local modules
  ../libs/waku_utils/waku_node,
  ./rest/rest_serialization,
  ./filepaths

from confutils import OutFile, `$`

type
  WakuNodeParams* = object
    wakuPort*: uint16
    discv5Port*: uint16
    requiredConnectedPeers*: int

  WakuHost* = object
    rng*: ref HmacDrbgContext
    wakuNode*: WakuNode
    wakuHandshake*: HandshakeResult

proc saveHandshakeData*(handshakeResult: HandshakeResult,
                        handshakeDataFile: OutFile): Result[OutFile, string] =
  if handshakeResult == HandshakeResult():
    warn "There is no waku handshake data to save"
    return err("There is no waku handshake data to save")

  let encodedHS = encodeBytes(handshakeResult,
                              "application/json").valueOr:
    error "Unable to serialize handshake result", reason = error
    return err("Unable to serialize handshake result. Reason: " & $error)

  let
    (dir, file) = os.splitPath($handshakeDataFile)
    wakuDirRes = secureCreatePath(dir)

  if wakuDirRes.isErr:
    warn "Failed to create waku data dir", path = dir, err = $wakuDirRes.error
    return err("Failed to create waku data dir, Reason: " & $wakuDirRes.error)

  let writeHSFileRes = secureWriteFile($handshakeDataFile, encodedHS)
  if writeHSFileRes.isErr:
    warn "Failed to write waku handshake data file",
        path = $handshakeDataFile, err = $writeHSFileRes.error
    return err("Failed to write waku handshake data file, Reason: " &
               $writeHSFileRes.error)

  notice "Waku handshake data saved to file", path = $handshakeDataFile
  ok(handshakeDataFile)

proc loadHandshakeData*(handshakeDataFile: OutFile
    ): Result[HandshakeResult, string] =
  let fileExists = isFile($handshakeDataFile)
  if not fileExists:
    warn "Waku handshake data file does not exist. New pairing is required"
    return err("Waku handshake data file does not exist. New pairing is required")

  let readHSFileRes = readAllFile($handshakeDataFile)

  if readHSFileRes.isErr:
    warn "Failed to read waku handshake data file",
        path = $handshakeDataFile, err = $readHSFileRes.error
    return err("Failed to read waku handshake data file. Reason: " &
               $readHSFileRes.error)


  let handshakeResult = HandshakeResult.decodeBytes(readHSFileRes.get,
                                                    Opt.none(ContentTypeData))

  if handshakeResult.isErr:
    warn "Failed to decode waku handshake data file",
        path = $handshakeDataFile, err = $handshakeResult.error
    return err("Failed to decode waku handshake data file. Reason: " &
               $handshakeResult.error)
  if handshakeResult.get == HandshakeResult():
    warn "Waku handshake data file is empty. New pairing is required"
    return err("Waku handshake data file is empty. New pairing is required")

  ok(handshakeResult.get)

proc init*(T: type WakuHost,
           rng: ref HmacDrbgContext,
           wakuNodeParams: WakuNodeParams,
           wakuHandshakeFile: string): Future[WakuHost] {.async.}=
  let node = await startWakuNode(rng, wakuNodeParams.wakuPort,
                                 wakuNodeParams.discv5Port,
                                 wakuNodeParams.requiredConnectedPeers)
  let handshakeDataFile = OutFile(wakuHandshakeFile)

  # Try to load handshake data from file, if the file exists
  let wakuHandshake =
    block:
      let loadRes = loadHandshakeData(handshakeDataFile)
      if loadRes.isOk:
        notice "Loaded waku handshake data from file", file = handshakeDataFile
        loadRes.get
      else:
        warn "Could not load waku handshake data from file", reason = loadRes.error()
        HandshakeResult()
  T(rng: rng,
    wakuNode: node,
    wakuHandshake: wakuHandshake
    )
