///|
fn check_contained(_base : String, _path : String) -> Unit raise @fga.FgaError {
  raise @fga.fail(
    @fga.ERR_VALIDATION,
    "secure fga.mod file loading requires --target native or --target js; wasm hosts must supply module contents",
  )
}
