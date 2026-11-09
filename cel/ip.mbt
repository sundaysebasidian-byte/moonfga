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
    if part.length() == 0 ||
      part.length() > 3 ||
      (part.length() > 1 && part.has_prefix("0")) {
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
      if left.contains(".") {
        return None
      }
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
  let (base, zone) = match text.find("%") {
    Some(i) => {
      if i + 1 == text.length() || !text[:i].to_owned().contains(":") {
        raise @fga.fail(@fga.ERR_VALIDATION, "invalid IP zone")
      }
      (text[:i].to_owned(), Some(text[i + 1:].to_owned()))
    }
    None => (text, None)
  }
  match parse_ip(base) {
    None =>
      raise @fga.fail(@fga.ERR_VALIDATION, "invalid IP address '" + text + "'")
    Some((family, bytes)) => {
      let mut mapped = family == 6
      if mapped {
        for i in 0..<10 {
          if bytes[i] != 0 {
            mapped = false
          }
        }
        mapped = mapped && bytes[10] == 255 && bytes[11] == 255
      }
      if family == 4 {
        return bytes.map(b => b.to_string()).join(".")
      }
      if mapped {
        return [bytes[12], bytes[13], bytes[14], bytes[15]]
          .map(b => b.to_string())
          .join(".")
      }
      let groups : Array[String] = []
      let mut best_start = 0
      let mut best_length = 0
      let mut i = 0
      while i < 8 {
        let value = bytes[i * 2] * 256 + bytes[i * 2 + 1]
        groups.push(hex_group(value))
        if value == 0 {
          let start = i
          while i + 1 < 8 &&
                bytes[(i + 1) * 2] == 0 &&
                bytes[(i + 1) * 2 + 1] == 0 {
            i += 1
            groups.push("0")
          }
          if i - start + 1 > best_length {
            best_start = start
            best_length = i - start + 1
          }
        }
        i += 1
      }
      let result = if best_length < 2 {
        groups.join(":")
      } else {
        let before : Array[String] = []
        let after : Array[String] = []
        for j in 0..<best_start {
          before.push(groups[j])
        }
        for j in (best_start + best_length)..<8 {
          after.push(groups[j])
        }
        before.join(":") + "::" + after.join(":")
      }
      result +
      (match zone {
        Some(z) => "%" + z
        None => ""
      })
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
  if prefix_text.is_empty() ||
    (prefix_text.length() > 1 && prefix_text.has_prefix("0")) {
    raise @fga.fail(@fga.ERR_VALIDATION, "invalid CIDR prefix")
  }
  let mut prefix = 0
  for ch in prefix_text {
    if !ch.is_ascii_digit() {
      raise @fga.fail(@fga.ERR_VALIDATION, "invalid CIDR prefix")
    }
    prefix = prefix * 10 + ch.to_int() - 48
    if prefix > 128 {
      raise @fga.fail(@fga.ERR_VALIDATION, "invalid CIDR prefix")
    }
  }
  let network = match parse_ip(network_text) {
    Some(v) => v
    None =>
      raise @fga.fail(
        @fga.ERR_VALIDATION,
        "invalid CIDR network '" + cidr + "'",
      )
  }
  let (network_family, network_bytes) = network
  if prefix > (if network_family == 4 { 32 } else { 128 }) {
    raise @fga.fail(@fga.ERR_VALIDATION, "invalid CIDR prefix")
  }
  let normalized = canonical_ip(ip)
  if normalized.contains("%") {
    return false
  }
  let (family, bytes) = match parse_ip(normalized) {
    Some(v) => v
    None => raise @fga.fail(@fga.ERR_VALIDATION, "invalid IP address")
  }
  if family != network_family {
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
