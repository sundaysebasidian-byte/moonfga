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
  budget : @fga.ExecutionBudget?,
) -> CelExpr raise @fga.FgaError {
  match budget {
    Some(b) => b.step()
    None => ()
  }
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
    CList(xs) => CList(xs.map(x => optimize_expr(x, env, budget)))
    CMap(xs) =>
      CMap(
        xs.map(x => {
          (optimize_expr(x.0, env, budget), optimize_expr(x.1, env, budget))
        }),
      )
    CObject(name, fields) =>
      CObject(name, fields.map(x => (x.0, optimize_expr(x.1, env, budget))))
    CUnary(op, x) => CUnary(op, optimize_expr(x, env, budget))
    CBinary(op, l, r) => {
      let left = optimize_expr(l, env, budget)
      let right = optimize_expr(r, env, budget)
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
        optimize_expr(a, env, budget),
        optimize_expr(b, env, budget),
        optimize_expr(c, env, budget),
      )
    CCall(name, args) =>
      CCall(name, args.map(x => optimize_expr(x, env, budget)))
    CMethod(target, name, args) => {
      let receiver = optimize_expr(target, env, budget)
      if ["all", "exists", "exists_one", "map", "filter"].contains(name) &&
        !args.is_empty() &&
        args[0] is CIdent(variable) {
        let bound = env.copy()
        bound[variable] = @fga.VNull
        let optimized : Array[CelExpr] = [args[0]]
        for i in 1..<args.length() {
          optimized.push(optimize_expr(args[i], bound, budget))
        }
        CMethod(receiver, name, optimized)
      } else {
        CMethod(receiver, name, args.map(x => optimize_expr(x, env, budget)))
      }
    }
    CIndex(a, b) =>
      CIndex(optimize_expr(a, env, budget), optimize_expr(b, env, budget))
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
    allow_numeric_local_timezone: false,
    budget,
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

///|
fn needs_program_optimization(expr : CelExpr) -> Bool {
  match expr {
    CLiteral(_) => false
    CIdent(name) =>
      match global_name(name) {
        "int"
        | "uint"
        | "double"
        | "bool"
        | "string"
        | "bytes"
        | "list"
        | "map"
        | "type"
        | "null_type" => true
        _ => false
      }
    CList(_) | CMap(_) => true
    CObject(_, fields) => fields.any(x => needs_program_optimization(x.1))
    CUnary(_, x) => needs_program_optimization(x)
    CBinary(_, a, b) | CIndex(a, b) =>
      needs_program_optimization(a) || needs_program_optimization(b)
    CTernary(a, b, c) =>
      needs_program_optimization(a) ||
      needs_program_optimization(b) ||
      needs_program_optimization(c)
    CCall(name, args) =>
      (
        conversion_function(global_name(name)) &&
        args.length() == 1 &&
        args[0] is CLiteral(_)
      ) ||
      args.any(needs_program_optimization)
    CMethod(target, _, args) =>
      qualified_type(expr) is Some(_) ||
      expression_path(expr) == Some("google.protobuf.NullValue.NULL_VALUE") ||
      needs_program_optimization(target) ||
      args.any(needs_program_optimization)
  }
}
