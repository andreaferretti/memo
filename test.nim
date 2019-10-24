import memo, unittest

proc fastFib(n: int): int =
  var
    a = 0
    b = 1
  for _ in 1 .. n:
    let c = a + b
    a = b
    b = c
  return a

proc fib(n : int) : int {.memoized.} =
  if n < 2: n
  else: fib(n-1) + fib(n-2)

proc fib1(n : int) : int

proc fib2(n : int) : int {.memoized.} =
  if n < 2: n
  else: fib1(n-1) + fib1(n-2)

proc fib1(n : int) : int {.memoized.} =
  if n < 2: n
  else: fib2(n-1) + fib2(n-2)

proc xib_tup(tup: (int, int)) : int {.memoized.} =
  let (x, n) = tup
  if n < x-1:
    result = 0
  elif n == x-1:
    result = 1
  else:
    result = 0
    for i in 1 .. x:
      result += xib_tup((x, n-i))

proc xib(x, n: int) : int {.memoized.} =
  if n < x-1:
    result = 0
  elif n == x-1:
    result = 1
  else:
    result = 0
    for i in 1 .. x:
      result += xib(x, n-i)

var x  = 0
proc impure(y: int): int {.memoized.} =
  x += y
  return x

suite "memoization":
  test "recursive function memoization":
    check fastFib(40) == fib(40)

  test "double recursive function memoization":
    check fastFib(40) == fib2(40)

  test "clearing the memoization cache":
    for y in 1 .. 10:
      discard impure(y)
    check x == 55
    for y in 1 .. 10:
      discard impure(y)
    check x == 55
    resetCacheImpure()
    for y in 1 .. 10:
      discard impure(y)
    check x == 110

  test "multiple-arguments recursive function memoization":
    check xib_tup((3, 10)) == xib(3, 10)
