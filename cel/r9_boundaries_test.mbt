///|
test "r9 index forms retain independent oracle costs" {
  let env = Map([("n", @fga.VInt(0L)), ("s", @fga.VString("a"))])
  for
    (source, expected) in [
      ("[1,2,3][n]", 2),
      ("{\"a\":1}[s]", 2),
      ("[1,2,3][n]==1", 3),
      ("[n,2,3][1]", 13),
      ("[1,2,3][0]", 2),
      ("[{\"a\":1}].all(v,has((n==0?v:v).a))", 7),
      ("has((n==0?{\"a\":1}:{\"a\":1}).a)", 3),
    ] {
    let (_, cost) = @cel.eval_expr_with_cost(@cel.compile(source), env, 100)
    assert_eq(cost, expected, msg=source)
  }
}

///|
test "r9 signed conversion and duration negation boundaries" {
  let min_double = @cel.compile("int(double(s))<0")
  let code = try {
    ignore(
      @cel.eval_expr_with_limit(
        min_double,
        Map([("s", @fga.VString("-9.223372036854775808e18"))]),
        100,
      ),
    )
    0
  } catch {
    e => @fga.error_code(e)
  }
  assert_eq(code, 2000)
  let adjacent = @cel.eval_expr_with_limit(
    min_double,
    Map([("s", @fga.VString("-9.2233720368547748e18"))]),
    100,
  )
  assert_true(@fga.cel_value_eq(adjacent, @fga.VBool(true)))
  let expr = @cel.compile("timestamp(s)-duration(t)>timestamp(s)")
  for stamp in ["0001-01-01T00:00:00Z", "2026-01-01T00:00:00Z"] {
    let env = Map([
      ("s", @fga.VString(stamp)),
      ("t", @fga.VString("-9223372036854775808ns")),
    ])
    let code = try {
      ignore(@cel.eval_expr_with_limit(expr, env, 100))
      0
    } catch {
      e => @fga.error_code(e)
    }
    assert_eq(code, 2000)
  }
}

///|
test "fixed Local offsets require an explicit host opt in" {
  let expr = @cel.compile("timestamp('2026-03-08T10:00:00Z').getHours('Local')")
  for (zone, hour) in [("+05:30", 15L), ("05:30", 15L), ("-08:00", 2L)] {
    let value = @cel.eval_expr_with_limit(
      expr,
      Map([]),
      100,
      local_timezone=Some(zone),
      allow_numeric_local_timezone=true,
    )
    assert_true(@fga.cel_value_eq(value, @fga.VInt(hour)))
  }
}

///|
test "numeric Local timezone defaults to the pinned Go TZ fallback" {
  let expr = @cel.compile("timestamp('2026-03-08T10:00:00Z').getHours('Local')")
  for zone in ["+05:30", "05:30", "-08:00"] {
    let value = @cel.eval_expr_with_limit(
      expr,
      Map([]),
      100,
      local_timezone=Some(zone),
    )
    assert_true(@fga.cel_value_eq(value, @fga.VInt(10L)))
  }
}
