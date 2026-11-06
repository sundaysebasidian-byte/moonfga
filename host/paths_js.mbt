///|
#module("node:fs")
extern "js" fn realpath(path : String) -> String = "realpathSync"

///|
extern "js" fn contained(
  resolve : (String) -> String,
  base : String,
  path : String,
) -> Bool =
  #| (resolve, base, path) => {
  #|   try {
  #|     const root = resolve(base || '.');
  #|     const file = resolve(path);
  #|     return file.startsWith(root.endsWith('/') ? root : root + '/');
  #|   } catch { return false; }
  #| }

///|
fn check_contained(base : String, path : String) -> Unit raise @fga.FgaError {
  if !contained(realpath, base, path) {
    raise @fga.fail(
      @fga.ERR_VALIDATION,
      "module path escapes root or cannot be resolved: " + path,
    )
  }
}
