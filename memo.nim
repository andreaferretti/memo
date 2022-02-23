import tables, macros, options

proc memoize*[A, B](f: proc(a: A): B): proc(a: A): B =
  ## Returns a memoized version of the given procedure.
  var cache = initTable[A, B]()

  result = proc(a: A): B =
    if cache.hasKey(a):
      result = cache[a]
    else:
      result = f(a)
      cache[a] = result


proc getSignature(fun: NimNode): (NimNode, NimNode) =
  ## Gets a routine's unrolled signature, meaning its return type
  ## and arguments, one by one (i.e. x,y: int will becone x:int, y:int).
  result[0] = fun.params()[0]

  result[1] = newTree(nnkArgList)
  for i in 1 ..< fun.params.len:  # first is for result type
    let idents = fun.params[i]
    let (typ, default) = (idents[^2], idents[^1])
    for j in 0 ..< idents.len-2:  # two last are type and default
      result[1].add(newTree(nnkIdentDefs, idents[j], typ, default))


proc toIdents(args: NimNode): NimNode =
  ## Generates arguments' names from argument list.
  ## If there is only one argument, it is returned as an identifier.
  ## If there are more, a par is returned.
  assert args.kind == nnkArgList
  if args.len == 1:
    result = args[0][0]
  else:
    result = newTree(nnkPar)
    for arg in args:  # two last are type
      result.add(arg[0])


proc toTypes(args: NimNode): NimNode =
  ## Generates arguments' types from argument list.
  ## If there is only one argument, it's type is returned.
  ## If there are more, a par is returned.
  assert args.kind == nnkArgList
  if args.len == 1:
    result = args[0][1]
  else:
    result = newTree(nnkPar)
    for arg in args:  # two last are type
      result.add(arg[1])


## Cache having an owner who can reset it.
type OwnedCache = object
  sym: NimNode
  decl: NimNode
  reset: NimNode

proc declCache(owner, argType, retType: NimNode): OwnedCache =
  ## Declares a new cache with given argument type and return type.
  ## Returns cache symbol, cache declaration and cache reset proc.
  ## For functions with arguments.
  ## Cache is implemented as a Table that hashes tuples of arguments.

  result.sym = genSym(nskVar, "cache")

  template cacheImpl(cache, argType, retType) =
    var cache = initTable[argType, retType]()
  result.decl = getAst(cacheImpl(result.sym, argType, retType))

  template declResetCache(cacheName, owner) =
    template `resetCache owner`() =
      cacheName.clear()
  result.reset = getAst(declResetCache(result.sym, owner.name))


proc declCacheNiladic(owner, argType, retType: NimNode): OwnedCache =
  ## Declares a new cache with given argument type and return type.
  ## Returns cache symbol, cache declaration and cache reset proc.
  ## For functions with no arguments.
  ## Cache is implemented as an Option.

  result.sym = genSym(nskVar, "cache")

  template cacheImpl(cache, retType) =
    var cache: Option[retType] = none(retType)
  result.decl = getAst(cacheImpl(result.sym, retType))

  template declResetCache(cacheName, owner, retType) =
    template `resetCache owner`() =
      cacheName = none(retType)
  result.reset = getAst(declResetCache(result.sym, owner.name, retType))


proc destructurizedCall(fun, args: NimNode): NimNode =
  ## For a non-tuple argument, returns a common proc call.
  ## For a tuple argument, destructurizes it before call.

  result = newCall(fun)
  if args.kind != nnkPar:
    result.add(args)
  else:
    for arg in args:
      result.add(arg)


proc destrTupNode(lhs, rhs: NimNode): NimNode =
  ## Generates AST for destructurizing a tuple.
  ## Left argument should be either an ident or par of idents.
  ## Right argument should be a tuple symbol or literal.

  if lhs.kind != nnkPar:
    result = newLetStmt(lhs, rhs)
  else:
    var vartup = newNimNode(nnkVarTuple)
    for nam in lhs:
      vartup.add(nam)
    vartup.add(newEmptyNode())
    vartup.add(rhs)
    result = newTree(nnkLetSection, vartup)


macro memoized*(e: untyped): auto =
  ## Rewrites a procedure so that it utilizes memoization.

  let (retType, args) = getSignature(e)
  let nams = args.toIdents()
  let atyp = args.toTypes()

  let hasArgs = args.len > 0
  let cache = if hasArgs:
    declCache(e, atyp, retType)
  else:
    declCacheNiladic(e, atyp, retType)

  # version results from which results will be memoized
  let mem = newProc(name = genSym(nskProc, "memoized"))
  mem.params = newNimNode(nnkFormalParams).add(e.params[0])

  # wrap original implementation
  let org = e.copy()
  org.name = genSym(nskProc, "impl")

  mem.body = newStmtList().add(org)

  if hasArgs:
    # pack arguments into a tuple
    let argSym = genSym(nskParam, "arg")
    mem.params.
      add(newTree(nnkIdentDefs, argSym, atyp, newEmptyNode()))

    let darg = nams.destrTupNode(argSym)
    let dcall = org.name.destructurizedCall(nams)

    # add implementation wrapping and argument destructurization
    mem.body.
      add(darg).
      add(newAssignment(ident("result"), dcall))
  else:
    # add implementation wrapping
    mem.body.
      add(newAssignment(ident("result"),
        newCall(org.name)
      ))

  # main procedure implementation:
  let fun = newProc(name = e.name)
  fun.params = e.params.copy

  # build tuple, check it in cache and optionally calculate
  template funImpl(impl, cache, fun, lhs, rhs) =
    impl
    let lhs = rhs
    if not cache.hasKey(lhs):
      cache[lhs] = fun(lhs)

  # check if cache has some and optionally calculate
  template funImplNiladic(impl, cache, fun) =
    impl
    if options.isNone(cache):
      cache = some(fun())

  if hasArgs:
    let packSym = genSym(nskLet, "pack")
    fun.body = getAst(funImpl(mem, cache.sym, mem.name, packSym, nams))
    fun.body.add(newAssignment(
                   ident("result"),
                   newCall(ident("[]"), cache.sym, nams)))
  else:
    fun.body = getAst(funImplNiladic(mem, cache.sym, mem.name))
    fun.body.add(newAssignment(
                   ident("result"),
                   newCall(ident("get"), cache.sym)))

  # return cache and its owner procedure
  result = newStmtList(cache.decl, fun, cache.reset)

export tables.`[]=`, tables.`[]`, options.`get`
