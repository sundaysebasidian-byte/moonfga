///|
test "compile rejects deep input with a controlled CEL error" {
  for depth in [250, 1000, 10000] {
    for
      source in [
        String::make(depth, '(') + "1" + String::make(depth, ')'),
        String::make(depth, '[') + "1" + String::make(depth, ']'),
      ] {
      let rejected = try {
        ignore(@cel.compile(source))
        false
      } catch {
        @fga.FgaError(_) => true
      }
      assert_true(rejected)
    }
  }
  ignore(@cel.compile(String::make(249, '(') + "1" + String::make(249, ')')))
}
