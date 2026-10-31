///|
fn tup(object : String, relation : String, user : String) -> @fga.Tuple {
  @fga.Tuple::{ object, relation, user, condition: None, }
}

///|
fn fixture() -> @engine.Engine raise {
  let model = @dsl.parse_model(
    "model\n  schema 1.1\ntype user\ntype group\n  relations\n    define member: [user, group#member]\ntype document\n  relations\n    define viewer: [group#member]",
  ) catch {
    e => abort(@fga.format_error(e))
  }
  let store = @store.MemoryStore::new()
  for i in 0..<10000 {
    let _ = store.write(
      tup("document:" + i.to_string(), "viewer", "group:9#member"),
    )
  }
  for i in 0..<10 {
    let user = if i == 0 {
      "user:alice"
    } else {
      "group:" + (i - 1).to_string() + "#member"
    }
    let _ = store.write(tup("group:" + i.to_string(), "member", user))
  }
  for i in 10..<90000 {
    let _ = store.write(tup("group:" + i.to_string(), "member", "user:noise"))
  }
  assert_eq(store.length(), 100000)
  @engine.Engine::new(model, store as &@fga.TupleReader)
}

///|
test "100k tuples, 10 groups: Check" (b : @bench.T) {
  let engine = fixture()
  assert_true(engine.check("document:0", "viewer", "user:alice"))
  b.bench(fn() {
    b.keep(
      engine.check("document:0", "viewer", "user:alice") catch {
        e => abort(@fga.format_error(e))
      },
    )
  })
}

///|
test "100k tuples, 10 groups: ListObjects" (b : @bench.T) {
  let engine = fixture()
  assert_eq(
    engine
    .list_objects("document", "viewer", "user:alice", Map([]), [])
    .length(),
    10000,
  )
  b.bench(fn() {
    b.keep(
      engine.list_objects("document", "viewer", "user:alice", Map([]), []) catch {
        e => abort(@fga.format_error(e))
      },
    )
  })
}
