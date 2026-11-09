// Evaluator for CEL condition expressions.

///|
fn eval_error(message : String) -> @fga.FgaError {
  @fga.fail(@fga.ERR_VALIDATION, message)
}

///|
fn as_bool_value(value : @fga.CelValue) -> Bool raise @fga.FgaError {
  match value {
    @fga.VBool(b) => b
    _ =>
      raise eval_error(
        "expected a boolean, found " + @fga.cel_value_type_name(value),
      )
  }
}

///|
fn as_string_value(value : @fga.CelValue) -> String raise @fga.FgaError {
  match value {
    @fga.VString(s) => s
    _ =>
      raise eval_error(
        "expected a string, found " + @fga.cel_value_type_name(value),
      )
  }
}

///|
fn as_int_value(value : @fga.CelValue) -> Int64 raise @fga.FgaError {
  match value {
    @fga.VInt(i) => i
    _ =>
      raise eval_error(
        "expected an int, found " + @fga.cel_value_type_name(value),
      )
  }
}

///|
fn numeric_double(value : @fga.CelValue) -> Double? {
  match value {
    @fga.VInt(i) => Some(i.to_double())
    @fga.VUint(u) => Some(u.to_double())
    @fga.VDouble(d) => Some(d)
    _ => None
  }
}

///|
fn with_binding(
  env : Map[String, @fga.CelValue],
  name : String,
  value : @fga.CelValue,
) -> Map[String, @fga.CelValue] {
  let copy : Map[String, @fga.CelValue] = Map([])
  env.each(fn(k, v) { copy[k] = v })
  copy[name] = value
  copy
}

///|
fn eval_arithmetic(
  op : String,
  left : @fga.CelValue,
  right : @fga.CelValue,
) -> @fga.CelValue raise @fga.FgaError {
  match (left, right) {
    (@fga.VInt(a), @fga.VInt(b)) => {
      let max = 9223372036854775807L
      let min = -9223372036854775807L - 1L
      let overflow = match op {
        "+" => (b > 0L && a > max - b) || (b < 0L && a < min - b)
        "-" => (b < 0L && a > max + b) || (b > 0L && a < min + b)
        "*" =>
          if a == 0L || b == 0L {
            false
          } else if a > 0L {
            if b > 0L {
              a > max / b
            } else {
              b < min / a
            }
          } else if b > 0L {
            a < min / b
          } else {
            a < max / b
          }
        "/" | "%" => a == min && b == -1L
        _ => false
      }
      if overflow {
        raise eval_error("integer overflow")
      }
    }
    (@fga.VUint(a), @fga.VUint(b)) => {
      let max = 18446744073709551615UL
      if (op == "+" && a > max - b) ||
        (op == "-" && a < b) ||
        (op == "*" && b != 0UL && a > max / b) {
        raise eval_error("unsigned integer overflow")
      }
    }
    _ => ()
  }
  match (left.timestamp_parts(), right.timestamp_parts(), left, right) {
    (Some((a, an)), Some((b, bn)), _, _) => {
      if op == "-" {
        return @fga.VDuration(
          (a - b) * 1000000L + an.to_int64() - bn.to_int64(),
        )
      }
      raise eval_error("unsupported timestamp operator")
    }
    (Some((a, an)), None, _, @fga.VDuration(ns)) => {
      if op != "+" && op != "-" {
        raise eval_error("unsupported timestamp operator")
      }
      let delta = if op == "+" { ns } else { -ns }
      return @fga.timestamp_value(
        a + delta / 1000000L,
        an.to_int64() + delta % 1000000L,
        offset=left.timestamp_offset(),
      )
    }
    (None, Some((b, bn)), @fga.VDuration(ns), _) => {
      if op != "+" {
        raise eval_error("unsupported timestamp operator")
      }
      return @fga.timestamp_value(
        b + ns / 1000000L,
        bn.to_int64() + ns % 1000000L,
        offset=right.timestamp_offset(),
      )
    }
    _ => ()
  }
  match (left, right) {
    (@fga.VInt(a), @fga.VInt(b)) =>
      match op {
        "+" => @fga.VInt(a + b)
        "-" => @fga.VInt(a - b)
        "*" => @fga.VInt(a * b)
        "/" =>
          if b == 0L {
            raise eval_error("division by zero")
          } else {
            @fga.VInt(a / b)
          }
        "%" =>
          if b == 0L {
            raise eval_error("division by zero")
          } else {
            @fga.VInt(a % b)
          }
        _ => raise eval_error("unsupported operator '" + op + "' for int")
      }
    (@fga.VUint(a), @fga.VUint(b)) =>
      match op {
        "+" => @fga.VUint(a + b)
        "-" => @fga.VUint(a - b)
        "*" => @fga.VUint(a * b)
        "/" =>
          if b == 0UL {
            raise eval_error("division by zero")
          } else {
            @fga.VUint(a / b)
          }
        "%" =>
          if b == 0UL {
            raise eval_error("division by zero")
          } else {
            @fga.VUint(a % b)
          }
        _ => raise eval_error("unsupported operator '" + op + "' for uint")
      }
    (@fga.VDouble(a), @fga.VDouble(b)) =>
      match op {
        "+" => @fga.VDouble(a + b)
        "-" => @fga.VDouble(a - b)
        "*" => @fga.VDouble(a * b)
        "/" =>
          if b == 0.0 {
            raise eval_error("division by zero")
          } else {
            @fga.VDouble(a / b)
          }
        "%" => raise eval_error("operator '%' is not defined for double")
        _ => raise eval_error("unsupported operator '" + op + "' for double")
      }
    (@fga.VBytes(a), @fga.VBytes(b)) =>
      if op == "+" {
        @fga.VBytes(a + b)
      } else {
        raise eval_error("unsupported bytes operator")
      }
    (@fga.VList(a), @fga.VList(b)) =>
      if op == "+" {
        @fga.VList(a + b)
      } else {
        raise eval_error("unsupported list operator")
      }
    (@fga.VString(a), @fga.VString(b)) =>
      if op == "+" {
        @fga.VString(a + b)
      } else {
        raise eval_error("unsupported operator '" + op + "' for string")
      }
    (@fga.VDuration(a), @fga.VDuration(b)) =>
      if op == "+" {
        @fga.VDuration(a + b)
      } else if op == "-" {
        @fga.VDuration(a - b)
      } else {
        raise eval_error("unsupported duration operator '" + op + "'")
      }
    _ => {
      let a = numeric_double(left)
      let b = numeric_double(right)
      match (a, b) {
        (Some(x), Some(y)) =>
          match op {
            "+" => @fga.VDouble(x + y)
            "-" => @fga.VDouble(x - y)
            "*" => @fga.VDouble(x * y)
            "/" =>
              if y == 0.0 {
                raise eval_error("division by zero")
              } else {
                @fga.VDouble(x / y)
              }
            _ => raise eval_error("unsupported numeric operator '" + op + "'")
          }
        _ =>
          raise eval_error(
            "cannot apply '" +
            op +
            "' to " +
            @fga.cel_value_type_name(left) +
            " and " +
            @fga.cel_value_type_name(right),
          )
      }
    }
  }
}

///|
fn compare_values(
  op : String,
  left : @fga.CelValue,
  right : @fga.CelValue,
) -> Bool raise @fga.FgaError {
  match (left.timestamp_parts(), right.timestamp_parts()) {
    (Some(a), Some(b)) => {
      let n = if a.0 < b.0 || (a.0 == b.0 && a.1 < b.1) {
        -1
      } else if a == b {
        0
      } else {
        1
      }
      return match op {
        "<" => n < 0
        "<=" => n <= 0
        ">" => n > 0
        ">=" => n >= 0
        _ => false
      }
    }
    _ => ()
  }
  let ordering = match (left, right) {
    (@fga.VInt(a), @fga.VInt(b)) =>
      if a < b {
        -1
      } else if a > b {
        1
      } else {
        0
      }
    (@fga.VUint(a), @fga.VUint(b)) =>
      if a < b {
        -1
      } else if a > b {
        1
      } else {
        0
      }
    (@fga.VString(a), @fga.VString(b)) => a.lexical_compare(b)
    (@fga.VBytes(a), @fga.VBytes(b)) => a.lexical_compare(b)
    (@fga.VTimestamp(a), @fga.VTimestamp(b)) =>
      if a < b {
        -1
      } else if a > b {
        1
      } else {
        0
      }
    (@fga.VDuration(a), @fga.VDuration(b)) =>
      if a < b {
        -1
      } else if a > b {
        1
      } else {
        0
      }
    _ => {
      let a = numeric_double(left)
      let b = numeric_double(right)
      match (a, b) {
        (Some(x), Some(y)) => if x < y { -1 } else if x > y { 1 } else { 0 }
        _ =>
          raise eval_error(
            "cannot compare " +
            @fga.cel_value_type_name(left) +
            " and " +
            @fga.cel_value_type_name(right),
          )
      }
    }
  }
  match op {
    "<" => ordering < 0
    "<=" => ordering <= 0
    ">" => ordering > 0
    ">=" => ordering >= 0
    _ => false
  }
}

///|
fn value_in(
  needle : @fga.CelValue,
  haystack : @fga.CelValue,
) -> Bool raise @fga.FgaError {
  match haystack {
    @fga.VList(items) => {
      let mut found = false
      for item in items {
        if @fga.cel_value_eq(needle, item) {
          found = true
        }
      }
      found
    }
    @fga.VMap(entries) => {
      let key = match needle {
        @fga.VString(s) => s
        _ => @fga.cel_value_to_display(needle)
      }
      entries.contains(key)
    }
    @fga.VString(_) =>
      raise eval_error("operator 'in' is not defined for strings")
    _ =>
      raise eval_error(
        "operator 'in' is not defined for " + @fga.cel_value_type_name(haystack),
      )
  }
}

///|
fn cell_value_key(value : @fga.CelValue) -> String raise @fga.FgaError {
  match value {
    @fga.VString(s) => s
    _ =>
      raise eval_error(
        "map keys must be strings, found " + @fga.cel_value_type_name(value),
      )
  }
}

///|
fn eval_index(
  target : @fga.CelValue,
  index : @fga.CelValue,
) -> @fga.CelValue raise @fga.FgaError {
  match target {
    @fga.VList(items) => {
      let i = as_int_value(index)
      if i < 0L || i >= items.length().to_int64() {
        raise eval_error("list index out of range")
      }
      items[i.to_int()]
    }
    @fga.VMap(entries) => {
      let key = cell_value_key(index)
      match entries.get(key) {
        Some(v) => v
        None => raise eval_error("no such key '" + key + "'")
      }
    }
    _ =>
      raise eval_error("cannot index into " + @fga.cel_value_type_name(target))
  }
}

///|
fn eval_predicate(
  items : Array[@fga.CelValue],
  variable : String,
  predicate : CelExpr,
  env : Map[String, @fga.CelValue],
  mode : String,
) -> @fga.CelValue raise @fga.FgaError {
  let mut count = 0
  let mut pending : @fga.FgaError? = None
  for item in items {
    let result = as_bool_value(
      eval_expr(predicate, with_binding(env, variable, item)),
    ) catch {
      err => {
        pending = Some(err)
        continue
      }
    }
    if result {
      count = count + 1
    }
    if mode == "exists" && result {
      return @fga.VBool(true)
    }
    if mode == "all" && !result {
      return @fga.VBool(false)
    }
  }
  match pending {
    Some(err) => raise err
    None => ()
  }
  @fga.VBool(if mode == "exists_one" { count == 1 } else { mode == "all" })
}

///|
fn eval_method(
  receiver : @fga.CelValue,
  name : String,
  args : Array[CelExpr],
  env : Map[String, @fga.CelValue],
) -> @fga.CelValue raise @fga.FgaError {
  match receiver {
    @fga.VBytes(b) =>
      if name == "size" && args.is_empty() {
        @fga.VInt(b.length().to_int64())
      } else {
        raise eval_error("unsupported bytes method")
      }
    @fga.VString(s) =>
      match name {
        "size" => @fga.VInt(s.char_length().to_int64())
        "startsWith" => {
          if args.length() != 1 {
            raise eval_error("startsWith expects one argument")
          }
          @fga.VBool(s.has_prefix(as_string_value(eval_expr(args[0], env))))
        }
        "endsWith" => {
          if args.length() != 1 {
            raise eval_error("endsWith expects one argument")
          }
          @fga.VBool(s.has_suffix(as_string_value(eval_expr(args[0], env))))
        }
        "contains" => {
          if args.length() != 1 {
            raise eval_error("contains expects one argument")
          }
          @fga.VBool(s.contains(as_string_value(eval_expr(args[0], env))))
        }
        "matches" => {
          if args.length() != 1 {
            raise eval_error("matches expects one argument")
          }
          @fga.VBool(regex_matches(as_string_value(eval_expr(args[0], env)), s))
        }
        _ => raise eval_error("unsupported string method '" + name + "'")
      }
    @fga.VList(items) =>
      match name {
        "size" => @fga.VInt(items.length().to_int64())
        "exists" | "exists_one" | "all" => {
          if args.length() != 2 {
            raise eval_error(name + " expects a variable and a predicate")
          }
          let variable = match args[0] {
            CIdent(v) => v
            _ =>
              raise eval_error(
                name + " expects an identifier as its first argument",
              )
          }
          eval_predicate(items, variable, args[1], env, name)
        }
        "map" => {
          if args.length() != 2 {
            raise eval_error("map expects a variable and an expression")
          }
          let variable = match args[0] {
            CIdent(v) => v
            _ =>
              raise eval_error(
                "map expects an identifier as its first argument",
              )
          }
          let result : Array[@fga.CelValue] = []
          for item in items {
            result.push(eval_expr(args[1], with_binding(env, variable, item)))
          }
          @fga.VList(result)
        }
        "filter" => {
          if args.length() != 2 {
            raise eval_error("filter expects a variable and a predicate")
          }
          let variable = match args[0] {
            CIdent(v) => v
            _ =>
              raise eval_error(
                "filter expects an identifier as its first argument",
              )
          }
          let result : Array[@fga.CelValue] = []
          for item in items {
            if as_bool_value(
                eval_expr(args[1], with_binding(env, variable, item)),
              ) {
              result.push(item)
            }
          }
          @fga.VList(result)
        }
        _ => raise eval_error("unsupported list method '" + name + "'")
      }
    @fga.VMap(entries) =>
      match name {
        "size" => @fga.VInt(entries.length().to_int64())
        _ =>
          if args.length() == 0 {
            match entries.get(name) {
              Some(v) => v
              None => raise eval_error("no such key '" + name + "'")
            }
          } else {
            raise eval_error("unsupported map method '" + name + "'")
          }
      }
    @fga.VIp(address) =>
      match name {
        "in_cidr" => {
          if args.length() != 1 {
            raise eval_error("in_cidr expects one argument")
          }
          @fga.VBool(
            ip_in_cidr(address, as_string_value(eval_expr(args[0], env))),
          )
        }
        _ => raise eval_error("unsupported ipaddress method '" + name + "'")
      }
    @fga.VTimestampPrecise(ms, _, _) =>
      eval_method(@fga.VTimestamp(ms), name, args, env)
    @fga.VTimestamp(ms) =>
      match name {
        "getSeconds" => @fga.VInt(ms / 1000L - ms / 1000L / 86400L * 86400L)
        "getMilliseconds" => @fga.VInt(ms % 1000L)
        _ => raise eval_error("unsupported timestamp method '" + name + "'")
      }
    @fga.VDuration(ns) =>
      match name {
        "getSeconds" => @fga.VInt(ns / 1000000000L)
        "getMilliseconds" => @fga.VInt(ns / 1000000L)
        _ => raise eval_error("unsupported duration method '" + name + "'")
      }
    @fga.VInt(i) =>
      match name {
        "string" => @fga.VString(i.to_string())
        _ => raise eval_error("unsupported int method '" + name + "'")
      }
    _ =>
      raise eval_error(
        "unsupported method '" +
        name +
        "' on " +
        @fga.cel_value_type_name(receiver),
      )
  }
}

///|
fn eval_call(
  name : String,
  args : Array[CelExpr],
  env : Map[String, @fga.CelValue],
) -> @fga.CelValue raise @fga.FgaError {
  if name == "has" {
    if args.length() != 1 {
      raise eval_error("has expects one field selection")
    }
    match args[0] {
      CMethod(receiver, field, call_args) => {
        if !call_args.is_empty() {
          raise eval_error("has expects a field selection")
        }
        match eval_expr(receiver, env) {
          @fga.VMap(entries) => return @fga.VBool(entries.contains(field))
          _ => raise eval_error("has expects a map field")
        }
      }
      _ => raise eval_error("has expects a field selection")
    }
  }
  let values : Array[@fga.CelValue] = []
  for arg in args {
    values.push(eval_expr(arg, env))
  }
  match name {
    "bytes" => {
      if values.length() != 1 {
        raise eval_error("bytes expects one argument")
      }
      match values[0] {
        @fga.VBytes(b) => @fga.VBytes(b)
        @fga.VString(s) => @fga.VBytes(@utf8.encode(s[:]))
        _ => raise eval_error("cannot convert value to bytes")
      }
    }
    "dyn" => {
      if values.length() != 1 {
        raise eval_error("dyn expects one argument")
      }
      values[0]
    }
    "timestamp" => {
      if values.length() != 1 {
        raise eval_error("timestamp expects one string argument")
      }
      parse_timestamp_value(as_string_value(values[0]))
    }
    "duration" => {
      if values.length() != 1 {
        raise eval_error("duration expects one string argument")
      }
      @fga.VDuration(parse_duration(as_string_value(values[0])))
    }
    "ipaddress" => {
      if values.length() != 1 {
        raise eval_error("ipaddress expects one string argument")
      }
      let text = as_string_value(values[0])
      @fga.VIp(canonical_ip(text))
    }
    "size" => {
      if values.length() != 1 {
        raise eval_error("size expects one argument")
      }
      match values[0] {
        @fga.VString(s) => @fga.VInt(s.char_length().to_int64())
        @fga.VBytes(b) => @fga.VInt(b.length().to_int64())
        @fga.VList(items) => @fga.VInt(items.length().to_int64())
        @fga.VMap(entries) => @fga.VInt(entries.length().to_int64())
        other =>
          raise eval_error(
            "cannot take size of " + @fga.cel_value_type_name(other),
          )
      }
    }
    "int" => {
      if values.length() != 1 {
        raise eval_error("int expects one argument")
      }
      match values[0] {
        @fga.VInt(i) => @fga.VInt(i)
        @fga.VUint(u) =>
          if u > 9223372036854775807UL {
            raise eval_error("integer overflow")
          } else {
            @fga.VInt(u.reinterpret_as_int64())
          }
        @fga.VDouble(d) =>
          if d.is_nan() ||
            d < -9223372036854775808.0 ||
            d >= 9223372036854775808.0 {
            raise eval_error("integer overflow")
          } else {
            @fga.VInt(d.to_int64())
          }
        @fga.VString(s) =>
          @fga.VInt(@string.parse_int64(s)) catch {
            _ => raise eval_error("cannot convert '" + s + "' to int")
          }
        other =>
          raise eval_error(
            "cannot convert " + @fga.cel_value_type_name(other) + " to int",
          )
      }
    }
    "uint" => {
      if values.length() != 1 {
        raise eval_error("uint expects one argument")
      }
      match values[0] {
        @fga.VUint(u) => @fga.VUint(u)
        @fga.VInt(i) =>
          if i < 0L {
            raise eval_error("cannot convert a negative int to uint")
          } else {
            @fga.VUint(i.reinterpret_as_uint64())
          }
        @fga.VString(s) =>
          @fga.VUint(@string.parse_uint64(s)) catch {
            _ => raise eval_error("invalid uint conversion")
          }
        @fga.VDouble(d) =>
          if d.is_nan() || d.is_inf() || d >= 18446744073709551616.0 || d < 0.0 {
            raise eval_error("cannot convert a negative double to uint")
          } else {
            @fga.VUint(
              if d < 9223372036854775808.0 {
                d.to_int64().reinterpret_as_uint64()
              } else {
                (d - 9223372036854775808.0).to_int64().reinterpret_as_uint64() +
                9223372036854775808UL
              },
            )
          }
        other =>
          raise eval_error(
            "cannot convert " + @fga.cel_value_type_name(other) + " to uint",
          )
      }
    }
    "double" => {
      if values.length() != 1 {
        raise eval_error("double expects one argument")
      }
      match values[0] {
        @fga.VDouble(d) => @fga.VDouble(d)
        @fga.VString(s) =>
          @fga.VDouble(@string.parse_double(s)) catch {
            _ => raise eval_error("invalid double conversion")
          }
        @fga.VInt(i) => @fga.VDouble(i.to_double())
        @fga.VUint(u) => @fga.VDouble(u.to_double())
        other =>
          raise eval_error(
            "cannot convert " + @fga.cel_value_type_name(other) + " to double",
          )
      }
    }
    "string" => {
      if values.length() != 1 {
        raise eval_error("string expects one argument")
      }
      match values[0] {
        @fga.VTimestamp(_) | @fga.VTimestampPrecise(_, _, _) =>
          @fga.VString(@fga.timestamp_to_rfc3339(values[0]))
        @fga.VBytes(b) =>
          @fga.VString(@utf8.decode(b[:], ignore_bom=true)) catch {
            _ => raise eval_error("invalid UTF-8 in bytes to string conversion")
          }
        @fga.VString(s) => @fga.VString(s)
        @fga.VUint(u) => @fga.VString(u.to_string())
        other => @fga.VString(@fga.cel_value_to_display(other))
      }
    }
    "bool" => {
      if values.length() != 1 {
        raise eval_error("bool expects one argument")
      }
      match values[0] {
        @fga.VBool(b) => @fga.VBool(b)
        @fga.VString("true") => @fga.VBool(true)
        @fga.VString("false") => @fga.VBool(false)
        _ => raise eval_error("invalid bool conversion")
      }
    }
    _ => raise eval_error("unknown function '" + name + "'")
  }
}

///|
/// A deciding boolean absorbs an error on either side. A deciding left
/// value still short-circuits, and unresolved errors remain errors.
fn eval_logical(
  left : CelExpr,
  right : CelExpr,
  env : Map[String, @fga.CelValue],
  deciding : Bool,
) -> @fga.CelValue raise @fga.FgaError {
  let mut left_error : @fga.FgaError? = None
  let value = as_bool_value(eval_expr(left, env)) catch {
    err => {
      left_error = Some(err)
      !deciding
    }
  }
  if value == deciding && left_error is None {
    return @fga.VBool(deciding)
  }
  let other = as_bool_value(eval_expr(right, env))
  if other == deciding {
    return @fga.VBool(deciding)
  }
  match left_error {
    Some(err) => raise err
    None => @fga.VBool(other)
  }
}

///|
/// Evaluates a compiled CEL expression in the given variable environment.
pub fn eval_expr(
  expr : CelExpr,
  env : Map[String, @fga.CelValue],
) -> @fga.CelValue raise @fga.FgaError {
  match expr {
    CLiteral(value) => value
    CIdent(name) =>
      match env.get(name) {
        Some(value) => value
        None => raise eval_error("no such variable '" + name + "'")
      }
    CUnary(op, inner) => {
      let value = eval_expr(inner, env)
      match op {
        "!" => @fga.VBool(!as_bool_value(value))
        "-" =>
          match value {
            @fga.VInt(i) =>
              if i == -9223372036854775807L - 1L {
                raise eval_error("integer overflow")
              } else {
                @fga.VInt(-i)
              }
            @fga.VDouble(d) => @fga.VDouble(-d)
            _ =>
              raise eval_error(
                "cannot negate " + @fga.cel_value_type_name(value),
              )
          }
        _ => raise eval_error("unsupported unary operator '" + op + "'")
      }
    }
    CBinary("&&", left, right) => eval_logical(left, right, env, false)
    CBinary("||", left, right) => eval_logical(left, right, env, true)
    CBinary("==", left, right) =>
      @fga.VBool(@fga.cel_value_eq(eval_expr(left, env), eval_expr(right, env)))
    CBinary("!=", left, right) =>
      @fga.VBool(
        !@fga.cel_value_eq(eval_expr(left, env), eval_expr(right, env)),
      )
    CBinary(op, left, right) => {
      let l = eval_expr(left, env)
      let r = eval_expr(right, env)
      if op == "in" {
        @fga.VBool(value_in(l, r))
      } else if op == "<" || op == "<=" || op == ">" || op == ">=" {
        @fga.VBool(compare_values(op, l, r))
      } else {
        eval_arithmetic(op, l, r)
      }
    }
    CTernary(condition, when_true, when_false) =>
      if as_bool_value(eval_expr(condition, env)) {
        eval_expr(when_true, env)
      } else {
        eval_expr(when_false, env)
      }
    CCall(name, args) => eval_call(name, args, env)
    CMethod(receiver, name, args) => {
      let value = eval_expr(receiver, env)
      eval_method(value, name, args, env)
    }
    CIndex(target, index) =>
      eval_index(eval_expr(target, env), eval_expr(index, env))
    CList(items) => {
      let values : Array[@fga.CelValue] = []
      for item in items {
        values.push(eval_expr(item, env))
      }
      @fga.VList(values)
    }
    CMap(entries) => {
      let result : Map[String, @fga.CelValue] = Map([])
      for (key_expr, value_expr) in entries {
        let key = cell_value_key(eval_expr(key_expr, env))
        result[key] = eval_expr(value_expr, env)
      }
      @fga.VMap(result)
    }
  }
}
