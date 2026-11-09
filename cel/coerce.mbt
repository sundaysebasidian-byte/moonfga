// Typed coercion of JSON request context into CEL values.

///|
fn coercion_error(
  param_name : String,
  expected : String,
  value : Json,
) -> @fga.FgaError {
  @fga.fail(
    @fga.ERR_VALIDATION,
    "parameter '" +
    param_name +
    "' expects " +
    expected +
    ", got " +
    @fga.cel_value_to_display(@fga.json_to_cel_value_raw(value)),
  )
}

///|
fn coerce_primitive(
  param_name : String,
  type_name : String,
  value : Json,
) -> @fga.CelValue raise @fga.FgaError {
  match type_name {
    "any" => dynamic_context(value)
    "bool" =>
      match value {
        True => @fga.VBool(true)
        False => @fga.VBool(false)
        other => raise coercion_error(param_name, "a bool", other)
      }
    "string" =>
      match value {
        String(s) => @fga.VString(s)
        other => raise coercion_error(param_name, "a string", other)
      }
    "int" => @fga.VInt(context_integer(value))
    "uint" => {
      let i = context_integer(value)
      if i < 0L {
        raise coercion_error(param_name, "a uint", value)
      }
      @fga.VUint(i.reinterpret_as_uint64())
    }
    "double" =>
      match value {
        Number(d, ..) => @fga.VDouble(d)
        String(s) => @fga.VDouble(context_double_text(s))
        other => raise coercion_error(param_name, "a double", other)
      }
    "duration" =>
      match value {
        String(s) => @fga.VDuration(parse_duration(s))
        other => raise coercion_error(param_name, "a duration string", other)
      }
    "timestamp" =>
      match value {
        String(s) => parse_timestamp_value(s, context_mode=true)
        other => raise coercion_error(param_name, "a timestamp string", other)
      }
    "ipaddress" =>
      match value {
        String(s) => @fga.VIp(canonical_ip(s))
        other => raise coercion_error(param_name, "an IP address string", other)
      }
    _ =>
      raise @fga.fail(
        @fga.ERR_VALIDATION,
        "unsupported condition parameter type '" + type_name + "'",
      )
  }
}

///|
fn coerce_value(
  param_name : String,
  type_name : String,
  generic_type : String?,
  value : Json,
) -> @fga.CelValue raise @fga.FgaError {
  match value {
    Null =>
      if type_name == "any" {
        @fga.VNull
      } else {
        raise coercion_error(param_name, type_name, value)
      }
    _ =>
      if type_name == "list" {
        match value {
          Array(items) => {
            let result : Array[@fga.CelValue] = []
            for item in items {
              let element = match generic_type {
                Some(inner) => coerce_type_text(param_name, inner, item)
                None => @fga.json_to_cel_value_raw(item)
              }
              result.push(element)
            }
            @fga.VList(result)
          }
          other => raise coercion_error(param_name, "a list", other)
        }
      } else if type_name == "map" {
        match value {
          Object(entries) => {
            let result : Map[String, @fga.CelValue] = Map([])
            for key in entries.keys() {
              match entries.get(key) {
                Some(item) =>
                  result[key] = match generic_type {
                    Some(inner) => coerce_type_text(param_name, inner, item)
                    None => @fga.json_to_cel_value_raw(item)
                  }
                None => ()
              }
            }
            @fga.VMap(result)
          }
          other => raise coercion_error(param_name, "a map", other)
        }
      } else {
        coerce_primitive(param_name, type_name, value)
      }
  }
}

///|
/// Coerces one JSON context value according to a declared condition parameter.
pub fn coerce_context(
  param : @fga.ConditionParam,
  value : Json,
) -> @fga.CelValue raise @fga.FgaError {
  coerce_value(param.name, param.type_name, param.generic_type, value)
}

///|
fn coerce_type_text(
  name : String,
  text : String,
  value : Json,
) -> @fga.CelValue raise @fga.FgaError {
  match text.find("<") {
    Some(i) =>
      coerce_value(
        name,
        text[:i].to_owned(),
        Some(text[i + 1:text.length() - 1].to_owned()),
        value,
      )
    None => coerce_value(name, text, None, value)
  }
}
