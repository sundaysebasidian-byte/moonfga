///|
fn contract(reader : &@fga.TupleReader) -> Unit raise {
  assert_eq(reader.read("document:missing", "viewer").length(), 0)
  assert_eq(reader.all_objects("absent").length(), 0)
  assert_eq(reader.read("document:a", "viewer").length(), 3)
  assert_eq(reader.read_userset("document:a", "viewer").length(), 1)
  assert_eq(reader.all_objects("document"), ["document:a"])
  let users = reader.all_users()
  users.sort()
  assert_eq(users, ["user:*", "user:alice", "group:g#member"])
  // Returned collections are owned by the caller.
  reader.read("document:a", "viewer").clear()
  reader.all_objects("document").clear()
  assert_eq(reader.read("document:a", "viewer").length(), 3)
  assert_eq(reader.all_objects("document").length(), 1)
  let model = @dsl.parse_model(
    "model\n  schema 1.1\ntype user\ntype group\n  relations\n    define member: [user]\ntype document\n  relations\n    define viewer: [user, user:*, group#member]",
  )
  let engine = @engine.Engine::new(model, reader)
  assert_true(engine.check("document:a", "viewer", "user:alice"))
  assert_eq(
    engine.list_objects("document", "viewer", "user:alice", Map([]), []),
    ["document:a"],
  )
}

///|
test "host contract: exact reads, usersets, wildcards, owned arrays" {
  let rows = ["user:alice", "user:*", "group:g#member"].map(fn(user) {
    @fga.Tuple::{
      object: "document:a",
      relation: "viewer",
      user,
      condition: None,
    }
  })
  let snapshot = load_snapshot(Ok(rows))
  rows.clear()
  contract(snapshot as &@fga.TupleReader)
}

///|
test "successful empty snapshot is an authorization miss" {
  let reader = load_snapshot(Ok([])) as &@fga.TupleReader
  assert_eq(reader.read("document:a", "viewer").length(), 0)
  assert_eq(reader.read_userset("document:a", "viewer").length(), 0)
  assert_eq(reader.all_objects("document"), [])
  assert_eq(reader.all_users(), [])
  let model = @dsl.parse_model(
    "model\n  schema 1.1\ntype user\ntype document\n  relations\n    define viewer: [user]",
  )
  let engine = @engine.Engine::new(model, reader)
  assert_false(engine.check("document:a", "viewer", "user:alice"))
  assert_eq(
    engine.list_objects("document", "viewer", "user:alice", Map([]), []),
    [],
  )
}

///|
test "failed host read prevents evaluation" {
  let mut message = ""
  try {
    let _ = load_snapshot(Err("database unavailable"))
  } catch {
    e => message = @fga.error_message(e)
  }
  assert_eq(message, "tuple host: database unavailable")
}

///|
test "host contract: conditional tuples keep name and parameters" {
  let snapshot = load_snapshot(
    Ok([
      @fga.Tuple::{
        object: "document:b",
        relation: "viewer",
        user: "user:bob",
        condition: Some(@fga.TupleCondition::{
          name: "in_office",
          context: Map([("office", @fga.CelValue::VString("hq"))]),
        }),
      },
    ]),
  )
  let reader = snapshot as &@fga.TupleReader
  let rows = reader.read("document:b", "viewer")
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].condition_name(), Some("in_office"))
  guard rows[0].condition is Some(cond) else { fail("condition dropped") }
  assert_eq(cond.context.length(), 1)
  let model = @dsl.parse_model(
    "model\n  schema 1.1\ntype user\ntype document\n  relations\n    define viewer: [user with in_office]\ncondition in_office(office: string, current: string) {\n  office == current\n}",
  )
  let engine = @engine.Engine::new(model, reader)
  assert_eq(
    engine.list_objects(
      "document",
      "viewer",
      "user:bob",
      Map([("current", Json::string("hq"))]),
      [],
    ),
    ["document:b"],
  )
  assert_eq(
    engine.list_objects(
      "document",
      "viewer",
      "user:bob",
      Map([("current", Json::string("remote"))]),
      [],
    ),
    [],
  )
}
