// CEL's default protobuf registry exposes these well-known descriptors. Values
// are adapted to CEL primitives rather than kept as user-defined messages.

///|
fn proto_known(name : String) -> Bool {
  [
    "google.protobuf.Struct.FieldsEntry", "google.protobuf.Timestamp", "google.protobuf.Duration",
    "google.protobuf.Empty", "google.protobuf.Any", "google.protobuf.Struct", "google.protobuf.ListValue",
    "google.protobuf.Value", "google.protobuf.BoolValue", "google.protobuf.BytesValue",
    "google.protobuf.StringValue", "google.protobuf.Int32Value", "google.protobuf.Int64Value",
    "google.protobuf.UInt32Value", "google.protobuf.UInt64Value", "google.protobuf.FloatValue",
    "google.protobuf.DoubleValue",
  ].contains(name)
}

///|
fn proto_json(value : @fga.CelValue) -> @fga.CelValue raise @fga.FgaError {
  match value {
    @fga.VInt(i) => @fga.VDouble(i.to_double())
    @fga.VUint(i) => @fga.VDouble(i.to_double())
    @fga.VDouble(_) => value
    @fga.VTimestamp(_)
    | @fga.VTimestampPrecise(_, _, _)
    | @fga.VTimestampWide(_, _) =>
      @fga.VString(@fga.timestamp_to_rfc3339(value))
    @fga.VDuration(ns) => @fga.VString(format_duration(ns))
    @fga.VBytes(b) => @fga.VString(@base64.encode(b[:]))
    @fga.VList(items) => @fga.VList(items.map(proto_json))
    @fga.VMap(entries) => {
      let result : Map[String, @fga.CelValue] = Map([])
      for (k, v) in entries {
        result[k] = proto_json(v)
      }
      @fga.VMap(result)
    }
    @fga.VKeyMap(entries) => {
      let result : Map[String, @fga.CelValue] = Map([])
      for (k, v) in entries {
        result[as_string_value(k)] = proto_json(v)
      }
      @fga.VMap(result)
    }
    @fga.VBool(_) | @fga.VString(_) | @fga.VNull => value
    _ => raise eval_error("cannot adapt value to protobuf JSON value")
  }
}

///|
fn proto_int32(value : @fga.CelValue) -> Int64 raise @fga.FgaError {
  let i = as_int_value(value)
  if i < -2147483648L || i > 2147483647L {
    raise eval_error("protobuf int32 overflow")
  }
  i
}

///|
fn proto_value(
  name : String,
  fields : Map[String, @fga.CelValue],
) -> @fga.CelValue raise @fga.FgaError {
  let schema = proto_schema(name)
  for (field, value) in fields {
    match schema.get(field) {
      Some(t) => proto_require(value, t)
      None => raise eval_error("unknown protobuf field")
    }
  }
  let v = fields.get("value")
  match name {
    "google.protobuf.Empty" => @fga.VProtoEmpty
    "google.protobuf.Struct.FieldsEntry" =>
      @fga.VProtoFields(
        fields.get("key").map(as_string_value).unwrap_or(""),
        fields.get("value").map(proto_json),
      )
    "google.protobuf.Int64Value" => v.unwrap_or(@fga.VInt(0L))
    "google.protobuf.Int32Value" =>
      @fga.VInt(proto_int32(v.unwrap_or(@fga.VInt(0L))))
    "google.protobuf.UInt64Value" => v.unwrap_or(@fga.VUint(0UL))
    "google.protobuf.UInt32Value" => {
      let x = v.unwrap_or(@fga.VUint(0UL))
      if x is @fga.VUint(u) && u <= 4294967295UL {
        x
      } else {
        raise eval_error("protobuf uint32 overflow")
      }
    }
    "google.protobuf.BoolValue" => v.unwrap_or(@fga.VBool(false))
    "google.protobuf.StringValue" => v.unwrap_or(@fga.VString(""))
    "google.protobuf.BytesValue" => v.unwrap_or(@fga.VBytes(b""))
    "google.protobuf.DoubleValue" => v.unwrap_or(@fga.VDouble(0.0))
    "google.protobuf.FloatValue" =>
      match v.unwrap_or(@fga.VDouble(0.0)) {
        @fga.VDouble(d) =>
          @fga.VDouble(@float.Float::from_double(d).to_double())
        _ => raise eval_error("invalid protobuf float")
      }
    "google.protobuf.Timestamp" => {
      let sec = as_int_value(fields.get("seconds").unwrap_or(@fga.VInt(0L)))
      let ns = proto_int32(fields.get("nanos").unwrap_or(@fga.VInt(0L)))
      @fga.timestamp_from_seconds(sec, ns)
    }
    "google.protobuf.Duration" => {
      let sec = as_int_value(fields.get("seconds").unwrap_or(@fga.VInt(0L)))
      let ns = proto_int32(fields.get("nanos").unwrap_or(@fga.VInt(0L)))
      let max = 9223372036854775807L
      let min = -9223372036854775807L - 1L
      let scaled = sec * 1000000000L
      @fga.VDuration(
        if sec > max / 1000000000L {
          max
        } else if sec < min / 1000000000L {
          min
        } else if ns > 0L && scaled > max - ns {
          max
        } else if ns < 0L && scaled < min - ns {
          min
        } else {
          scaled + ns
        },
      )
    }
    "google.protobuf.Struct" =>
      proto_json(fields.get("fields").unwrap_or(@fga.VMap(Map([]))))
    "google.protobuf.ListValue" =>
      proto_json(fields.get("values").unwrap_or(@fga.VList([])))
    "google.protobuf.Value" => {
      if fields.get("null_value") is Some(v) {
        ignore(proto_int32(v))
      }
      let mut result = @fga.VNull
      for (key, value) in fields {
        result = if key == "null_value" {
          @fga.VNull
        } else {
          proto_json(value)
        }
      }
      result
    }
    "google.protobuf.Any" => {
      let url = as_string_value(
        fields.get("type_url").unwrap_or(@fga.VString("")),
      )
      let payload = match fields.get("value").unwrap_or(@fga.VBytes(b"")) {
        @fga.VBytes(b) => b
        _ => raise eval_error("invalid Any bytes")
      }
      proto_unpack(url, payload)
    }
    _ => raise eval_error("unknown protobuf type")
  }
}

///|
priv struct ProtoReader {
  data : Bytes
  mut pos : Int32
}

///|
fn ProtoReader::varint(self : ProtoReader) -> UInt64 raise @fga.FgaError {
  let mut result = 0UL
  for i in 0..<10 {
    if self.pos >= self.data.length() {
      raise eval_error("truncated protobuf varint")
    }
    let b = self.data[self.pos].to_int()
    self.pos += 1
    if i == 9 && b > 1 {
      raise eval_error("protobuf varint overflow")
    }
    result = result | ((b & 127).to_uint64() << (i * 7))
    if b < 128 {
      return result
    }
  }
  raise eval_error("invalid protobuf varint")
}

///|
fn ProtoReader::take(
  self : ProtoReader,
  n : Int32,
) -> Bytes raise @fga.FgaError {
  if n < 0 || n > self.data.length() - self.pos {
    raise eval_error("truncated protobuf field")
  }
  let result = self.data[self.pos:self.pos + n].to_owned()
  self.pos += n
  result
}

///|
fn ProtoReader::block(self : ProtoReader) -> Bytes raise @fga.FgaError {
  let n = self.varint()
  if n > (self.data.length() - self.pos).to_uint64() {
    raise eval_error("invalid protobuf field length")
  }
  self.take(n.to_int())
}

///|
fn ProtoReader::fixed(
  self : ProtoReader,
  count : Int32,
) -> UInt64 raise @fga.FgaError {
  let bytes = self.take(count)
  let mut result = 0UL
  for i in 0..<count {
    result = result | (bytes[i].to_int().to_uint64() << (i * 8))
  }
  result
}

///|
fn ProtoReader::skip(
  self : ProtoReader,
  tag : Int32,
  depth : Int32,
) -> Unit raise @fga.FgaError {
  if depth > 10000 {
    raise eval_error("protobuf recursion limit")
  }
  match tag & 7 {
    0 => ignore(self.varint())
    1 => ignore(self.take(8))
    2 => ignore(self.block())
    3 => {
      while self.pos < self.data.length() {
        let next = self.varint().to_int()
        if (next & 7) == 4 {
          if next >> 3 != tag >> 3 {
            raise eval_error("mismatched protobuf group")
          }
          return
        }
        self.skip(next, depth + 1)
      }
      raise eval_error("unterminated protobuf group")
    }
    5 => ignore(self.take(4))
    _ => raise eval_error("invalid protobuf wire type")
  }
}

///|
fn proto_text(bytes : Bytes) -> String raise @fga.FgaError {
  @utf8.decode(bytes[:], ignore_bom=true) catch {
    _ => raise eval_error("invalid protobuf UTF-8")
  }
}

///|
fn proto_unpack(
  url : String,
  payload : Bytes,
) -> @fga.CelValue raise @fga.FgaError {
  let parts = url.split("/").collect()
  proto_decode(parts.last().unwrap_or("").to_owned(), payload, 0)
}

///|
fn proto_decode(
  name : String,
  payload : Bytes,
  depth : Int32,
) -> @fga.CelValue raise @fga.FgaError {
  if !proto_known(name) || depth > 10000 {
    raise eval_error("unknown protobuf type or recursion limit")
  }
  let reader : ProtoReader = { data: payload, pos: 0, }
  let fields : Map[String, @fga.CelValue] = Map([])
  let items : Array[@fga.CelValue] = []
  let entries : Map[String, @fga.CelValue] = Map([])
  while reader.pos < payload.length() {
    let tag = reader.varint()
    if tag >> 3 == 0UL || tag >> 3 > 536870911UL {
      raise eval_error("invalid protobuf field number")
    }
    let number = (tag >> 3).to_int()
    let wire = (tag & 7UL).to_int()
    let field = if name == "google.protobuf.Timestamp" ||
      name == "google.protobuf.Duration" {
      match number {
        1 => "seconds"
        2 => "nanos"
        _ => ""
      }
    } else if name == "google.protobuf.Any" {
      match number {
        1 => "type_url"
        2 => "value"
        _ => ""
      }
    } else if name == "google.protobuf.Value" {
      match number {
        1 => "null_value"
        2 => "number_value"
        3 => "string_value"
        4 => "bool_value"
        5 => "struct_value"
        6 => "list_value"
        _ => ""
      }
    } else if number == 1 && name != "google.protobuf.Empty" {
      "value"
    } else {
      ""
    }
    if field == "" {
      reader.skip(tag.to_int(), depth)
      continue
    }
    let required_wire = if field == "number_value" ||
      name == "google.protobuf.DoubleValue" {
      1
    } else if name == "google.protobuf.FloatValue" {
      5
    } else if [
        "google.protobuf.StringValue", "google.protobuf.BytesValue", "google.protobuf.Any",
        "google.protobuf.Struct", "google.protobuf.ListValue",
      ].contains(name) ||
      ["string_value", "struct_value", "list_value"].contains(field) {
      2
    } else {
      0
    }
    if wire != required_wire {
      reader.skip(tag.to_int(), depth)
      continue
    }
    let value = if wire == 0 {
      let u = reader.varint()
      if name == "google.protobuf.BoolValue" || field == "bool_value" {
        @fga.VBool(u != 0UL)
      } else if name == "google.protobuf.UInt64Value" {
        @fga.VUint(u)
      } else if name == "google.protobuf.UInt32Value" {
        @fga.VUint(u & 4294967295UL)
      } else if name == "google.protobuf.Int32Value" ||
        field == "nanos" ||
        field == "null_value" {
        @fga.VInt(u.to_int().to_int64())
      } else {
        @fga.VInt(u.reinterpret_as_int64())
      }
    } else if wire == 1 {
      @fga.VDouble(reader.fixed(8).reinterpret_as_double())
    } else if wire == 5 {
      @fga.VDouble(
        @float.Float::reinterpret_from_uint(reader.fixed(4).to_uint()).to_double(),
      )
    } else {
      let bytes = reader.block()
      if name == "google.protobuf.BytesValue" ||
        (name == "google.protobuf.Any" && field == "value") {
        @fga.VBytes(bytes)
      } else if name == "google.protobuf.ListValue" {
        let item = proto_decode("google.protobuf.Value", bytes, depth + 1)
        items.push(item)
        @fga.VList(items)
      } else if name == "google.protobuf.Struct" {
        let entry : ProtoReader = { data: bytes, pos: 0, }
        let mut key = ""
        let mut value = @fga.VNull
        while entry.pos < bytes.length() {
          let entry_tag = entry.varint().to_int()
          if entry_tag == 10 {
            key = proto_text(entry.block())
          } else if entry_tag == 18 {
            value = proto_decode(
              "google.protobuf.Value",
              entry.block(),
              depth + 1,
            )
          } else {
            entry.skip(entry_tag, depth + 1)
          }
        }
        entries[key] = value
        @fga.VMap(entries)
      } else if field == "struct_value" {
        proto_decode("google.protobuf.Struct", bytes, depth + 1)
      } else if field == "list_value" {
        proto_decode("google.protobuf.ListValue", bytes, depth + 1)
      } else {
        @fga.VString(proto_text(bytes))
      }
    }
    if name == "google.protobuf.Value" {
      fields.clear()
    }
    fields[field] = value
  }
  if name == "google.protobuf.ListValue" {
    @fga.VList(items)
  } else if name == "google.protobuf.Struct" {
    @fga.VMap(entries)
  } else if name == "google.protobuf.Any" {
    let url = as_string_value(
      fields.get("type_url").unwrap_or(@fga.VString("")),
    )
    let data = match fields.get("value").unwrap_or(@fga.VBytes(b"")) {
      @fga.VBytes(b) => b
      _ => raise eval_error("invalid Any")
    }
    let parts = url.split("/").collect()
    proto_decode(parts.last().unwrap_or("").to_owned(), data, depth + 1)
  } else {
    proto_value(name, fields)
  }
}

///|
fn proto_require(
  value : @fga.CelValue,
  expected : CType,
) -> Unit raise @fga.FgaError {
  match expected {
    Dynamic => ()
    Atom(t) =>
      if @fga.cel_value_type_name(value) != t {
        raise eval_error("invalid protobuf field value")
      }
    List(t) =>
      match value {
        @fga.VList(xs) =>
          for x in xs {
            proto_require(x, t)
          }
        _ => raise eval_error("invalid protobuf list field")
      }
    Map(k, v) =>
      match value {
        @fga.VMap(xs) =>
          for (key, value) in xs {
            proto_require(@fga.VString(key), k)
            proto_require(value, v)
          }
        @fga.VKeyMap(xs) =>
          for (key, value) in xs {
            proto_require(key, k)
            proto_require(value, v)
          }
        _ => raise eval_error("invalid protobuf map field")
      }
  }
}
