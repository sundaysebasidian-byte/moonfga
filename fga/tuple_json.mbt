// Tuple parsing shared by the CLI, store-test runner and conformance matrix.

///|
fn tuple_invalid(message : String) -> FgaError {
  fail(ERR_VALIDATION, message)
}

///|
pub fn tuple_from_json(value : Json) -> Tuple raise FgaError {
  let obj = match value {
    Object(m) => m
    _ => raise tuple_invalid("tuple must be a JSON object")
  }
  let object = match obj.get("object") {
    Some(String(s)) => s
    _ => raise tuple_invalid("tuple 'object' must be a string")
  }
  let relation = match obj.get("relation") {
    Some(String(s)) => s
    _ => raise tuple_invalid("tuple 'relation' must be a string")
  }
  let user = match obj.get("user") {
    Some(String(s)) => s
    _ => raise tuple_invalid("tuple 'user' must be a string")
  }
  let condition = match obj.get("condition") {
    None | Some(Null) => None
    Some(Object(c)) => {
      let name = match c.get("name") {
        Some(String(s)) => s
        _ => raise tuple_invalid("tuple condition 'name' must be a string")
      }
      let context = match c.get("context") {
        None | Some(Null) => Map([])
        Some(ctx) => json_object_to_value_map(ctx)
      }
      Some(TupleCondition::{ name, context, })
    }
    Some(_) => raise tuple_invalid("tuple 'condition' must be an object")
  }
  Tuple::{ object, relation, user, condition, }
}

///|
pub fn tuples_from_json(value : Json?) -> Array[Tuple] raise FgaError {
  match value {
    None | Some(Null) => []
    Some(Array(items)) => {
      let out : Array[Tuple] = []
      for item in items {
        out.push(tuple_from_json(item))
      }
      out
    }
    Some(_) => raise tuple_invalid("tuples must be a JSON array")
  }
}

///|
pub fn context_from_json(value : Json?) -> Map[String, CelValue] raise FgaError {
  match value {
    None | Some(Null) => Map([])
    Some(ctx) => json_object_to_value_map(ctx)
  }
}

///|
fn parse_condition_suffix(spec : String) -> TupleCondition raise FgaError {
  let (name, raw_context) = match spec.find(":") {
    None => (spec, "{}")
    Some(colon) => (spec[:colon].to_owned(), spec[colon + 1:].to_owned())
  }
  if name == "" {
    raise tuple_invalid("tuple condition name cannot be empty")
  }
  let parsed = @json.parse(raw_context) catch {
    _ => raise tuple_invalid("tuple condition context is not valid JSON")
  }
  TupleCondition::{ name, context: json_object_to_value_map(parsed), }
}

///|
/// Parses the OpenFGA text form `object#relation@user` and the optional
/// condition suffix `[name:{"param": 1}]`.
pub fn tuple_from_string(raw : String) -> Tuple raise FgaError {
  let text = raw.trim().to_owned()
  if text == "" {
    raise tuple_invalid("tuple cannot be empty")
  }
  let hash = match text.find("#") {
    Some(i) => i
    None => raise tuple_invalid("tuple is missing '#': " + text)
  }
  let at = match text.find("@") {
    Some(i) => i
    None => raise tuple_invalid("tuple is missing '@': " + text)
  }
  if at <= hash {
    raise tuple_invalid("tuple must be object#relation@user: " + text)
  }
  let object = text[:hash].to_owned()
  let relation = text[hash + 1:at].to_owned()
  let rest = text[at + 1:].to_owned()
  if relation == "" {
    raise tuple_invalid("tuple relation cannot be empty")
  }
  let (user, condition) = match rest.find("[") {
    None => (rest, None)
    Some(start) => {
      if !rest.has_suffix("]") {
        raise tuple_invalid("tuple condition must end with ']': " + text)
      }
      let user = rest[:start].to_owned()
      let spec = rest[start + 1:rest.length() - 1].to_owned()
      (user, Some(parse_condition_suffix(spec)))
    }
  }
  if !is_valid_object(object) {
    raise tuple_invalid("invalid tuple object: " + object)
  }
  if !is_valid_user(user) {
    raise tuple_invalid("invalid tuple user: " + user)
  }
  Tuple::{ object, relation, user, condition, }
}

///|
/// Reads one tuple per line, ignoring blank lines and `#` comments.
pub fn tuples_from_text(source : String) -> Array[Tuple] raise FgaError {
  let out : Array[Tuple] = []
  for line in source.split("\n") {
    let trimmed = line.trim().to_owned()
    if trimmed == "" || trimmed.has_prefix("#") {
      continue
    }
    out.push(tuple_from_string(trimmed))
  }
  out
}
