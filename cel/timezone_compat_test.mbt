///|
test "pinned CEL getter offset forms retain exact hours and runtime errors" {
  for
    (zone, hour) in [
      ("+05:30", 15L),
      ("-08:00", 2L),
      ("05:30", 15L),
      ("5:30", 15L),
      ("+5:30", 15L),
      ("-00:30", 9L),
      ("00:00", 10L),
      ("+23:59", 9L),
      ("-23:59", 10L),
      ("8:+01", 18L),
      ("", 10L),
      ("UTC", 10L),
      ("Local", 10L),
      ("America/Los_Angeles", 3L),
    ] {
    let expr = @cel.compile("timestamp('2026-03-08T10:00:00Z').getHours(s)")
    let value = @cel.eval_expr(expr, Map([("s", @fga.VString(zone))]))
    assert_true(@fga.cel_value_eq(value, @fga.VInt(hour)), msg=zone)
  }
  for
    zone in [
      "24:00", "+24:00", "-24:00", "00:60", "8:-01", "0x8:00", "1_0:00", "+05:30:00",
      ":30", "5:", "+0530", "Z",
    ] {
    let code = try {
      ignore(
        @cel.eval_expr(
          @cel.compile("timestamp('2026-03-08T10:00:00Z').getHours(s)"),
          Map([("s", @fga.VString(zone))]),
        ),
      )
      0
    } catch {
      e => @fga.error_code(e)
    }
    assert_eq(code, 2000, msg=zone)
  }
}

///|
test "Local opt in preserves omitted getters conversions and named zone DST" {
  for allow in [false, true] {
    for
      (zone, stamp, hour) in [
        ("+05:30", "2026-01-01T00:00:00Z", if allow { 5L } else { 0L }),
        ("America/Los_Angeles", "2026-01-01T00:00:00Z", 16L),
        ("America/Los_Angeles", "2026-07-01T00:00:00Z", 17L),
        ("Asia/Kolkata", "2026-01-01T00:00:00Z", 5L),
      ] {
      let env = Map([("s", @fga.VString(stamp))])
      let value = @cel.eval_expr_with_cost(
          @cel.compile("timestamp(s).getHours('Local')"),
          env,
          100,
          local_timezone=Some(zone),
          allow_numeric_local_timezone=allow,
        ).0
      assert_true(@fga.cel_value_eq(value, @fga.VInt(hour)))
      let utc = @cel.eval_expr_with_limit(
        @cel.compile("timestamp(s).getHours()"),
        env,
        100,
        local_timezone=Some(zone),
        allow_numeric_local_timezone=allow,
      )
      assert_true(@fga.cel_value_eq(utc, @fga.VInt(0L)))
      let converted = @cel.eval_expr_with_limit(
        @cel.compile("string(timestamp('2026-01-01T00:00:00+08:00'))"),
        Map([]),
        100,
        local_timezone=Some(zone),
        allow_numeric_local_timezone=allow,
      )
      assert_true(
        @fga.cel_value_eq(converted, @fga.VString("2026-01-01T00:00:00+08:00")),
      )
    }
  }
}

///|
test "Local strips one leading colon using pinned Go TZ lookup semantics" {
  for allow in [false, true] {
    for
      (zone, hour) in [
        (":Asia/Kolkata", 15L),
        (":UTC", 10L),
        ("::UTC", 10L),
        (":+05:30", 10L),
        (":", 10L),
        (":America/Los_Angeles", 3L),
        (":Etc/GMT-5", 15L),
        ("::Asia/Kolkata", 10L),
        (":05:30", 10L),
        (":Invalid/Zone", 10L),
        (":::UTC", 10L),
      ] {
      let value = @cel.eval_expr_with_limit(
        @cel.compile("timestamp('2026-03-08T10:00:00Z').getHours('Local')"),
        Map([]),
        100,
        local_timezone=Some(zone),
        allow_numeric_local_timezone=allow,
      )
      assert_true(@fga.cel_value_eq(value, @fga.VInt(hour)), msg=zone)
    }
  }
}

///|
test "non numeric colon Local settings retain E2000 instead of silent UTC" {
  for zone in ["Foo:Bar", "0x8:00", "+05:30:15", " +05:30", "+05:30 "] {
    let code = try {
      ignore(
        @cel.eval_expr_with_limit(
          @cel.compile("timestamp('2026-03-08T10:00:00Z').getHours('Local')"),
          Map([]),
          100,
          local_timezone=Some(zone),
        ),
      )
      0
    } catch {
      e => @fga.error_code(e)
    }
    assert_eq(code, 2000, msg=zone)
  }
}

///|
test "colon free numeric Local settings remain outside the supported offset contract" {
  for allow in [false, true] {
    for zone in ["+5", "-8", "+05", "+0530"] {
      let code = try {
        ignore(
          @cel.eval_expr_with_limit(
            @cel.compile("timestamp('2026-03-08T10:00:00Z').getHours('Local')"),
            Map([]),
            100,
            local_timezone=Some(zone),
            allow_numeric_local_timezone=allow,
          ),
        )
        0
      } catch {
        e => @fga.error_code(e)
      }
      assert_eq(code, 2000, msg=zone)
    }
  }
}
