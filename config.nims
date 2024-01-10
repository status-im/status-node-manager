# begin Nimble config (version 2)
--noNimblePath
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# end Nimble config

--threads:on
--opt:speed
--excessiveStackTrace:on
# enable metric collection
--define:metrics
