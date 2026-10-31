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
