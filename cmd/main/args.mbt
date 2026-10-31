// Minimal `--flag value` parser for the CLI.

///|
struct CliArgs {
  positionals : Array[String]
  values : Map[String, String]
  flags : Map[String, Bool]
}

///|
fn flag_takes_value(name : String) -> Bool {
  match name {
    "--to"
    | "--model"
    | "--store"
    | "--object"
    | "--relation"
    | "--user"
    | "--type"
    | "--context"
    | "--context-file"
    | "--contextual"
    | "--filters"
    | "--out" => true
    _ => false
  }
}

///|
fn parse_cli_args(args : Array[String]) -> CliArgs raise @fga.FgaError {
  let positionals : Array[String] = []
  let values : Map[String, String] = Map([])
  let flags : Map[String, Bool] = Map([])
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if arg.has_prefix("--") {
      if flag_takes_value(arg) {
        if i + 1 >= args.length() {
          raise @fga.fail(
            @fga.ERR_VALIDATION,
            "usage: " + arg + " requires a value",
          )
        }
        values[arg] = args[i + 1]
        i = i + 2
      } else {
        flags[arg] = true
        i = i + 1
      }
    } else {
      positionals.push(arg)
      i = i + 1
    }
  }
  CliArgs::{ positionals, values, flags, }
}

///|
fn has_flag(args : CliArgs, name : String) -> Bool {
  match args.flags.get(name) {
    Some(_) => true
    None => false
  }
}

///|
fn flag_value(args : CliArgs, name : String) -> String? {
  args.values.get(name)
}

///|
fn require_value(args : CliArgs, name : String) -> String raise @fga.FgaError {
  match args.values.get(name) {
    Some(value) => value
    None => raise @fga.fail(@fga.ERR_VALIDATION, "usage: missing " + name)
  }
}
