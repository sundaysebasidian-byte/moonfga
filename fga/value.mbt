// JSON bridge for CEL values. Typed coercion (for example interpreting a
// JSON string as a timestamp) lives in the CEL package where the parsers are.

///|
pub fn json_to_cel_value_raw(value : Json) -> CelValue {
  match value {
    Null => VNull
    True => VBool(true)
    False => VBool(false)
    String(s) => VString(s)
    Number(d, ..) =>
      if d.is_nan() || d.is_inf() {
        VDouble(d)
      } else if d == d.floor() &&
        d >= -9223372036854775808.0 &&
        d <= 9223372036854775807.0 {
        VInt(d.to_int64())
      } else {
        VDouble(d)
      }
    Array(xs) => VList(xs.map(fn(x) { json_to_cel_value_raw(x) }))
    Object(m) => {
      let out : Map[String, CelValue] = Map([])
      m.each(fn(k, v) { out[k] = json_to_cel_value_raw(v) })
      VMap(out)
    }
  }
}

///|
pub fn cel_value_to_json(value : CelValue) -> Json {
  match value {
    VInt(x) => Json::number(x.to_double(), repr=x.to_string())
    VUint(x) => Json::number(x.to_double(), repr=x.to_string())
    VDouble(x) => Json::number(x)
    VBool(x) => Json::boolean(x)
    VString(x) => Json::string(x)
    VBytes(x) =>
      Json::array(x.to_array().map(b => Json::number(b.to_int().to_double())))
    VDuration(x) => Json::string(x.to_string() + "ns")
    VTimestamp(_) | VTimestampPrecise(_, _, _) =>
      Json::string(timestamp_to_rfc3339(value))
    VList(xs) => Json::array(xs.map(fn(x) { cel_value_to_json(x) }))
    VMap(m) => {
      let out : Map[String, Json] = Map([])
      m.each(fn(k, v) { out[k] = cel_value_to_json(v) })
      Json::object(out)
    }
    VIp(x) => Json::string(x)
    VType(x) => Json::string(x)
    VKeyMap(xs) =>
      Json::array(
        xs.map(x => {
          Json::array([cel_value_to_json(x.0), cel_value_to_json(x.1)])
        }),
      )
    VNull => Json::null()
  }
}

///|
pub fn json_object_to_value_map(
  value : Json,
) -> Map[String, CelValue] raise FgaError {
  match value {
    Object(m) => {
      let out : Map[String, CelValue] = Map([])
      m.each(fn(k, v) { out[k] = json_to_cel_value_raw(v) })
      out
    }
    Null => Map([])
    _ =>
      raise fail(ERR_VALIDATION, "expected a JSON object for condition context")
  }
}

///|
pub fn json_object_get(value : Json, key : String) -> Json? {
  match value {
    Object(m) => m.get(key)
    _ => None
  }
}

///|
pub fn json_get_string(value : Json, key : String) -> String? {
  match json_object_get(value, key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
pub fn json_get_bool(value : Json, key : String) -> Bool? {
  match json_object_get(value, key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
pub fn json_get_array(value : Json, key : String) -> Array[Json] {
  match json_object_get(value, key) {
    Some(Array(xs)) => xs
    _ => []
  }
}

///|
pub fn json_get_object(value : Json, key : String) -> Json? {
  match json_object_get(value, key) {
    Some(Object(_) as o) => Some(o)
    _ => None
  }
}

///|
/// CEL's observable cost-model size, not a serialized byte length.
pub fn cel_value_size(value : CelValue) -> Int32 {
  match value {
    VString(s) => s.char_length()
    VBytes(b) => b.length()
    VList(xs) => xs.length()
    VMap(xs) => xs.length()
    VKeyMap(xs) => xs.length()
    _ => 1
  }
}
