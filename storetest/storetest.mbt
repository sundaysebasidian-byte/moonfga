// Runs OpenFGA `.fga.yaml` store tests: model, tuples and assertions.

///|
fn store_test_error(message : String) -> @fga.FgaError {
  @fga.fail(@fga.ERR_VALIDATION, message)
}

///|
fn object_of(
  value : Json,
  what : String,
) -> Map[String, Json] raise @fga.FgaError {
  match value {
    Object(m) => m
    _ => raise store_test_error(what + " must be an object")
  }
}

///|
fn string_of_field(
  obj : Map[String, Json],
  key : String,
  what : String,
) -> String raise @fga.FgaError {
  match obj.get(key) {
    Some(String(s)) => s
    _ => raise store_test_error(what + " is missing string field '" + key + "'")
  }
}

///|
fn optional_string_field(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
fn context_of(obj : Map[String, Json]) -> Map[String, Json] raise @fga.FgaError {
  match obj.get("context") {
    None | Some(Null) => Map([])
    Some(Object(m)) => m
    Some(_) => raise store_test_error("context must be an object")
  }
}

///|
fn tuples_of(
  obj : Map[String, Json],
  key : String,
) -> Array[@fga.Tuple] raise @fga.FgaError {
  let value = match obj.get(key) {
    Some(v) => Some(v)
    None =>
      match obj.get("contextual_tuples") {
        Some(v) => Some(v)
        None => None
      }
  }
  @fga.tuples_from_json(value)
}

///|
fn assertions_of(
  obj : Map[String, Json],
  what : String,
) -> Array[(String, Json)] raise @fga.FgaError {
  match obj.get("assertions") {
    None | Some(Null) => []
    Some(Object(m)) => {
      let out : Array[(String, Json)] = []
      m.each(fn(key, value) { out.push((key, value)) })
      out
    }
    Some(_) => raise store_test_error(what + " assertions must be an object")
  }
}

///|
fn array_field(
  obj : Map[String, Json],
  what : String,
) -> Array[Json] raise @fga.FgaError {
  match obj.get(what) {
    None | Some(Null) => []
    Some(Array(items)) => items
    Some(_) => raise store_test_error(what + " must be an array")
  }
}

///|
fn filter_text(value : Json) -> String raise @fga.FgaError {
  match value {
    String(s) => s
    Object(m) => {
      let type_name = match m.get("type") {
        Some(String(s)) => s
        _ => raise store_test_error("user filter is missing 'type'")
      }
      match m.get("relation") {
        Some(String(relation)) => type_name + "#" + relation
        _ => type_name
      }
    }
    _ => raise store_test_error("user filter must be a string or object")
  }
}

///|
fn filters_of(obj : Map[String, Json]) -> Array[String] raise @fga.FgaError {
  let raw = match obj.get("user_filter") {
    Some(v) => Some(v)
    None =>
      match obj.get("user_filters") {
        Some(v) => Some(v)
        None => obj.get("filters")
      }
  }
  match raw {
    None | Some(Null) => []
    Some(Array(items)) => {
      let out : Array[String] = []
      for item in items {
        out.push(filter_text(item))
      }
      out
    }
    Some(_) => raise store_test_error("user filters must be an array")
  }
}

///|
fn default_filters(model : @fga.AuthModel) -> Array[String] {
  let out : Array[String] = []
  for type_def in model.types {
    out.push(type_def.name)
  }
  out
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
fn join_path(base : String, relative : String) -> String {
  if relative.has_prefix("/") {
    return relative
  }
  if base == "" || base.has_suffix("/") || base.has_suffix("\\") {
    base + relative
  } else {
    base + "/" + relative
  }
}

///|
fn read_text(path : String) -> String raise @fga.FgaError {
  @fs.read_file_to_string(path) catch {
    _ => raise store_test_error("cannot read file: " + path)
  }
}

///|
pub(all) struct CheckCase {
  user : String
  object : String
  context : Map[String, Json]
  contextual : Array[@fga.Tuple]
  assertions : Array[(String, Json)]
}

///|
pub(all) struct ListObjectsCase {
  user : String
  object_type : String
  context : Map[String, Json]
  contextual : Array[@fga.Tuple]
  assertions : Array[(String, Json)]
}

///|
pub(all) struct ListUsersCase {
  object : String
  filters : Array[String]
  context : Map[String, Json]
  contextual : Array[@fga.Tuple]
  assertions : Array[(String, Json)]
}

///|
pub(all) struct StoreTest {
  name : String
  tuples : Array[@fga.Tuple]
  checks : Array[CheckCase]
  list_objects : Array[ListObjectsCase]
  list_users : Array[ListUsersCase]
}

///|
pub(all) struct StoreTestSuite {
  name : String
  model : @fga.AuthModel
  tuples : Array[@fga.Tuple]
  tests : Array[StoreTest]
}

///|
pub(all) struct StoreTestFailure {
  test_name : String
  section : String
  request : String
  expected : String
  actual : String
  message : String
}

///|
pub(all) struct StoreTestReport {
  name : String
  tests_total : Int32
  tests_passed : Int32
  tests_failed : Int32
  assertions_total : Int32
  assertions_passed : Int32
  assertions_failed : Int32
  failures : Array[StoreTestFailure]
}

///|
fn parse_check_case(value : Json) -> CheckCase raise @fga.FgaError {
  let obj = object_of(value, "check request")
  let contextual = tuples_of(obj, "contextualTuples")
  CheckCase::{
    user: string_of_field(obj, "user", "check request"),
    object: string_of_field(obj, "object", "check request"),
    context: context_of(obj),
    contextual,
    assertions: assertions_of(obj, "check"),
  }
}

///|
fn parse_list_objects_case(value : Json) -> ListObjectsCase raise @fga.FgaError {
  let obj = object_of(value, "listObjects request")
  let contextual = tuples_of(obj, "contextualTuples")
  ListObjectsCase::{
    user: string_of_field(obj, "user", "listObjects request"),
    object_type: string_of_field(obj, "type", "listObjects request"),
    context: context_of(obj),
    contextual,
    assertions: assertions_of(obj, "listObjects"),
  }
}

///|
fn parse_list_users_case(
  value : Json,
  model : @fga.AuthModel,
) -> ListUsersCase raise @fga.FgaError {
  let obj = object_of(value, "listUsers request")
  let contextual = tuples_of(obj, "contextualTuples")
  let filters = filters_of(obj)
  ListUsersCase::{
    object: string_of_field(obj, "object", "listUsers request"),
    filters: if filters.length() == 0 {
      default_filters(model)
    } else {
      filters
    },
    context: context_of(obj),
    contextual,
    assertions: assertions_of(obj, "listUsers"),
  }
}

///|
fn parse_tests(
  value : Json,
  model : @fga.AuthModel,
) -> StoreTest raise @fga.FgaError {
  let obj = object_of(value, "test")
  let name = match optional_string_field(obj, "name") {
    Some(name) => name
    None => "unnamed"
  }
  let checks : Array[CheckCase] = []
  for item in array_field(obj, "check") {
    checks.push(parse_check_case(item))
  }
  let list_objects : Array[ListObjectsCase] = []
  for item in array_field(obj, "listObjects") {
    list_objects.push(parse_list_objects_case(item))
  }
  let list_users : Array[ListUsersCase] = []
  for item in array_field(obj, "listUsers") {
    list_users.push(parse_list_users_case(item, model))
  }
  StoreTest::{
    name,
    tuples: tuples_of(obj, "tuples"),
    checks,
    list_objects,
    list_users,
  }
}

///|
/// Loads a `.fga.yaml` suite. `base_dir` is used to resolve `model_file`.
pub fn load_store_test(
  source : String,
  base_dir : String,
) -> StoreTestSuite raise @fga.FgaError {
  let documents = @yaml.Yaml::load_from_string(source) catch {
    _ => raise store_test_error("invalid YAML in store test")
  }
  if documents.length() == 0 {
    raise store_test_error("empty store test file")
  }
  let root = object_of(documents[0].to_json(), "store test")
  let model_source = match root.get("model") {
    Some(String(source)) => source
    Some(_) => raise store_test_error("model must be a string")
    None =>
      match optional_string_field(root, "model_file") {
        Some(file) => read_text(join_path(base_dir, file))
        None =>
          raise store_test_error("store test requires model or model_file")
      }
  }
  let model = @model.model_from_source(model_source)
  let tests_json = array_field(root, "tests")
  let tests : Array[StoreTest] = []
  for item in tests_json {
    tests.push(parse_tests(item, model))
  }
  StoreTestSuite::{
    name: match optional_string_field(root, "name") {
      Some(name) => name
      None => "store test"
    },
    model,
    tuples: tuples_of(root, "tuples"),
    tests,
  }
}

///|
pub fn load_store_test_file(
  path : String,
) -> StoreTestSuite raise @fga.FgaError {
  let source = read_text(path)
  load_store_test(source, dirname(path))
}

///|
priv enum ExpectedResult {
  ExpectedBool(Bool)
  ExpectedList(Array[String])
  ExpectedError(Int32)
  ExpectedMalformed(String)
}

///|
fn expected_result(value : Json) -> ExpectedResult {
  match value {
    True => ExpectedBool(true)
    False => ExpectedBool(false)
    Array(items) => {
      let out : Array[String] = []
      for item in items {
        match item {
          String(s) => out.push(s)
          Object(m) =>
            match m.get("object") {
              Some(String(s)) => out.push(s)
              _ =>
                match m.get("user") {
                  Some(String(s)) => out.push(s)
                  _ => out.push(item.stringify())
                }
            }
          _ => out.push(item.stringify())
        }
      }
      ExpectedList(out)
    }
    Object(m) =>
      match m.get("errorCode") {
        Some(Number(code, ..)) => ExpectedError(code.to_int())
        _ =>
          match m.get("error_code") {
            Some(Number(code, ..)) => ExpectedError(code.to_int())
            _ =>
              ExpectedMalformed("assertion must be a bool, list or errorCode")
          }
      }
    _ => ExpectedMalformed("assertion must be a bool, list or errorCode")
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
fn failure(
  test_name : String,
  section : String,
  request : String,
  expected : String,
  actual : String,
  message : String,
) -> StoreTestFailure {
  StoreTestFailure::{ test_name, section, request, expected, actual, message, }
}

///|
fn run_check(
  engine : @engine.Engine,
  test_name : String,
  relation : String,
  request : CheckCase,
  expected : Json,
  failures : Array[StoreTestFailure],
) -> Unit {
  let label = "object=" +
    request.object +
    " relation=" +
    relation +
    " user=" +
    request.user
  match expected_result(expected) {
    ExpectedBool(want) => {
      let actual = Some(
        engine.check_with(
          request.object,
          relation,
          request.user,
          request.context,
          request.contextual,
        ),
      ) catch {
        @fga.FgaError(..) as err => {
          failures.push(
            failure(
              test_name,
              "check",
              label,
              want.to_string(),
              "error " + @fga.error_code(err).to_string(),
              @fga.error_message(err),
            ),
          )
          None
        }
      }
      match actual {
        Some(got) =>
          if got != want {
            failures.push(
              failure(
                test_name,
                "check",
                label,
                want.to_string(),
                got.to_string(),
                "check result mismatch",
              ),
            )
          }
        None => ()
      }
    }
    ExpectedError(code) =>
      try {
        let got = engine.check_with(
          request.object,
          relation,
          request.user,
          request.context,
          request.contextual,
        )
        failures.push(
          failure(
            test_name,
            "check",
            label,
            "error " + code.to_string(),
            got.to_string(),
            "expected an error",
          ),
        )
      } catch {
        @fga.FgaError(..) as err =>
          if @fga.error_code(err) != code {
            failures.push(
              failure(
                test_name,
                "check",
                label,
                "error " + code.to_string(),
                "error " + @fga.error_code(err).to_string(),
                @fga.error_message(err),
              ),
            )
          }
      }
    ExpectedList(_) =>
      failures.push(
        failure(
          test_name,
          "check",
          label,
          "bool or errorCode",
          expected.stringify(),
          "check assertions cannot be lists",
        ),
      )
    ExpectedMalformed(message) =>
      failures.push(
        failure(
          test_name,
          "check",
          label,
          "bool or errorCode",
          expected.stringify(),
          message,
        ),
      )
  }
}

///|
fn run_list_objects(
  engine : @engine.Engine,
  test_name : String,
  relation : String,
  request : ListObjectsCase,
  expected : Json,
  failures : Array[StoreTestFailure],
) -> Unit {
  let label = "type=" +
    request.object_type +
    " relation=" +
    relation +
    " user=" +
    request.user
  match expected_result(expected) {
    ExpectedList(want) => {
      let actual = Some(
        engine.list_objects(
          request.object_type,
          relation,
          request.user,
          request.context,
          request.contextual,
        ),
      ) catch {
        @fga.FgaError(..) as err => {
          failures.push(
            failure(
              test_name,
              "list_objects",
              label,
              show_strings(sorted_strings(want)),
              "error " + @fga.error_code(err).to_string(),
              @fga.error_message(err),
            ),
          )
          None
        }
      }
      match actual {
        Some(got) =>
          if !same_strings(sorted_strings(want), sorted_strings(got)) {
            failures.push(
              failure(
                test_name,
                "list_objects",
                label,
                show_strings(sorted_strings(want)),
                show_strings(sorted_strings(got)),
                "listObjects result mismatch",
              ),
            )
          }
        None => ()
      }
    }
    ExpectedError(code) =>
      try {
        let got = engine.list_objects(
          request.object_type,
          relation,
          request.user,
          request.context,
          request.contextual,
        )
        failures.push(
          failure(
            test_name,
            "list_objects",
            label,
            "error " + code.to_string(),
            show_strings(sorted_strings(got)),
            "expected an error",
          ),
        )
      } catch {
        @fga.FgaError(..) as err =>
          if @fga.error_code(err) != code {
            failures.push(
              failure(
                test_name,
                "list_objects",
                label,
                "error " + code.to_string(),
                "error " + @fga.error_code(err).to_string(),
                @fga.error_message(err),
              ),
            )
          }
      }
    ExpectedBool(_) =>
      failures.push(
        failure(
          test_name,
          "list_objects",
          label,
          "list or errorCode",
          expected.stringify(),
          "listObjects assertions cannot be booleans",
        ),
      )
    ExpectedMalformed(message) =>
      failures.push(
        failure(
          test_name,
          "list_objects",
          label,
          "list or errorCode",
          expected.stringify(),
          message,
        ),
      )
  }
}

///|
fn run_list_users(
  engine : @engine.Engine,
  test_name : String,
  relation : String,
  request : ListUsersCase,
  expected : Json,
  failures : Array[StoreTestFailure],
) -> Unit {
  let label = "object=" +
    request.object +
    " relation=" +
    relation +
    " filters=" +
    show_strings(request.filters)
  match expected_result(expected) {
    ExpectedList(want) => {
      let actual = Some(
        engine.list_users(
          request.object,
          relation,
          request.filters,
          request.context,
          request.contextual,
        ),
      ) catch {
        @fga.FgaError(..) as err => {
          failures.push(
            failure(
              test_name,
              "list_users",
              label,
              show_strings(sorted_strings(want)),
              "error " + @fga.error_code(err).to_string(),
              @fga.error_message(err),
            ),
          )
          None
        }
      }
      match actual {
        Some(got) =>
          if !same_strings(sorted_strings(want), sorted_strings(got)) {
            failures.push(
              failure(
                test_name,
                "list_users",
                label,
                show_strings(sorted_strings(want)),
                show_strings(sorted_strings(got)),
                "listUsers result mismatch",
              ),
            )
          }
        None => ()
      }
    }
    ExpectedError(code) =>
      try {
        let got = engine.list_users(
          request.object,
          relation,
          request.filters,
          request.context,
          request.contextual,
        )
        failures.push(
          failure(
            test_name,
            "list_users",
            label,
            "error " + code.to_string(),
            show_strings(sorted_strings(got)),
            "expected an error",
          ),
        )
      } catch {
        @fga.FgaError(..) as err =>
          if @fga.error_code(err) != code {
            failures.push(
              failure(
                test_name,
                "list_users",
                label,
                "error " + code.to_string(),
                "error " + @fga.error_code(err).to_string(),
                @fga.error_message(err),
              ),
            )
          }
      }
    ExpectedBool(_) =>
      failures.push(
        failure(
          test_name,
          "list_users",
          label,
          "list or errorCode",
          expected.stringify(),
          "listUsers assertions cannot be booleans",
        ),
      )
    ExpectedMalformed(message) =>
      failures.push(
        failure(
          test_name,
          "list_users",
          label,
          "list or errorCode",
          expected.stringify(),
          message,
        ),
      )
  }
}

///|
/// Evaluates every test against a fresh in-memory store seeded with the
/// suite-wide tuples.
pub fn run_store_test(suite : StoreTestSuite) -> StoreTestReport {
  let failures : Array[StoreTestFailure] = []
  let mut assertions_total = 0
  let mut tests_passed = 0
  for test_case in suite.tests {
    let before = failures.length()
    let store = @store.MemoryStore::new()
    let _ = store.write_all(suite.tuples)
    let _ = store.write_all(test_case.tuples)
    let engine = @engine.Engine::new(suite.model, store as &@fga.TupleReader)
    for case in test_case.checks {
      for (relation, expected) in case.assertions {
        assertions_total = assertions_total + 1
        run_check(engine, test_case.name, relation, case, expected, failures)
      }
    }
    for case in test_case.list_objects {
      for (relation, expected) in case.assertions {
        assertions_total = assertions_total + 1
        run_list_objects(
          engine,
          test_case.name,
          relation,
          case,
          expected,
          failures,
        )
      }
    }
    for case in test_case.list_users {
      for (relation, expected) in case.assertions {
        assertions_total = assertions_total + 1
        run_list_users(
          engine,
          test_case.name,
          relation,
          case,
          expected,
          failures,
        )
      }
    }
    if failures.length() == before {
      tests_passed = tests_passed + 1
    }
  }
  let assertions_failed = failures.length()
  StoreTestReport::{
    name: suite.name,
    tests_total: suite.tests.length(),
    tests_passed,
    tests_failed: suite.tests.length() - tests_passed,
    assertions_total,
    assertions_passed: assertions_total - assertions_failed,
    assertions_failed,
    failures,
  }
}

///|
pub fn run_store_test_file(
  path : String,
) -> StoreTestReport raise @fga.FgaError {
  let suite = load_store_test_file(path)
  run_store_test(suite)
}

///|
pub fn format_store_test_report(report : StoreTestReport) -> String {
  let out = StringBuilder()
  out.write_string("store test: " + report.name + "\n")
  out.write_string(
    "tests: " +
    report.tests_passed.to_string() +
    "/" +
    report.tests_total.to_string() +
    " passed\n",
  )
  out.write_string(
    "assertions: " +
    report.assertions_passed.to_string() +
    "/" +
    report.assertions_total.to_string() +
    " passed\n",
  )
  if report.failures.length() > 0 {
    out.write_string("failures:\n")
    for item in report.failures {
      out.write_string(
        "  FAIL [" +
        item.test_name +
        "] " +
        item.section +
        " " +
        item.request +
        "\n",
      )
      out.write_string("    expected: " + item.expected + "\n")
      out.write_string("    actual:   " + item.actual + "\n")
      if item.message != "" {
        out.write_string("    message:  " + item.message + "\n")
      }
    }
  }
  out.to_string()
}
