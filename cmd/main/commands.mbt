// CLI command implementations.

///|
fn usage() -> String {
  (
    #|MoonFGA - OpenFGA-compatible authorization engine
    #|
    #|Usage:
    #|  moonfga validate <model.fga|model.json> [--json]
    #|  moonfga transform <model> --to json|dsl [--out <file>]
    #|  moonfga check --model <file> --object <obj> --relation <rel> --user <user>
    #|                [--store <tuples>] [--context <json>] [--contextual <file>]
    #|                [--explain] [--json]
    #|  moonfga list-objects --model <file> --type <type> --relation <rel> --user <user>
    #|                       [--store <tuples>] [--context <json>] [--contextual <file>]
    #|                       [--json]
    #|  moonfga list-users --model <file> --object <obj> --relation <rel>
    #|                     [--filters user,group#member] [--store <tuples>]
    #|                     [--context <json>] [--contextual <file>] [--json]
    #|  moonfga expand --model <file> --object <obj> --relation <rel>
    #|                 [--contextual <file>]
    #|  moonfga test <store.fga.yaml>
    #|
    #|Tuple files accept JSON (`[{"object":...}]`), YAML (`tuples:`),
    #|or one `object#relation@user` per line.
  )
}

///|
fn positional(
  args : CliArgs,
  index : Int32,
  what : String,
) -> String raise @fga.FgaError {
  if index >= args.positionals.length() {
    raise @fga.fail(@fga.ERR_VALIDATION, "usage: missing " + what)
  }
  args.positionals[index]
}

///|
fn issues_json(issues : Array[@validate.ValidationIssue]) -> Json {
  let items : Array[Json] = []
  for issue in issues {
    let fields : Map[String, Json] = Map([])
    fields["code"] = Json::number(issue.code.to_double())
    fields["message"] = Json::string(issue.message)
    fields["line"] = Json::number(issue.line.to_double())
    fields["column"] = Json::number(issue.column.to_double())
    fields["symbol"] = Json::string(issue.symbol)
    items.push(Json::object(fields))
  }
  Json::array(items)
}

///|
fn command_validate(args : CliArgs) -> Int32 raise @fga.FgaError {
  let path = positional(args, 1, "model file")
  let model = load_model_file(path)
  let issues = @validate.validate_model(model)
  if has_flag(args, "--json") {
    println(issues_json(issues).stringify(indent=2))
  } else if issues.length() == 0 {
    println("model is valid")
  } else {
    for issue in issues {
      println(@validate.format_issue(issue))
    }
  }
  if issues.length() == 0 {
    0
  } else {
    1
  }
}

///|
fn command_transform(args : CliArgs) -> Int32 raise @fga.FgaError {
  let path = positional(args, 1, "model file")
  let target = require_value(args, "--to")
  let model = load_model_file(path)
  let output = match target {
    "json" => @model.model_to_json_string(model)
    "dsl" => @dsl.to_dsl(model)
    _ => raise @fga.fail(@fga.ERR_VALIDATION, "usage: --to must be json or dsl")
  }
  match flag_value(args, "--out") {
    Some(out) => {
      write_text(out, output + "\n")
      println("wrote " + out)
    }
    None => println(output)
  }
  0
}

///|
fn command_check(args : CliArgs) -> Int32 raise @fga.FgaError {
  let model = load_model_file(require_value(args, "--model"))
  let object = require_value(args, "--object")
  let relation = require_value(args, "--relation")
  let user = require_value(args, "--user")
  let context = load_context(args)
  let contextual = load_optional_tuples(args, "--contextual")
  let store = @store.MemoryStore::new()
  let _ = store.write_all(load_optional_tuples(args, "--store"))
  let engine = @engine.Engine::new(model, store as &@fga.TupleReader)
  if has_flag(args, "--explain") {
    let result = engine.explain_check(
      object, relation, user, context, contextual,
    )
    if has_flag(args, "--json") {
      let fields : Map[String, Json] = Map([])
      fields["allowed"] = Json::boolean(result.allowed)
      let paths : Array[Json] = []
      for path in result.paths {
        paths.push(Json::string(path))
      }
      fields["paths"] = Json::array(paths)
      println(Json::object(fields).stringify(indent=2))
    } else {
      println("allowed: " + result.allowed.to_string())
      for path in result.paths {
        println("  " + path)
      }
    }
  } else {
    let allowed = engine.check_with(object, relation, user, context, contextual)
    if has_flag(args, "--json") {
      let fields : Map[String, Json] = Map([])
      fields["allowed"] = Json::boolean(allowed)
      println(Json::object(fields).stringify(indent=2))
    } else {
      println(allowed.to_string())
    }
  }
  0
}

///|
fn print_strings(values : Array[String], as_json : Bool) -> Unit {
  if as_json {
    let items : Array[Json] = []
    for value in values {
      items.push(Json::string(value))
    }
    println(Json::array(items).stringify(indent=2))
  } else {
    for value in values {
      println(value)
    }
  }
}

///|
fn command_list_objects(args : CliArgs) -> Int32 raise @fga.FgaError {
  let model = load_model_file(require_value(args, "--model"))
  let type_name = require_value(args, "--type")
  let relation = require_value(args, "--relation")
  let user = require_value(args, "--user")
  let context = load_context(args)
  let contextual = load_optional_tuples(args, "--contextual")
  let store = @store.MemoryStore::new()
  let _ = store.write_all(load_optional_tuples(args, "--store"))
  let engine = @engine.Engine::new(model, store as &@fga.TupleReader)
  let objects = engine.list_objects(
    type_name, relation, user, context, contextual,
  )
  print_strings(objects, has_flag(args, "--json"))
  0
}

///|
fn command_list_users(args : CliArgs) -> Int32 raise @fga.FgaError {
  let model = load_model_file(require_value(args, "--model"))
  let object = require_value(args, "--object")
  let relation = require_value(args, "--relation")
  let filters = parse_filters(args, model)
  let context = load_context(args)
  let contextual = load_optional_tuples(args, "--contextual")
  let store = @store.MemoryStore::new()
  let _ = store.write_all(load_optional_tuples(args, "--store"))
  let engine = @engine.Engine::new(model, store as &@fga.TupleReader)
  let users = engine.list_users(object, relation, filters, context, contextual)
  print_strings(users, has_flag(args, "--json"))
  0
}

///|
fn command_expand(args : CliArgs) -> Int32 raise @fga.FgaError {
  let model = load_model_file(require_value(args, "--model"))
  let object = require_value(args, "--object")
  let relation = require_value(args, "--relation")
  let contextual = load_optional_tuples(args, "--contextual")
  let store = @store.MemoryStore::new()
  let _ = store.write_all(load_optional_tuples(args, "--store"))
  let engine = @engine.Engine::new(model, store as &@fga.TupleReader)
  let tree = engine.expand_json(object, relation, contextual)
  println(tree.stringify(indent=2))
  0
}

///|
fn command_test(args : CliArgs) -> Int32 raise @fga.FgaError {
  let path = positional(args, 1, "store test file")
  let report = @storetest.run_store_test_file(path)
  println(@storetest.format_store_test_report(report))
  if report.failures.length() == 0 {
    0
  } else {
    1
  }
}
