///|
/// Collect parse, composition and semantic diagnostics without failing fast.
/// The returned model is partial and must not be used when diagnostics exist.
pub fn modules_with_diagnostics(
  source : String,
  files : Array[@dsl.ModuleFile],
) -> (@fga.AuthModel, Array[@dsl.ModuleDiagnostic]) raise @fga.FgaError {
  let selected : Array[@dsl.ModuleFile] = []
  for path in parse_mod(source) {
    let matches = files.filter(fn(file) { file.name == path })
    if matches.length() != 1 {
      raise invalid("expected one module file: " + path)
    }
    selected.push(matches[0])
  }
  collect_module_diagnostics(selected)
}

///|
/// Collect diagnostics for host-supplied files without a manifest.
pub fn collect_module_diagnostics(
  files : Array[@dsl.ModuleFile],
) -> (@fga.AuthModel, Array[@dsl.ModuleDiagnostic]) {
  let (model, errors) = @dsl.collect_modules(files)
  for issue in @validate.validate_model(model) {
    let parts = issue.symbol
    // Match the validator's exact legacy source prefix against structured
    // metadata. Do not parse delimiters inside arbitrary filenames or messages.
    let mut meta : Json? = None
    let mut prefix_length = 0
    model.metadata.each(fn(_, value) {
      if value is Object(obj) {
        let prefix = "[" + Json::object(obj).stringify() + "] "
        if issue.message.has_prefix(prefix) {
          meta = Some(value)
          prefix_length = prefix.length()
        }
      }
    })
    let mut message = issue.message[prefix_length:].to_owned()
    let mut error_type = ""
    if message.contains("does not match naming rules") {
      error_type = "invalid-name"
      let limit = if message.has_prefix("type '") { "254" } else { "50" }
      message = message.replace(
        old="naming rules.",
        new="naming rule: '^[^:#@\\*\\s]{1," + limit + "}$'.",
      )
    } else if message.has_prefix("a type cannot") {
      error_type = "reserved-type-keywords"
      message = "a type cannot be named 'self' or 'this'."
    } else if message.has_prefix("a relation cannot") {
      error_type = "reserved-relation-keywords"
      message = "a relation cannot be named 'self' or 'this'."
    } else if message.contains("impossible relation") {
      error_type = "relation-no-entry-point"
    } else if message.contains("does not exist on") {
      error_type = "invalid-relation-on-tupleset"
    } else if message.contains("allows only direct") {
      error_type = "tupleuserset-not-direct"
    } else if message.contains("not a valid type") {
      error_type = "invalid-type"
    } else if message.contains("not a valid relation") {
      error_type = "invalid-relation-type"
    } else if message.contains("not a defined condition") {
      error_type = "condition-not-defined"
    } else if message.contains("is not used in the model") {
      error_type = "condition-not-used"
    } else if message.contains("does not exist") {
      error_type = "missing-definition"
    }
    let mut file = ""
    let mut module_name = ""
    if meta is Some(Object(obj)) {
      if obj.get("module") is Some(String(s)) {
        module_name = s
      }
      if obj.get("source_info") is Some(Object(info)) {
        if info.get("file") is Some(String(s)) {
          file = s
        }
      }
    }
    let line = issue.line - 1
    let mut column = issue.column - 1
    let mut end_column = column + parts.length()
    for input in files {
      if input.name != file {
        continue
      }
      let tokens = @dsl.lex(input.contents) catch { _ => [] }
      let on_line = tokens.filter(fn(t) { t.line == issue.line })
      let mut chosen = -1
      for i, token in on_line {
        if token.text == parts && token.column >= issue.column {
          if error_type != "relation-no-entry-point" || chosen < 0 {
            chosen = i
          }
        }
      }
      if chosen >= 0 {
        let token = on_line[chosen]
        column = token.column - 1
        end_column = column + token.text.length()
        if error_type == "invalid-relation-type" {
          if chosen > 1 && on_line[chosen - 1].kind == @dsl.Hash {
            column = on_line[chosen - 2].column - 1
          } else if chosen > 1 && on_line[chosen - 1].text == "from" {
            column = on_line[chosen - 2].column - 1
          }
        } else if error_type == "invalid-relation-on-tupleset" {
          if chosen + 2 < on_line.length() && on_line[chosen + 1].text == "from" {
            end_column = on_line[chosen + 2].column -
              1 +
              on_line[chosen + 2].text.length()
          }
        }
      }
    }
    errors.push({
      message,
      file,
      module_name,
      line,
      column,
      end_line: line,
      end_column,
      error_type,
    })
  }
  (model, errors)
}
