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
