// Recursive-descent parser for the OpenFGA schema 1.1 DSL.

///|
priv struct Parser {
  tokens : Array[Token]
  mut pos : Int32
}

///|
fn Parser::peek(self : Parser) -> Token {
  self.tokens[self.pos]
}

///|
fn Parser::advance(self : Parser) -> Unit {
  if self.peek().kind != Eof {
    self.pos = self.pos + 1
  }
}

///|
fn Parser::next(self : Parser) -> Token {
  let token = self.peek()
  self.advance()
  token
}

///|
fn Parser::at_kind(self : Parser, kind : TokenKind) -> Bool {
  self.peek().kind == kind
}

///|
fn Parser::at_word(self : Parser, word : String) -> Bool {
  self.peek().is_word(word)
}

///|
fn Parser::expect_kind(
  self : Parser,
  kind : TokenKind,
  what : String,
) -> Unit raise @fga.FgaError {
  let token = self.peek()
  if token.kind != kind {
    raise @fga.fail_at(
      @fga.ERR_VALIDATION,
      "expected " + what,
      token.line,
      token.column,
    )
  }
  self.advance()
}

///|
fn Parser::expect_word(
  self : Parser,
  what : String,
) -> Token raise @fga.FgaError {
  let token = self.peek()
  if token.kind != Word {
    raise @fga.fail_at(
      @fga.ERR_VALIDATION,
      "expected " + what,
      token.line,
      token.column,
    )
  }
  self.advance()
  token
}

///|
fn Parser::expect_word_text(
  self : Parser,
  word : String,
) -> Token raise @fga.FgaError {
  let token = self.peek()
  if !token.is_word(word) {
    raise @fga.fail_at(
      @fga.ERR_VALIDATION,
      "expected '" + word + "'",
      token.line,
      token.column,
    )
  }
  self.advance()
  token
}

///|
fn add_restriction(
  restrictions : Array[@fga.TypeRestriction],
  r : @fga.TypeRestriction,
) -> Unit {
  // Duplicates are preserved so semantic validation can report them with a
  // position instead of silently accepting the model.
  restrictions.push(r)
}

///|
fn parse_restriction(p : Parser) -> @fga.TypeRestriction raise @fga.FgaError {
  let type_tok = p.expect_word("a type name")
  let mut relation : String? = None
  let mut wildcard = false
  if p.at_kind(Colon) {
    p.advance()
    p.expect_kind(Star, "'*' after ':'")
    wildcard = true
  } else if p.at_kind(Hash) {
    p.advance()
    relation = Some(p.expect_word("a relation name").text)
  }
  let mut condition : String? = None
  if p.at_word("with") {
    p.advance()
    condition = Some(p.expect_word("a condition name").text)
  }
  @fga.TypeRestriction::{
    type_name: type_tok.text,
    relation,
    wildcard,
    condition,
  }
}

///|
fn parse_direct_assignments(
  p : Parser,
  restrictions : Array[@fga.TypeRestriction],
) -> Unit raise @fga.FgaError {
  p.expect_kind(LBracket, "'['")
  if !p.at_kind(RBracket) {
    while true {
      add_restriction(restrictions, parse_restriction(p))
      if p.at_kind(Comma) {
        p.advance()
      } else {
        break
      }
    }
  }
  p.expect_kind(RBracket, "']'")
}

///|
fn parse_userset_unary(
  p : Parser,
  restrictions : Array[@fga.TypeRestriction],
) -> @fga.Userset raise @fga.FgaError {
  match p.peek().kind {
    LBracket => {
      parse_direct_assignments(p, restrictions)
      @fga.This
    }
    LParen => {
      p.advance()
      let inner = parse_userset_or(p, restrictions)
      p.expect_kind(RParen, "')'")
      inner
    }
    Word => {
      let name = p.next().text
      if p.at_word("from") {
        p.advance()
        let tupleset = p.expect_word("a tupleset relation").text
        @fga.TupleToUserset(name, tupleset)
      } else {
        @fga.Computed(name)
      }
    }
    _ => {
      let token = p.peek()
      raise @fga.fail_at(
        @fga.ERR_VALIDATION,
        "expected a direct assignment, relation name or '('",
        token.line,
        token.column,
      )
    }
  }
}

///|
fn parse_userset_diff(
  p : Parser,
  restrictions : Array[@fga.TypeRestriction],
) -> @fga.Userset raise @fga.FgaError {
  let mut left = parse_userset_unary(p, restrictions)
  while p.at_word("but not") {
    p.advance()
    let right = parse_userset_unary(p, restrictions)
    left = @fga.Difference(left, right)
  }
  left
}

///|
fn parse_userset_and(
  p : Parser,
  restrictions : Array[@fga.TypeRestriction],
) -> @fga.Userset raise @fga.FgaError {
  let children = [parse_userset_diff(p, restrictions)]
  while p.at_word("and") {
    p.advance()
    children.push(parse_userset_diff(p, restrictions))
  }
  if children.length() == 1 {
    children[0]
  } else {
    @fga.Intersection(children)
  }
}

///|
fn parse_userset_or(
  p : Parser,
  restrictions : Array[@fga.TypeRestriction],
) -> @fga.Userset raise @fga.FgaError {
  let children = [parse_userset_and(p, restrictions)]
  while p.at_word("or") {
    p.advance()
    children.push(parse_userset_and(p, restrictions))
  }
  if children.length() == 1 {
    children[0]
  } else {
    @fga.Union(children)
  }
}

///|
fn parse_relation(
  p : Parser,
  model : @fga.AuthModel,
  td : @fga.TypeDefinition,
) -> Unit raise @fga.FgaError {
  p.advance() // define
  let name_tok = p.expect_word("a relation name")
  if name_tok.text == "self" || name_tok.text == "this" {
    raise @fga.fail_at(
      @fga.ERR_VALIDATION,
      "a relation cannot be named 'self' or 'this'",
      name_tok.line,
      name_tok.column,
    )
  }
  if td.relations.contains(name_tok.text) {
    raise @fga.fail_at(
      @fga.ERR_VALIDATION,
      "relation '" +
      name_tok.text +
      "' is already defined on type '" +
      td.name +
      "'",
      name_tok.line,
      name_tok.column,
    )
  }
  p.expect_kind(Colon, "':' after relation name")
  let restrictions : Array[@fga.TypeRestriction] = []
  let rewrite = parse_userset_or(p, restrictions)
  td.set_relation(name_tok.text, rewrite, restrictions)
  model.set_span(
    "rel:" + td.name + ":" + name_tok.text,
    name_tok.line,
    name_tok.column,
  )
}

///|
fn parse_type_body(
  p : Parser,
  model : @fga.AuthModel,
  td : @fga.TypeDefinition,
) -> Unit raise @fga.FgaError {
  if p.at_word("relations") {
    p.advance()
    while p.at_word("define") {
      parse_relation(p, model, td)
    }
  }
}

///|
fn parse_type_definition(
  p : Parser,
  model : @fga.AuthModel,
) -> Unit raise @fga.FgaError {
  let type_tok = p.expect_word("type")
  let name_tok = p.expect_word("a type name")
  if name_tok.text == "self" || name_tok.text == "this" {
    raise @fga.fail_at(
      @fga.ERR_VALIDATION,
      "a type cannot be named 'self' or 'this'",
      name_tok.line,
      name_tok.column,
    )
  }
  for existing in model.types {
    if existing.name == name_tok.text {
      raise @fga.fail_at(
        @fga.ERR_VALIDATION,
        "type '" + name_tok.text + "' is defined more than once",
        name_tok.line,
        name_tok.column,
      )
    }
  }
  let td = @fga.TypeDefinition::new(name_tok.text)
  model.set_span("type:" + name_tok.text, type_tok.line, type_tok.column)
  parse_type_body(p, model, td)
  model.add_type(td)
}

///|
fn parse_extend_type(
  p : Parser,
  model : @fga.AuthModel,
) -> Unit raise @fga.FgaError {
  p.advance() // extend
  let _ = p.expect_word_text("type")
  let name_tok = p.expect_word("a type name")
  match model.find_type(name_tok.text) {
    None =>
      raise @fga.fail_at(
        @fga.ERR_VALIDATION,
        "cannot extend unknown type '" + name_tok.text + "'",
        name_tok.line,
        name_tok.column,
      )
    Some(td) => parse_type_body(p, model, td)
  }
}

///|
fn is_parameter_type(name : String) -> Bool {
  name == "bool" ||
  name == "string" ||
  name == "int" ||
  name == "uint" ||
  name == "double" ||
  name == "duration" ||
  name == "timestamp" ||
  name == "ipaddress"
}

///|
fn parse_condition(
  p : Parser,
  model : @fga.AuthModel,
) -> Unit raise @fga.FgaError {
  let cond_tok = p.next() // condition
  let name_tok = p.expect_word("a condition name")
  if model.conditions.contains(name_tok.text) {
    raise @fga.fail_at(
      @fga.ERR_VALIDATION,
      "condition '" + name_tok.text + "' is defined more than once",
      name_tok.line,
      name_tok.column,
    )
  }
  p.expect_kind(LParen, "'(' after condition name")
  let parameters : Array[@fga.ConditionParam] = []
  if !p.at_kind(RParen) {
    while true {
      let param_tok = p.expect_word("a parameter name")
      p.expect_kind(Colon, "':' after parameter name")
      let type_tok = p.expect_word("a parameter type")
      let base = type_tok.text
      let mut generic : String? = None
      if base == "list" || base == "map" {
        p.expect_kind(Less, "'<'")
        let inner = p.expect_word("a parameter element type")
        if !is_parameter_type(inner.text) {
          raise @fga.fail_at(
            @fga.ERR_VALIDATION,
            "invalid condition parameter type '" + inner.text + "'",
            inner.line,
            inner.column,
          )
        }
        generic = Some(inner.text)
        p.expect_kind(Greater, "'>'")
      } else if !is_parameter_type(base) {
        raise @fga.fail_at(
          @fga.ERR_VALIDATION,
          "invalid condition parameter type '" + base + "'",
          type_tok.line,
          type_tok.column,
        )
      }
      parameters.push(@fga.ConditionParam::{
        name: param_tok.text,
        type_name: base,
        generic_type: generic,
      })
      if p.at_kind(Comma) {
        p.advance()
      } else {
        break
      }
    }
  }
  p.expect_kind(RParen, "')' after condition parameters")
  let body_tok = p.peek()
  p.expect_kind(ConditionBody, "a condition body in braces")
  let expression = body_tok.text.trim().to_owned()
  if expression == "" {
    raise @fga.fail_at(
      @fga.ERR_VALIDATION,
      "condition '" + name_tok.text + "' has an empty body",
      body_tok.line,
      body_tok.column,
    )
  }
  model.add_condition(@fga.Condition::{
    name: name_tok.text,
    expression,
    parameters,
  })
  model.set_span("condition:" + name_tok.text, cond_tok.line, cond_tok.column)
}

///|
/// Parses a schema 1.1 DSL document into an authorization model.
///
/// Use merge_modules for multi-file module composition.
pub fn parse_model(source : String) -> @fga.AuthModel raise @fga.FgaError {
  let tokens = lex(source)
  let p = Parser::{ tokens, pos: 0, }
  let mut schema_version = "1.1"
  if p.at_word("module") {
    p.advance()
    let _ = p.expect_word("a module name")
  } else if p.at_word("model") {
    p.advance()
    let _ = p.expect_word_text("schema")
    let version = p.peek()
    match version.kind {
      Version => {
        if version.text != "1.1" && version.text != "1.2" {
          raise @fga.fail_at(
            @fga.ERR_VALIDATION,
            "invalid schema " +
            version.text +
            " (only 1.1 and 1.2 are supported)",
            version.line,
            version.column,
          )
        }
        p.advance()
        schema_version = version.text
      }
      _ =>
        raise @fga.fail_at(
          @fga.ERR_VALIDATION,
          "expected schema version such as 1.1",
          version.line,
          version.column,
        )
    }
  } else {
    let token = p.peek()
    raise @fga.fail_at(
      @fga.ERR_VALIDATION,
      "expected 'model' or 'module' header",
      token.line,
      token.column,
    )
  }
  let model = @fga.AuthModel::new(schema_version)
  while !p.at_kind(Eof) {
    if p.at_word("type") {
      parse_type_definition(p, model)
    } else if p.at_word("extend") {
      parse_extend_type(p, model)
    } else if p.at_word("condition") {
      parse_condition(p, model)
    } else {
      let token = p.peek()
      raise @fga.fail_at(
        @fga.ERR_VALIDATION,
        "unexpected token '" +
        token.text +
        "', expected 'type', 'extend' or 'condition'",
        token.line,
        token.column,
      )
    }
  }
  model
}
