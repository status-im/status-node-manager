{.experimental: "notnil".}

#TODO: Consider importing from `nimbus-eth2`
template newClone*[T: not ref](x: T): ref T =
  # TODO not nil in return type: https://github.com/nim-lang/Nim/issues/14146
  # TODO use only when x is a function call that returns a new instance!
  let res = new typeof(x) # TODO safe to do noinit here?
  res[] = x
  res

# TODO Careful, not nil analysis is broken / incomplete and the semantics will
#      likely change in future versions of the language:
#      https://github.com/nim-lang/RFCs/issues/250
template newClone*[T](x: ref T not nil): ref T =
  newClone(x[])
