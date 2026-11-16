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
  let utc = @cel.eval_expr_with_limit(
    @cel.compile("timestamp('2026-01-01T00:00:00Z').getHours('Local') == 0"),
    Map([]),
    100,
  )
  assert_true(@fga.cel_value_eq(utc, @fga.VBool(true)))
}

///|
test "request budget interrupts deciding CEL and regex paths" {
  for source in ["true", "(1/0==0)||true", "[1,2,3].exists(x,x>0)"] {
    let budget = @fga.ExecutionBudget::new(steps=0)
    let code = try {
      ignore(
        @cel.eval_expr_with_limit(
          @cel.compile(source),
          Map([]),
          100,
          budget=Some(budget),
        ),
      )
      0
    } catch {
      e => @fga.error_code(e)
    }
    assert_eq(code, @fga.ERR_DEADLINE_EXCEEDED)
  }
  let budget = @fga.ExecutionBudget::new(steps=1)
  let code = try {
    ignore(
      @cel.regex_matches("a+", String::make(4096, 'a'), budget=Some(budget)),
    )
    0
  } catch {
    e => @fga.error_code(e)
  }
  assert_eq(code, @fga.ERR_DEADLINE_EXCEEDED)
}

///|
test "portable work units have deterministic exact boundaries" {
  let expr = @cel.compile("n+1")
  let env = Map([("n", @fga.VInt(0L))])
  let value = @cel.eval_expr_with_limit(
    expr,
    env,
    100,
    budget=Some(@fga.ExecutionBudget::new(steps=3)),
  )
  assert_true(@fga.cel_value_eq(value, @fga.VInt(1L)))
  let code = try {
    ignore(
      @cel.eval_expr_with_limit(
        expr,
        env,
        100,
        budget=Some(@fga.ExecutionBudget::new(steps=2)),
      ),
    )
    0
  } catch {
    e => @fga.error_code(e)
  }
  assert_eq(code, 4004)
}

///|
test "nested singleton list inference fits portable wasm stack" {
  let source = "size(" +
    String::make(248, '[') +
    "1" +
    String::make(248, ']') +
    ")==1"
  @cel.check_condition({ name: "nested", expression: source, parameters: [], })
}

///|
test "large string cost multiplication cannot wrap past the limit" {
  for (source, size) in [("s.contains(s)", 500000), ("s.matches(t)", 300000)] {
    let env = Map([("s", @fga.VString(String::make(size, 'a')))])
    if source == "s.matches(t)" {
      env["t"] = @fga.VString(Array::make(75000, "(?i)").join(""))
    }
    let code = try {
      ignore(@cel.eval_expr_with_limit(@cel.compile(source), env, 100))
      0
    } catch {
      e => @fga.error_code(e)
    }
    assert_eq(code, 2000, msg=source)
  }
}
