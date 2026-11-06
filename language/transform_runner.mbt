// Compares the DSL <-> JSON transformer with openfga/language fixtures.

///|
fn transform_error(message : String) -> @fga.FgaError {
  @fga.fail(@fga.ERR_VALIDATION, message)
}

///|
fn read_text(path : String) -> String raise @fga.FgaError {
  @fs.read_file_to_string(path) catch {
    _ => raise transform_error("cannot read file: " + path)
  }
}

///|
pub(all) struct TransformCaseResult {
  name : String
  dsl_to_json : Bool
  json_to_model : Bool
  error : String
}

///|
pub(all) struct TransformReport {
  root : String
  total : Int32
  passed : Int32
  failed : Int32
  results : Array[TransformCaseResult]
}

///|
fn run_case(directory : String, name : String) -> TransformCaseResult {
  let fga_path = directory + "/" + name + "/authorization-model.fga"
  let json_path = directory + "/" + name + "/authorization-model.json"
  let source = read_text(fga_path) catch {
    @fga.FgaError(..) as err =>
      return TransformCaseResult::{
        name,
        dsl_to_json: false,
        json_to_model: false,
        error: @fga.error_message(err),
      }
  }
  let json_source = read_text(json_path) catch {
    @fga.FgaError(..) as err =>
      return TransformCaseResult::{
        name,
        dsl_to_json: false,
        json_to_model: false,
        error: @fga.error_message(err),
      }
  }
  let dsl_to_json = try {
    let model = @dsl.parse_model(source)
    let encoded = @model.model_to_json(model)
    let expected = @json.parse(json_source) catch {
      _ => raise transform_error("fixture JSON is invalid")
    }
    @model.json_eq(encoded, expected)
  } catch {
    @fga.FgaError(..) => false
  }
  let json_to_model = try {
    let from_dsl = @dsl.parse_model(source)
    let from_json = @model.json_to_model(json_source)
    @model.model_eq(from_dsl, from_json)
  } catch {
    @fga.FgaError(..) => false
  }
  let error = if dsl_to_json && json_to_model {
    ""
  } else {
    "DSL <-> JSON mismatch"
  }
  TransformCaseResult::{ name, dsl_to_json, json_to_model, error, }
}

///|
pub fn run_transformer_dir(
  root : String,
) -> TransformReport raise @fga.FgaError {
  let entries = @fs.read_dir(root).to_owned() catch {
    _ => raise transform_error("cannot list directory: " + root)
  }
  let names : Array[String] = []
  for entry in entries {
    let name = entry
    if name.has_prefix(".") {
      continue
    }
    let path = root + "/" + name
    let is_directory = @fs.is_dir(path) catch { _ => false }
    if is_directory {
      names.push(name)
    }
  }
  names.sort_by(fn(a, b) { a.lexical_compare(b) })
  let results : Array[TransformCaseResult] = []
  let mut passed = 0
  for name in names {
    let result = run_case(root, name)
    if result.dsl_to_json && result.json_to_model {
      passed = passed + 1
    }
    results.push(result)
  }
  TransformReport::{
    root,
    total: results.length(),
    passed,
    failed: results.length() - passed,
    results,
  }
}

///|
pub fn format_transform_report(report : TransformReport) -> String {
  let out = StringBuilder()
  out.write_string("transformer: " + report.root + "\n")
  out.write_string(
    "cases: " +
    report.passed.to_string() +
    "/" +
    report.total.to_string() +
    " passed\n",
  )
  for result in report.results {
    if result.dsl_to_json && result.json_to_model {
      continue
    }
    out.write_string("  FAIL " + result.name + "\n")
    out.write_string(
      "    dsl->json: " +
      result.dsl_to_json.to_string() +
      ", json->model: " +
      result.json_to_model.to_string() +
      "\n",
    )
    if result.error != "" {
      out.write_string("    " + result.error + "\n")
    }
  }
  out.to_string()
}

///|
fn module_files(
  root : String,
  prefix : String,
) -> Array[@dsl.ModuleFile] raise @fga.FgaError {
  let entries = @fs.read_dir(root + "/" + prefix).to_owned() catch {
    _ => raise transform_error("cannot list module files")
  }
  entries.sort_by(fn(a, b) { a.lexical_compare(b) })
  let files : Array[@dsl.ModuleFile] = []
  for name in entries {
    let relative = if prefix == "" { name } else { prefix + "/" + name }
    if (@fs.is_dir(root + "/" + relative) catch { _ => false }) {
      files.append(module_files(root, relative))
    } else if name.has_suffix(".fga") {
      files.push(@dsl.ModuleFile::{
        name: relative,
        contents: read_text(root + "/" + relative),
      })
    }
  }
  files
}

///|
/// All module directories are reported, including missing upstream inputs.
pub fn run_module_dir(root : String) -> Int32 raise @fga.FgaError {
  let names = @fs.read_dir(root).to_owned() catch {
    _ => raise transform_error("cannot list modules")
  }
  names.sort_by(fn(a, b) { a.lexical_compare(b) })
  let mut passed = 0
  let mut supplied = 0
  let mut unavailable = 0
  let mut failures = 0
  for name in names {
    let directory = root + "/" + name
    if !(@fs.is_dir(directory) catch { _ => false }) {
      continue
    }
    if !@fs.path_exists(directory + "/module") {
      // The pinned complex fixture has JSON only. Exercise preservation without
      // presenting it as a module-input transformation.
      unavailable += 1
      let source = read_text(directory + "/authorization-model.json")
      let expected = @json.parse(source) catch {
        _ => raise transform_error("invalid JSON fixture")
      }
      let same = @model.json_eq(
        @model.model_to_json(@model.json_to_model(source)),
        expected,
      )
      println(
        "  UNAVAILABLE " +
        name +
        ": no module inputs upstream; JSON metadata roundtrip=" +
        same.to_string(),
      )
      if !same {
        failures += 1
      }
      continue
    }
    supplied += 1
    let files = module_files(directory + "/module", "")
    let expects_error = @fs.path_exists(directory + "/expected_errors.json")
    let result = try {
      let model = @dsl.merge_modules(files)
      let issues = @validate.validate_model(model)
      if expects_error {
        issues.length() > 0
      } else {
        let expected = @json.parse(
          read_text(directory + "/authorization-model.json"),
        ) catch {
          _ => raise transform_error("invalid JSON fixture")
        }
        @model.json_eq(@model.model_to_json(model), expected)
      }
    } catch {
      @fga.FgaError(..) as err => {
        if !expects_error {
          println(@fga.format_error(err))
        }
        expects_error
      }
    }
    println(
      "  " +
      (if result { "PASS " } else { "FAIL " }) +
      name +
      (if expects_error {
        " (rejection; diagnostic-list equality not asserted)"
      } else {
        " (full JSON equality)"
      }),
    )
    if result {
      passed += 1
    } else {
      failures += 1
    }
  }
  println(
    "modules: " +
    passed.to_string() +
    "/" +
    supplied.to_string() +
    " supplied-input cases; " +
    unavailable.to_string() +
    " missing-input fixture(s)",
  )
  failures
}

///|
pub fn run_mod_cases(path : String) -> Int32 raise @fga.FgaError {
  let docs = @yaml.Yaml::load_from_string(read_text(path)) catch {
    _ => raise transform_error("invalid mod fixtures")
  }
  let cases = match docs[0].to_json() {
    Array(xs) => xs
    _ => raise transform_error("invalid mod fixtures")
  }
  let mut passed = 0
  for item in cases {
    if item is Object(obj) {
      let source = match obj.get("modFile") {
        Some(String(s)) => s
        _ => ""
      }
      let expects_error = obj.contains("expected_errors")
      let ok = try {
        let _ = @model.parse_mod(source)
        !expects_error
      } catch {
        @fga.FgaError(..) => expects_error
      }
      if ok {
        passed += 1
      } else {
        println("FAIL fga.mod: " + item.stringify())
      }
    }
  }
  println(
    "fga.mod: " +
    passed.to_string() +
    "/" +
    cases.length().to_string() +
    " acceptance/rejection cases",
  )
  cases.length() - passed
}
