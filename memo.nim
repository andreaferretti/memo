import tables, macros


proc memoize*[A, B](f: proc(a: A): B): proc(a: A): B =
  var cache = initTable[A, B]()

  result = proc(a: A): B =
    if cache.hasKey(a):
      result = cache[a]
    else:
      result = f(a)
      cache[a] = result


macro memoized*(e: untyped): auto =
  template memoTemplate(n, nT, retType, procName, procBody : untyped): auto =
    var cache = initTable[nT,retType]()
    when not declared(procName):
      proc procName(n : nT) : retType
    proc funName(n : nT) : retType {.gensym.} =
      procBody
    proc procName(n : nT) : retType =
      if not cache.hasKey(n):
        cache[n] = funName(n)
      return cache[n]
    type procType = proc(n : nT) : retType
    template resetCache(p) =
      when p == procName:
        cache = initTable[nT,retType]()

  let
    retType = e.params()[0]
    param   = e.params()[1]
    (n, nT) = (param[0], param[1])
  getAst(memoTemplate(n, nT, retType, e.name(), e.body()))

export tables.`[]=`, tables.`[]`
