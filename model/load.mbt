// Loads an authorization model from either the DSL or the JSON wire format.

///|
/// Sniffs the source: a leading `{` means AuthorizationModel JSON, anything
/// else is treated as the DSL (which starts with `model`).
pub fn model_from_source(source : String) -> @fga.AuthModel raise @fga.FgaError {
  if source.trim().has_prefix("{") {
    json_to_model(source)
  } else {
    @dsl.parse_model(source)
  }
}
