import tables, macros

proc memoize*[A, B](f: proc(a: A): B): proc(a: A): B =
  var cache = initTable[A, B]()
  
  proc g(a: A): B =
    if cache.hasKey(a): return cache[a]
    else:
      let b = f(a)
      cache[a] = b
      return b
  
  return g

macro memoized*(e: expr): stmt =
  
  template memoTemplate(n, nType, retType, procName, procBody : expr): stmt =
    var cache = initTable[nType,retType]()
    proc procName(n : nType) : retType
    proc funName(n : nType) : retType {.gensym.} =
      procBody
    proc procName(n : nType) : retType =
      if not cache.hasKey(n):
        cache[n] = funName(n)
      return cache[n]
  
  let
    retType = e.params()[0]
    param   = e.params()[1]
  getAst(memoTemplate(param[0], param[1], retType, e.name(), e.body()))

export tables.`[]=`, tables.`[]`