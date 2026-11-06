// Tokenizer for the OpenFGA schema 1.1 DSL.
//
// The lexer deliberately recognises condition bodies as opaque text: the CEL
// parser owns that grammar. Comments start with `#` when preceded by
// whitespace (or at the beginning of a line); `group#member` is a userset
// separator and therefore not a comment.

///|
#derive(Eq)
pub(all) enum TokenKind {
  Word
  Version
  LBracket
  RBracket
  LParen
  RParen
  LBrace
  RBrace
  Colon
  Comma
  Hash
  Star
  Less
  Greater
  ConditionBody
  Eof
}

///|
pub extend TokenKind with Eq::{not_equal, equal}

///|
pub(all) struct Token {
  kind : TokenKind
  text : String
  line : Int32
  column : Int32
}

///|
pub fn Token::is_word(self : Token, word : String) -> Bool {
  self.kind == Word && self.text == word
}

///|
priv struct Lexer {
  src : String
  len : Int32
  mut i : Int32
  mut line : Int32
  mut column : Int32
  tokens : Array[Token]
}

///|
fn Lexer::peek(self : Lexer) -> Char? {
  self.src.get_char(self.i)
}

///|
fn Lexer::advance(self : Lexer) -> Unit {
  match self.peek() {
    Some(ch) => {
      if ch == '\n' {
        self.line = self.line + 1
        self.column = 1
      } else {
        self.column = self.column + 1
      }
      self.i = self.i + 1
    }
    None => ()
  }
}

///|
fn is_space(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\r' || c == '\n'
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_alpha(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

///|
fn is_ident_char(c : Char) -> Bool {
  is_alpha(c) || is_digit(c) || c == '.' || c == '-' || c == '/' || c == '$'
}

///|
fn Lexer::emit(
  self : Lexer,
  kind : TokenKind,
  text : String,
  line : Int32,
  column : Int32,
) -> Unit {
  self.tokens.push(Token::{ kind, text, line, column, })
}

///|
fn Lexer::skip_comment(self : Lexer) -> Unit {
  while true {
    match self.peek() {
      Some('\n') | None => break
      _ => {
        self.advance()
        ()
      }
    }
  }
}

///|
fn Lexer::scan_word(self : Lexer) -> String {
  let sb = StringBuilder()
  while true {
    match self.peek() {
      Some(c) =>
        if is_ident_char(c) {
          sb.write_char(c)
          self.advance()
        } else {
          break
        }
      None => break
    }
  }
  sb.to_string()
}

///|
/// Scans a condition body, assuming the current character is `{`.
/// Nested braces and string literals are respected; the closing brace is
/// consumed but not included in the returned expression.
fn Lexer::scan_condition_body(
  self : Lexer,
  line : Int32,
  column : Int32,
) -> String raise @fga.FgaError {
  let sb = StringBuilder()
  self.advance() // opening brace
  let mut depth = 1
  let mut quote : Char? = None
  let mut escaped = false
  let mut done = false
  while !done {
    let c = match self.peek() {
      Some(c) => {
        self.advance()
        c
      }
      None =>
        raise @fga.fail_at(
          @fga.ERR_VALIDATION,
          "unterminated condition body",
          line,
          column,
        )
    }
    match quote {
      Some(q) =>
        if escaped {
          escaped = false
          sb.write_char(c)
        } else if c == '\\' {
          escaped = true
          sb.write_char(c)
        } else if c == q {
          quote = None
          sb.write_char(c)
        } else {
          sb.write_char(c)
        }
      None =>
        if c == '"' || c == '\'' {
          quote = Some(c)
          sb.write_char(c)
        } else if c == '/' && self.peek() == Some('/') {
          // CEL line comment: skip until newline, preserve a space.
          self.advance()
          while true {
            match self.peek() {
              Some('\n') | None => break
              _ => {
                self.advance()
                ()
              }
            }
          }
          sb.write_char(' ')
        } else if c == '{' {
          depth = depth + 1
          sb.write_char(c)
        } else if c == '}' {
          depth = depth - 1
          if depth == 0 {
            done = true
          } else {
            sb.write_char(c)
          }
        } else {
          sb.write_char(c)
        }
    }
  }
  sb.to_string()
}

///|
pub fn lex(src : String) -> Array[Token] raise @fga.FgaError {
  let lexer = Lexer::{
    src,
    len: src.length(),
    i: 0,
    line: 1,
    column: 1,
    tokens: [],
  }
  let mut in_condition = false
  while lexer.i < lexer.len {
    let c = match lexer.peek() {
      Some(c) => c
      None => break
    }
    let line = lexer.line
    let column = lexer.column
    if is_space(c) {
      lexer.advance()
      continue
    }
    if c == '#' {
      let prev = if lexer.i == 0 {
        None
      } else {
        lexer.src.get_char(lexer.i - 1)
      }
      let comment = match prev {
        None => true
        Some(p) => is_space(p)
      }
      if comment {
        lexer.skip_comment()
        continue
      }
      lexer.advance()
      lexer.emit(Hash, "#", line, column)
      continue
    }
    if c == '{' && in_condition {
      let body = lexer.scan_condition_body(line, column)
      lexer.emit(ConditionBody, body, line, column)
      in_condition = false
      continue
    }
    match c {
      '[' => {
        lexer.advance()
        lexer.emit(LBracket, "[", line, column)
      }
      ']' => {
        lexer.advance()
        lexer.emit(RBracket, "]", line, column)
      }
      '(' => {
        lexer.advance()
        lexer.emit(LParen, "(", line, column)
      }
      ')' => {
        lexer.advance()
        lexer.emit(RParen, ")", line, column)
      }
      '{' => {
        lexer.advance()
        lexer.emit(LBrace, "{", line, column)
      }
      '}' => {
        lexer.advance()
        lexer.emit(RBrace, "}", line, column)
      }
      ':' => {
        lexer.advance()
        lexer.emit(Colon, ":", line, column)
      }
      ',' => {
        lexer.advance()
        lexer.emit(Comma, ",", line, column)
      }
      '*' => {
        lexer.advance()
        lexer.emit(Star, "*", line, column)
      }
      '<' => {
        lexer.advance()
        lexer.emit(Less, "<", line, column)
      }
      '>' => {
        lexer.advance()
        lexer.emit(Greater, ">", line, column)
      }
      _ =>
        if is_digit(c) {
          let sb = StringBuilder()
          while true {
            match lexer.peek() {
              Some(ch) =>
                if is_digit(ch) || ch == '.' {
                  sb.write_char(ch)
                  lexer.advance()
                } else {
                  break
                }
              None => break
            }
          }
          lexer.emit(Version, sb.to_string(), line, column)
        } else if is_alpha(c) || c == '$' {
          let word = lexer.scan_word()
          if word == "but" {
            // Merge "but not" into a single token.
            let save_i = lexer.i
            let save_line = lexer.line
            let save_col = lexer.column
            let mut saw_space = false
            while true {
              match lexer.peek() {
                Some(ch) =>
                  if is_space(ch) {
                    saw_space = true
                    lexer.advance()
                  } else {
                    break
                  }
                None => break
              }
            }
            let not_word = lexer.scan_word()
            if saw_space && not_word == "not" {
              lexer.emit(Word, "but not", line, column)
            } else {
              lexer.i = save_i
              lexer.line = save_line
              lexer.column = save_col
              lexer.emit(Word, word, line, column)
            }
          } else {
            lexer.emit(Word, word, line, column)
            if word == "condition" {
              in_condition = true
            }
          }
        } else {
          raise @fga.fail_at(
            @fga.ERR_VALIDATION,
            "unexpected character in model source",
            line,
            column,
          )
        }
    }
  }
  lexer.tokens.push(Token::{
    kind: Eof,
    text: "",
    line: lexer.line,
    column: lexer.column,
  })
  lexer.tokens
}
