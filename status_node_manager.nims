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

### Tasks
task wakuUtils, "Building Waku Utils":
    buildBinary "waku_handshake_utils", "libs/waku-utils/"

task wakuUtilsExamples, "Building Waku Utils Examples":
    buildBinary "agentA", "libs/waku-utils/example/"
    buildBinary "agentB", "libs/waku-utils/example/"
    buildBinary "initiator", "libs/waku-utils/example/js-waku/"
