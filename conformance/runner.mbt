// Replays the upstream OpenFGA YAML matrix against the local engine.
//
// Stages are cumulative: tuples written by earlier stages stay in the store
// while each stage replaces the authorization model. Assertions are executed
// independently and classified as pass, fail or skip so unsupported request
// shapes are reported honestly instead of being counted as passes.

///|
fn invalid(message : String) -> @fga.FgaError {
  @fga.fail(@fga.ERR_VALIDATION, message)
}

///|
fn as_object(
  value : Json,
  what : String,
) -> Map[String, Json] raise @fga.FgaError {
  match value {
    Object(m) => m
    _ => raise invalid(what + " must be an object")
  }
}

///|
fn as_string(value : Json, what : String) -> String raise @fga.FgaError {
  match value {
    String(s) => s
    _ => raise invalid(what + " must be a string")
  }
}

///|
fn required(
  obj : Map[String, Json],
  key : String,
  what : String,
) -> Json raise @fga.FgaError {
  match obj.get(key) {
    Some(v) => v
    None => raise invalid(what + " is missing '" + key + "'")
  }
}

///|
fn list_field(obj : Map[String, Json], key : String) -> Array[Json] {
  match obj.get(key) {
    Some(Array(items)) => items
    _ => []
  }
}

///|
pub(all) struct AssertionResult {
  kind : String
  test_name : String
  stage : Int32
  status : String
  category : String
  detail : String
}

///|
fn pass_result(
  kind : String,
  test_name : String,
  stage : Int32,
) -> AssertionResult {
  AssertionResult::{
    kind,
    test_name,
    stage,
    status: "pass",
    category: "",
    detail: "",
  }
}

///|
fn fail_result(
  kind : String,
  test_name : String,
  stage : Int32,
  category : String,
  detail : String,
) -> AssertionResult {
  AssertionResult::{ kind, test_name, stage, status: "fail", category, detail, }
}

///|
fn skip_result(
  kind : String,
  test_name : String,
  stage : Int32,
  category : String,
  detail : String,
) -> AssertionResult {
  AssertionResult::{ kind, test_name, stage, status: "skip", category, detail, }
}

///|
pub(all) struct CategoryReport {
  kind : String
  total : Int32
  passed : Int32
  failed : Int32
  skipped : Int32
  failures : Array[String]
  categories : Array[(String, Int32)]
}

///|
fn aggregate(kind : String, results : Array[AssertionResult]) -> CategoryReport {
  let mut total = 0
  let mut passed = 0
  let mut failed = 0
  let mut skipped = 0
  let failures : Array[String] = []
  let counts : Map[String, Int32] = Map([])
  for r in results {
    if r.kind == kind {
      total += 1
      if r.status == "pass" {
        passed += 1
      } else {
        if r.status == "fail" {
          failed += 1
          failures.push(
            "[" +
            r.kind +
            "] " +
            r.test_name +
            " (stage " +
            r.stage.to_string() +
            "): " +
            r.detail,
          )
        } else {
          skipped += 1
        }
        let key = r.status + "/" + r.category
        let count = match counts.get(key) {
          Some(n) => n
          None => 0
        }
        counts[key] = count + 1
      }
    }
  }
  let categories : Array[(String, Int32)] = []
  for key in counts.keys() {
    match counts.get(key) {
      Some(n) => categories.push((key, n))
      None => ()
    }
  }
  categories.sort_by(fn(a, b) { a.0.lexical_compare(b.0) })
  CategoryReport::{
    kind,
    total,
    passed,
    failed,
    skipped,
    failures,
    categories,
  }
}

///|
pub(all) struct ConformanceReport {
  label : String
  test_count : Int32
  check : CategoryReport
  list_objects : CategoryReport
  list_users : CategoryReport
  results : Array[AssertionResult]
}

///|
fn percentage(passed : Int32, total : Int32) -> String {
  if total == 0 {
    "n/a"
  } else {
    let tenths = passed * 1000 / total
    (tenths / 10).to_string() + "." + (tenths % 10).to_string() + "%"
  }
}

///|
fn format_category(out : StringBuilder, report : CategoryReport) -> Unit {
  out.write_string(
    report.kind +
    ": " +
    report.passed.to_string() +
    "/" +
    report.total.to_string() +
    " passed (" +
    percentage(report.passed, report.total) +
    "), " +
    report.failed.to_string() +
    " failed, " +
    report.skipped.to_string() +
    " skipped\n",
  )
  for pair in report.categories {
    out.write_string("  " + pair.0 + ": " + pair.1.to_string() + "\n")
  }
}

///|
pub fn format_report(report : ConformanceReport) -> String {
  let out = StringBuilder()
  out.write_string("conformance: " + report.label + "\n")
  out.write_string("tests: " + report.test_count.to_string() + "\n")
  format_category(out, report.check)
  format_category(out, report.list_objects)
  format_category(out, report.list_users)
  let failures : Array[String] = []
  for r in report.results {
    if r.status == "fail" {
      failures.push(
        "[" +
        r.kind +
        "] " +
        r.test_name +
        " (stage " +
        r.stage.to_string() +
        "): " +
        r.detail,
      )
    }
  }
  if failures.length() > 0 {
    out.write_string("failures:\n")
    for failure in failures {
      out.write_string("  " + failure + "\n")
    }
  }
  out.to_string()
}

///|
priv enum ModelLoad {
  ModelOk(@fga.AuthModel)
  ModelFailed(String)
}

///|
fn load_model(source : String) -> ModelLoad {
  try {
    if source.trim().has_prefix("{") {
      ModelOk(@model.json_to_model(source))
    } else {
      ModelOk(@dsl.parse_model(source))
    }
  } catch {
    @fga.FgaError(..) as err => ModelFailed(@fga.format_error(err))
  }
}

///|
fn parse_tuple_context(
  value : Json,
) -> Map[String, @fga.CelValue] raise @fga.FgaError {
  match value {
    Null => Map([])
    Object(fields) => {
      let out : Map[String, @fga.CelValue] = Map([])
      for key in fields.keys() {
        match fields.get(key) {
          Some(field) => out[key] = @fga.json_to_cel_value_raw(field)
          None => ()
        }
      }
      out
    }
    _ => raise invalid("tuple condition context must be an object")
  }
}

///|
fn parse_tuple(value : Json) -> @fga.Tuple raise @fga.FgaError {
  let obj = as_object(value, "tuple")
  let condition = match obj.get("condition") {
    None | Some(Null) => None
    Some(condition_value) => {
      let c = as_object(condition_value, "tuple condition")
      let name = as_string(
        required(c, "name", "tuple condition"),
        "tuple condition name",
      )
      let context = match c.get("context") {
        None | Some(Null) => Map([])
        Some(ctx) => parse_tuple_context(ctx)
      }
      Some(@fga.TupleCondition::{ name, context, })
    }
  }
  @fga.Tuple::{
    object: as_string(required(obj, "object", "tuple"), "tuple object"),
    relation: as_string(required(obj, "relation", "tuple"), "tuple relation"),
    user: as_string(required(obj, "user", "tuple"), "tuple user"),
    condition,
  }
}

///|
fn parse_tuples(value : Json?) -> Array[@fga.Tuple] raise @fga.FgaError {
  match value {
    None | Some(Null) => []
    Some(Array(items)) => {
      let out : Array[@fga.Tuple] = []
      for item in items {
        out.push(parse_tuple(item))
      }
      out
    }
    Some(_) => raise invalid("tuples must be an array")
  }
}

///|
fn parse_context(value : Json?) -> Map[String, Json] raise @fga.FgaError {
  match value {
    None | Some(Null) => Map([])
    Some(Object(fields)) => fields
    Some(_) => raise invalid("context must be an object")
  }
}

///|
fn context_from(
  obj : Map[String, Json],
  request : Map[String, Json],
) -> Map[String, Json] raise @fga.FgaError {
  match obj.get("context") {
    Some(value) => parse_context(Some(value))
    None => parse_context(request.get("context"))
  }
}

///|
fn contextual_from(
  obj : Map[String, Json],
  request : Map[String, Json],
) -> Array[@fga.Tuple] raise @fga.FgaError {
  match obj.get("contextualTuples") {
    Some(value) => parse_tuples(Some(value))
    None => parse_tuples(request.get("contextualTuples"))
  }
}

///|
fn expected_error_code(obj : Map[String, Json]) -> Int32? raise @fga.FgaError {
  match obj.get("errorCode") {
    None | Some(Null) => None
    Some(Number(value, ..)) => Some(value.to_int())
    Some(_) => raise invalid("errorCode must be a number")
  }
}

///|
fn expected_bool(obj : Map[String, Json]) -> Bool? raise @fga.FgaError {
  match obj.get("expectation") {
    None | Some(Null) => None
    Some(True) => Some(true)
    Some(False) => Some(false)
    Some(_) => raise invalid("expectation must be a boolean")
  }
}

///|
fn expected_strings(value : Json) -> Array[String] raise @fga.FgaError {
  match value {
    String(s) => [s]
    Array(items) => {
      let out : Array[String] = []
      for item in items {
        out.push(as_string(item, "list expectation entry"))
      }
      out
    }
    _ => raise invalid("expectation must be a string array")
  }
}

///|
fn sorted_strings(values : Array[String]) -> Array[String] {
  let out = values.copy()
  out.sort_by(fn(a, b) { a.lexical_compare(b) })
  out
}

///|
fn same_strings(a : Array[String], b : Array[String]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
fn show_strings(values : Array[String]) -> String {
  let out = StringBuilder()
  out.write_string("[")
  for i in 0..<values.length() {
    if i > 0 {
      out.write_string(", ")
    }
    out.write_string(values[i])
  }
  out.write_string("]")
  out.to_string()
}

///|
priv enum EvalBool {
  EvalAllowed(Bool)
  EvalBoolError(Int32, String)
}

///|
fn eval_check(
  engine : @engine.Engine,
  object : String,
  relation : String,
  user : String,
  context : Map[String, Json],
  contextual : Array[@fga.Tuple],
) -> EvalBool {
  EvalAllowed(engine.check_with(object, relation, user, context, contextual)) catch {
    @fga.FgaError(..) as err =>
      EvalBoolError(@fga.error_code(err), @fga.error_message(err))
  }
}

///|
priv enum EvalList {
  EvalValues(Array[String])
  EvalListError(Int32, String)
}

///|
fn eval_list_objects(
  engine : @engine.Engine,
  type_name : String,
  relation : String,
  user : String,
  context : Map[String, Json],
  contextual : Array[@fga.Tuple],
) -> EvalList {
  EvalValues(
    engine.list_objects(type_name, relation, user, context, contextual),
  ) catch {
    @fga.FgaError(..) as err =>
      EvalListError(@fga.error_code(err), @fga.error_message(err))
  }
}

///|
fn eval_list_users(
  engine : @engine.Engine,
  object : String,
  relation : String,
  filters : Array[String],
  context : Map[String, Json],
  contextual : Array[@fga.Tuple],
) -> EvalList {
  EvalValues(engine.list_users(object, relation, filters, context, contextual)) catch {
    @fga.FgaError(..) as err =>
      EvalListError(@fga.error_code(err), @fga.error_message(err))
  }
}

///|
fn run_check_assertion(
  engine : @engine.Engine,
  value : Json,
  test_name : String,
  stage : Int32,
) -> AssertionResult {
  let kind = "check"
  try {
    let obj = as_object(value, "check assertion")
    let tuple = as_object(
      required(obj, "tuple", "check assertion"),
      "check tuple",
    )
    let object = as_string(
      required(tuple, "object", "check tuple"),
      "check object",
    )
    let relation = as_string(
      required(tuple, "relation", "check tuple"),
      "check relation",
    )
    let user = as_string(required(tuple, "user", "check tuple"), "check user")
    let context = parse_context(obj.get("context"))
    let contextual = parse_tuples(obj.get("contextualTuples"))
    let wanted_error = expected_error_code(obj)
    let wanted = expected_bool(obj)
    match wanted_error {
      Some(code) =>
        match eval_check(engine, object, relation, user, context, contextual) {
          EvalAllowed(_) =>
            fail_result(
              kind,
              test_name,
              stage,
              "missing_error",
              "expected E" + code.to_string() + ", got a boolean result",
            )
          EvalBoolError(got, message) =>
            if got.to_string() == code.to_string() {
              pass_result(kind, test_name, stage)
            } else {
              fail_result(
                kind,
                test_name,
                stage,
                "wrong_error_code",
                "expected E" +
                code.to_string() +
                ", got E" +
                got.to_string() +
                ": " +
                message,
              )
            }
        }
      None =>
        match wanted {
          None =>
            skip_result(
              kind, test_name, stage, "no_expectation", "assertion has neither expectation nor errorCode",
            )
          Some(expected) =>
            match
              eval_check(engine, object, relation, user, context, contextual) {
              EvalAllowed(got) =>
                if got == expected {
                  pass_result(kind, test_name, stage)
                } else {
                  fail_result(
                    kind,
                    test_name,
                    stage,
                    "wrong_result",
                    "expected " +
                    expected.to_string() +
                    ", got " +
                    got.to_string() +
                    " for " +
                    object +
                    "#" +
                    relation +
                    "@" +
                    user,
                  )
                }
              EvalBoolError(got, message) =>
                fail_result(
                  kind,
                  test_name,
                  stage,
                  "unexpected_error",
                  "expected " +
                  expected.to_string() +
                  ", got E" +
                  got.to_string() +
                  ": " +
                  message,
                )
            }
        }
    }
  } catch {
    @fga.FgaError(..) as err =>
      skip_result(
        kind,
        test_name,
        stage,
        "malformed_assertion",
        @fga.format_error(err),
      )
  }
}

///|
fn run_list_objects_assertion(
  engine : @engine.Engine,
  value : Json,
  test_name : String,
  stage : Int32,
) -> AssertionResult {
  let kind = "list_objects"
  try {
    let obj = as_object(value, "list objects assertion")
    let request = as_object(
      required(obj, "request", "list objects assertion"),
      "list objects request",
    )
    let user = as_string(
      required(request, "user", "list objects request"),
      "list objects user",
    )
    let type_name = as_string(
      required(request, "type", "list objects request"),
      "list objects type",
    )
    let relation = as_string(
      required(request, "relation", "list objects request"),
      "list objects relation",
    )
    let context = context_from(obj, request)
    let contextual = contextual_from(obj, request)
    let wanted_error = expected_error_code(obj)
    let wanted = match obj.get("expectation") {
      None => None
      // `expectation:` with no value is an empty result in the upstream YAML.
      Some(Null) => Some([])
      Some(expectation) => Some(expected_strings(expectation))
    }
    match wanted_error {
      Some(code) =>
        match
          eval_list_objects(
            engine, type_name, relation, user, context, contextual,
          ) {
          EvalValues(_) =>
            fail_result(
              kind,
              test_name,
              stage,
              "missing_error",
              "expected E" + code.to_string() + ", got an object list",
            )
          EvalListError(got, message) =>
            if got.to_string() == code.to_string() {
              pass_result(kind, test_name, stage)
            } else {
              fail_result(
                kind,
                test_name,
                stage,
                "wrong_error_code",
                "expected E" +
                code.to_string() +
                ", got E" +
                got.to_string() +
                ": " +
                message,
              )
            }
        }
      None =>
        match wanted {
          None =>
            skip_result(
              kind, test_name, stage, "no_expectation", "assertion has neither expectation nor errorCode",
            )
          Some(expected) =>
            match
              eval_list_objects(
                engine, type_name, relation, user, context, contextual,
              ) {
              EvalValues(values) =>
                if same_strings(
                    sorted_strings(values),
                    sorted_strings(expected),
                  ) {
                  pass_result(kind, test_name, stage)
                } else {
                  fail_result(
                    kind,
                    test_name,
                    stage,
                    "wrong_result",
                    "expected " +
                    show_strings(expected) +
                    ", got " +
                    show_strings(values),
                  )
                }
              EvalListError(got, message) =>
                fail_result(
                  kind,
                  test_name,
                  stage,
                  "unexpected_error",
                  "expected " +
                  show_strings(expected) +
                  ", got E" +
                  got.to_string() +
                  ": " +
                  message,
                )
            }
        }
    }
  } catch {
    @fga.FgaError(..) as err =>
      skip_result(
        kind,
        test_name,
        stage,
        "malformed_assertion",
        @fga.format_error(err),
      )
  }
}

///|
fn parse_filters(
  request : Map[String, Json],
) -> Array[String] raise @fga.FgaError {
  match request.get("filters") {
    Some(Array(items)) => {
      let out : Array[String] = []
      for item in items {
        match item {
          String(s) => out.push(s)
          Object(fields) => {
            let type_name = as_string(
              required(fields, "type", "user filter"),
              "user filter type",
            )
            match fields.get("relation") {
              Some(String(relation)) => out.push(type_name + "#" + relation)
              _ => out.push(type_name)
            }
          }
          _ => raise invalid("user filter must be a string or an object")
        }
      }
      out
    }
    Some(_) => raise invalid("list users request needs a 'filters' array")
    None => raise invalid("list users request needs a 'filters' array")
  }
}

///|
fn run_list_users_assertion(
  engine : @engine.Engine,
  value : Json,
  test_name : String,
  stage : Int32,
) -> AssertionResult {
  let kind = "list_users"
  try {
    let obj = as_object(value, "list users assertion")
    let request = as_object(
      required(obj, "request", "list users assertion"),
      "list users request",
    )
    let object = as_string(
      required(request, "object", "list users request"),
      "list users object",
    )
    let relation = as_string(
      required(request, "relation", "list users request"),
      "list users relation",
    )
    let filters = parse_filters(request)
    let context = context_from(obj, request)
    let contextual = contextual_from(obj, request)
    let wanted_error = expected_error_code(obj)
    let wanted = match obj.get("expectation") {
      None => None
      // `expectation:` with no value is an empty result in the upstream YAML.
      Some(Null) => Some([])
      Some(expectation) => Some(expected_strings(expectation))
    }
    match wanted_error {
      Some(code) =>
        match
          eval_list_users(
            engine, object, relation, filters, context, contextual,
          ) {
          EvalValues(_) =>
            fail_result(
              kind,
              test_name,
              stage,
              "missing_error",
              "expected E" + code.to_string() + ", got a user list",
            )
          EvalListError(got, message) =>
            if got.to_string() == code.to_string() {
              pass_result(kind, test_name, stage)
            } else {
              fail_result(
                kind,
                test_name,
                stage,
                "wrong_error_code",
                "expected E" +
                code.to_string() +
                ", got E" +
                got.to_string() +
                ": " +
                message,
              )
            }
        }
      None =>
        match wanted {
          None =>
            skip_result(
              kind, test_name, stage, "no_expectation", "assertion has neither expectation nor errorCode",
            )
          Some(expected) =>
            match
              eval_list_users(
                engine, object, relation, filters, context, contextual,
              ) {
              EvalValues(values) =>
                if same_strings(
                    sorted_strings(values),
                    sorted_strings(expected),
                  ) {
                  pass_result(kind, test_name, stage)
                } else {
                  fail_result(
                    kind,
                    test_name,
                    stage,
                    "wrong_result",
                    "expected " +
                    show_strings(expected) +
                    ", got " +
                    show_strings(values) +
                    " for " +
                    object +
                    "#" +
                    relation,
                  )
                }
              EvalListError(got, message) =>
                fail_result(
                  kind,
                  test_name,
                  stage,
                  "unexpected_error",
                  "expected " +
                  show_strings(expected) +
                  ", got E" +
                  got.to_string() +
                  ": " +
                  message,
                )
            }
        }
    }
  } catch {
    @fga.FgaError(..) as err =>
      skip_result(
        kind,
        test_name,
        stage,
        "malformed_assertion",
        @fga.format_error(err),
      )
  }
}

///|
fn skip_stage_assertions(
  results : Array[AssertionResult],
  stage : Map[String, Json],
  test_name : String,
  stage_index : Int32,
  category : String,
  message : String,
) -> Unit {
  for _ in list_field(stage, "checkAssertions") {
    results.push(
      skip_result("check", test_name, stage_index, category, message),
    )
  }
  for _ in list_field(stage, "listObjectsAssertions") {
    results.push(
      skip_result("list_objects", test_name, stage_index, category, message),
    )
  }
  for _ in list_field(stage, "listUsersAssertions") {
    results.push(
      skip_result("list_users", test_name, stage_index, category, message),
    )
  }
}

///|
pub fn run_conformance_source(
  source : String,
  label : String,
) -> ConformanceReport raise @fga.FgaError {
  let documents = @yaml.Yaml::load_from_string(source) catch {
    _ => raise invalid("cannot parse " + label + " as YAML")
  }
  if documents.length() == 0 {
    raise invalid(label + " contains no YAML document")
  }
  let root = as_object(documents[0].to_json(), label)
  let tests = match root.get("tests") {
    Some(Array(items)) => items
    _ => raise invalid(label + " has no 'tests' array")
  }
  let results : Array[AssertionResult] = []
  let mut test_count = 0
  for test_value in tests {
    test_count += 1
    let test_obj = as_object(test_value, "test")
    let test_name = match test_obj.get("name") {
      Some(String(name)) => name
      _ => "test-" + test_count.to_string()
    }
    let stages = match test_obj.get("stages") {
      Some(Array(items)) => items
      _ => []
    }
    let store = @store.MemoryStore::new()
    let mut stage_index = 0
    for stage_value in stages {
      let stage = as_object(stage_value, "stage")
      let loaded : Array[@fga.Tuple] = parse_tuples(stage.get("tuples")) catch {
        @fga.FgaError(..) as err => {
          skip_stage_assertions(
            results,
            stage,
            test_name,
            stage_index,
            "tuple_parse",
            @fga.format_error(err),
          )
          stage_index += 1
          continue
        }
      }
      let _ = store.write_all(loaded)
      let model_source = match stage.get("model") {
        Some(String(source)) => Some(source)
        _ => None
      }
      let model_load = match model_source {
        Some(source) => load_model(source)
        None => ModelFailed("stage has no model")
      }
      match model_load {
        ModelFailed(message) =>
          skip_stage_assertions(
            results, stage, test_name, stage_index, "model_parse", message,
          )
        ModelOk(model) => {
          let engine = @engine.Engine::new(model, store as &@fga.TupleReader)
          for assertion in list_field(stage, "checkAssertions") {
            results.push(
              run_check_assertion(engine, assertion, test_name, stage_index),
            )
          }
          for assertion in list_field(stage, "listObjectsAssertions") {
            results.push(
              run_list_objects_assertion(
                engine, assertion, test_name, stage_index,
              ),
            )
          }
          for assertion in list_field(stage, "listUsersAssertions") {
            results.push(
              run_list_users_assertion(
                engine, assertion, test_name, stage_index,
              ),
            )
          }
        }
      }
      stage_index += 1
    }
  }
  ConformanceReport::{
    label,
    test_count,
    check: aggregate("check", results),
    list_objects: aggregate("list_objects", results),
    list_users: aggregate("list_users", results),
    results,
  }
}

///|
pub fn run_conformance_file(
  path : String,
) -> ConformanceReport raise @fga.FgaError {
  let source = @fs.read_file_to_string(path) catch {
    _ => raise invalid("cannot read " + path)
  }
  run_conformance_source(source, path)
}
