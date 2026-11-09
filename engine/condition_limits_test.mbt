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
