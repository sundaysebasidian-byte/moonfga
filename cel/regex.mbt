// A small regular-expression matcher for CEL `matches`.
//
// Supports literals, `.`, character classes and ranges, escaped classes
// (`\d`, `\w`, `\s`), the quantifiers `*`, `+`, `?`, anchors `^` and `$`,
// and top-level alternation. Groups, backreferences and lazy quantifiers are
// intentionally unsupported; CEL conditions in OpenFGA models rarely use
// them and docs/conformance.md records the boundary.

///|
priv enum ReAtom {
  RLiteral(Char)
  RAny
  RClass(Array[(Char, Char)], Bool)
  RDigit
  RWord
  RSpace
}

///|
fn re_class_contains(ranges : Array[(Char, Char)], c : Char) -> Bool {
  for (lo, hi) in ranges {
    if c >= lo && c <= hi {
      return true
    }
  }
  false
}

///|
fn re_atom_match(atom : ReAtom, c : Char) -> Bool {
  match atom {
    RLiteral(expected) => c == expected
    RAny => c != '\n'
    RClass(ranges, negated) => {
      let inside = re_class_contains(ranges, c)
      if negated {
        !inside
      } else {
        inside
      }
    }
    RDigit => c >= '0' && c <= '9'
    RWord =>
      (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '_'
    RSpace => c == ' ' || c == '\t' || c == '\n' || c == '\r'
  }
}

///|
/// Parses one atom starting at `pos`. Returns the atom and the next position,
/// or raises when the pattern is malformed.
fn re_parse_atom(
  pattern : String,
  pos : Int32,
) -> (ReAtom, Int32) raise @fga.FgaError {
  let invalid = @fga.fail(
    @fga.ERR_VALIDATION,
    "invalid regular expression '" + pattern + "'",
  )
  let c = match pattern.get_char(pos) {
    Some(c) => c
    None => raise invalid
  }
  if c == '\\' {
    let escaped = match pattern.get_char(pos + 1) {
      Some(e) => e
      None => raise invalid
    }
    match escaped {
      'd' => (RDigit, pos + 2)
      'D' => (RClass([('0', '9')], true), pos + 2)
      'w' => (RWord, pos + 2)
      'W' =>
        (
          RClass([('a', 'z'), ('A', 'Z'), ('0', '9'), ('_', '_')], true),
          pos + 2,
        )
      's' => (RSpace, pos + 2)
      'S' =>
        (
          RClass([(' ', ' '), ('\t', '\t'), ('\n', '\n'), ('\r', '\r')], true),
          pos + 2,
        )
      'n' => (RLiteral('\n'), pos + 2)
      't' => (RLiteral('\t'), pos + 2)
      _ => (RLiteral(escaped), pos + 2)
    }
  } else if c == '.' {
    (RAny, pos + 1)
  } else if c == '[' {
    let mut i = pos + 1
    let mut negated = false
    if pattern.get_char(i) == Some('^') {
      negated = true
      i = i + 1
    }
    let ranges : Array[(Char, Char)] = []
    let mut closed = false
    while i < pattern.length() {
      let current = match pattern.get_char(i) {
        Some(ch) => ch
        None => raise invalid
      }
      if current == ']' {
        closed = true
        i = i + 1
        break
      }
      let lo = if current == '\\' {
        let escaped = match pattern.get_char(i + 1) {
          Some(e) => e
          None => raise invalid
        }
        i = i + 2
        match escaped {
          'd' => {
            ranges.push(('0', '9'))
            continue
          }
          'w' => {
            ranges.push(('a', 'z'))
            ranges.push(('A', 'Z'))
            ranges.push(('0', '9'))
            ranges.push(('_', '_'))
            continue
          }
          's' => {
            ranges.push((' ', ' '))
            ranges.push(('\t', '\t'))
            ranges.push(('\n', '\n'))
            ranges.push(('\r', '\r'))
            continue
          }
          'n' => '\n'
          't' => '\t'
          _ => escaped
        }
      } else {
        i = i + 1
        current
      }
      if pattern.get_char(i) == Some('-') &&
        pattern.get_char(i + 1) != Some(']') {
        let hi = match pattern.get_char(i + 1) {
          Some(ch) => ch
          None => raise invalid
        }
        ranges.push((lo, hi))
        i = i + 2
      } else {
        ranges.push((lo, lo))
      }
    }
    if !closed {
      raise invalid
    }
    (RClass(ranges, negated), i)
  } else {
    (RLiteral(c), pos + 1)
  }
}

///|
fn re_match_seq(
  pattern : String,
  pos : Int32,
  text : String,
  text_pos : Int32,
  anchored_end : Bool,
) -> Bool raise @fga.FgaError {
  if pos >= pattern.length() {
    return if anchored_end { text_pos == text.length() } else { true }
  }
  if pattern.get_char(pos) == Some('$') && pos + 1 == pattern.length() {
    return text_pos == text.length()
  }
  let (atom, next) = re_parse_atom(pattern, pos)
  let quantifier = match pattern.get_char(next) {
    Some('*') => "*"
    Some('+') => "+"
    Some('?') => "?"
    _ => ""
  }
  let rest_pos = if quantifier == "" { next } else { next + 1 }
  let positions : Array[Int32] = [text_pos]
  let mut current = text_pos
  while current < text.length() {
    let c = match text.get_char(current) {
      Some(c) => c
      None => break
    }
    if re_atom_match(atom, c) {
      current = current + 1
      positions.push(current)
    } else {
      break
    }
  }
  let (min_count, max_count) = match quantifier {
    "*" => (0, positions.length() - 1)
    "+" => (1, positions.length() - 1)
    "?" => (0, 1)
    _ => (1, 1)
  }
  if positions.length() - 1 < min_count {
    return false
  }
  let upper = if max_count < positions.length() - 1 {
    max_count
  } else {
    positions.length() - 1
  }
  let mut k = upper
  while k >= min_count {
    if re_match_seq(pattern, rest_pos, text, positions[k], anchored_end) {
      return true
    }
    k = k - 1
  }
  false
}

///|
fn re_split_alternation(pattern : String) -> Array[String] {
  let parts : Array[String] = []
  let sb = StringBuilder()
  let mut i = 0
  let mut escaped = false
  let mut in_class = false
  while i < pattern.length() {
    let c = match pattern.get_char(i) {
      Some(c) => c
      None => break
    }
    if escaped {
      sb.write_char(c)
      escaped = false
    } else if c == '\\' {
      sb.write_char(c)
      escaped = true
    } else if c == '[' {
      in_class = true
      sb.write_char(c)
    } else if c == ']' {
      in_class = false
      sb.write_char(c)
    } else if c == '|' && !in_class {
      parts.push(sb.to_string())
      sb.reset()
    } else {
      sb.write_char(c)
    }
    i = i + 1
  }
  parts.push(sb.to_string())
  parts
}

///|
fn re_try_branch(branch : String, text : String) -> Bool raise @fga.FgaError {
  let mut pattern = branch
  let mut anchored_start = false
  let mut anchored_end = false
  if pattern.length() > 0 && pattern.get_char(0) == Some('^') {
    anchored_start = true
    pattern = pattern[1:].to_owned()
  }
  if pattern.length() > 0 && pattern.get_char(pattern.length() - 1) == Some('$') {
    // Only treat a trailing `$` as an anchor when it is not escaped.
    let mut backslashes = 0
    let mut i = pattern.length() - 2
    while i >= 0 && pattern.get_char(i) == Some('\\') {
      backslashes = backslashes + 1
      i = i - 1
    }
    if backslashes % 2 == 0 {
      anchored_end = true
      pattern = pattern[:pattern.length() - 1].to_owned()
    }
  }
  if pattern.length() == 0 {
    return if anchored_end { text.length() == 0 } else { true }
  }
  if anchored_start {
    return re_match_seq(pattern, 0, text, 0, anchored_end)
  }
  let mut start = 0
  while start <= text.length() {
    if re_match_seq(pattern, 0, text, start, anchored_end) {
      return true
    }
    start = start + 1
  }
  false
}

///|
/// CEL `matches`: reports whether the pattern matches any part of the input.
pub fn regex_matches(
  pattern : String,
  text : String,
) -> Bool raise @fga.FgaError {
  for branch in re_split_alternation(pattern) {
    if re_try_branch(branch, text) {
      return true
    }
  }
  false
}
