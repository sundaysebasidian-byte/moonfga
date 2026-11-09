// Expression AST and parser for CEL conditions.

///|
pub(all) enum CelExpr {
  CLiteral(@fga.CelValue)
  CIdent(String)
  CUnary(String, CelExpr)
  CBinary(String, CelExpr, CelExpr)
  CTernary(CelExpr, CelExpr, CelExpr)
  CCall(String, Array[CelExpr])
  CMethod(CelExpr, String, Array[CelExpr])
  CIndex(CelExpr, CelExpr)
  CList(Array[CelExpr])
  CMap(Array[(CelExpr, CelExpr)])
  CObject(String, Array[(String, CelExpr)])
}

///|
priv struct CelParser {
  tokens : Array[CToken]
  mut pos : Int32
}

///|
fn CelParser::peek(self : CelParser) -> CToken {
  self.tokens[self.pos]
}

///|
fn CelParser::advance(self : CelParser) -> Unit {
  if self.pos + 1 < self.tokens.length() {
    self.pos = self.pos + 1
  }
}

///|
fn CelParser::at_eof(self : CelParser) -> Bool {
  match self.peek().kind {
    CEof => true
    _ => false
  }
}

///|
fn CelParser::at_symbol(self : CelParser, symbol : String) -> Bool {
  match self.peek().kind {
    CSymbol(s) => s == symbol
    _ => false
  }
}

///|
fn CelParser::expect_symbol(
  self : CelParser,
  symbol : String,
) -> Unit raise @fga.FgaError {
  let token = self.peek()
  match token.kind {
    CSymbol(s) =>
      if s == symbol {
        self.advance()
      } else {
        raise cel_fail(
          "expected '" + symbol + "', found '" + s + "'",
          token.line,
          token.column,
        )
      }
    _ => raise cel_fail("expected '" + symbol + "'", token.line, token.column)
  }
}

///|
fn CelParser::expect_ident(self : CelParser) -> String raise @fga.FgaError {
  let token = self.peek()
  match token.kind {
    CIdent(name) => {
      self.advance()
      name
    }
    _ => raise cel_fail("expected an identifier", token.line, token.column)
  }
}

///|
fn binary_precedence(symbol : String) -> Int32 {
  match symbol {
    "||" => 1
    "&&" => 2
    "==" => 3
    "!=" => 3
    "<" => 4
    "<=" => 4
    ">" => 4
    ">=" => 4
    "in" => 4
    "+" => 5
    "-" => 5
    "*" => 6
    "/" => 6
    "%" => 6
    _ => 0
  }
}

///|
fn CelParser::peek_binary_symbol(self : CelParser) -> String {
  match self.peek().kind {
    CSymbol(s) => s
    CIdent(s) => if s == "in" { s } else { "" }
    _ => ""
  }
}

///|
fn CelParser::parse_arguments(
  self : CelParser,
) -> Array[CelExpr] raise @fga.FgaError {
  self.expect_symbol("(")
  let args : Array[CelExpr] = []
  if !self.at_symbol(")") {
    while true {
      args.push(self.parse_expr())
      if self.at_symbol(",") {
        self.advance()
      } else {
        break
      }
    }
  }
  self.expect_symbol(")")
  args
}

///|
fn CelParser::parse_postfix(self : CelParser) -> CelExpr raise @fga.FgaError {
  let mut expr = self.parse_primary()
  while true {
    if self.at_symbol("(") {
      let name = match expr {
        CIdent(name) => name
        _ =>
          raise cel_fail(
            "only named functions can be called",
            self.peek().line,
            self.peek().column,
          )
      }
      let args = self.parse_arguments()
      expr = CCall(name, args)
    } else if self.at_symbol("{") {
      let name = expression_path(expr).unwrap_or("")
      if name == "" {
        raise cel_fail(
          "expected message type",
          self.peek().line,
          self.peek().column,
        )
      }
      self.advance()
      let fields : Array[(String, CelExpr)] = []
      while !self.at_symbol("}") {
        let field = self.expect_ident()
        self.expect_symbol(":")
        fields.push((field, self.parse_expr()))
        if !self.at_symbol(",") {
          break
        }
        self.advance()
      }
      self.expect_symbol("}")
      expr = CObject(name, fields)
    } else if self.at_symbol("[") {
      self.advance()
      let index = self.parse_expr()
      self.expect_symbol("]")
      expr = CIndex(expr, index)
    } else if self.at_symbol(".") {
      self.advance()
      let name = self.expect_ident()
      let call = self.at_symbol("(")
      let args = if call { self.parse_arguments() } else { [] }
      expr = CMethod(expr, if call { name } else { "@field:" + name }, args)
    } else {
      break
    }
  }
  expr
}

///|
fn CelParser::parse_unary(self : CelParser) -> CelExpr raise @fga.FgaError {
  if self.at_symbol("!") || self.at_symbol("-") {
    let symbol = match self.peek().kind {
      CSymbol(s) => s
      _ => "!"
    }
    self.advance()
    if symbol == "-" &&
      self.peek().kind is CIntLit(i) &&
      i == -9223372036854775807L - 1L {
      self.advance()
      return CLiteral(VInt(i))
    }
    CUnary(symbol, self.parse_unary())
  } else {
    self.parse_postfix()
  }
}

///|
fn CelParser::parse_binary(
  self : CelParser,
  min_precedence : Int32,
) -> CelExpr raise @fga.FgaError {
  let mut left = self.parse_unary()
  while true {
    let symbol = self.peek_binary_symbol()
    let precedence = binary_precedence(symbol)
    if precedence == 0 || precedence < min_precedence {
      break
    }
    self.advance()
    let right = self.parse_binary(precedence + 1)
    left = CBinary(symbol, left, right)
  }
  left
}

///|
fn CelParser::parse_expr(self : CelParser) -> CelExpr raise @fga.FgaError {
  let condition = self.parse_binary(1)
  if self.at_symbol("?") {
    self.advance()
    let when_true = self.parse_expr()
    self.expect_symbol(":")
    let when_false = self.parse_expr()
    CTernary(condition, when_true, when_false)
  } else {
    condition
  }
}

///|
fn CelParser::parse_primary(self : CelParser) -> CelExpr raise @fga.FgaError {
  let token = self.peek()
  match token.kind {
    CIntLit(v) => {
      if v == -9223372036854775807L - 1L {
        raise cel_fail("integer literal overflow", token.line, token.column)
      }
      self.advance()
      CLiteral(VInt(v))
    }
    CUintLit(v) => {
      self.advance()
      CLiteral(VUint(v))
    }
    CDoubleLit(v) => {
      self.advance()
      CLiteral(VDouble(v))
    }
    CBytesLit(v) => {
      self.advance()
      CLiteral(VBytes(v))
    }
    CStringLit(v) => {
      self.advance()
      CLiteral(VString(v))
    }
    CIdent(name) =>
      if name == "true" {
        self.advance()
        CLiteral(VBool(true))
      } else if name == "false" {
        self.advance()
        CLiteral(VBool(false))
      } else if name == "null" {
        self.advance()
        CLiteral(VNull)
      } else {
        self.advance()
        CIdent(name)
      }
    CSymbol("(") => {
      self.advance()
      let inner = self.parse_expr()
      self.expect_symbol(")")
      inner
    }
    CSymbol("[") => {
      self.advance()
      let items : Array[CelExpr] = []
      if !self.at_symbol("]") {
        while true {
          items.push(self.parse_expr())
          if self.at_symbol(",") {
            self.advance()
            if self.at_symbol("]") {
              break
            }
          } else {
            break
          }
        }
      }
      self.expect_symbol("]")
      CList(items)
    }
    CSymbol("{") => {
      self.advance()
      let entries : Array[(CelExpr, CelExpr)] = []
      if !self.at_symbol("}") {
        while true {
          let key = self.parse_expr()
          self.expect_symbol(":")
          let value = self.parse_expr()
          entries.push((key, value))
          if self.at_symbol(",") {
            self.advance()
            if self.at_symbol("}") {
              break
            }
          } else {
            break
          }
        }
      }
      self.expect_symbol("}")
      CMap(entries)
    }
    _ =>
      raise cel_fail(
        "unexpected token in condition expression",
        token.line,
        token.column,
      )
  }
}

///|
/// Compiles a CEL expression into an AST.
pub fn compile(source : String) -> CelExpr raise @fga.FgaError {
  let tokens = lex_cel_tokens(source)
  let parser = CelParser::{ tokens, pos: 0, }
  let expr = parser.parse_expr()
  if !parser.at_eof() {
    let token = parser.peek()
    raise cel_fail(
      "unexpected trailing input in condition",
      token.line,
      token.column,
    )
  }
  expr
}

///|
fn expression_path(expr : CelExpr) -> String? {
  match expr {
    CIdent(n) => Some(n)
    CMethod(target, field, args) =>
      if args.is_empty() && field.has_prefix("@field:") {
        expression_path(target).map(p => p + "." + field[7:].to_owned())
      } else {
        None
      }
    _ => None
  }
}
