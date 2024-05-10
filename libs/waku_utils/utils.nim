import
  std/times,

  waku/waku_core

proc now*(): Timestamp =
  getNanosecondTime(getTime().toUnixFloat())
