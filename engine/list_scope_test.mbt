///|
test "query scoped graph sees writes deletes clear and request overlays" {
  let model = @dsl.parse_model(
    "model\n  schema 1.1\ntype user\ntype group\n  relations\n    define member: [user, group#member]\ntype document\n  relations\n    define viewer: [group#member]",
  )
  let store = @store.MemoryStore::new()
  let engine = @engine.Engine::new(model, store as &@fga.TupleReader)
  let membership = @fga.Tuple::{
    object: "group:g",
    relation: "member",
    user: "user:a",
    condition: None,
  }
  let viewer = @fga.Tuple::{
    object: "document:d",
    relation: "viewer",
    user: "group:g#member",
    condition: None,
  }
  let list = fn(extra) raise {
    engine.list_objects("document", "viewer", "user:a", Map([]), extra)
  }
  assert_eq(list([]), [])
  assert_true(store.write(viewer))
  assert_eq(list([]), [])
  assert_true(store.write(membership))
  assert_eq(list([]), ["document:d"])
  assert_true(store.delete(membership))
  assert_eq(list([]), [])
  assert_eq(list([membership]), ["document:d"])
  assert_eq(list([]), [])
  assert_true(store.write(membership))
  assert_true(store.delete(viewer))
  assert_eq(list([]), [])
  assert_eq(list([viewer]), ["document:d"])
  assert_eq(list([]), [])
  store.clear()
  assert_eq(list([]), [])
}

///|
test "dependency discovery terminates on cycles and preserves userset identity" {
  let model = @dsl.parse_model(
    "model\n  schema 1.1\ntype user\ntype group\n  relations\n    define member: [user, group#member]\ntype document\n  relations\n    define viewer: [group#member]",
  )
  let store = @store.MemoryStore::new()
  let _ = store.write_all([
    @fga.Tuple::{
      object: "document:d",
      relation: "viewer",
      user: "group:a#member",
      condition: None,
    },
    @fga.Tuple::{
      object: "group:a",
      relation: "member",
      user: "group:b#member",
      condition: None,
    },
    @fga.Tuple::{
      object: "group:b",
      relation: "member",
      user: "group:a#member",
      condition: None,
    },
  ])
  let engine = @engine.Engine::new(model, store as &@fga.TupleReader)
  assert_eq(engine.list_objects("document", "viewer", "user:a", Map([]), []), [])
  assert_eq(
    engine.list_objects("document", "viewer", "group:b#member", Map([]), []),
    ["document:d"],
  )
  assert_eq(
    engine.list_objects("group", "member", "group:absent#member", Map([]), []),
    ["group:absent"],
  )
}
