// Lexer for CEL condition expressions.

///|
priv enum CTokenKind {
  CIdent(String)
  CIntLit(Int64)
  CUintLit(UInt64)
  CDoubleLit(Double)
  CStringLit(String)
  CBytesLit(Bytes)
  CSymbol(String)
  CEof
}

///|
priv struct CToken {
  kind : CTokenKind
  line : Int32
  column : Int32
}

///|
fn cel_fail(message : String, line : Int32, column : Int32) -> @fga.FgaError {
  @fga.fail_at(@fga.ERR_VALIDATION, message, line, column)
}

///|
fn cel_is_space(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\r' || c == '\n'
}

///|
fn cel_is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn cel_is_alpha(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

///|
fn cel_is_ident_char(c : Char) -> Bool {
  cel_is_alpha(c) || cel_is_digit(c)
}

///|
priv struct CelLexer {
  src : String
  len : Int32
  mut i : Int32
  mut line : Int32
  mut column : Int32
  tokens : Array[CToken]
}

///|
fn CelLexer::peek(self : CelLexer) -> Char? {
  self.src.get_char(self.i)
}

///|
fn CelLexer::advance(self : CelLexer) -> Unit {
  match self.peek() {
    Some(c) => {
      if c == '\n' {
        self.line = self.line + 1
        self.column = 1
      } else {
        self.column = self.column + 1
      }
      self.i = self.i + (if c.to_int() > 65535 { 2 } else { 1 })
    }
    None => ()
  }
}

///|
fn CelLexer::emit(
  self : CelLexer,
  kind : CTokenKind,
  line : Int32,
  column : Int32,
) -> Unit {
  self.tokens.push(CToken::{ kind, line, column, })
}

///|
fn CelLexer::skip_comment(self : CelLexer) -> Unit {
  while true {
    match self.peek() {
      Some('\n') | None => break
      _ => self.advance()
    }
  }
}

///|
fn CelLexer::scan_string(
  self : CelLexer,
  quote : Char,
  line : Int32,
  column : Int32,
  bytes_mode : Bool,
  raw : Bool,
) -> CTokenKind raise @fga.FgaError {
  let out : Array[Byte] = []
  self.advance()
  let triple = self.src.get_char(self.i) == Some(quote) &&
    self.src.get_char(self.i + 1) == Some(quote)
  if triple {
    self.advance()
    self.advance()
  }
  while true {
    let c = match self.peek() {
      Some(c) => c
      None => raise cel_fail("unterminated string literal", line, column)
    }
    if c == quote &&
      (
        !triple ||
        (
          self.src.get_char(self.i + 1) == Some(quote) &&
          self.src.get_char(self.i + 2) == Some(quote)
        )
      ) {
      self.advance()
      if triple {
        self.advance()
        self.advance()
      }
      break
    }
    if !triple && (c == '\n' || c == '\r') {
      raise cel_fail("newline in string literal", line, column)
    }
    if c == '\\' && raw {
      out.push((92).to_byte())
      self.advance()
      let escaped = match self.peek() {
        Some(ch) => ch
        None => raise cel_fail("unterminated raw literal", line, column)
      }
      for b in @utf8.encode(escaped.to_string()[:]) {
        out.push(b)
      }
      self.advance()
    } else if c == '\\' && !raw {
      self.advance()
      let esc = match self.peek() {
        Some(c) => c
        None => raise cel_fail("unterminated escape sequence", line, column)
      }
      self.advance()
      let simple = match esc {
        'a' => Some(7)
        'b' => Some(8)
        'f' => Some(12)
        'n' => Some(10)
        'r' => Some(13)
        't' => Some(9)
        'v' => Some(11)
        '\\' => Some(92)
        '"' => Some(34)
        '\'' => Some(39)
        '?' => Some(63)
        _ => None
      }
      match simple {
        Some(n) => out.push(n.to_byte())
        None => {
          let octal = esc >= '0' && esc <= '7'
          let digits = if octal {
            3
          } else if esc == 'x' || esc == 'X' {
            2
          } else if !bytes_mode && esc == 'u' {
            4
          } else if !bytes_mode && esc == 'U' {
            8
          } else {
            raise cel_fail("invalid escape sequence", line, column)
          }
          let base = if octal { 8 } else { 16 }
          let mut n = 0L
          for j in 0..<digits {
            let ch = if octal && j == 0 {
              esc
            } else {
              let ch = match self.peek() {
                Some(ch) => ch
                None =>
                  raise cel_fail("incomplete escape sequence", line, column)
              }
              self.advance()
              ch
            }
            let d = if ch >= '0' && ch <= '9' {
              ch.to_int() - 48
            } else if ch >= 'a' && ch <= 'f' {
              ch.to_int() - 87
            } else if ch >= 'A' && ch <= 'F' {
              ch.to_int() - 55
            } else {
              -1
            }
            if d < 0 || d >= base {
              raise cel_fail("invalid escape digit", line, column)
            }
            n = n * base.to_int64() + d.to_int64()
          }
          if esc == 'u' || esc == 'U' {
            if n > 1114111L || (n >= 55296L && n <= 57343L) {
              raise cel_fail("invalid Unicode escape", line, column)
            }
            for b in @utf8.encode(n.to_int().unsafe_to_char().to_string()[:]) {
              out.push(b)
            }
          } else {
            if n > 255L {
              raise cel_fail("byte escape out of range", line, column)
            }
            if bytes_mode {
              out.push(n.to_int().to_byte())
            } else {
              for b in @utf8.encode(n.to_int().unsafe_to_char().to_string()[:]) {
                out.push(b)
              }
            }
          }
        }
      }
    } else {
      for b in @utf8.encode(c.to_string()[:]) {
        out.push(b)
      }
      self.advance()
    }
  }
  let bytes = Bytes::from_array(out[:])
  if bytes_mode {
    CBytesLit(bytes)
  } else {
    CStringLit(@utf8.decode(bytes[:])) catch {
      _ => raise cel_fail("invalid UTF-8 in string literal", line, column)
    }
  }
}

///|
fn CelLexer::scan_number(
  self : CelLexer,
  line : Int32,
  column : Int32,
) -> CTokenKind raise @fga.FgaError {
  if self.peek() == Some('0') && self.src.get_char(self.i + 1) == Some('x') {
    self.advance()
    self.advance()
    let start = self.i
    while self.peek() is Some(c) && c.is_ascii_hexdigit() {
      self.advance()
    }
    if start == self.i {
      raise cel_fail("invalid hex literal", line, column)
    }
    let text = self.src[start:self.i].to_owned()
    let u = @string.parse_uint64("0x" + text) catch {
      _ => raise cel_fail("integer literal overflow", line, column)
    }
    if self.peek() == Some('u') || self.peek() == Some('U') {
      self.advance()
      return CUintLit(u)
    }
    if u > 9223372036854775808UL {
      raise cel_fail("integer literal overflow", line, column)
    }
    return CIntLit(u.reinterpret_as_int64())
  }
  let sb = StringBuilder()
  let mut is_double = false
  let mut is_uint = false
  while true {
    match self.peek() {
      Some(c) =>
        if cel_is_digit(c) {
          sb.write_char(c)
          self.advance()
        } else {
          break
        }
      None => break
    }
  }
  if self.peek() == Some('.') {
    is_double = true
    sb.write_char('.')
    self.advance()
    if !(self.peek() is Some(c) && cel_is_digit(c)) {
      raise cel_fail("expected fractional digits", line, column)
    }
    while true {
      match self.peek() {
        Some(c) =>
          if cel_is_digit(c) {
            sb.write_char(c)
            self.advance()
          } else {
            break
          }
        None => break
      }
    }
  }
  match self.peek() {
    Some('e') | Some('E') => {
      is_double = true
      sb.write_char('e')
      self.advance()
      match self.peek() {
        Some('+') | Some('-') => {
          sb.write_char(self.peek().unwrap())
          self.advance()
        }
        _ => ()
      }
      while true {
        match self.peek() {
          Some(c) =>
            if cel_is_digit(c) {
              sb.write_char(c)
              self.advance()
            } else {
              break
            }
          None => break
        }
      }
    }
    _ => ()
  }
  if self.peek() == Some('u') || self.peek() == Some('U') {
    is_uint = true
    self.advance()
  }
  let text = sb.to_string()
  if is_uint {
    if is_double {
      raise cel_fail(
        "invalid unsigned integer literal '" + text + "u'",
        line,
        column,
      )
    }
    CUintLit(@string.parse_uint64(text)) catch {
      _ =>
        raise cel_fail(
          "invalid unsigned integer literal '" + text + "'",
          line,
          column,
        )
    }
  } else if is_double {
    CDoubleLit(@string.parse_double(text)) catch {
      _ => raise cel_fail("invalid double literal '" + text + "'", line, column)
    }
  } else {
    if text == "9223372036854775808" {
      return CIntLit(-9223372036854775807L - 1L)
    }
    CIntLit(@string.parse_int64(text)) catch {
      _ =>
        raise cel_fail("invalid integer literal '" + text + "'", line, column)
    }
  }
}

///|
fn lex_cel_tokens(source : String) -> Array[CToken] raise @fga.FgaError {
  let lexer = CelLexer::{
    src: source,
    len: source.length(),
    i: 0,
    line: 1,
    column: 1,
    tokens: [],
  }
  while lexer.i < lexer.len {
    let c = match lexer.peek() {
      Some(c) => c
      None => break
    }
    let line = lexer.line
    let column = lexer.column
    if cel_is_space(c) {
      lexer.advance()
      continue
    }
    if c == '/' && lexer.i + 1 < lexer.len {
      match source.get_char(lexer.i + 1) {
        Some('/') => {
          lexer.skip_comment()
          continue
        }
        _ => ()
      }
    }
    if c == '"' || c == '\'' {
      lexer.emit(lexer.scan_string(c, line, column, false, false), line, column)
      continue
    }
    if c == 'b' || c == 'B' || c == 'r' || c == 'R' {
      let mut end = lexer.i + 1
      let mut bytes_mode = c == 'b' || c == 'B'
      let mut raw = c == 'r' || c == 'R'
      match source.get_char(end) {
        Some('r') | Some('R') =>
          if bytes_mode {
            raw = true
            end = end + 1
          }
        Some('b') | Some('B') =>
          if raw {
            bytes_mode = true
            end = end + 1
          }
        _ => ()
      }
      match source.get_char(end) {
        Some('"') | Some('\'') as q => {
          while lexer.i < end {
            lexer.advance()
          }
          lexer.emit(
            lexer.scan_string(q.unwrap(), line, column, bytes_mode, raw),
            line,
            column,
          )
          continue
        }
        _ => ()
      }
    }
    if cel_is_digit(c) ||
      (c == '.' && source.get_char(lexer.i + 1) is Some(d) && cel_is_digit(d)) {
      let kind = lexer.scan_number(line, column)
      lexer.emit(kind, line, column)
      continue
    }
    if cel_is_alpha(c) {
      let sb = StringBuilder()
      while true {
        match lexer.peek() {
          Some(ch) =>
            if cel_is_ident_char(ch) {
              sb.write_char(ch)
              lexer.advance()
            } else {
              break
            }
          None => break
        }
      }
      lexer.emit(CIdent(sb.to_string()), line, column)
      continue
    }
    let pair = if lexer.i + 1 < lexer.len {
      match source.get_char(lexer.i + 1) {
        Some(ch) => c.to_string() + ch.to_string()
        None => ""
      }
    } else {
      ""
    }
    if pair == "&&" ||
      pair == "||" ||
      pair == "==" ||
      pair == "!=" ||
      pair == "<=" ||
      pair == ">=" {
      lexer.advance()
      lexer.advance()
      lexer.emit(CSymbol(pair), line, column)
      continue
    }
    let symbol = c.to_string()
    if "!<>+-*/%?:.,()[]{}".contains(symbol) {
      lexer.advance()
      lexer.emit(CSymbol(symbol), line, column)
      continue
    }
    raise cel_fail(
      "unexpected character '" + symbol + "' in condition",
      line,
      column,
    )
  }
  lexer.tokens.push(CToken::{
    kind: CEof,
    line: lexer.line,
    column: lexer.column,
  })
  lexer.tokens
}
