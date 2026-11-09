// Official OpenFGA v1.22.1 expectations from scripts/oracle_cel.py, seed 20261108.

///|
test "CEL bytes conversions overflow and quantifier oracle regressions" {
  let env : Map[String, @fga.CelValue] = Map([
    ("n", @fga.VInt(0L)),
    ("s", @fga.VString("")),
  ])
  let cases : Array[(String, String)] = [
    ("b\"\" == bytes(\"\")", "true"),
    ("b\"abc\" == bytes(\"abc\")", "true"),
    ("b\"a\" + b\"b\" == b\"ab\"", "true"),
    ("b\"a\" < b\"b\"", "true"),
    ("b\"a\" <= b\"a\"", "true"),
    ("b\"b\" > b\"a\"", "true"),
    ("b\"b\" >= b\"b\"", "true"),
    ("size(b\"😀\") == 4", "true"),
    ("b\"😀\".size() == 4", "true"),
    ("string(b\"hello\") == \"hello\"", "true"),
    ("string(bytes(\"😀\")) == \"😀\"", "true"),
    ("b\"a\" in [b\"b\", b\"a\"]", "true"),
    ("{\"b\": b\"x\"}.b == b\"x\"", "true"),
    ("[b\"x\", 1, true][0] == b\"x\"", "true"),
    ("bytes(b\"x\") == b\"x\"", "true"),
    ("b\"\\xff\" > b\"\\x7f\"", "true"),
    ("b\"\\000\\377\".size() == 2", "true"),
    ("b\"\\a\\b\\f\\n\\r\\t\\v\\?\".size() == 8", "true"),
    ("b\"\\x41\" == b\"A\"", "true"),
    ("\"\\u4e2d\\U0001f600\" == \"中😀\"", "true"),
    ("br\"\\x41\" == bytes(r\"\\x41\")", "true"),
    ("b\"\"\"a\nb\"\"\" == bytes(\"a\\nb\")", "true"),
    ("string(b\"\\xff\" + bytes(s)) == \"x\"", "error"),
    ("int(dyn(18446744073709551615u + uint(n))) == 0", "error"),
    ("int(dyn(9223372036854775808.0 + double(n))) == 0", "error"),
    ("uint(\"18446744073709551615\") == 18446744073709551615u", "true"),
    ("double(\"1.5\") == 1.5", "true"),
    ("bool(\"true\") && !bool(\"false\")", "true"),
    ("string(\"abc\") == \"abc\"", "true"),
    ("string(1u) == \"1\"", "true"),
    ("dyn(b\"x\") == b\"x\"", "true"),
    ("has({\"a\": b\"x\"}.a)", "true"),
    ("!has({\"a\": 1}.b)", "true"),
    ("[1,2] + [3] == [1,2,3]", "true"),
    ("[0,1].exists(x, x == 0 || 1 / x == 1)", "true"),
    ("[0,1].exists(x, 1 / x == 1)", "true"),
    ("[0,1].all(x, 1 / x == 0)", "false"),
    ("[1,0].all(x, x == 0)", "false"),
    ("[0,1].exists_one(x, 1 / x == 1)", "error"),
    ("9223372036854775807 + (1 + n) == 0", "error"),
    ("(-9223372036854775807 - 1) - (1 + n) == 0", "error"),
    ("9223372036854775807 * (2 + n) == 0", "error"),
    ("(-9223372036854775807 - 1) / (-1 + n) == 0", "error"),
    ("(-9223372036854775807 - 1) % (-1 + n) == 0", "error"),
    ("-(-9223372036854775807 - 1 + n) == 0", "error"),
    ("18446744073709551615u + uint(1 + n) == 0u", "error"),
    ("uint(n) - 1u == 0u", "error"),
    ("18446744073709551615u * uint(2 + n) == 0u", "error"),
    ("1 / n == 0", "error"),
    ("1u / uint(n) == 0u", "error"),
    ("(1 / n == 0) || true", "true"),
    ("(1 / n == 0) && false", "false"),
  ]
  for (source, expected) in cases {
    let actual = try {
      match @cel.eval_expr(@cel.compile(source), env) {
        @fga.VBool(b) => b.to_string()
        _ => "non-bool"
      }
    } catch {
      _ => "error"
    }
    assert_eq(actual, expected, msg=source)
  }
}

///|
test "CEL literal rejects malformed byte and Unicode escapes" {
  for
    source in [
      "b\"\\400\"", "b\"\\u0041\"", "\"\\uD800\"", "\"\\U00110000\"", "b\"\\xg0\"",
    ] {
    let rejected = try {
      ignore(@cel.compile(source))
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg=source)
  }
}
