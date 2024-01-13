import
  options,
  confutils/defs

type
  Config* = object
    wakuKeyPath* {.
      name: "waku-key"
      desc: "A path to Waku identity key" .}: Option[InputFile]
