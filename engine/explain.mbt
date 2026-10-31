// Witnesses are collected during the successful Check, never by a second
// traversal that could fail on branches the decision legitimately ignored.

///|
/// A successful decision may have an incomplete explanation; that condition
/// is reported separately and never turns an allowed decision into an error.
pub(all) struct ExplainResult {
  allowed : Bool
  paths : Array[String]
  complete : Bool
  explain_error : String?
}

///|
fn Engine::record_trace(
  self : Engine,
  object : String,
  relation : String,
  user : String,
  paths : Array[String],
) -> Unit {
  match self.traces {
    Some(m) => m[path_key(object, relation) + "@" + user] = paths
    None => ()
  }
}

///|
fn Engine::trace_for(
  self : Engine,
  object : String,
  relation : String,
  user : String,
) -> Array[String] {
  match self.traces {
    Some(m) => m.get(path_key(object, relation) + "@" + user).unwrap_or([])
    None => []
  }
}

///|
/// Shared JSON representation for CLI and JS: paths are arrays of steps.
pub fn ExplainResult::to_json(self : ExplainResult) -> Json {
  let fields : Map[String, Json] = Map([
    ("allowed", Json::boolean(self.allowed)),
    ("complete", Json::boolean(self.complete)),
    (
      "paths",
      Json::array(
        self.paths.map(fn(p) {
          Json::array(
            p.split(" -> ").map(fn(s) { Json::string(s.to_owned()) }).collect(),
          )
        }),
      ),
    ),
  ])
  match self.explain_error {
    Some(message) => fields["explain_error"] = Json::string(message)
    None => ()
  }
  Json::object(fields)
}

///|
/// Returns the Check decision and witnesses recorded on its successful path.
/// Decision errors still raise FgaError; incomplete witnesses are non-fatal.
pub fn Engine::explain_check(
  self : Engine,
  object : String,
  relation : String,
  user : String,
  context : Map[String, Json],
  contextual_tuples : Array[@fga.Tuple],
) -> ExplainResult raise @fga.FgaError {
  let engine = Engine::{ ..self, traces: Some(Map([])), }
  let allowed = engine.check_with(
    object, relation, user, context, contextual_tuples,
  )
  let paths = if allowed {
    engine.trace_for(object, relation, user)
  } else {
    []
  }
  let complete = !allowed || !paths.is_empty()
  let explain_error = if complete {
    None
  } else {
    Some("decision succeeded but no complete witness was recorded")
  }
  { allowed, paths, complete, explain_error, }
}
