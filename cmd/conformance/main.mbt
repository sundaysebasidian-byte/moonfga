// Runs the upstream OpenFGA conformance matrix and prints a summary.
//
// Usage: moon run cmd/conformance -- <file.yaml> [<file.yaml> ...]
// With no arguments both pinned upstream files are used.

///|
fn default_paths() -> Array[String] {
  [
    ".upstream/openfga/consolidated_1_1_tests.yaml", ".upstream/openfga/abac_tests.yaml",
  ]
}

///|
fn main {
  let args = @env.args()
  let paths : Array[String] = []
  for i in 1..<args.length() {
    paths.push(args[i])
  }
  let selected = if paths.length() == 0 { default_paths() } else { paths }
  let mut failures = 0
  let mut read_error = false
  let mut total_check = 0
  let mut total_check_passed = 0
  let mut total_objects = 0
  let mut total_objects_passed = 0
  let mut total_users = 0
  let mut total_users_passed = 0
  for path in selected {
    let report = Some(@conf.run_conformance_file(path)) catch { _ => None }
    match report {
      Some(value) => {
        println(@conf.format_report(value))
        failures = failures +
          value.check.failed +
          value.list_objects.failed +
          value.list_users.failed
        total_check = total_check + value.check.total
        total_check_passed = total_check_passed + value.check.passed
        total_objects = total_objects + value.list_objects.total
        total_objects_passed = total_objects_passed + value.list_objects.passed
        total_users = total_users + value.list_users.total
        total_users_passed = total_users_passed + value.list_users.passed
      }
      None => {
        println("cannot read conformance file: " + path)
        read_error = true
      }
    }
  }
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
  if read_error {
    @sys.exit(2)
  } else if failures > 0 {
    @sys.exit(1)
  }
}
