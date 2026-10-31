// Bi-directional DSL <-> JSON transformer.

///|
pub fn json_to_model(source : String) -> @fga.AuthModel raise @fga.FgaError {
  let value = @json.parse(source) catch {
    _ =>
      raise @fga.fail(@fga.ERR_VALIDATION, "invalid JSON authorization model")
  }
  model_from_json(value)
}

///|
pub fn json_to_dsl(source : String) -> String raise @fga.FgaError {
  @dsl.to_dsl(json_to_model(source))
}

///|
pub fn dsl_to_model(source : String) -> @fga.AuthModel raise @fga.FgaError {
  @dsl.parse_model(source)
}

///|
pub fn dsl_to_json(source : String) -> String raise @fga.FgaError {
  model_to_json_string(@dsl.parse_model(source))
}
