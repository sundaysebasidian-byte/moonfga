///|
fn BigNatural::bit(self : BigNatural, index : Int32) -> Int32 {
  if index < 0 {
    0
  } else {
    (self.limbs.get(index / 15).unwrap_or(0) >> (index % 15)) & 1
  }
}

///|
fn parse_cel_double(text : String) -> Double raise @fga.FgaError {
  let negative = text.has_prefix("-")
  let start = if negative || text.has_prefix("+") { 1 } else { 0 }
  let body = text[start:].to_owned()
  if !body.has_prefix("0x") && !body.has_prefix("0X") {
    let d = @string.parse_double(text) catch {
      _ => raise eval_error("invalid double conversion")
    }
    return if d == 0.0 && negative { -0.0 } else { d }
  }
  let number = BigNatural::{ limbs: [0], }
  let chars = body.iter().collect()
  let mut pos = 2
  let mut dot = false
  let mut fraction = 0
  let mut digits = 0
  while pos < chars.length() {
    let c = chars[pos]
    if c == '.' && !dot {
      dot = true
      pos += 1
      continue
    }
    if c == 'p' || c == 'P' {
      break
    }
    let d = if c >= '0' && c <= '9' {
      c.to_int() - 48
    } else if c >= 'a' && c <= 'f' {
      c.to_int() - 87
    } else if c >= 'A' && c <= 'F' {
      c.to_int() - 55
    } else {
      raise eval_error("invalid hexadecimal double")
    }
    number.multiply(16, add=d)
    if dot {
      fraction += 1
    }
    digits += 1
    pos += 1
  }
  if digits == 0 || pos == chars.length() {
    raise eval_error("invalid hexadecimal double")
  }
  let exponent = @string.parse_int(String::from_array(chars[pos + 1:])) catch {
    _ => raise eval_error("invalid hexadecimal exponent")
  }
  if exponent < -100000 {
    return if negative { -0.0 } else { 0.0 }
  }
  if exponent > 100000 {
    raise eval_error("double conversion overflow")
  }
  let bits = number.bits()
  if bits == 0 {
    return if negative { -0.0 } else { 0.0 }
  }
  let effective = exponent - fraction * 4 + bits - 1
  if effective > 1023 {
    raise eval_error("double conversion overflow")
  }
  if effective < -1075 {
    return if negative { -0.0 } else { 0.0 }
  }
  let retained = (53 + (effective + 1022).min(0)).max(0).min(bits)
  let mut top = 0UL
  for i = bits - 1; i >= bits - retained; i = i - 1 {
    top = (top << 1) | number.bit(i).to_int64().reinterpret_as_uint64()
  }
  let dropped = bits - retained
  if dropped > 0 && number.bit(dropped - 1) != 0 {
    let mut sticky = false
    for i in 0..<(dropped - 1) {
      if number.bit(i) != 0 {
        sticky = true
        break
      }
    }
    if sticky || (top & 1UL) != 0UL {
      top += 1UL
    }
  }
  let d = top.to_double() *
    @math.pow(2.0, (exponent - fraction * 4 + dropped).to_double())
  if d.is_inf() {
    raise eval_error("double conversion overflow")
  }
  if negative {
    -d
  } else {
    d
  }
}

///|
fn format_cel_double(d : Double) -> String {
  if d.is_nan() {
    return "NaN"
  }
  if d.is_inf() {
    return if d < 0.0 { "-Inf" } else { "+Inf" }
  }
  if d == 0.0 {
    return if 1.0 / d < 0.0 { "-0" } else { "0" }
  }
  let text = d.to_string()
  let negative = text.has_prefix("-")
  let body = if negative { text[1:].to_owned() } else { text }
  let marker = match body.find("e") {
    Some(i) => Some(i)
    None => body.find("E")
  }
  let (mantissa, suffix) = match marker {
    Some(i) =>
      (
        body[:i].to_owned(),
        @string.parse_int(body[i + 1:].to_owned()) catch {
          _ => 0
        },
      )
    None => (body, 0)
  }
  let point = mantissa.find(".").unwrap_or(mantissa.length())
  let raw = mantissa.replace(old=".", new="")
  let mut first = 0
  while first < raw.length() && raw.get_char(first) == Some('0') {
    first += 1
  }
  let exponent = point - first - 1 + suffix
  let mut digits = raw[first:].to_owned()
  while digits.length() > 1 && digits.has_suffix("0") {
    digits = digits[:digits.length() - 1].to_owned()
  }
  let sign = if negative { "-" } else { "" }
  if exponent < -4 || exponent >= 6 {
    let exp = (if exponent < 0 { -exponent } else { exponent }).to_string()
    sign +
    digits[:1].to_owned() +
    (if digits.length() > 1 { "." + digits[1:].to_owned() } else { "" }) +
    "e" +
    (if exponent < 0 { "-" } else { "+" }) +
    (if exp.length() == 1 { "0" } else { "" }) +
    exp
  } else {
    let place = exponent + 1
    sign +
    (if place <= 0 {
      "0." + Array::make(-place, "0").join("") + digits
    } else if place >= digits.length() {
      digits + Array::make(place - digits.length(), "0").join("")
    } else {
      digits[:place].to_owned() + "." + digits[place:].to_owned()
    })
  }
}
