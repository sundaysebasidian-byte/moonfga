///|
test "host condition budget survives contextual and list engine copies" {
  let model = model_of(
    (
      #|model
      #|  schema 1.1
      #|type user
      #|type document
      #|  relations
      #|    define viewer: [user with enabled]
      #|condition enabled(n: int) { n > 0 }
    ),
  )
  let store = @store.MemoryStore::new()
  ignore(
    store.write({
      object: "document:1",
      relation: "viewer",
      user: "user:1",
      condition: Some({ name: "enabled", context: Map([("n", @fga.VInt(1L))]), }),
    }),
  )
  let engine = @engine.Engine::new(
    model,
    store as &@fga.TupleReader,
    condition_cost_limit=0,
  )
  inspect(
    status_of(() => engine.check("document:1", "viewer", "user:1")),
    content="E2000",
  )
  let objects_failed = try {
    ignore(engine.list_objects("document", "viewer", "user:1", Map([]), []))
    false
  } catch {
    _ => true
  }
  let users_failed = try {
    ignore(engine.list_users("document:1", "viewer", ["user"], Map([]), []))
    false
  } catch {
    _ => true
  }
  assert_true(objects_failed)
  assert_true(users_failed)
  let cancelled = @engine.Engine::new(model, store as &@fga.TupleReader, condition_cancelled=fn() {
    true
  })
  inspect(
    status_of(() => cancelled.check("document:1", "viewer", "user:1")),
    content="E2000",
  )
}

///|
test "request work budget covers unconditional Check list Expand and batch" {
  let model = model_of(
    "model\n  schema 1.1\ntype user\ntype document\n  relations\n    define viewer: [user]",
  )
  let store = @store.MemoryStore::new()
  ignore(
    store.write({
      object: "document:1",
      relation: "viewer",
      user: "user:1",
      condition: None,
    }),
  )
  let base = @engine.Engine::new(model, store as &@fga.TupleReader)
  let budget = @fga.ExecutionBudget::new(steps=0)
  let limited = base.with_budget(budget)
  inspect(
    status_of(() => limited.check("document:1", "viewer", "user:1")),
    content="E4004",
  )
  let objects = try {
    ignore(limited.list_objects("document", "viewer", "user:1", Map([]), []))
    0
  } catch {
    e => @fga.error_code(e)
  }
  let users = try {
    ignore(limited.list_users("document:1", "viewer", ["user"], Map([]), []))
    0
  } catch {
    e => @fga.error_code(e)
  }
  let expand = try {
    ignore(limited.expand_json("document:1", "viewer", []))
    0
  } catch {
    e => @fga.error_code(e)
  }
  assert_eq(objects, 4004)
  assert_eq(users, 4004)
  assert_eq(expand, 4004)
  let batch = limited.batch_check([
    @engine.CheckRequest::new("document:1", "viewer", "user:1"),
  ])
  assert_eq(batch[0].error_code, Some(4004))
  // An interrupted request must not contaminate the reusable base engine.
  assert_true(base.check("document:1", "viewer", "user:1"))
  assert_true(
    base
    .with_budget(@fga.ExecutionBudget::new(steps=100))
    .check("document:1", "viewer", "user:1"),
  )
}

///|
test "host deadline callback is sticky across requests" {
  let model = model_of(
    "model\n  schema 1.1\ntype user\ntype document\n  relations\n    define viewer: [user]",
  )
  let store = @store.MemoryStore::new()
  let mut calls = 0
  let budget = @fga.ExecutionBudget::new(cancelled=fn() {
    calls += 1
    calls >= 3
  })
  let engine = @engine.Engine::new(model, store as &@fga.TupleReader).with_budget(
    budget,
  )
  inspect(
    status_of(() => engine.check("document:1", "viewer", "user:1")),
    content="E4004",
  )
  let code = try {
    budget.check()
    0
  } catch {
    e => @fga.error_code(e)
  }
  assert_eq(code, 4004)
}

///|
test "request deadline wins over earlier branch condition errors" {
  let model = model_of(
    "model\n  schema 1.1\ntype user\ntype document\n  relations\n    define first: [user with broken]\n    define second: [user with broken]\n    define viewer: first or second\ncondition broken(n: int) { 1/n==0 }",
  )
  let store = @store.MemoryStore::new()
  for relation in ["first", "second"] {
    ignore(
      store.write({
        object: "document:1",
        relation,
        user: "user:1",
        condition: Some({
          name: "broken",
          context: Map([("n", @fga.VInt(0L))]),
        }),
      }),
    )
  }
  let base = @engine.Engine::new(model, store as &@fga.TupleReader)
  for steps in 0..<32 {
    for api in 0..<3 {
      let budget = @fga.ExecutionBudget::new(steps~)
      let engine = base.with_budget(budget)
      let code = try {
        if api == 0 {
          ignore(engine.check("document:1", "viewer", "user:1"))
        } else if api == 1 {
          ignore(
            engine.list_objects("document", "viewer", "user:1", Map([]), []),
          )
        } else {
          ignore(
            engine.list_users("document:1", "viewer", ["user"], Map([]), []),
          )
        }
        0
      } catch {
        e => @fga.error_code(e)
      }
      let exhausted = try {
        budget.check()
        false
      } catch {
        _ => true
      }
      if exhausted {
        assert_eq(
          code,
          4004,
          msg="api=" + api.to_string() + " steps=" + steps.to_string(),
        )
      }
    }
  }
}

///|
test "request validation precedes an expired work budget" {
  let model = model_of(
    "model\n  schema 1.1\ntype user\ntype document\n  relations\n    define viewer: [user]",
  )
  let store = @store.MemoryStore::new()
  let base = @engine.Engine::new(model, store as &@fga.TupleReader)
  let operations : Array[(@engine.Engine) -> Unit raise @fga.FgaError] = [
    e => ignore(e.check("document:1", "missing", "user:1")),
    e => ignore(e.check_with("document:1", "missing", "user:1", Map([]), [])),
    e => {
      ignore(
        e.check_request(
          @engine.CheckRequest::new("document:1", "missing", "user:1"),
        ),
      )
    },
    e => ignore(e.list_objects("document", "missing", "user:1", Map([]), [])),
    e => ignore(e.list_users("document:1", "missing", ["user"], Map([]), [])),
    e => ignore(e.expand_json("document:1", "missing", [])),
    e => ignore(e.explain_check("document:1", "missing", "user:1", Map([]), [])),
  ]
  for i in 0..<operations.length() {
    let operation = operations[i]
    let expected = if i != 3 && i != 4 {
      @fga.ERR_VALIDATION
    } else {
      @fga.ERR_RELATION_NOT_FOUND
    }
    for steps in [-2147483648, -1, 0, 1] {
      let e = base.with_budget(@fga.ExecutionBudget::new(steps~))
      let code = try {
        operation(e)
        0
      } catch {
        err => @fga.error_code(err)
      }
      assert_eq(code, expected)
    }
    let e = base.with_budget(@fga.ExecutionBudget::new(cancelled=fn() { true }))
    let code = try {
      operation(e)
      0
    } catch {
      err => @fga.error_code(err)
    }
    assert_eq(code, expected)
  }
  let e = base.with_budget(@fga.ExecutionBudget::new(steps=0))
  let batch = e.batch_check([
    @engine.CheckRequest::new("document:1", "missing", "user:1"),
  ])
  assert_eq(batch[0].error_code, Some(@fga.ERR_VALIDATION))
}

///|
test "numeric Local opt in survives named inline contextual list and budget copies" {
  for inline in [false, true] {
    let condition_name = if inline { "$expression" } else { "enabled" }
    let expression = "timestamp('2026-03-08T10:00:00Z').getHours('Local') == 15"
    let model = model_of(
      "model\n  schema 1.1\ntype user\ntype document\n  relations\n    define viewer: [user with " +
      condition_name +
      "]" +
      (if inline { "" } else { "\ncondition enabled() { " + expression + " }" }),
    )
    let store = @store.MemoryStore::new()
    let tuple : @fga.Tuple = {
      object: "document:1",
      relation: "viewer",
      user: "user:1",
      condition: Some({
        name: condition_name,
        context: if inline {
          Map([("expression", @fga.VString(expression))])
        } else {
          Map([])
        },
      }),
    }
    for allow in [false, true] {
      let engine = @engine.Engine::new(
        model,
        store as &@fga.TupleReader,
        condition_local_timezone=Some("+05:30"),
        condition_allow_numeric_local_timezone=allow,
      ).with_budget(@fga.ExecutionBudget::new(steps=10000))
      assert_eq(
        engine.check_with("document:1", "viewer", "user:1", Map([]), [tuple]),
        allow,
      )
      assert_eq(
        engine.list_objects("document", "viewer", "user:1", Map([]), [tuple]),
        if allow {
          ["document:1"]
        } else {
          []
        },
      )
      assert_eq(
        engine.list_users("document:1", "viewer", ["user"], Map([]), [tuple]),
        if allow {
          ["user:1"]
        } else {
          []
        },
      )
    }
  }
}

///|
fn numeric_local_engine(allow : Bool?) -> @engine.Engine {
  let model = model_of(
    "model\n  schema 1.1\ntype user\ntype document\n  relations\n    define viewer: [user with enabled]\ncondition enabled() { timestamp('2026-03-08T10:00:00Z').getHours('Local') == 15 }",
  )
  let store = @store.MemoryStore::new()
  ignore(
    store.write({
      object: "document:1",
      relation: "viewer",
      user: "user:1",
      condition: Some({ name: "enabled", context: Map([]), }),
    }),
  )
  match allow {
    None =>
      @engine.Engine::new(
        model,
        store as &@fga.TupleReader,
        condition_local_timezone=Some("+05:30"),
      )
    Some(flag) =>
      @engine.Engine::new(
        model,
        store as &@fga.TupleReader,
        condition_local_timezone=Some("+05:30"),
        condition_allow_numeric_local_timezone=flag,
      )
  }
}

///|
test "Engine Check numeric Local defaults off and honours explicit opt in" {
  for allow in [None, Some(false), Some(true)] {
    assert_eq(
      numeric_local_engine(allow).check("document:1", "viewer", "user:1"),
      allow == Some(true),
    )
  }
}

///|
test "Engine ListObjects numeric Local defaults off and honours explicit opt in" {
  for allow in [None, Some(false), Some(true)] {
    assert_eq(
      numeric_local_engine(allow).list_objects(
        "document",
        "viewer",
        "user:1",
        Map([]),
        [],
      ),
      if allow == Some(true) {
        ["document:1"]
      } else {
        []
      },
    )
  }
}

///|
test "Engine ListUsers numeric Local defaults off and honours explicit opt in" {
  for allow in [None, Some(false), Some(true)] {
    assert_eq(
      numeric_local_engine(allow).list_users(
        "document:1",
        "viewer",
        ["user"],
        Map([]),
        [],
      ),
      if allow == Some(true) {
        ["user:1"]
      } else {
        []
      },
    )
  }
}
