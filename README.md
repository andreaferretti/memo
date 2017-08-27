Memoize Nim functions
=====================

[![Build Status](https://travis-ci.org/andreaferretti/memo.svg?branch=master)](https://travis-ci.org/andreaferretti/memo)
[![nimble](https://raw.githubusercontent.com/yglukhov/nimble-tag/master/nimble_js.png)](https://github.com/yglukhov/nimble-tag)

This small package offers a function and a macro to memoize Nim functions.

Usage
-----

If `f(a: A): B` is a function, one can obtain a memoized version of `f` by doing

```nim
import memo
let g = memoize(f)
```

`g` will then be equivalent to `f` (modulo side effects), but results of calling `g` will be cached. The function `memoize` can be used on any function, but will not handle correctly recursive functions, as self calls of `f`, both direct and indirect, will still keep refering to the non-memoize version of `f`.

If you have access to the definition of `f`, one can do better with the `memoized` macro. Usage is as follows:

```nim
import memo
proc f(a: A): B {.memoized.} =
  ...
```

Then `f` will be memoized and recursive calls will be handled correctly (both direct self-recursion and mutual recursion).

Example
-------

```nim
import memo

proc fib(n : int) : int {.memoized.} =
  if n < 2: n
  else: fib(n-1) + fib(n-2)

when isMainModule:
  echo fib(40)
```

This small program returns very fast, while without the `memoized` pragma, it takes a few seconds before producing a result. For an example of mutual recursive functions

```nim
import memo

proc fib(n : int) : int

proc fib1(n : int) : int {.memoized.} =
  if n < 2: n
  else: fib(n-1) + fib(n-2)

proc fib(n : int) : int {.memoized.} =
  if n < 2: n
  else: fib1(n-1) + fib1(n-2)

when isMainModule:
  echo fib(80)
```

Restrictions
------------

* `memoize` function, as opposed to `memoized` macro, can only memoize functions of a single argument, altough one can convert any function in this form by using a tuple argument
* types of all arguments have to implement ``hash``, since they will be used as parts of a key in a hashtable

An example of the first issue would be memoizing the Levenshtein distance for strings, as it is a function of two arguments. It can be done like this:

```nim
import memo

template tail(s: string): string = s[1 .. s.high]

template head(s: string): char = s[0]

# `memoized` macro handles multiple arguments:
proc lev(a: string, b: string): int {.memoized.} =
  if a.len == 0: return b.len
  if b.len == 0: return a.len
  let
    d1 = lev(a.tail, b) + 1
    d2 = lev(a, b.tail) + 1
    d3 = lev(a.tail, b.tail) + (if a.head == b.head: 0 else: 1)
  result = min(min(d1, d2), d3)

# `memoize` function does not:
template memTwoArg =
  let levMem: proc(int): int = memoize(lev)
assert: not compiles memTwoArg

when isMainModule:
  echo levenshtein("submarine", "subreddit")
```
