///|
/// A host-supplied module file; name is the relative source filename.
pub(all) struct ModuleFile {
  name : String
  contents : String
}

///|
fn module_metadata(module_name : String, file : String) -> Json {
  Json::object(
    Map([
      ("module", Json::string(module_name)),
      ("source_info", Json::object(Map([("file", Json::string(file))]))),
    ]),
  )
}

///|
/// Compose files without filesystem access. Extensions are resolved after all
/// base types, so forward references and mutually referencing modules work.
pub fn merge_modules(
  files : Array[ModuleFile],
) -> @fga.AuthModel raise @fga.FgaError {
  let model = @fga.AuthModel::new("1.2")
  let extensions : Array[(@fga.AuthModel, String, String)] = []
  let filenames : Map[String, Bool] = Map([])
  for file in files {
    let mut module_name = "?"
    try {
      if filenames.contains(file.name) {
        raise @fga.fail_at(@fga.ERR_VALIDATION, "duplicate module file", 1, 1)
      }
      filenames[file.name] = true
      let p = Parser::{ tokens: lex(file.contents), pos: 0, }
      let _ = p.expect_word_text("module")
      module_name = p.expect_word("a module name").text
      let meta = module_metadata(module_name, file.name)
      let extended_types : Map[String, Bool] = Map([])
      while !p.at_kind(Eof) {
        let part = @fga.AuthModel::new("1.2")
        let extended = p.at_word("extend")
        if extended {
          p.advance()
        }
        if p.at_word("type") {
          parse_type_definition(p, part)
          let td = part.types[0]
          let key = "type:" + td.name
          part.metadata[key] = meta
          for rel in td.relation_order {
            part.metadata["rel:" + td.name + ":" + rel] = meta
          }
          if extended {
            if extended_types.contains(td.name) {
              let span = part.spans[key]
              raise @fga.fail_at(
                @fga.ERR_VALIDATION,
                "'" + td.name + "' is already extended in file.",
                span.line,
                span.column,
              )
            }
            extended_types[td.name] = true
            extensions.push((part, module_name, file.name))
          } else {
            if model.find_type(td.name) is Some(_) {
              let span = part.spans[key]
              raise @fga.fail_at(
                @fga.ERR_VALIDATION,
                "duplicate type '" + td.name + "'",
                span.line,
                span.column,
              )
            }
            model.add_type(td)
            model.metadata[key] = meta
            part.spans.each(fn(k, v) { model.spans[k] = v })
          }
        } else if !extended && p.at_word("condition") {
          parse_condition(p, part)
          let name = part.condition_order[0]
          let key = "condition:" + name
          if model.conditions.contains(name) {
            let span = part.spans[key]
            raise @fga.fail_at(
              @fga.ERR_VALIDATION,
              "duplicate condition '" + name + "'",
              span.line,
              span.column,
            )
          }
          model.add_condition(part.conditions[name])
          model.metadata[key] = meta
          part.spans.each(fn(k, v) { model.spans[k] = v })
        } else {
          let t = p.peek()
          raise @fga.fail_at(
            @fga.ERR_VALIDATION,
            "expected type, extend type or condition",
            t.line,
            t.column,
          )
        }
      }
    } catch {
      @fga.FgaError(code~, message~, line~, column~) =>
        raise @fga.fail_at(
          code,
          "module " + module_name + " (" + file.name + "): " + message,
          line,
          column,
        )
    }
  }
  for (part, module_name, file) in extensions {
    let extension = part.types[0]
    let key = "type:" + extension.name
    let td = match model.find_type(extension.name) {
      Some(td) => td
      None => {
        let span = part.spans[key]
        raise @fga.fail_at(
          @fga.ERR_VALIDATION,
          "module " +
          module_name +
          " (" +
          file +
          "): cannot extend unknown type '" +
          extension.name +
          "'",
          span.line,
          span.column,
        )
      }
    }
    for rel in extension.relation_order {
      let key = "rel:" + td.name + ":" + rel
      let span = part.spans[key]
      if td.relations.contains(rel) {
        raise @fga.fail_at(
          @fga.ERR_VALIDATION,
          "module " +
          module_name +
          " (" +
          file +
          "): duplicate relation '" +
          td.name +
          "#" +
          rel +
          "'",
          span.line,
          span.column,
        )
      }
      td.set_relation(
        rel,
        extension.relations[rel],
        extension.restrictions(rel),
      )
      model.spans[key] = span
      model.metadata[key] = part.metadata[key]
    }
  }
  model
}
