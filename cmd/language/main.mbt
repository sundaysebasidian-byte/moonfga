// Runs the openfga/language DSL <-> JSON transformer fixtures.

///|
fn main {
  let args = @env.args()
  let paths : Array[String] = []
  for i in 1..<args.length() {
    paths.push(args[i])
  }
  let selected = if paths.length() == 0 {
    [".upstream/language/data/transformer"]
  } else {
    paths
  }
  let mut failures = 0
  let mut read_error = false
  for path in selected {
    let report = Some(@lang.run_transformer_dir(path)) catch { _ => None }
    match report {
      Some(value) => {
        println(@lang.format_transform_report(value))
        failures = failures + value.failed
      }
      None => {
        println("cannot run transformer fixtures in " + path)
        read_error = true
      }
    }
  }
  if paths.length() == 0 {
    try {
      failures += @lang.run_module_dir(
        ".upstream/language/data/transformer-module",
      )
      failures += @lang.run_mod_cases(
        ".upstream/language/data/fga-mod-transformer-cases.yaml",
      )
    } catch {
      _ => read_error = true
    }
  }
  if read_error {
    @sys.exit(2)
  } else if failures > 0 {
    @sys.exit(1)
  }
}
