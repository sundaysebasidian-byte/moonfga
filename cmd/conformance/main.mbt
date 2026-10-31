// Runs the upstream OpenFGA conformance matrix and prints a summary.
//
// Usage: moon run cmd/conformance -- [--json] [<file.yaml> ...]
// With no file arguments both pinned upstream files are used.

///|
fn default_paths() -> Array[String] {
  [
    ".upstream/openfga/consolidated_1_1_tests.yaml", ".upstream/openfga/abac_tests.yaml",
  ]
}

///|
fn totals_json(
  check : @conf.CategoryReport,
  list_objects : @conf.CategoryReport,
  list_users : @conf.CategoryReport,
) -> Json {
  let fields : Map[String, Json] = Map([])
  for report in [check, list_objects, list_users] {
    fields[report.kind] = Json::object(
      Map([
        ("total", Json::number(report.total.to_double())),
        ("passed", Json::number(report.passed.to_double())),
        ("failed", Json::number(report.failed.to_double())),
        ("skipped", Json::number(report.skipped.to_double())),
      ]),
    )
  }
  Json::object(fields)
}

///|
fn main {
  let args = @env.args()
  let paths : Array[String] = []
  let mut json_output = false
  for i in 1..<args.length() {
    if args[i] == "--json" {
      json_output = true
    } else {
      paths.push(args[i])
    }
  }
  let selected = if paths.length() == 0 { default_paths() } else { paths }
  let mut failures = 0
  let mut read_error = false
  let mut total_check = 0
  let mut total_check_passed = 0
  let mut total_check_failed = 0
  let mut total_check_skipped = 0
  let mut total_objects = 0
  let mut total_objects_passed = 0
  let mut total_objects_failed = 0
  let mut total_objects_skipped = 0
  let mut total_users = 0
  let mut total_users_passed = 0
  let mut total_users_failed = 0
  let mut total_users_skipped = 0
  let files : Array[Json] = []
  for path in selected {
    let report = Some(@conf.run_conformance_file(path)) catch { _ => None }
    match report {
      Some(value) => {
        if json_output {
          files.push(@conf.report_to_json(value))
        } else {
          println(@conf.format_report(value))
        }
        failures = failures +
          value.check.failed +
          value.list_objects.failed +
          value.list_users.failed
        total_check = total_check + value.check.total
        total_check_passed = total_check_passed + value.check.passed
        total_check_failed = total_check_failed + value.check.failed
        total_check_skipped = total_check_skipped + value.check.skipped
        total_objects = total_objects + value.list_objects.total
        total_objects_passed = total_objects_passed + value.list_objects.passed
        total_objects_failed = total_objects_failed + value.list_objects.failed
        total_objects_skipped = total_objects_skipped +
          value.list_objects.skipped
        total_users = total_users + value.list_users.total
        total_users_passed = total_users_passed + value.list_users.passed
        total_users_failed = total_users_failed + value.list_users.failed
        total_users_skipped = total_users_skipped + value.list_users.skipped
      }
      None => {
        println("cannot read conformance file: " + path)
        read_error = true
      }
    }
  }
  let check_totals = @conf.CategoryReport::{
    kind: "check",
    total: total_check,
    passed: total_check_passed,
    failed: total_check_failed,
    skipped: total_check_skipped,
    failures: [],
    categories: [],
  }
  let object_totals = @conf.CategoryReport::{
    kind: "list_objects",
    total: total_objects,
    passed: total_objects_passed,
    failed: total_objects_failed,
    skipped: total_objects_skipped,
    failures: [],
    categories: [],
  }
  let user_totals = @conf.CategoryReport::{
    kind: "list_users",
    total: total_users,
    passed: total_users_passed,
    failed: total_users_failed,
    skipped: total_users_skipped,
    failures: [],
    categories: [],
  }
  if json_output {
    let root : Map[String, Json] = Map([])
    root["files"] = Json::array(files)
    root["totals"] = totals_json(check_totals, object_totals, user_totals)
    println(Json::object(root).stringify(indent=2))
  } else {
    println(
      "totals: check " +
      total_check_passed.to_string() +
      "/" +
      total_check.to_string() +
      ", list_objects " +
      total_objects_passed.to_string() +
      "/" +
      total_objects.to_string() +
      ", list_users " +
      total_users_passed.to_string() +
      "/" +
      total_users.to_string(),
    )
  }
  if read_error {
    @sys.exit(2)
  } else if failures > 0 {
    @sys.exit(1)
  }
}
