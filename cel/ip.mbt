// IPv4/IPv6 parsing and CIDR containment for CEL `ipaddress` values.

///|
fn split_char(text : String, separator : Char) -> Array[String] {
  let parts : Array[String] = []
  let sb = StringBuilder()
  let mut i = 0
  while i < text.length() {
    match text.get_char(i) {
      Some(c) =>
        if c == separator {
          parts.push(sb.to_string())
          sb.reset()
        } else {
          sb.write_char(c)
        }
      None => ()
    }
    i = i + 1
  }
  parts.push(sb.to_string())
  parts
}

///|
fn parse_ipv4(text : String) -> Array[Int32]? {
  let parts = split_char(text, '.')
  if parts.length() != 4 {
    return None
  }
  let bytes : Array[Int32] = []
  for part in parts {
    if part.length() == 0 || part.length() > 3 {
      return None
    }
    let mut value = 0
    for i in 0..<part.length() {
      match part.get_char(i) {
        Some(c) =>
          if c >= '0' && c <= '9' {
            value = value * 10 + (c.to_int() - '0'.to_int())
          } else {
            return None
          }
        None => return None
      }
    }
    if value > 255 {
      return None
    }
    bytes.push(value)
  }
  Some(bytes)
}

///|
fn parse_hex_group(part : String) -> Int32? {
  if part.length() == 0 || part.length() > 4 {
    return None
  }
  let mut value = 0
  for i in 0..<part.length() {
    let digit = match part.get_char(i) {
      Some(c) =>
        if c >= '0' && c <= '9' {
          c.to_int() - '0'.to_int()
        } else if c >= 'a' && c <= 'f' {
          c.to_int() - 'a'.to_int() + 10
        } else if c >= 'A' && c <= 'F' {
          c.to_int() - 'A'.to_int() + 10
        } else {
          return None
        }
      None => return None
    }
    value = value * 16 + digit
  }
  Some(value)
}

///|
fn ipv6_side_groups(side : String) -> Array[Int32]? {
  let words : Array[Int32] = []
  if side.length() == 0 {
    return Some(words)
  }
  let parts = split_char(side, ':')
  for i in 0..<parts.length() {
    let part = parts[i]
    if part.length() == 0 {
      return None
    }
    if part.contains(".") {
      if i + 1 != parts.length() {
        return None
      }
      let bytes = match parse_ipv4(part) {
        Some(b) => b
        None => return None
      }
      words.push(bytes[0] * 256 + bytes[1])
      words.push(bytes[2] * 256 + bytes[3])
    } else {
      let word = match parse_hex_group(part) {
        Some(v) => v
        None => return None
      }
      words.push(word)
    }
  }
  Some(words)
}

///|
fn parse_ipv6(text : String) -> Array[Int32]? {
  let double_colon = text.find("::")
  let words : Array[Int32] = []
  match double_colon {
    None => {
      let groups = match ipv6_side_groups(text) {
        Some(g) => g
        None => return None
      }
      if groups.length() != 8 {
        return None
      }
      for w in groups {
        words.push(w)
      }
    }
    Some(index) => {
      let left = text[:index].to_owned()
      let right = text[index + 2:].to_owned()
      let left_words = match ipv6_side_groups(left) {
        Some(g) => g
        None => return None
      }
      let right_words = match ipv6_side_groups(right) {
        Some(g) => g
        None => return None
      }
      if left_words.length() + right_words.length() > 7 {
        return None
      }
      for w in left_words {
        words.push(w)
      }
      for _ in 0..<(8 - left_words.length() - right_words.length()) {
        words.push(0)
      }
      for w in right_words {
        words.push(w)
      }
    }
  }
  let bytes : Array[Int32] = []
  for word in words {
    bytes.push(word / 256)
    bytes.push(word % 256)
  }
  Some(bytes)
}

///|
fn parse_ip(text : String) -> (Int32, Array[Int32])? {
  if text.contains(":") {
    match parse_ipv6(text) {
      Some(bytes) => Some((6, bytes))
      None => None
    }
  } else {
    match parse_ipv4(text) {
      Some(bytes) => Some((4, bytes))
      None => None
    }
  }
}

///|
fn hex_group(value : Int32) -> String {
  let digits = "0123456789abcdef"
  let mut text = ""
  let mut started = false
  let mut shift = 12
  while shift >= 0 {
    let digit = (value >> shift) & 0xF
    if digit != 0 || started || shift == 0 {
      started = true
      match digits.get_char(digit) {
        Some(c) => text = text + c.to_string()
        None => ()
      }
    }
    shift = shift - 4
  }
  text
}

///|
/// Returns a canonical textual form used for equality comparisons.
pub fn canonical_ip(text : String) -> String raise @fga.FgaError {
  match parse_ip(text) {
    None =>
      raise @fga.fail(@fga.ERR_VALIDATION, "invalid IP address '" + text + "'")
    Some((family, bytes)) =>
      if family == 4 {
        bytes.map(fn(b) { b.to_string() }).join(".")
      } else {
        let groups : Array[String] = []
        let mut i = 0
        while i < 16 {
          groups.push(hex_group(bytes[i] * 256 + bytes[i + 1]))
          i = i + 2
        }
        groups.join(":")
      }
  }
}

///|
/// Tests whether an IP address is contained in a CIDR block.
pub fn ip_in_cidr(ip : String, cidr : String) -> Bool raise @fga.FgaError {
  let slash = match cidr.find("/") {
    Some(i) => i
    None =>
      raise @fga.fail(@fga.ERR_VALIDATION, "invalid CIDR block '" + cidr + "'")
  }
  let network_text = cidr[:slash].to_owned()
  let prefix_text = cidr[slash + 1:].to_owned()
  let prefix = match fixed_digits(prefix_text, 0, prefix_text.length()) {
    Some(v) => v
    None =>
      raise @fga.fail(
        @fga.ERR_VALIDATION,
        "invalid CIDR prefix in '" + cidr + "'",
      )
  }
  let network = match parse_ip(network_text) {
    Some(v) => v
    None =>
      raise @fga.fail(
        @fga.ERR_VALIDATION,
        "invalid CIDR network '" + cidr + "'",
      )
  }
  let address = match parse_ip(ip) {
    Some(v) => v
    None =>
      raise @fga.fail(@fga.ERR_VALIDATION, "invalid IP address '" + ip + "'")
  }
  let (network_family, network_bytes) = network
  let (family, bytes) = address
  let max_prefix = if family == 4 { 32 } else { 128 }
  if family != network_family || prefix < 0 || prefix > max_prefix {
    return false
  }
  let full_bytes = prefix / 8
  let remainder = prefix % 8
  let mut i = 0
  while i < full_bytes {
    if bytes[i] != network_bytes[i] {
      return false
    }
    i = i + 1
  }
  if remainder == 0 {
    return true
  }
  let mask = (0xFF << (8 - remainder)) & 0xFF
  (bytes[i] & mask) == (network_bytes[i] & mask)
}
