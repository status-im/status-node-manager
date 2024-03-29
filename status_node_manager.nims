### Helper functions
proc buildBinary(name: string, srcDir = "./", params = "", lang = "c") =
  if not dirExists "build":
    mkDir "build"
  # allow something like "nim nimbus --verbosity:0 --hints:off nimbus.nims"
  var extra_params = params
  for i in 2..<paramCount():
    extra_params &= " " & paramStr(i)
  exec "nim " & lang & " --out:build/" & name & " " & extra_params & " " & srcDir & name & ".nim"

proc buildLibrary(name: string, srcDir = "./", params = "", `type` = "static") =
  if not dirExists "build":
    mkDir "build"
  # allow something like "nim nimbus --verbosity:0 --hints:off nimbus.nims"
  var extra_params = params
  for i in 2..<paramCount():
    extra_params &= " " & paramStr(i)
  if `type` == "static":
    exec "nim c" & " --out:build/" & name & ".a --threads:on --app:staticlib --opt:size --noMain --header " & extra_params & " " & srcDir & name & ".nim"
  else:
    exec "nim c" & " --out:build/" & name & ".so --threads:on --app:lib --opt:size --noMain --header " & extra_params & " " & srcDir & name & ".nim"

proc test(name: string, params = "-d:chronicles_log_level=DEBUG", lang = "c") =
  buildBinary name, "tests/", params
  exec "build/" & name

### Tasks
task wakuUtils, "Building Waku Utils":
    buildBinary "waku_handshake_utils", "libs/waku_utils/"

task wakuUtilsExamples, "Building Waku Utils Examples":
    buildBinary "agentA", "libs/waku_utils/example/nwaku/"
    buildBinary "agentB", "libs/waku_utils/example/nwaku/"
    buildBinary "initiator", "libs/waku_utils/example/js-waku/"

task statusNodeManager, "Building Status Node Manager":
    buildBinary "status_node_manager", "src/"

task test, "Build & run all tests":
    test "test_waku_api"
