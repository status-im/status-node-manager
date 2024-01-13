# This is just an example to get you started. A typical hybrid package
# uses this file as the main entry point of the application.

import
  confutils,
  status_node_manager/[
    config,
    helpers/submodule # TODO: remove me
  ]

when isMainModule:
  let conf = load Config
  echo(getWelcomeMessage()) # TODO: remove me
