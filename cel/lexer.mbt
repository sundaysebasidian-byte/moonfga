// Lexer for the CEL subset used by OpenFGA conditions.

///|
priv enum CTokenKind {
  CIdent(String)
  CIntLit(Int64)
  CUintLit(UInt64)
  CDoubleLit(Double)
  CStringLit(String)
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
) -> String raise @fga.FgaError {
  let sb = StringBuilder()
  self.advance() // opening quote
  let mut done = false
  while !done {
    let c = match self.peek() {
      Some(c) => c
      None => raise cel_fail("unterminated string literal", line, column)
    }
    if c == quote {
      self.advance()
      done = true
    } else if c == '\\' {
      self.advance()
      let esc = match self.peek() {
        Some(c) => c
        None => raise cel_fail("unterminated escape sequence", line, column)
      }
      self.advance()
      match esc {
        'n' => sb.write_char('\n')
        't' => sb.write_char('\t')
        'r' => sb.write_char('\r')
        '\\' => sb.write_char('\\')
        '"' => sb.write_char('"')
        '\'' => sb.write_char('\'')
        '/' => sb.write_char('/')
        _ =>
          raise cel_fail(
            "unsupported escape sequence '\\" + esc.to_string() + "'",
            line,
            column,
          )
      }
    } else {
      sb.write_char(c)
      self.advance()
    }
  }
  sb.to_string()
}

///|
fn CelLexer::scan_number(
  self : CelLexer,
  line : Int32,
  column : Int32,
) -> CTokenKind raise @fga.FgaError {
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
      let text = lexer.scan_string(c, line, column)
      lexer.emit(CStringLit(text), line, column)
      continue
    }
    if cel_is_digit(c) {
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
