///|
#derive(Eq)
priv enum CType {
  Atom(String)
  List(CType)
  Map(CType, CType)
  Dynamic
}

///|
fn compatible(a : CType, b : CType) -> Bool {
  match (a, b) {
    (Dynamic, _) | (_, Dynamic) => true
    (List(x), List(y)) => compatible(x, y)
    (Map(k, v), Map(k2, v2)) => compatible(k, k2) && compatible(v, v2)
    _ => a == b
  }
}

///|
fn require_type(actual : CType, expected : CType) -> Unit raise @fga.FgaError {
  if !compatible(actual, expected) {
    raise eval_error("no matching CEL overload")
  }
}

///|
fn common_type(a : CType, b : CType) -> CType {
  if a == b {
    a
  } else {
    Dynamic
  }
}

///|
fn infer(expr : CelExpr, env : Map[String, CType]) -> CType raise @fga.FgaError {
  if qualified_type(expr) is Some(_) {
    return Atom("type")
  }
  match expr {
    CLiteral(v) =>
      match v {
        @fga.VList(_) => List(Dynamic)
        @fga.VMap(_) | @fga.VKeyMap(_) => Map(Dynamic, Dynamic)
        _ => Atom(@fga.cel_value_type_name(v))
      }
    CIdent(name) =>
      match env.get(name) {
        Some(t) => t
        None =>
          if [
              "int", "uint", "double", "bool", "string", "bytes", "list", "map",
              "type", "null_type",
            ].contains(name) {
            Atom("type")
          } else {
            raise eval_error("undefined parameter `" + name + "`")
          }
      }
    CUnary(op, inner) => {
      let t = infer(inner, env)
      if op == "!" {
        require_type(t, Atom("bool"))
        Atom("bool")
      } else if t == Dynamic || t == Atom("int") || t == Atom("double") {
        t
      } else {
        raise eval_error("no matching unary overload")
      }
    }
    CBinary(op, left, right) => {
      let l = infer(left, env)
      let r = infer(right, env)
      if op == "&&" || op == "||" {
        require_type(l, Atom("bool"))
        require_type(r, Atom("bool"))
        return Atom("bool")
      }
      if op == "==" || op == "!=" {
        // CEL's equality overload uses a shared type parameter, including dyn.
        require_type(l, r)
        return Atom("bool")
      }
      if op == "in" {
        match r {
          List(t) => require_type(l, t)
          Map(k, _) => require_type(l, k)
          Dynamic => ()
          _ => raise eval_error("no matching in overload")
        }
        return Atom("bool")
      }
      if op == "<" || op == "<=" || op == ">" || op == ">=" {
        require_type(l, r)
        if l != Dynamic &&
          ![
            Atom("int"),
            Atom("uint"),
            Atom("double"),
            Atom("string"),
            Atom("bytes"),
            Atom("duration"),
            Atom("timestamp"),
          ].contains(l) {
          raise eval_error("no matching comparison overload")
        }
        return Atom("bool")
      }
      if (op == "+" || op == "-") &&
        l == Atom("timestamp") &&
        r == Atom("duration") {
        return l
      }
      if op == "+" && l == Atom("duration") && r == Atom("timestamp") {
        return r
      }
      if op == "-" && l == Atom("timestamp") && r == l {
        return Atom("duration")
      }
      require_type(l, r)
      if l == Dynamic {
        return Dynamic
      }
      if l == Atom("int") || l == Atom("uint") {
        return l
      }
      if l == Atom("double") && op != "%" {
        return l
      }
      if op == "+" &&
        (l is List(_) || l == Atom("string") || l == Atom("bytes")) {
        return l
      }
      if (op == "+" || op == "-") && l == Atom("duration") {
        return l
      }
      raise eval_error("no matching arithmetic overload")
    }
    CTernary(c, t, f) => {
      require_type(infer(c, env), Atom("bool"))
      let a = infer(t, env)
      let b = infer(f, env)
      require_type(a, b)
      common_type(a, b)
    }
    CList(items) => {
      let mut element = Dynamic
      for i in 0..<items.length() {
        let t = infer(items[i], env)
        element = if i == 0 { t } else { common_type(element, t) }
      }
      List(element)
    }
    CMap(entries) => {
      let mut key = Dynamic
      let mut value = Dynamic
      for i in 0..<entries.length() {
        let k = infer(entries[i].0, env)
        let v = infer(entries[i].1, env)
        if k != Dynamic &&
          ![Atom("int"), Atom("uint"), Atom("bool"), Atom("string")].contains(k) {
          raise eval_error("invalid map key type")
        }
        key = if i == 0 { k } else { common_type(key, k) }
        value = if i == 0 { v } else { common_type(value, v) }
      }
      Map(key, value)
    }
    CIndex(target, index) => {
      let t = infer(target, env)
      let k = infer(index, env)
      match t {
        List(v) => {
          require_type(k, Atom("int"))
          v
        }
        Map(key, v) => {
          require_type(k, key)
          v
        }
        Dynamic => Dynamic
        _ => raise eval_error("not indexable")
      }
    }
    CCall(name, args) => {
      if name == "matches" {
        if args.length() != 2 {
          raise eval_error("invalid matches arity")
        }
        for arg in args {
          require_type(infer(arg, env), Atom("string"))
        }
        if args[1] is CLiteral(@fga.VString(pattern)) {
          validate_regex(pattern)
        }
        return Atom("bool")
      }
      if args.length() != 1 {
        raise eval_error("invalid function arity")
      }
      if name == "has" {
        match args[0] {
          CMethod(target, field, a) => {
            if !field.has_prefix("@field:") || !a.is_empty() {
              raise eval_error("has expects field selection")
            }
            match infer(target, env) {
              Map(_, _) | Dynamic => ()
              _ => raise eval_error("has expects map")
            }
          }
          _ => raise eval_error("has expects field selection")
        }
        return Atom("bool")
      }
      let t = infer(args[0], env)
      if name == "dyn" {
        return Dynamic
      }
      if name == "type" {
        return Atom("type")
      }
      if name == "size" {
        if t != Dynamic &&
          t != Atom("string") &&
          t != Atom("bytes") &&
          !(t is List(_)) &&
          !(t is Map(_, _)) {
          raise eval_error("no matching size overload")
        }
        return Atom("int")
      }
      let allowed = match name {
        "int" => ["int", "uint", "double", "string", "duration", "timestamp"]
        "uint" | "double" => ["int", "uint", "double", "string"]
        "bool" => ["bool", "string"]
        "bytes" => ["bytes", "string"]
        "string" =>
          [
            "string", "int", "uint", "double", "bool", "bytes", "duration", "timestamp",
          ]
        "timestamp" => ["timestamp", "string", "int"]
        "duration" => ["duration", "string"]
        "ipaddress" => ["string"]
        _ => raise eval_error("unknown function '" + name + "'")
      }
      if t != Dynamic && !allowed.any(a => t == Atom(a)) {
        raise eval_error("no matching conversion overload")
      }
      if name != "ipaddress" && foldable_argument(args[0]) {
        ignore(eval_expr(expr, Map([])))
      }
      Atom(name)
    }
    CMethod(target, name, args) => {
      let t = infer(target, env)
      if ["all", "exists", "exists_one", "map", "filter"].contains(name) {
        if args.length() != 2 && !(name == "map" && args.length() == 3) {
          raise eval_error("invalid macro arity")
        }
        let variable = match args[0] {
          CIdent(v) => v
          _ => raise eval_error("invalid macro variable")
        }
        let element = match t {
          List(v) => v
          Map(k, _) => k
          Dynamic => Dynamic
          _ => raise eval_error("invalid macro receiver")
        }
        let bound = env.copy()
        bound[variable] = element
        let predicate = infer(args[1], bound)
        if name != "map" || args.length() == 3 {
          require_type(predicate, Atom("bool"))
        }
        if name == "map" {
          return List(
            if args.length() == 3 {
              infer(args[2], bound)
            } else {
              predicate
            },
          )
        }
        if name == "filter" {
          return List(element)
        }
        return Atom("bool")
      }
      // A property selection has no arguments. The parser distinguishes calls.
      if name.has_prefix("@field:") {
        match t {
          Map(_, v) => return v
          Dynamic => return Dynamic
          _ => raise eval_error("invalid field selection")
        }
      }
      if name == "size" {
        if !args.is_empty() {
          raise eval_error("invalid size arity")
        }
        match t {
          List(_) | Map(_, _) => return Atom("int")
          _ => ()
        }
        if t == Dynamic || t == Atom("string") || t == Atom("bytes") {
          return Atom("int")
        }
      }
      if ["contains", "startsWith", "endsWith", "matches", "in_cidr"].contains(
          name,
        ) {
        if args.length() != 1 {
          raise eval_error("invalid method arity")
        }
        require_type(
          t,
          Atom(if name == "in_cidr" { "ipaddress" } else { "string" }),
        )
        require_type(infer(args[0], env), Atom("string"))
        if name == "matches" && args[0] is CLiteral(@fga.VString(pattern)) {
          validate_regex(pattern)
        }
        return Atom("bool")
      }
      if [
          "getFullYear", "getMonth", "getDate", "getDayOfMonth", "getDayOfWeek",
          "getDayOfYear", "getHours", "getMinutes", "getSeconds", "getMilliseconds",
        ].contains(name) {
        if t == Atom("duration") &&
          ["getHours", "getMinutes", "getSeconds", "getMilliseconds"].contains(
            name,
          ) &&
          args.is_empty() {
          return Atom("int")
        }
        require_type(t, Atom("timestamp"))
        if args.length() > 1 {
          raise eval_error("invalid getter arity")
        }
        for arg in args {
          require_type(infer(arg, env), Atom("string"))
        }
        return Atom("int")
      }
      raise eval_error("unknown method '" + name + "'")
    }
  }
}

///|
/// Validates model-time types independently of request values.
pub fn check_condition(condition : @fga.Condition) -> Unit raise @fga.FgaError {
  if @utf8.encode(condition.expression[:]).length() > 512 {
    raise eval_error("condition expression exceeds 512-byte request limit")
  }
  let env : Map[String, CType] = Map([])
  for p in condition.parameters {
    let scalar = condition_type
    env[p.name] = if p.type_name == "list" {
      List(scalar(p.generic_type.unwrap_or("any")))
    } else if p.type_name == "map" {
      Map(Atom("string"), scalar(p.generic_type.unwrap_or("any")))
    } else {
      scalar(p.type_name)
    }
  }
  let output = infer(compile(condition.expression), env)
  if output != Atom("bool") {
    raise eval_error("expected a bool condition expression output")
  }
}

///|
fn condition_type(text : String) -> CType {
  if text == "any" {
    return Dynamic
  }
  match text.find("<") {
    Some(i) => {
      let inner = condition_type(text[i + 1:text.length() - 1].to_owned())
      if text[:i].to_owned() == "list" {
        List(inner)
      } else {
        Map(Atom("string"), inner)
      }
    }
    None => Atom(text)
  }
}

///|
fn qualified_type(expr : CelExpr) -> String? {
  fn path(e : CelExpr) -> String? {
    match e {
      CIdent(n) => Some(n)
      CMethod(target, field, args) =>
        if args.is_empty() && field.has_prefix("@field:") {
          path(target).map(p => p + "." + field[7:].to_owned())
        } else {
          None
        }
      _ => None
    }
  }
  match path(expr) {
    Some("google.protobuf.Timestamp" as n)
    | Some("google.protobuf.Duration" as n) => Some(n)
    _ => None
  }
}

///|
fn foldable_argument(expr : CelExpr) -> Bool {
  match expr {
    CLiteral(_) => true
    CList(items) => items.all(foldable_argument)
    CMap(items) =>
      items.all(e => foldable_argument(e.0) && foldable_argument(e.1))
    CCall("type", args) | CCall("dyn", args) =>
      args.length() == 1 && foldable_argument(args[0])
    _ => false
  }
}
