///|
fn tuple(object : String, relation : String, user : String) -> @fga.Tuple {
  @fga.Tuple::{ object, relation, user, condition: None, }
}

///|
test "memory store write read delete" {
  let store = @store.MemoryStore::new()
  inspect(
    store.write(tuple("document:1", "viewer", "user:alice")),
    content="true",
  )
  inspect(
    store.write(tuple("document:1", "viewer", "user:alice")),
    content="false",
  )
  inspect(
    store.write(tuple("document:1", "editor", "user:bob")),
    content="true",
  )
  inspect(store.length(), content="2")
  inspect(store.read("document:1", "viewer").length(), content="1")
  inspect(store.read_by_user("user:alice").length(), content="1")
  inspect(
    store.delete(tuple("document:1", "viewer", "user:alice")),
    content="true",
  )
  inspect(
    store.delete(tuple("document:1", "viewer", "user:alice")),
    content="false",
  )
  inspect(store.length(), content="1")
  inspect(store.read("document:1", "viewer").length(), content="0")
  inspect(store.read_by_user("user:alice").length(), content="0")
}

///|
test "memory store indexes and usersets" {
  let store = @store.MemoryStore::new()
  let _ = store.write(tuple("document:1", "viewer", "group:eng#member"))
  let _ = store.write(tuple("document:2", "viewer", "user:alice"))
  let _ = store.write(tuple("folder:1", "viewer", "user:alice"))
  inspect(
    store.all_objects("document").join(","),
    content="document:1,document:2",
  )
  inspect(store.all_objects("folder").join(","), content="folder:1")
  inspect(store.all_users().join(","), content="group:eng#member,user:alice")
  inspect(store.read_userset("document:1", "viewer").length(), content="1")
  inspect(store.read_userset("document:2", "viewer").length(), content="0")
}

///|
test "conditional tuples are distinct" {
  let store = @store.MemoryStore::new()
  let base = tuple("document:1", "viewer", "user:alice")
  let conditioned = @fga.Tuple::{
    object: "document:1",
    relation: "viewer",
    user: "user:alice",
    condition: Some(@fga.TupleCondition::{ name: "is_ok", context: Map([]), }),
  }
  inspect(store.write(base), content="true")
  inspect(store.write(conditioned), content="true")
  inspect(store.length(), content="2")
}

///|
test "contextual store overlays tuples" {
  let base = @store.MemoryStore::new()
  let _ = base.write(tuple("document:1", "viewer", "user:alice"))
  let contextual = @store.ContextualStore::from_store(base, [
    tuple("document:1", "viewer", "user:bob"),
  ])
  let reader = contextual as &@fga.TupleReader
  inspect(reader.read("document:1", "viewer").length(), content="2")
  inspect(reader.all_users().join(","), content="user:bob,user:alice")
}

///|
test "object type index tracks last deletion clear and reinsertion" {
  let store = @store.MemoryStore::new()
  let a = tuple("document:a", "viewer", "user:a")
  let b = tuple("document:a", "editor", "user:b")
  let c = tuple("document:c", "viewer", "user:c")
  let _ = store.write_all([a, b, c, tuple("group:g", "member", "user:a")])
  assert_eq(store.all_objects("document"), ["document:a", "document:c"])
  let returned = store.all_objects("document")
  returned.clear()
  assert_eq(store.all_objects("document").length(), 2)
  assert_true(store.delete(a))
  assert_eq(store.all_objects("document").length(), 2)
  assert_true(store.delete(b))
  assert_eq(store.all_objects("document"), ["document:c"])
  assert_true(store.write(a))
  assert_eq(store.all_objects("document"), ["document:c", "document:a"])
  store.clear()
  assert_eq(store.all_objects("document").length(), 0)
  assert_true(store.write(a))
  assert_eq(store.all_objects("document"), ["document:a"])
}

///|
test "list reader combines distinct conditional bindings without mutating base" {
  let base = @store.MemoryStore::new()
  let t = tuple("document:1", "viewer", "user:a")
  let stored = @fga.Tuple::{
    ..t,
    condition: Some(@fga.TupleCondition::{
      name: "enabled",
      context: Map([("ok", @fga.VBool(true))]),
    }),
  }
  let overlay = @fga.Tuple::{
    ..t,
    condition: Some(@fga.TupleCondition::{
      name: "enabled",
      context: Map([("ok", @fga.VBool(false))]),
    }),
  }
  let _ = base.write(stored)
  let shadow = @store.ContextualStore::new(base as &@fga.TupleReader, [overlay])
  let combined = @store.ContextualStore::new(
    base as &@fga.TupleReader,
    [overlay],
    shadow=false,
  )
  assert_eq(shadow.read("document:1", "viewer").length(), 1)
  let rows = combined.read("document:1", "viewer")
  assert_eq(rows.length(), 2)
  assert_true(
    rows[0].condition.unwrap().context.get("ok") is Some(@fga.VBool(false)),
  )
  assert_true(
    rows[1].condition.unwrap().context.get("ok") is Some(@fga.VBool(true)),
  )
  rows.clear()
  assert_eq(combined.read("document:1", "viewer").length(), 2)
  assert_eq(base.length(), 1)
}
