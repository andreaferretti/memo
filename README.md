Memoize Nim functions
=====================

This small package offers a function and a macro to memoize Nim functions.

Usage
-----

If `f(a: A): B` is a function, one can obtain a memoized version of `f` by doing

    import memo
    let g = memoize(f)

`g` will then be equivalent to `f` (modulo side effects), but results of calling `g` will be cached. The function `memoize` can be used on any function, but will not handle correctly recursive functions, as self calls of `f`, both direct and indirect, will still keep refering to the non-memoize version of `f`.

If you have access to the definition of `f`, one can do better with the `memoized` macro. Usage is as follows:

    import memo
    proc f(a: A): B {.memoized.} =
      ...

Then `f` will be memoized and recursive calls will be handled correctly (both direct self-recursion and mutual recursion).

Example
-------

    import memo

    proc fib(n : int) : int {.memoized.} =
      if n < 2: n
      else: fib(n-1) + fib(n-2)

    when isMainModule:
      echo fib(40)

This small program returns very fast, while without the `memoized` pragma, it takes a few seconds before producing a result. For an example of mutual recursive functions

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

Restrictions
------------

* one can only memoize functions of a single argument, altough one can convert any function in this form by using a tuple argument
* the argument type has to implement ``hash``, since it will be used as key in a hashtable