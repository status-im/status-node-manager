{.push raises: [].}

type
  SNMStatus* = enum
    Starting
    Running
    Stopping

var snmStatus* = SNMStatus.Starting
