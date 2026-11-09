///|
/// Decimal decomposition shared by OpenFGA's numeric context conversion.
fn decimal_parts(text : String) -> (Bool, String, Int32) raise @fga.FgaError {
  let chars = text.iter().collect()
  let mut pos = 0
  let negative = chars.get(0) == Some('-')
  if negative || chars.get(0) == Some('+') {
    pos += 1
  }
  let sb = StringBuilder()
  let mut fraction = 0
  let mut dot = false
  let mut count = 0
  while pos < chars.length() {
    let c = chars[pos]
    if c == '.' && !dot {
      dot = true
      pos += 1
      continue
    }
    if !c.is_ascii_digit() {
      break
    }
    sb.write_char(c)
    count += 1
    if dot {
      fraction += 1
    }
    pos += 1
  }
  if count == 0 {
    raise eval_error("invalid numeric context")
  }
  let mut exponent = 0
  if chars.get(pos) == Some('e') || chars.get(pos) == Some('E') {
    pos += 1
    exponent = @string.parse_int(String::from_array(chars[pos:])) catch {
      _ => raise eval_error("invalid numeric context exponent")
    }
    pos = chars.length()
  }
  if pos != chars.length() {
    raise eval_error("invalid numeric context")
  }
  let raw = sb.to_string()
  let mut start = 0
  while start < raw.length() && raw.get_char(start) == Some('0') {
    start += 1
  }
  (negative, raw[start:].to_owned(), exponent - fraction)
}

///|
fn context_integer_text(text : String) -> Int64 raise @fga.FgaError {
  let (negative, significant, exponent) = rounded_decimal(text)
  if significant == 0UL {
    return 0L
  }
  if exponent < 0 {
    raise eval_error("non-integral context")
  }
  if exponent >= 63 {
    return if negative {
      -9223372036854775807L - 1L
    } else {
      9223372036854775807L
    }
  }
  let shift = 63 - exponent
  if (significant & ((1UL << shift) - 1UL)) != 0UL {
    raise eval_error("non-integral context")
  }
  let integer = (significant >> shift).reinterpret_as_int64()
  if negative {
    -integer
  } else {
    integer
  }
}

///|
fn context_integer(value : Json) -> Int64 raise @fga.FgaError {
  match value {
    String(s) => context_integer_text(s)
    Number(d, ..) => {
      if d.is_nan() || d.is_inf() || d.floor() != d {
        raise eval_error("non-integral context")
      }
      if d >= 9223372036854775808.0 {
        9223372036854775807L
      } else if d <= -9223372036854775808.0 {
        -9223372036854775807L - 1L
      } else {
        d.to_int64()
      }
    }
    _ => raise eval_error("invalid numeric context")
  }
}

///|
fn dynamic_context(value : Json) -> @fga.CelValue {
  match value {
    Number(d, ..) => @fga.VDouble(d)
    Array(items) => @fga.VList(items.map(dynamic_context))
    Object(entries) => {
      let result : Map[String, @fga.CelValue] = Map([])
      entries.each((k, v) => result[k] = dynamic_context(v))
      @fga.VMap(result)
    }
    _ => @fga.json_to_cel_value_raw(value)
  }
}

///|
fn context_double_text(text : String) -> Double raise @fga.FgaError {
  if ["Inf", "+Inf"].contains(text) {
    return 1.0 / 0.0
  }
  if text == "-Inf" {
    return -1.0 / 0.0
  }
  let (negative, significant, exponent) = rounded_decimal(text)
  let result = if text.contains("p") || text.contains("P") {
    (if negative { -1.0 } else { 1.0 }) *
    (significant.to_double() / 9223372036854775808.0) *
    @math.pow(2.0, exponent.to_double())
  } else {
    @string.parse_double(text) catch {
      _ => raise eval_error("invalid double context")
    }
  }
  if significant == 0UL {
    return result
  }
  let discarded = 11 + (if exponent < -1022 { -1022 - exponent } else { 0 })
  if exponent > 1023 ||
    discarded >= 64 ||
    (significant & ((1UL << discarded) - 1UL)) != 0UL {
    raise eval_error("double context precision is not representable")
  }
  result
}
