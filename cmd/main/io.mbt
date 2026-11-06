// File, model, tuple and context loading shared by CLI commands.

///|
fn read_text(path : String) -> String raise @fga.FgaError {
  @fs.read_file_to_string(path) catch {
    _ => raise @fga.fail(@fga.ERR_VALIDATION, "usage: cannot read file " + path)
  }
}

///|
fn write_text(path : String, text : String) -> Unit raise @fga.FgaError {
  @fs.write_string_to_file(path, text) catch {
    _ =>
      raise @fga.fail(@fga.ERR_VALIDATION, "usage: cannot write file " + path)
  }
}

///|
fn load_model_file(path : String) -> @fga.AuthModel raise @fga.FgaError {
  if path.has_suffix(".mod") {
    let (source, files) = read_module_files(path)
    @model.modules_to_model(source, files)
  } else {
    @model.model_from_source(read_text(path))
  }
}

///|
fn tuples_from_value(value : Json) -> Array[@fga.Tuple] raise @fga.FgaError {
  match value {
    Array(_) => @fga.tuples_from_json(Some(value))
    Object(m) =>
      match m.get("tuples") {
        Some(tuples) => @fga.tuples_from_json(Some(tuples))
        None =>
          raise @fga.fail(
            @fga.ERR_VALIDATION,
            "tuple document must be an array or an object with 'tuples'",
          )
      }
    _ =>
      raise @fga.fail(
        @fga.ERR_VALIDATION,
        "tuple document must be an array or object",
      )
  }
}

///|
fn load_tuples_file(path : String) -> Array[@fga.Tuple] raise @fga.FgaError {
  let source = read_text(path)
  let trimmed = source.trim()
  if trimmed == "" {
    return []
  }
  if trimmed.has_prefix("[") || trimmed.has_prefix("{") {
    let parsed = @json.parse(source) catch {
      _ =>
        raise @fga.fail(
          @fga.ERR_VALIDATION,
          "usage: invalid JSON tuples in " + path,
        )
    }
    tuples_from_value(parsed)
  } else if path.has_suffix(".yaml") || path.has_suffix(".yml") {
    let documents = @yaml.Yaml::load_from_string(source) catch {
      _ =>
        raise @fga.fail(
          @fga.ERR_VALIDATION,
          "usage: invalid YAML tuples in " + path,
        )
    }
    if documents.length() == 0 {
      []
    } else {
      tuples_from_value(documents[0].to_json())
    }
  } else {
    @fga.tuples_from_text(source)
  }
}

///|
fn load_optional_tuples(
  args : CliArgs,
  flag : String,
) -> Array[@fga.Tuple] raise @fga.FgaError {
  match flag_value(args, flag) {
    Some(path) => load_tuples_file(path)
    None => []
  }
}

///|
fn parse_context_text(text : String) -> Map[String, Json] raise @fga.FgaError {
  let parsed = @json.parse(text) catch {
    _ =>
      raise @fga.fail(
        @fga.ERR_VALIDATION,
        "usage: --context must be a JSON object",
      )
  }
  match parsed {
    Object(m) => m
    _ =>
      raise @fga.fail(
        @fga.ERR_VALIDATION,
        "usage: --context must be a JSON object",
      )
  }
}

///|
fn load_context(args : CliArgs) -> Map[String, Json] raise @fga.FgaError {
  match flag_value(args, "--context") {
    Some(text) => parse_context_text(text)
    None =>
      match flag_value(args, "--context-file") {
        Some(path) => parse_context_text(read_text(path))
        None => Map([])
      }
  }
}

///|
fn parse_filters(args : CliArgs, model : @fga.AuthModel) -> Array[String] {
  match flag_value(args, "--filters") {
    Some(text) => {
      let out : Array[String] = []
      for part in text.split(",") {
        let filter = part.trim().to_owned()
        if filter != "" {
          out.push(filter)
        }
      }
      out
    }
    None => {
      let out : Array[String] = []
      for type_def in model.types {
        out.push(type_def.name)
      }
      out
    }
  }
}

///|
fn dirname(path : String) -> String {
  let mut last = -1
  for i in 0..<path.length() {
    match path.get_char(i) {
      Some('/') | Some('\\') => last = i
      _ => ()
    }
  }
  if last < 0 {
    ""
  } else {
    path[:last + 1].to_owned()
  }
}

///|
fn read_module_files(
  path : String,
) -> (String, Array[@dsl.ModuleFile]) raise @fga.FgaError {
  let source = read_text(path)
  let files : Array[@dsl.ModuleFile] = []
  for name in @model.parse_mod(source) {
    let target = dirname(path) + name
    @host.require_contained(dirname(path), target)
    files.push(@dsl.ModuleFile::{ name, contents: read_text(target), })
  }
  (source, files)
}
