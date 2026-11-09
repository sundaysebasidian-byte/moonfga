// Optimize the same program shapes as the pinned interpreter: constant
// containers, unary standard conversions, and primitive constant membership.
// Arithmetic is deliberately evaluated at runtime and still incurs cost.

///|
fn conversion_function(name : String) -> Bool {
  [
    "bool", "bytes", "double", "duration", "dyn", "int", "string", "timestamp", "type",
    "uint",
  ].contains(name)
}

///|
fn optimize_expr(
  expr : CelExpr,
  env : Map[String, @fga.CelValue],
) -> CelExpr raise @fga.FgaError {
  if qualified_type(expr) is Some(name) {
    return CLiteral(@fga.VType(name))
  }
  if expression_path(expr) == Some("google.protobuf.NullValue.NULL_VALUE") {
    return CLiteral(@fga.VInt(0L))
  }
  let result = match expr {
    CIdent(name) =>
      if !env.contains(global_name(name)) &&
        [
          "int", "uint", "double", "bool", "string", "bytes", "list", "map", "type",
          "null_type",
        ].contains(global_name(name)) {
        CLiteral(@fga.VType(global_name(name)))
      } else {
        expr
      }
    CLiteral(_) => expr
    CList(xs) => CList(xs.map(x => optimize_expr(x, env)))
    CMap(xs) =>
      CMap(xs.map(x => (optimize_expr(x.0, env), optimize_expr(x.1, env))))
    CObject(name, fields) =>
      CObject(name, fields.map(x => (x.0, optimize_expr(x.1, env))))
    CUnary(op, x) => CUnary(op, optimize_expr(x, env))
    CBinary(op, l, r) => {
      let left = optimize_expr(l, env)
      let right = optimize_expr(r, env)
      if op == "in" && right is CLiteral(@fga.VList(xs)) {
        if xs.is_empty() {
          CLiteral(@fga.VBool(false))
        } else if xs.all(x => {
            match x {
              @fga.VInt(_)
              | @fga.VUint(_)
              | @fga.VDouble(_)
              | @fga.VBool(_)
              | @fga.VString(_) => true
              _ => false
            }
          }) {
          CBinary("@set_in", left, right)
        } else {
          CBinary(op, left, right)
        }
      } else {
        CBinary(op, left, right)
      }
    }
    CTernary(a, b, c) =>
      CTernary(
        optimize_expr(a, env),
        optimize_expr(b, env),
        optimize_expr(c, env),
      )
    CCall(name, args) => CCall(name, args.map(x => optimize_expr(x, env)))
    CMethod(target, name, args) => {
      let receiver = optimize_expr(target, env)
      if ["all", "exists", "exists_one", "map", "filter"].contains(name) &&
        !args.is_empty() &&
        args[0] is CIdent(variable) {
        let bound = env.copy()
        bound[variable] = @fga.VNull
        let optimized : Array[CelExpr] = [args[0]]
        for i in 1..<args.length() {
          optimized.push(optimize_expr(args[i], bound))
        }
        CMethod(receiver, name, optimized)
      } else {
        CMethod(receiver, name, args.map(x => optimize_expr(x, env)))
      }
    }
    CIndex(a, b) => CIndex(optimize_expr(a, env), optimize_expr(b, env))
  }
  let fold = match result {
    CCall(name, args) =>
      conversion_function(global_name(name)) &&
      args.length() == 1 &&
      args[0] is CLiteral(_)
    CList(xs) => xs.all(x => x is CLiteral(_))
    CMap(xs) => xs.all(x => x.0 is CLiteral(_) && x.1 is CLiteral(_))
    _ => false
  }
  if !fold {
    return result
  }
  let state : EvalState = {
    cost: 0,
    limit: 2147483647,
    interrupted: false,
    cancelled: fn() { false },
    local_timezone: None,
  }
  CLiteral(eval_expr_state(result, Map([]), state))
}

///|
fn optimized_member(
  needle : @fga.CelValue,
  haystack : @fga.CelValue,
) -> Bool raise @fga.FgaError {
  let values = match haystack {
    @fga.VList(xs) => xs
    _ => raise eval_error("invalid optimized membership")
  }
  values.any(item => {
    if item is @fga.VDouble(_) &&
      (needle is @fga.VInt(_) || needle is @fga.VUint(_)) {
      @fga.numeric_compare(needle, item) == Some(0)
    } else {
      @fga.cel_value_eq(needle, item)
    }
  })
}
