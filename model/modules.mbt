///|
// Bound both recursion (including aliases) and total expanded nodes before
// constructing JSON. Never call the dependency's unbounded container to_json.
fn mod_yaml_to_json(
  node : @yaml.Yaml,
  depth : Int32,
  count : Array[Int32],
) -> Json raise @fga.FgaError {
  if depth > 64 || count[0] >= 10000 {
    raise invalid("fga.mod YAML exceeds depth or expanded node limit")
  }
  count[0] += 1
  match node {
    @yaml.Map(values) => {
      let result : Map[String, Json] = Map([])
      for key, value in values {
        result[key] = mod_yaml_to_json(value, depth + 1, count)
      }
      Json::object(result)
    }
    @yaml.Array(values) => {
      let result : Array[Json] = []
      for value in values {
        result.push(mod_yaml_to_json(value, depth + 1, count))
      }
      Json::array(result)
    }
    @yaml.BadValue => raise invalid("invalid fga.mod YAML value or alias")
    _ => node.to_json()
  }
}

///|
/// Parse fga.mod schema and relative content paths using YAML.
fn parse_mod_paths(source : String) -> Array[String] raise @fga.FgaError {
  let docs = @yaml.Yaml::load_from_string(source) catch {
    _ => raise invalid("invalid fga.mod YAML")
  }
  if docs.length() != 1 {
    raise invalid("fga.mod requires one YAML document")
  }
  let obj = as_object(mod_yaml_to_json(docs[0], 0, [0]), "fga.mod")
  if as_string(required(obj, "schema", "fga.mod"), "schema") != "1.2" {
    raise invalid("fga.mod requires schema '1.2'")
  }
  let paths : Array[String] = []
  for item in as_array(required(obj, "contents", "fga.mod"), "contents") {
    let path = as_string(item, "contents item")
    // Reject encoded paths and platform-specific separators as well as traversal.
    if !path.has_suffix(".fga") ||
      path.has_prefix("/") ||
      path.contains("\\") ||
      path.contains(":") ||
      path.contains("%") ||
      path.split("/").any(fn(p) { p == ".." || p == "" }) {
      raise invalid("invalid fga.mod contents path: " + path)
    }
    if paths.contains(path) {
      raise invalid("duplicate fga.mod contents path: " + path)
    }
    paths.push(path)
  }
  paths
}

///|
/// Compose exactly the files listed by fga.mod. The host supplies all contents.
pub fn modules_to_model(
  source : String,
  files : Array[@dsl.ModuleFile],
) -> @fga.AuthModel raise @fga.FgaError {
  let selected : Array[@dsl.ModuleFile] = []
  for path in parse_mod(source) {
    let matches = files.filter(fn(file) { file.name == path })
    if matches.length() != 1 {
      raise invalid("expected one module file: " + path)
    }
    selected.push(matches[0])
  }
  let model = @dsl.merge_modules(selected)
  let issues = @validate.validate_model(model)
  if issues.length() > 0 {
    let issue = issues[0]
    raise @fga.fail_at(issue.code, issue.message, issue.line, issue.column)
  }
  model
}

///|
priv struct ModLocations {
  scalars : Map[String, @fga.Span]
  anchors : Array[Int32]
  mut cyclic_alias : Bool
}

///|
impl @yaml.MarkedEventReceiver for ModLocations with fn on_event(
  self,
  event,
  mark,
) {
  match event {
    @yaml.SequenceStart(id~, ..) | @yaml.MappingStart(id~, ..) =>
      self.anchors.push(id)
    @yaml.SequenceEnd | @yaml.MappingEnd => ignore(self.anchors.pop())
    @yaml.Alias(id~) =>
      if self.anchors.contains(id) {
        self.cyclic_alias = true
      }
    _ => ()
  }
  if event is @yaml.Scalar(value~, ..) {
    self.scalars[value] = @fga.Span::{ line: mark.line, column: mark.col + 1, }
  }
}

///|
/// Parse the module manifest. Errors identify fga.mod and a YAML source position.
pub fn parse_mod(source : String) -> Array[String] raise @fga.FgaError {
  let locations = ModLocations::{
    scalars: Map([]),
    anchors: [],
    cyclic_alias: false,
  }
  @yaml.Parser::Parser(source).load(locations, true) catch {
    @yaml.YamlError(mark~, info~) =>
      raise @fga.fail_at(
        @fga.ERR_VALIDATION,
        "fga.mod: " + info,
        mark.line,
        mark.col + 1,
      )
  }
  if locations.cyclic_alias {
    raise @fga.fail_at(@fga.ERR_VALIDATION, "fga.mod: cyclic YAML alias", 1, 1)
  }
  parse_mod_paths(source) catch {
    @fga.FgaError(code~, message~, ..) => {
      let mut span = @fga.Span::{ line: 1, column: 1, }
      let key = if message.contains("schema") { "schema" } else { "contents" }
      if locations.scalars.get(key) is Some(location) {
        span = location
      }
      locations.scalars.each(fn(value, location) {
        if value.has_suffix(".fga") && message.contains(value) {
          span = location
        }
      })
      raise @fga.fail_at(code, "fga.mod: " + message, span.line, span.column)
    }
  }
}
