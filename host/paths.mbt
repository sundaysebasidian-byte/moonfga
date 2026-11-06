///|
/// Resolve paths before a CLI read, including symlinks. Host files must remain
/// stable between this check and the read.
pub fn require_contained(
  base : String,
  path : String,
) -> Unit raise @fga.FgaError {
  for byte in @utf8.encode(base + path) {
    if byte == 0 {
      raise @fga.fail(@fga.ERR_VALIDATION, "NUL in module path")
    }
  }
  check_contained(base, path)
}
