///|
test "portable cost and host cancellation cannot be absorbed" {
  let expr = @cel.compile("(1 + 2 == 3) || true")
  let limited = try {
    ignore(@cel.eval_expr_with_limit(expr, Map([]), 0))
    false
  } catch {
    _ => true
  }
  assert_true(limited)
  let cancelled = try {
    ignore(
      @cel.eval_expr_with_limit(@cel.compile("true"), Map([]), 100, cancelled=fn() {
        true
      }),
    )
    false
  } catch {
    _ => true
  }
  assert_true(cancelled)
  let cancelled_regex = try {
    ignore(
      @cel.regex_matches("(a|aa)*b", String::make(10000, 'a'), cancelled=fn() {
        true
      }),
    )
    false
  } catch {
    _ => true
  }
  assert_true(cancelled_regex)
  assert_false(@cel.regex_matches("(a|aa)*b", String::make(10000, 'a')))
}

///|
test "Local timezone is an explicit portable host setting" {
  let expr = @cel.compile(
    "timestamp('2026-01-01T00:00:00Z').getHours('Local') == 16",
  )
  let value = @cel.eval_expr_with_limit(
    expr,
    Map([]),
    100,
    local_timezone=Some("America/Los_Angeles"),
  )
  assert_true(@fga.cel_value_eq(value, @fga.VBool(true)))
  let absent = try {
    ignore(@cel.eval_expr_with_limit(expr, Map([]), 100))
    false
  } catch {
    _ => true
  }
  assert_true(absent)
}
