// Timestamp, duration and IP address parsing for CEL values.

///|
fn fixed_digits(text : String, start : Int32, count : Int32) -> Int32? {
  if start < 0 || start + count > text.length() {
    return None
  }
  let mut value = 0
  for i in 0..<count {
    match text.get_char(start + i) {
      Some(c) =>
        if c >= '0' && c <= '9' {
          value = value * 10 + (c.to_int() - '0'.to_int())
        } else {
          return None
        }
      None => return None
    }
  }
  Some(value)
}

///|
fn days_from_civil(year : Int64, month : Int64, day : Int64) -> Int64 {
  let y = if month <= 2L { year - 1L } else { year }
  let era = if y >= 0L { y / 400L } else { (y - 399L) / 400L }
  let yoe = y - era * 400L
  let mp = if month > 2L { month - 3L } else { month + 9L }
  let doy = (153L * mp + 2L) / 5L + day - 1L
  let doe = yoe * 365L + yoe / 4L - yoe / 100L + doy
  era * 146097L + doe - 719468L
}

///|
fn days_in_month(year : Int32, month : Int32) -> Int32 {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 =>
      if year % 4 == 0 && (year % 100 != 0 || year % 400 == 0) {
        29
      } else {
        28
      }
    _ => 0
  }
}

///|
/// Parses an RFC 3339 timestamp into milliseconds since the Unix epoch.
pub fn parse_timestamp(
  text : String,
  context_mode~ : Bool = false,
) -> Int64 raise @fga.FgaError {
  let invalid = @fga.fail(
    @fga.ERR_VALIDATION,
    "invalid timestamp '" + text + "'",
  )
  if text.length() < 19 {
    raise invalid
  }
  let year = match fixed_digits(text, 0, 4) {
    Some(v) => v
    None => raise invalid
  }
  if text.get_char(4) != Some('-') || text.get_char(7) != Some('-') {
    raise invalid
  }
  let month = match fixed_digits(text, 5, 2) {
    Some(v) => v
    None => raise invalid
  }
  let day = match fixed_digits(text, 8, 2) {
    Some(v) => v
    None => raise invalid
  }
  match text.get_char(10) {
    Some('T') => ()
    _ => raise invalid
  }
  if text.get_char(13) != Some(':') || text.get_char(16) != Some(':') {
    raise invalid
  }
  let hour = match fixed_digits(text, 11, 2) {
    Some(v) => v
    None => raise invalid
  }
  let minute = match fixed_digits(text, 14, 2) {
    Some(v) => v
    None => raise invalid
  }
  let second = match fixed_digits(text, 17, 2) {
    Some(v) => v
    None => raise invalid
  }
  if month < 1 ||
    month > 12 ||
    day < 1 ||
    day > days_in_month(year, month) ||
    hour > 23 ||
    minute > 59 ||
    second > 59 ||
    (!context_mode && year < 1) {
    raise invalid
  }
  let mut pos = 19
  let mut millis = 0L
  if text.get_char(pos) == Some('.') {
    pos = pos + 1
    let mut digits = 0
    let mut scale = 100
    while true {
      match text.get_char(pos) {
        Some(c) =>
          if c >= '0' && c <= '9' {
            if digits < 3 {
              millis = millis +
                (c.to_int() - '0'.to_int()).to_int64() * scale.to_int64()
              scale = scale / 10
            }
            digits = digits + 1
            pos = pos + 1
          } else {
            break
          }
        None => break
      }
    }
    if digits == 0 {
      raise invalid
    }
  }
  let mut offset_minutes = 0
  match text.get_char(pos) {
    Some('Z') => pos = pos + 1
    Some('+') | Some('-') => {
      let sign = if text.get_char(pos) == Some('+') { 1 } else { -1 }
      let oh = match fixed_digits(text, pos + 1, 2) {
        Some(v) => v
        None => raise invalid
      }
      if text.get_char(pos + 3) != Some(':') {
        raise invalid
      }
      let om = match fixed_digits(text, pos + 4, 2) {
        Some(v) => v
        None => raise invalid
      }
      if oh > (if context_mode { 24 } else { 23 }) ||
        om > (if context_mode { 60 } else { 59 }) {
        raise invalid
      }
      offset_minutes = sign * (oh * 60 + om)
      pos = pos + 6
    }
    _ => raise invalid
  }
  if pos != text.length() {
    raise invalid
  }
  let days = days_from_civil(year.to_int64(), month.to_int64(), day.to_int64())
  let seconds = days * 86400L + (hour * 3600 + minute * 60 + second).to_int64()
  seconds * 1000L + millis - offset_minutes.to_int64() * 60000L
}

///|
fn duration_unit_ns(unit : String) -> Int64? {
  match unit {
    "ns" => Some(1L)
    "us" => Some(1000L)
    "µs" | "μs" => Some(1000L)
    "ms" => Some(1000000L)
    "s" => Some(1000000000L)
    "m" => Some(60000000000L)
    "h" => Some(3600000000000L)
    _ => None
  }
}

///|
/// Parses a Go-style duration such as `1h30m` or `250ms` into nanoseconds.
pub fn parse_duration(text : String) -> Int64 raise @fga.FgaError {
  let invalid = @fga.fail(
    @fga.ERR_VALIDATION,
    "invalid duration '" + text + "'",
  )
  if text.length() == 0 {
    raise invalid
  }
  let mut pos = 0
  let mut sign = 1L
  match text.get_char(0) {
    Some('+') => pos = 1
    Some('-') => {
      sign = -1L
      pos = 1
    }
    _ => ()
  }
  if pos >= text.length() {
    raise invalid
  }
  if text[pos:].to_owned() == "0" {
    return 0L
  }
  let limit = if sign < 0L {
    9223372036854775808UL
  } else {
    9223372036854775807UL
  }
  let mut total = 0UL
  while pos < text.length() {
    let start = pos
    while pos < text.length() && cel_is_digit(text.get_char(pos).unwrap()) {
      pos += 1
    }
    let whole = if pos == start {
      0UL
    } else {
      @string.parse_uint64(text[start:pos].to_owned()) catch {
        _ => raise invalid
      }
    }
    let mut fractional_digits = ""
    let mut digits = pos - start
    if text.get_char(pos) == Some('.') {
      pos += 1
      let fraction_start = pos
      while pos < text.length() && cel_is_digit(text.get_char(pos).unwrap()) {
        digits += 1
        pos += 1
      }
      fractional_digits = text[fraction_start:pos].to_owned()
    }
    if digits == 0 {
      raise invalid
    }
    let unit_start = pos
    while pos < text.length() {
      let ch = text.get_char(pos).unwrap()
      if ch.is_ascii_alphabetic() || ch == '\u{00b5}' || ch == '\u{03bc}' {
        pos += 1
      } else {
        break
      }
    }
    let factor = match duration_unit_ns(text[unit_start:pos].to_owned()) {
      Some(v) => v.reinterpret_as_uint64()
      None => raise invalid
    }
    if whole > limit / factor {
      raise invalid
    }
    // Decimal long multiplication retains all fractional digits without
    // binary floating point rounding or a wide-integer dependency.
    let mut fractional = 0UL
    for i = fractional_digits.length() - 1; i >= 0; i = i - 1 {
      fractional = (
          (fractional_digits.get_char(i).unwrap().to_int() - 48)
          .to_int64()
          .reinterpret_as_uint64() *
          factor +
          fractional
        ) /
        10UL
    }
    let amount = whole * factor
    if fractional > limit - amount || total > limit - amount - fractional {
      raise invalid
    }
    total += amount + fractional
  }
  if sign < 0L {
    -total.reinterpret_as_int64()
  } else {
    total.reinterpret_as_int64()
  }
}

///|
/// Formats epoch milliseconds as UTC RFC3339.
pub fn format_timestamp(ms : Int64) -> String {
  @fga.timestamp_to_rfc3339(@fga.VTimestamp(ms))
}

///|
fn parse_timestamp_value(
  text : String,
  context_mode~ : Bool = false,
) -> @fga.CelValue raise @fga.FgaError {
  let ms = parse_timestamp(text, context_mode~)
  let mut ns = 0L
  let mut scale = 100000L
  let mut pos = 23
  if text.get_char(19) == Some('.') {
    while pos < text.length() && scale > 0L {
      match text.get_char(pos) {
        Some(c) =>
          if c >= '0' && c <= '9' {
            ns += (c.to_int() - 48).to_int64() * scale
            scale /= 10L
            pos += 1
          } else {
            break
          }
        None => break
      }
    }
  }
  let mut offset = 0
  let sign_pos = text.length() - 6
  if sign_pos >= 19 {
    match text.get_char(sign_pos) {
      Some('+') | Some('-') => {
        offset = fixed_digits(text, sign_pos + 1, 2).unwrap() * 60 +
          fixed_digits(text, sign_pos + 4, 2).unwrap()
        if text.get_char(sign_pos) == Some('-') {
          offset = -offset
        }
      }
      _ => ()
    }
  }
  @fga.timestamp_value(ms, ns, offset~)
}

///|
fn format_duration(ns : Int64) -> String {
  let magnitude = if ns < 0L {
    (-ns).reinterpret_as_uint64()
  } else {
    ns.reinterpret_as_uint64()
  }
  let seconds = magnitude / 1000000000UL
  let remainder = magnitude % 1000000000UL
  let fraction = if remainder == 0UL {
    ""
  } else {
    let mut f = remainder.to_string()
    f = Array::make(9 - f.length(), "0").join("") + f
    while f.has_suffix("0") {
      f = f[:f.length() - 1].to_owned()
    }
    "." + f
  }
  (if ns < 0L { "-" } else { "" }) + seconds.to_string() + fraction + "s"
}

///|
fn checked_timestamp(
  value : @fga.CelValue,
) -> @fga.CelValue raise @fga.FgaError {
  let (ms, _) = value.timestamp_parts().unwrap()
  if ms < -62135596800000L || ms > 253402300799999L {
    raise eval_error("timestamp out of range")
  }
  value
}
