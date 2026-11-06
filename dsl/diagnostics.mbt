///|
/// Module diagnostics use zero-based, end-exclusive source ranges.
pub(all) struct ModuleDiagnostic {
  message : String
  file : String
  module_name : String
  line : Int32
  column : Int32
  end_line : Int32
  end_column : Int32
  error_type : String
}

///|
pub fn ModuleDiagnostic::to_json(self : ModuleDiagnostic) -> Json {
  let fields : Map[String, Json] = Map([
    ("msg", Json::string(self.message)),
    ("file", Json::string(self.file)),
    ("module", Json::string(self.module_name)),
    ("line", { "start": self.line, "end": self.end_line }),
    ("column", { "start": self.column, "end": self.end_column }),
  ])
  if self.error_type == "syntax" {
    fields["type"] = "syntax"
  } else if self.error_type != "" {
    fields["metadata"] = { "errorType": self.error_type }
  }
  Json::object(fields)
}

///|
fn diagnostic(
  message : String,
  file : String,
  module_name : String,
  token : Token,
  error_type : String,
) -> ModuleDiagnostic {
  {
    message,
    file,
    module_name,
    line: token.line - 1,
    column: token.column - 1,
    end_line: token.line - 1,
    end_column: token.column - 1 + token.text.length(),
    error_type,
  }
}

///|
/// Recover at the next top-level declaration after a parse error. A partial
/// model is returned only for diagnostics; callers must reject nonempty errors.
pub fn collect_modules(
  files : Array[ModuleFile],
) -> (@fga.AuthModel, Array[ModuleDiagnostic]) {
  let model = @fga.AuthModel::new("1.2")
  let errors : Array[ModuleDiagnostic] = []
  let extensions : Array[(@fga.AuthModel, String, String)] = []
  let filenames : Map[String, Bool] = Map([])
  for file in files {
    let mut module_name = ""
    let tokens = lex(file.contents) catch {
      @fga.FgaError(message~, line~, column~, ..) => {
        errors.push({
          message,
          file: file.name,
          module_name,
          line: line - 1,
          column: column - 1,
          end_line: line - 1,
          end_column: column - 1,
          error_type: "syntax",
        })
        continue
      }
    }
    let p = Parser::{ tokens, pos: 0, }
    if !p.at_word("module") {
      errors.push({
        message: "file is not a module",
        file: file.name,
        module_name,
        line: 0,
        column: 0,
        end_line: 0,
        end_column: 0,
        error_type: "",
      })
      continue
    }
    p.advance()
    module_name = p.expect_word("a module name").text catch {
        @fga.FgaError(message~, ..) => {
          errors.push(
            diagnostic(message, file.name, module_name, p.peek(), "syntax"),
          )
          continue
        }
      }
    if filenames.contains(file.name) {
      errors.push(
        diagnostic(
          "duplicate module file",
          file.name,
          module_name,
          tokens[0],
          "",
        ),
      )
      continue
    }
    filenames[file.name] = true
    let meta = module_metadata(module_name, file.name)
    let extended_types : Map[String, Bool] = Map([])
    while !p.at_kind(Eof) {
      let start = p.pos
      try {
        let part = @fga.AuthModel::new("1.2")
        let extended = p.at_word("extend")
        if extended {
          p.advance()
        }
        if p.at_word("type") {
          parse_type_definition(p, part, module_mode=true)
          let td = part.types[0]
          let key = "type:" + td.name
          // Type diagnostics point to the name, not the 'type' keyword.
          let name_token = tokens[start + (if extended { 2 } else { 1 })]
          part.set_span(key, name_token.line, name_token.column)
          part.metadata[key] = meta
          for rel in td.relation_order {
            part.metadata["rel:" + td.name + ":" + rel] = meta
          }
          if extended {
            if extended_types.contains(td.name) {
              errors.push(
                diagnostic(
                  "'" + td.name + "' is already extended in file.",
                  file.name,
                  module_name,
                  name_token,
                  "",
                ),
              )
            } else {
              extended_types[td.name] = true
              extensions.push((part, module_name, file.name))
            }
          } else if model.find_type(td.name) is Some(_) {
            errors.push(
              diagnostic(
                "duplicate type '" + td.name + "'",
                file.name,
                module_name,
                name_token,
                "",
              ),
            )
          } else {
            model.add_type(td)
            model.metadata[key] = meta
            part.spans.each(fn(k, v) { model.spans[k] = v })
          }
        } else if !extended && p.at_word("condition") {
          parse_condition(p, part)
          let name = part.condition_order[0]
          if model.conditions.contains(name) {
            errors.push(
              diagnostic(
                "duplicate condition " + name,
                file.name,
                module_name,
                tokens[start + 1],
                "",
              ),
            )
          } else {
            model.add_condition(part.conditions[name])
            model.metadata["condition:" + name] = meta
            let t = tokens[start + 1]
            model.set_span("condition:" + name, t.line, t.column)
          }
        } else {
          let t = p.peek()
          let message = if t.is_word("define") {
            let input = StringBuilder()
            input.write_string("no viable alternative at input '\\n")
            for _ in 1..<t.column {
              input.write_string(" ")
            }
            input.write_string(t.text + "'")
            input.to_string()
          } else {
            "expected type, extend type or condition"
          }
          raise @fga.fail_at(@fga.ERR_VALIDATION, message, t.line, t.column)
        }
      } catch {
        @fga.FgaError(message~, line~, column~, ..) => {
          let mut t = p.peek()
          for token in tokens {
            if token.line == line && token.column == column {
              t = token
            }
          }
          errors.push(diagnostic(message, file.name, module_name, t, "syntax"))
          if p.pos == start {
            p.advance()
          }
          while !p.at_kind(Eof) &&
                !(p.peek().column == 1 &&
                (
                  p.at_word("type") ||
                  p.at_word("extend") ||
                  p.at_word("condition")
                )) {
            p.advance()
          }
        }
      }
    }
  }
  for (part, module_name, file) in extensions {
    let extension = part.types[0]
    let span = part.spans["type:" + extension.name]
    let t = Token::{
      kind: Word,
      text: extension.name,
      line: span.line,
      column: span.column,
    }
    let td = match model.find_type(extension.name) {
      Some(td) => td
      None => {
        errors.push(
          diagnostic(
            "extended type " + extension.name + " does not exist",
            file,
            module_name,
            t,
            "",
          ),
        )
        continue
      }
    }
    for rel in extension.relation_order {
      let key = "rel:" + td.name + ":" + rel
      let span = part.spans[key]
      if td.relations.contains(rel) {
        errors.push(
          diagnostic(
            "relation " + rel + " already exists on type " + td.name,
            file,
            module_name,
            { kind: Word, text: rel, line: span.line, column: span.column, },
            "",
          ),
        )
      } else {
        td.set_relation(
          rel,
          extension.relations[rel],
          extension.restrictions(rel),
        )
        model.spans[key] = span
        model.metadata[key] = part.metadata[key]
      }
    }
  }
  (model, errors)
}
