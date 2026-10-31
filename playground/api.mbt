// JavaScript-facing API for the browser playground.
//
// Every export takes one JSON string and returns one JSON string. Failures are
// reported as `{"ok":false,"error":{...}}`; nothing here throws.

///|
fn obj(fields : Array[(String, Json)]) -> Json {
  let m : Map[String, Json] = Map([])
  for pair in fields {
    m[pair.0] = pair.1
  }
  Json::object(m)
}

///|
fn strings_json(values : Array[String]) -> Json {
  let items : Array[Json] = []
  for value in values {
    items.push(Json::string(value))
  }
  Json::array(items)
}

///|
fn int_json(value : Int32) -> Json {
  Json::number(value.to_double())
}

///|
fn error_json(
  code : Int32,
  message : String,
  line : Int32,
  column : Int32,
) -> Json {
  obj([
    ("ok", Json::boolean(false)),
    (
      "error",
      obj([
        ("code", int_json(code)),
        ("message", Json::string(message)),
        ("line", int_json(line)),
        ("column", int_json(column)),
      ]),
    ),
  ])
}

///|
fn issue_json(issue : @validate.ValidationIssue) -> Json {
  obj([
    ("code", int_json(issue.code)),
    ("message", Json::string(issue.message)),
    ("line", int_json(issue.line)),
    ("column", int_json(issue.column)),
    ("symbol", Json::string(issue.symbol)),
  ])
}

///|
fn issues_array(issues : Array[@validate.ValidationIssue]) -> Json {
  let items : Array[Json] = []
  for issue in issues {
    items.push(issue_json(issue))
  }
  Json::array(items)
}

///|
fn bad_request(message : String) -> @fga.FgaError {
  @fga.fail(@fga.ERR_VALIDATION, "request: " + message)
}

///|
priv suberror ModelInvalidError {
  ModelInvalid(Array[@validate.ValidationIssue])
}

///|
fn parse_request(text : String) -> Map[String, Json] raise Error {
  let parsed = @json.parse(text) catch {
    _ => raise bad_request("body is not valid JSON")
  }
  match parsed {
    Object(m) => m
    _ => raise bad_request("body must be a JSON object")
  }
}

///|
fn string_field(req : Map[String, Json], name : String) -> String raise Error {
  match req.get(name) {
    Some(String(s)) => s
    _ => raise bad_request("missing string field '" + name + "'")
  }
}

///|
/// Accepts a JSON array of tuple objects, or a string: JSON text of such an
/// array, or one `object#relation@user` per line.
fn tuples_field(
  req : Map[String, Json],
  name : String,
) -> Array[@fga.Tuple] raise Error {
  match req.get(name) {
    None | Some(Null) => []
    Some(Array(_) as value) => @fga.tuples_from_json(Some(value))
    Some(String(text)) => {
      let trimmed = text.trim().to_owned()
      if trimmed == "" {
        return []
      }
      if trimmed.has_prefix("{") {
        raise bad_request("'" + name + "' must be a JSON array of tuples")
      }
      if trimmed.has_prefix("[") {
        let parsed = @json.parse(trimmed) catch {
          _ => raise bad_request("'" + name + "' is not valid JSON")
        }
        @fga.tuples_from_json(Some(parsed))
      } else {
        @fga.tuples_from_text(text)
      }
    }
    _ => raise bad_request("'" + name + "' must be an array or a string")
  }
}

///|
/// Accepts a JSON object or a string holding one.
fn context_field(req : Map[String, Json]) -> Map[String, Json] raise Error {
  match req.get("context") {
    None | Some(Null) => Map([])
    Some(Object(m)) => m
    Some(String(text)) => {
      if text.trim() == "" {
        return Map([])
      }
      let parsed = @json.parse(text) catch {
        _ => raise bad_request("'context' is not valid JSON")
      }
      match parsed {
        Object(m) => m
        _ => raise bad_request("'context' must be a JSON object")
      }
    }
    _ => raise bad_request("'context' must be an object")
  }
}

///|
fn load_valid_model(source : String) -> @fga.AuthModel raise Error {
  let model = @model.model_from_source(source)
  let issues = @validate.validate_model(model)
  if issues.length() > 0 {
    raise ModelInvalid(issues)
  }
  model
}

///|
fn build_engine(req : Map[String, Json]) -> @engine.Engine raise Error {
  let model = load_valid_model(string_field(req, "model"))
  let store = @store.MemoryStore::new()
  let _ = store.write_all(tuples_field(req, "tuples"))
  @engine.Engine::new(model, store as &@fga.TupleReader)
}

///|
fn failure_json(failure : Error) -> Json {
  match failure {
    @fga.FgaError(code~, message~, line~, column~) =>
      error_json(code, message, line, column)
    ModelInvalid(issues) => {
      let first = issues[0]
      let base = error_json(first.code, first.message, first.line, first.column)
      match base {
        Object(m) => {
          m["issues"] = issues_array(issues)
          Json::object(m)
        }
        other => other
      }
    }
    _ => error_json(@fga.ERR_VALIDATION, "unexpected error", -1, -1)
  }
}

///|
fn respond(body : () -> Json raise Error) -> String {
  let result = body() catch { e => failure_json(e) }
  result.stringify()
}

///|
fn ok_with(fields : Array[(String, Json)]) -> Json {
  let all : Array[(String, Json)] = [("ok", Json::boolean(true))]
  for field in fields {
    all.push(field)
  }
  obj(all)
}

///|
/// Request: `{"model": "<DSL or JSON>"}`.
/// Response: `{"ok":true,"valid":bool,"issues":[{code,message,line,column,symbol}]}`.
/// Syntax errors are reported as a single issue, so the caller never has to
/// distinguish parse from semantic failures.
pub fn validate_model(request : String) -> String {
  respond(fn() raise Error {
    let req = parse_request(request)
    let source = string_field(req, "model")
    let model = @model.model_from_source(source) catch {
      FgaError(code~, message~, line~, column~) => {
        let issue = @validate.ValidationIssue::{
          code,
          message,
          line,
          column,
          symbol: "",
        }
        return ok_with([
          ("valid", Json::boolean(false)),
          ("issues", issues_array([issue])),
        ])
      }
    }
    let issues = @validate.validate_model(model)
    ok_with([
      ("valid", Json::boolean(issues.length() == 0)),
      ("issues", issues_array(issues)),
    ])
  })
}

///|
/// Request: `{"model": "<DSL or JSON>"}`. Response: `{"ok":true,"output":"<JSON text>"}`.
pub fn dsl_to_json(request : String) -> String {
  respond(fn() raise Error {
    let req = parse_request(request)
    let model = @model.model_from_source(string_field(req, "model"))
    let output = @model.model_to_json_string(model)
    ok_with([("output", Json::string(output))])
  })
}

///|
/// Request: `{"model": "<DSL or JSON>"}`. Response: `{"ok":true,"output":"<DSL text>"}`.
pub fn json_to_dsl(request : String) -> String {
  respond(fn() raise Error {
    let req = parse_request(request)
    let model = @model.model_from_source(string_field(req, "model"))
    ok_with([("output", Json::string(@dsl.to_dsl(model)))])
  })
}

///|
/// Request: `{model, tuples?, object, relation, user, context?, contextual_tuples?, explain?}`.
/// Response: `{"ok":true,"allowed":bool}`; with `explain` it is the engine's
/// `ExplainResult` JSON plus `ok`: `{"ok":true,"allowed","complete","paths":[[step,...],...]}`
/// and, when the decision succeeded but the explanation is incomplete,
/// `complete:false` with `explain_error`. The CLI prints the same model.
pub fn check(request : String) -> String {
  respond(fn() raise Error {
    let req = parse_request(request)
    let engine = build_engine(req)
    let object = string_field(req, "object")
    let relation = string_field(req, "relation")
    let user = string_field(req, "user")
    let context = context_field(req)
    let contextual = tuples_field(req, "contextual_tuples")
    let explain = match req.get("explain") {
      Some(True) => true
      _ => false
    }
    if explain {
      let result = engine.explain_check(
        object, relation, user, context, contextual,
      )
      let response = result.to_json()
      match response {
        Object(fields) => fields["ok"] = Json::boolean(true)
        _ => ()
      }
      response
    } else {
      let allowed = engine.check_with(
        object, relation, user, context, contextual,
      )
      ok_with([("allowed", Json::boolean(allowed))])
    }
  })
}

///|
/// Request: `{model, tuples?, type, relation, user, context?, contextual_tuples?}`.
/// Response: `{"ok":true,"objects":[...]}`.
pub fn list_objects(request : String) -> String {
  respond(fn() raise Error {
    let req = parse_request(request)
    let engine = build_engine(req)
    let objects = engine.list_objects(
      string_field(req, "type"),
      string_field(req, "relation"),
      string_field(req, "user"),
      context_field(req),
      tuples_field(req, "contextual_tuples"),
    )
    ok_with([("objects", strings_json(objects))])
  })
}

///|
/// Request: `{model, tuples?, object, relation, filters?, context?, contextual_tuples?}`;
/// `filters` is an array such as `["user","group#member"]` or a comma-separated
/// string; only when it is absent or `null` does it default to every type.
/// Response: `{"ok":true,"users":[...]}`.
pub fn list_users(request : String) -> String {
  respond(fn() raise Error {
    let req = parse_request(request)
    let engine = build_engine(req)
    let filters : Array[String] = []
    match req.get("filters") {
      None | Some(Null) => {
        let model = load_valid_model(string_field(req, "model"))
        for type_def in model.types {
          filters.push(type_def.name)
        }
      }
      Some(Array(items)) =>
        for item in items {
          match item {
            String(s) => filters.push(s)
            _ => raise bad_request("'filters' must be an array of strings")
          }
        }
      Some(String(text)) => {
        for part in text.split(",") {
          let filter = part.trim().to_owned()
          if filter != "" {
            filters.push(filter)
          }
        }
        if filters.length() == 0 {
          raise bad_request("'filters' has no entries")
        }
      }
      Some(_) =>
        raise bad_request(
          "'filters' must be an array of strings or a comma-separated string",
        )
    }
    let users = engine.list_users(
      string_field(req, "object"),
      string_field(req, "relation"),
      filters,
      context_field(req),
      tuples_field(req, "contextual_tuples"),
    )
    ok_with([("users", strings_json(users))])
  })
}

///|
/// Request: `{"source": "<.fga.yaml text>"}`; the suite must inline its model
/// with `model:` because `model_file` needs a file system.
/// Response: `{"ok":true,"name",tests_total,tests_passed,tests_failed,assertions_*,"failures":[...]}`.
pub fn run_tests(request : String) -> String {
  respond(fn() raise Error {
    let req = parse_request(request)
    let suite = @storetest.load_store_test(string_field(req, "source"), "")
    let report = @storetest.run_store_test(suite)
    let failures : Array[Json] = []
    for item in report.failures {
      failures.push(
        obj([
          ("test", Json::string(item.test_name)),
          ("section", Json::string(item.section)),
          ("request", Json::string(item.request)),
          ("expected", Json::string(item.expected)),
          ("actual", Json::string(item.actual)),
          ("message", Json::string(item.message)),
        ]),
      )
    }
    ok_with([
      ("name", Json::string(report.name)),
      ("tests_total", int_json(report.tests_total)),
      ("tests_passed", int_json(report.tests_passed)),
      ("tests_failed", int_json(report.tests_failed)),
      ("assertions_total", int_json(report.assertions_total)),
      ("assertions_passed", int_json(report.assertions_passed)),
      ("assertions_failed", int_json(report.assertions_failed)),
      ("failures", Json::array(failures)),
    ])
  })
}
