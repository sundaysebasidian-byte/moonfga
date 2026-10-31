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
