// Independent Thompson NFA for Boolean CEL matches. No backtracking or capture
// storage: capture ordering does not affect a Boolean existence result.

///|
priv enum RegexTree {
  REmpty
  RChars(Array[(Array[(Int32, Int32)], Bool)], Bool, Bool)
  RAssert(String, Bool)
  RSeq(Array[RegexTree])
  RAlt(Array[RegexTree])
  RRepeat(RegexTree, Int32, Int32?)
}

///|
priv enum RegexInst {
  IChars(Array[(Array[(Int32, Int32)], Bool)], Bool, Bool, Int32)
  IAssert(String, Bool, Int32)
  ISplit(Int32, Int32)
  IAccept
}

///|
priv struct RegexParser {
  chars : Array[Char]
  mut pos : Int32
  mut flags : Int32
  mut depth : Int32
}

///|
fn regex_error() -> @fga.FgaError {
  eval_error("invalid regular expression")
}

///|
fn RegexParser::peek(self : RegexParser) -> Char? {
  self.chars.get(self.pos)
}

///|
fn RegexParser::take(self : RegexParser) -> Char raise @fga.FgaError {
  let c = match self.peek() {
    Some(c) => c
    None => raise regex_error()
  }
  self.pos += 1
  c
}

///|
fn regex_ascii(name : String) -> Array[(Int32, Int32)] raise @fga.FgaError {
  match name {
    "digit" => [(48, 57)]
    "word" => [(48, 57), (65, 90), (95, 95), (97, 122)]
    "space" => [(9, 13), (32, 32)]
    "blank" => [(9, 9), (32, 32)]
    "alpha" => [(65, 90), (97, 122)]
    "alnum" => [(48, 57), (65, 90), (97, 122)]
    "lower" => [(97, 122)]
    "upper" => [(65, 90)]
    "ascii" => [(0, 127)]
    "cntrl" => [(0, 31), (127, 127)]
    "graph" => [(33, 126)]
    "print" => [(32, 126)]
    "punct" => [(33, 47), (58, 64), (91, 96), (123, 126)]
    "xdigit" => [(48, 57), (65, 70), (97, 102)]
    _ => raise regex_error()
  }
}

///|
fn RegexParser::escaped(self : RegexParser) -> RegexTree raise @fga.FgaError {
  let c = self.take()
  let fold = (self.flags & 1) != 0
  let ranges = match c {
    'd' | 'D' => return RChars([(regex_ascii("digit"), c == 'D')], false, fold)
    'w' | 'W' => return RChars([(regex_ascii("word"), c == 'W')], false, fold)
    's' | 'S' =>
      return RChars([([(9, 10), (12, 13), (32, 32)], c == 'S')], false, fold)
    'p' | 'P' => {
      let name = if self.peek() == Some('{') {
        self.pos += 1
        let sb = StringBuilder()
        while self.peek() != Some('}') {
          sb.write_char(self.take())
        }
        self.pos += 1
        sb.to_string()
      } else {
        self.take().to_string()
      }
      let negative = (c == 'P') != name.has_prefix("^")
      let key = if name.has_prefix("^") { name[1:].to_owned() } else { name }
      let ranges = if key == "Any" {
        [(0, 1114111)]
      } else {
        match unicode_property(key) {
          Some(r) => r
          None => raise regex_error()
        }
      }
      return RChars([(ranges, negative)], false, fold)
    }
    'A' | 'z' | 'b' | 'B' => return RAssert(c.to_string(), false)
    'a' => [(7, 7)]
    'f' => [(12, 12)]
    't' => [(9, 9)]
    'n' => [(10, 10)]
    'r' => [(13, 13)]
    'v' => [(11, 11)]
    'Q' => {
      let items : Array[RegexTree] = []
      while self.peek() is Some(ch) {
        if ch == '\\' && self.chars.get(self.pos + 1) == Some('E') {
          self.pos += 2
          break
        }
        self.pos += 1
        items.push(RChars([([(ch.to_int(), ch.to_int())], false)], false, fold))
      }
      return RSeq(items)
    }
    'x' => {
      let braced = self.peek() == Some('{')
      if braced {
        self.pos += 1
      }
      let mut n = 0
      let mut count = 0
      while (if braced { self.peek() != Some('}') } else { count < 2 }) {
        let ch = self.take()
        let d = if ch >= '0' && ch <= '9' {
          ch.to_int() - 48
        } else if ch >= 'a' && ch <= 'f' {
          ch.to_int() - 87
        } else if ch >= 'A' && ch <= 'F' {
          ch.to_int() - 55
        } else {
          raise regex_error()
        }
        if n > 1114111 / 16 {
          raise regex_error()
        }
        n = n * 16 + d
        count += 1
      }
      if braced {
        self.pos += 1
      }
      if count == 0 || n > 1114111 {
        raise regex_error()
      }
      [(n, n)]
    }
    '0'..<='7' => {
      let mut n = c.to_int() - 48
      let mut count = 1
      while count < 3 {
        match self.peek() {
          Some('0'..<='7' as ch) => {
            self.pos += 1
            count += 1
            n = n * 8 + ch.to_int() - 48
          }
          _ => break
        }
      }
      if c != '0' && count == 1 {
        raise regex_error()
      }
      [(n, n)]
    }
    _ => {
      if c.is_ascii_alphabetic() || c.is_ascii_digit() {
        raise regex_error()
      }
      [(c.to_int(), c.to_int())]
    }
  }
  RChars([(ranges, false)], false, fold)
}

///|
fn RegexParser::class_item(
  self : RegexParser,
) -> Array[(Array[(Int32, Int32)], Bool)] raise @fga.FgaError {
  let c = self.take()
  if c == '[' && self.peek() == Some(':') {
    self.pos += 1
    let sb = StringBuilder()
    while self.peek() != Some(':') {
      sb.write_char(self.take())
    }
    self.pos += 1
    if self.take() != ']' {
      raise regex_error()
    }
    let name = sb.to_string()
    let neg = name.has_prefix("^")
    return [(regex_ascii(if neg { name[1:].to_owned() } else { name }), neg)]
  }
  if c == '\\' {
    match self.escaped() {
      RChars(r, false, _) => r
      _ => raise regex_error()
    }
  } else {
    [([(c.to_int(), c.to_int())], false)]
  }
}

///|
fn regex_single(r : Array[(Array[(Int32, Int32)], Bool)]) -> Int32? {
  if r.length() == 1 &&
    !r[0].1 &&
    r[0].0.length() == 1 &&
    r[0].0[0].0 == r[0].0[0].1 {
    Some(r[0].0[0].0)
  } else {
    None
  }
}

///|
fn RegexParser::atom(self : RegexParser) -> RegexTree raise @fga.FgaError {
  let c = self.take()
  match c {
    '\\' => self.escaped()
    '.' =>
      if (self.flags & 4) != 0 {
        RChars([([(0, 1114111)], false)], false, false)
      } else {
        RChars([([(0, 9), (11, 1114111)], false)], false, false)
      }
    '^' | '$' => RAssert(c.to_string(), (self.flags & 2) != 0)
    '*' | '+' | '?' => raise regex_error()
    '[' => {
      let neg = self.peek() == Some('^')
      if neg {
        self.pos += 1
      }
      let sets : Array[(Array[(Int32, Int32)], Bool)] = []
      let mut first = true
      while first || self.peek() != Some(']') {
        first = false
        let item = self.class_item()
        if self.peek() == Some('-') && self.chars.get(self.pos + 1) != Some(']') {
          self.pos += 1
          let end = self.class_item()
          let a = match regex_single(item) {
            Some(n) => n
            None => raise regex_error()
          }
          let b = match regex_single(end) {
            Some(n) => n
            None => raise regex_error()
          }
          if a > b {
            raise regex_error()
          }
          sets.push(([(a, b)], false))
        } else {
          for s in item {
            sets.push(s)
          }
        }
      }
      self.pos += 1
      RChars(sets, neg, (self.flags & 1) != 0)
    }
    '(' => {
      self.depth += 1
      if self.depth > 1000 {
        raise regex_error()
      }
      let saved = self.flags
      if self.peek() == Some('?') {
        self.pos += 1
        if self.peek() == Some('P') {
          self.pos += 1
          if self.peek() != Some('<') {
            raise regex_error()
          }
        }
        if self.peek() == Some('<') {
          self.pos += 1
          let mut count = 0
          while self.peek() != Some('>') {
            let ch = self.take()
            if !(ch.is_ascii_alphabetic() || ch.is_ascii_digit() || ch == '_') {
              raise regex_error()
            }
            count += 1
          }
          if count == 0 {
            raise regex_error()
          }
          self.pos += 1
        } else {
          let mut enable = true
          let mut flags_seen = 0
          let mut after_minus = false
          while self.peek() != Some(':') && self.peek() != Some(')') {
            let ch = self.take()
            if ch == '-' {
              if after_minus {
                raise regex_error()
              }
              after_minus = true
              enable = false
              flags_seen = 0
              continue
            }
            let bit = match ch {
              'i' => 1
              'm' => 2
              's' => 4
              'U' => 8
              _ => raise regex_error()
            }
            flags_seen += 1
            self.flags = if enable {
              self.flags | bit
            } else {
              self.flags & (15 - bit)
            }
          }
          if flags_seen == 0 && after_minus {
            raise regex_error()
          }
          if self.peek() == Some(')') {
            self.pos += 1
            self.depth -= 1
            return REmpty
          }
          self.pos += 1
        }
      }
      let inner = self.alternate()
      if self.take() != ')' {
        raise regex_error()
      }
      self.flags = saved
      self.depth -= 1
      inner
    }
    _ =>
      RChars(
        [([(c.to_int(), c.to_int())], false)],
        false,
        (self.flags & 1) != 0,
      )
  }
}

///|
fn RegexParser::sequence(self : RegexParser) -> RegexTree raise @fga.FgaError {
  let items : Array[RegexTree] = []
  while self.peek() is Some(c) && c != ')' && c != '|' {
    let mut atom = self.atom()
    let repeat = match self.peek() {
      Some('*') => {
        self.pos += 1
        Some((0, None))
      }
      Some('+') => {
        self.pos += 1
        Some((1, None))
      }
      Some('?') => {
        self.pos += 1
        Some((0, Some(1)))
      }
      Some('{') => {
        let saved = self.pos
        self.pos += 1
        let start = self.pos
        while self.peek() is Some(ch) && ch.is_ascii_digit() {
          self.pos += 1
        }
        if self.pos == start {
          self.pos = saved
          None
        } else {
          let low = @string.parse_int(
            String::from_array(self.chars[start:self.pos]),
          ) catch {
            _ => raise regex_error()
          }
          let high = if self.peek() == Some(',') {
            self.pos += 1
            let begin = self.pos
            while self.peek() is Some(ch) && ch.is_ascii_digit() {
              self.pos += 1
            }
            if begin == self.pos {
              None
            } else {
              Some(
                @string.parse_int(
                  String::from_array(self.chars[begin:self.pos]),
                ) catch {
                  _ => raise regex_error()
                },
              )
            }
          } else {
            Some(low)
          }
          if self.peek() != Some('}') {
            self.pos = saved
            None
          } else {
            self.pos += 1
            if low > 1000 || (high is Some(h) && (h > 1000 || h < low)) {
              raise regex_error()
            }
            Some((low, high))
          }
        }
      }
      _ => None
    }
    match repeat {
      Some((low, high)) => {
        if self.peek() == Some('?') {
          self.pos += 1
        }
        atom = RRepeat(atom, low, high)
        if regex_repeat_bound(atom) > 1000 {
          raise regex_error()
        }
        if self.peek() == Some('{') &&
          self.chars.get(self.pos + 1) is Some(ch) &&
          ch.is_ascii_digit() {
          raise regex_error()
        }
      }
      None => ()
    }
    items.push(atom)
  }
  RSeq(items)
}

///|
fn RegexParser::alternate(self : RegexParser) -> RegexTree raise @fga.FgaError {
  let branches = [self.sequence()]
  while self.peek() == Some('|') {
    self.pos += 1
    branches.push(self.sequence())
  }
  RAlt(branches)
}

///|
fn regex_compile(
  tree : RegexTree,
  next : Int32,
  code : Array[RegexInst],
) -> Int32 raise @fga.FgaError {
  if code.length() > 3355443 {
    raise regex_error()
  }
  match tree {
    REmpty => next
    RChars(sets, neg, fold) => {
      code.push(IChars(sets, neg, fold, next))
      code.length() - 1
    }
    RAssert(kind, multi) => {
      code.push(IAssert(kind, multi, next))
      code.length() - 1
    }
    RSeq(items) => {
      let mut entry = next
      for i = items.length() - 1; i >= 0; i = i - 1 {
        entry = regex_compile(items[i], entry, code)
      }
      entry
    }
    RAlt(branches) => {
      let mut entry = regex_compile(branches[0], next, code)
      for i in 1..<branches.length() {
        let other = regex_compile(branches[i], next, code)
        code.push(ISplit(entry, other))
        entry = code.length() - 1
      }
      entry
    }
    RRepeat(inner, low, high) => {
      let mut entry = next
      match high {
        None => {
          let split = code.length()
          code.push(ISplit(next, next))
          let body = regex_compile(inner, split, code)
          code[split] = ISplit(body, next)
          entry = split
        }
        Some(h) =>
          for _ in low..<h {
            let body = regex_compile(inner, entry, code)
            code.push(ISplit(body, entry))
            entry = code.length() - 1
          }
      }
      for _ in 0..<low {
        entry = regex_compile(inner, entry, code)
      }
      entry
    }
  }
}

///|
fn regex_word(c : Char?) -> Bool {
  match c {
    Some(ch) => ch.is_ascii_alphabetic() || ch.is_ascii_digit() || ch == '_'
    None => false
  }
}

///|
fn regex_assert(
  kind : String,
  multi : Bool,
  text : Array[Char],
  pos : Int32,
) -> Bool {
  let left = text.get(pos - 1)
  let right = text.get(pos)
  match kind {
    "A" => pos == 0
    "z" => pos == text.length()
    "^" => pos == 0 || (multi && left == Some('\n'))
    "$" => pos == text.length() || (multi && right == Some('\n'))
    "b" => regex_word(left) != regex_word(right)
    "B" => regex_word(left) == regex_word(right)
    _ => false
  }
}

///|
fn regex_contains(
  ranges : Array[(Int32, Int32)],
  n : Int32,
  fold : Bool,
) -> Bool {
  if ranges.any(r => n >= r.0 && n <= r.1) {
    return true
  }
  if !fold {
    return false
  }
  let canonical = unicode_simple_fold(n)
  if ranges.any(r => canonical >= r.0 && canonical <= r.1) {
    return true
  }
  // Check the small Unicode simple-fold orbit, including Kelvin sign and long s.
  let variants = unicode_simple_orbit(canonical)
  variants.any(v => ranges.any(r => v >= r.0 && v <= r.1))
}

///|
/// Runs epsilon closure iteratively, once per program state per code point.
pub fn regex_matches(
  pattern : String,
  text : String,
  cancelled~ : () -> Bool = fn() { false },
) -> Bool raise @fga.FgaError {
  if cancelled() {
    raise eval_error("regex evaluation interrupted")
  }
  let tree = regex_tree(pattern)
  if regex_min_width(tree) > text.char_length() {
    return false
  }
  let code : Array[RegexInst] = [IAccept]
  let start = regex_compile(tree, 0, code)
  let chars = text.iter().collect()
  let mut pending : Array[Int32] = []
  let seen = Array::make(code.length(), -1)
  for pos in 0..<=chars.length() {
    if pos % 1024 == 0 && cancelled() {
      raise eval_error("regex evaluation interrupted")
    }
    pending.push(start)
    let next : Array[Int32] = []
    while !pending.is_empty() {
      let pc = pending.pop().unwrap()
      if seen[pc] == pos {
        continue
      }
      seen[pc] = pos
      match code[pc] {
        IAccept => return true
        ISplit(a, b) => {
          pending.push(a)
          pending.push(b)
        }
        IAssert(kind, multi, target) =>
          if regex_assert(kind, multi, chars, pos) {
            pending.push(target)
          }
        IChars(sets, neg, fold, target) =>
          if chars.get(pos) is Some(c) {
            let inside = sets.any(s => {
              regex_contains(s.0, c.to_int(), fold) != s.1
            })
            if inside != neg {
              next.push(target)
            }
          }
      }
    }
    pending = next
  }
  false
}

///|
fn regex_repeat_bound(tree : RegexTree) -> Int32 {
  match tree {
    RRepeat(inner, low, high) => {
      let count = high.unwrap_or(low).max(1)
      let nested = regex_repeat_bound(inner)
      if nested > 1000 / count {
        1001
      } else {
        nested * count
      }
    }
    RSeq(items) | RAlt(items) =>
      items.fold(init=1, (n, t) => n.max(regex_repeat_bound(t)))
    _ => 1
  }
}

///|
fn regex_tree(pattern : String) -> RegexTree raise @fga.FgaError {
  let parser = RegexParser::{
    chars: pattern.iter().collect(),
    pos: 0,
    flags: 0,
    depth: 0,
  }
  let tree = parser.alternate()
  if parser.pos != parser.chars.length() {
    raise regex_error()
  }
  tree
}

///|
/// Model validation parses syntax without constructing a potentially large NFA.
pub fn validate_regex(pattern : String) -> Unit raise @fga.FgaError {
  ignore(regex_tree(pattern))
}

///|
fn regex_min_width(tree : RegexTree) -> Int32 {
  match tree {
    RChars(_, _, _) => 1
    RRepeat(inner, low, _) => {
      let width = regex_min_width(inner)
      if width > 2147483647 / low.max(1) {
        2147483647
      } else {
        width * low
      }
    }
    RSeq(items) =>
      items.fold(init=0, (n, t) => {
        let width = regex_min_width(t)
        if n > 2147483647 - width {
          2147483647
        } else {
          n + width
        }
      })
    RAlt(items) =>
      items.fold(init=2147483647, (n, t) => n.min(regex_min_width(t)))
    _ => 0
  }
}
