///|
#borrow(base, path)
extern "C" fn contained(base : Bytes, path : Bytes) -> Int32 = "moonfga_contained"

///|
fn check_contained(base : String, path : String) -> Unit raise @fga.FgaError {
  if contained(
      @utf8.encode(if base == "" { "." } else { base }) + b"\x00",
      @utf8.encode(path) + b"\x00",
    ) ==
    0 {
    raise @fga.fail(
      @fga.ERR_VALIDATION,
      "module path escapes root or cannot be resolved: " + path,
    )
  }
}
