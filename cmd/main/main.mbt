// Entry point and command dispatch.

///|
fn dispatch(args : CliArgs) -> Int32 raise @fga.FgaError {
  if args.positionals.length() == 0 {
    println(usage())
    return 2
  }
  let command = args.positionals[0]
  match command {
    "validate" => command_validate(args)
    "transform" => command_transform(args)
    "check" => command_check(args)
    "list-objects" => command_list_objects(args)
    "list-users" => command_list_users(args)
    "expand" => command_expand(args)
    "test" => command_test(args)
    "help" | "-h" => {
      println(usage())
      0
    }
    _ => {
      println("unknown command: " + command)
      println(usage())
      2
    }
  }
}

///|
fn main {
  let code = try {
    let args = parse_cli_args(cli_arguments())
    if has_flag(args, "--help") {
      println(usage())
      0
    } else {
      dispatch(args)
    }
  } catch {
    @fga.FgaError(..) as err => {
      let message = @fga.error_message(err)
      if message.has_prefix("usage: ") {
        println(message)
        println(usage())
        2
      } else {
        println(@fga.format_error(err))
        1
      }
    }
  }
  @sys.exit(code)
}
