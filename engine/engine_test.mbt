///|
fn tup(object : String, relation : String, user : String) -> @fga.Tuple {
  @fga.Tuple::{ object, relation, user, condition: None, }
}

///|
fn model_of(source : String) -> @fga.AuthModel {
  @dsl.parse_model(source) catch {
    @fga.FgaError(..) as e => abort(@fga.format_error(e))
  }
}

///|
fn engine_of(source : String, tuples : Array[@fga.Tuple]) -> @engine.Engine {
  let model = model_of(source)
  let store = @store.MemoryStore::new()
  let _ = store.write_all(tuples)
  @engine.Engine::new(model, store as &@fga.TupleReader)
}

///|
fn status_of(result : () -> Bool raise @fga.FgaError) -> String {
  try {
    if result() {
      "true"
    } else {
      "false"
    }
  } catch {
    @fga.FgaError(..) as e => "E" + @fga.error_code(e).to_string()
  }
}

///|
fn list_status(f : () -> Array[String] raise @fga.FgaError) -> String {
  try {
    let _ = f()
    "ok"
  } catch {
    @fga.FgaError(..) as e => "E" + @fga.error_code(e).to_string()
  }
}

///|
let demo_model : String =
  #|model
  #|  schema 1.1
  #|type user
  #|
  #|type group
  #|  relations
  #|    define member: [user, user:*]
  #|
  #|type folder
  #|  relations
  #|    define owner: [user]
  #|    define viewer: [user, group#member] or owner
  #|
  #|type document
  #|  relations
  #|    define parent: [folder]
  #|    define editor: [user]
  #|    define viewer: [user] or editor or viewer from parent
  #|    define blocked: [user]
  #|    define can_view: viewer but not blocked
  #|    define public_viewer: [group#member]
  #|

///|
fn demo_tuples() -> Array[@fga.Tuple] {
  [
    tup("group:eng", "member", "user:alice"),
    tup("group:all", "member", "user:*"),
    tup("folder:f1", "owner", "user:bob"),
    tup("folder:f1", "viewer", "group:eng#member"),
    tup("document:1", "parent", "folder:f1"),
    tup("document:1", "editor", "user:carol"),
    tup("document:1", "blocked", "user:carol"),
    tup("document:2", "viewer", "user:dave"),
    tup("document:3", "public_viewer", "group:all#member"),
  ]
}

///|
test "check direct computed ttu union exclusion" {
  let engine = engine_of(demo_model, demo_tuples())
  inspect(engine.check("document:2", "viewer", "user:dave"), content="true")
  inspect(engine.check("document:2", "viewer", "user:alice"), content="false")
  // editor
  inspect(engine.check("document:1", "viewer", "user:carol"), content="true")
  // folder owner through tuple-to-userset union
  inspect(engine.check("document:1", "viewer", "user:bob"), content="true")
  // group membership through folder viewer userset restriction
  inspect(engine.check("document:1", "viewer", "user:alice"), content="true")
  // exclusion
  inspect(engine.check("document:1", "can_view", "user:carol"), content="false")
  inspect(engine.check("document:1", "can_view", "user:bob"), content="true")
}

///|
test "check wildcard" {
  let engine = engine_of(demo_model, demo_tuples())
  inspect(
    engine.check("document:3", "public_viewer", "user:zed"),
    content="true",
  )
  inspect(engine.check("document:1", "viewer", "user:zed"), content="false")
  inspect(engine.check("group:all", "member", "user:zed"), content="true")
}

///|
test "check contextual tuples" {
  let engine = engine_of(demo_model, demo_tuples())
  let contextual = [tup("document:9", "viewer", "user:zoe")]
  inspect(
    engine.check_with("document:9", "viewer", "user:zoe", Map([]), contextual),
    content="true",
  )
  inspect(
    status_of(() => engine.check("document:9", "viewer", "user:zoe")),
    content="false",
  )
  let invalid = [tup("document:9", "viewer", "user:*")]
  inspect(
    status_of(() => {
      engine.check_with("document:9", "viewer", "user:zoe", Map([]), invalid)
    }),
    content="E2027",
  )
}

///|
test "check validation errors" {
  let engine = engine_of(demo_model, demo_tuples())
  inspect(
    status_of(() => engine.check("user:alice", "viewer", "user:bob")),
    content="E2000",
  )
  inspect(
    status_of(() => engine.check("document:1", "viewer", "unknown:x")),
    content="E2000",
  )
  inspect(
    status_of(() => engine.check("document:1", "viewer", "a:b:c")),
    content="E2000",
  )
  inspect(
    status_of(() => engine.check("document:1", "viewer", "document:1#viewer")),
    content="true",
  )
}

///|
test "conditions and context" {
  let model =
    #|model
    #|  schema 1.1
    #|type user
    #|type meeting
    #|  relations
    #|    define attendee: [user with in_office]
    #|condition in_office(hour: int) {
    #|  hour >= 9 && hour < 17
    #|}
  let conditioned = @fga.Tuple::{
    object: "meeting:1",
    relation: "attendee",
    user: "user:erin",
    condition: Some(@fga.TupleCondition::{
      name: "in_office",
      context: Map([]),
    }),
  }
  let engine = engine_of(model, [conditioned])
  let at_ten = Map([("hour", Json::number(10.0))])
  let at_twenty = Map([("hour", Json::number(20.0))])
  inspect(
    engine.check_with("meeting:1", "attendee", "user:erin", at_ten, []),
    content="true",
  )
  inspect(
    engine.check_with("meeting:1", "attendee", "user:erin", at_twenty, []),
    content="false",
  )
  inspect(
    status_of(() => engine.check("meeting:1", "attendee", "user:erin")),
    content="E2000",
  )
}

///|
test "inline expression condition" {
  let model =
    #|model
    #|  schema 1.1
    #|type user
    #|type document
    #|  relations
    #|    define viewer: [user with $expression]
  let conditioned = @fga.Tuple::{
    object: "document:1",
    relation: "viewer",
    user: "user:alice",
    condition: Some(@fga.TupleCondition::{
      name: "$expression",
      context: Map([
        ("expression", @fga.VString("dept == 'eng'")),
        ("parameters", @fga.VMap(Map([("dept", @fga.VString("string"))]))),
      ]),
    }),
  }
  let engine = engine_of(model, [conditioned])
  let eng = Map([("dept", Json::string("eng"))])
  let sales = Map([("dept", Json::string("sales"))])
  inspect(
    engine.check_with("document:1", "viewer", "user:alice", eng, []),
    content="true",
  )
  inspect(
    engine.check_with("document:1", "viewer", "user:alice", sales, []),
    content="false",
  )
}

///|
test "list objects and users" {
  let engine = engine_of(demo_model, demo_tuples())
  let objects = engine.list_objects(
    "document",
    "viewer",
    "user:alice",
    Map([]),
    [],
  )
  inspect(objects.join(","), content="document:1")
  let documents = engine.list_objects(
    "document",
    "can_view",
    "user:bob",
    Map([]),
    [],
  )
  inspect(documents.join(","), content="document:1")
  let users = engine.list_users("document:1", "viewer", ["user"], Map([]), [])
  inspect(users.join(","), content="user:alice,user:bob,user:carol")
  let wildcard_users = engine.list_users(
    "document:3",
    "public_viewer",
    ["user"],
    Map([]),
    [],
  )
  inspect(wildcard_users.join(","), content="user:*")
  let groups = engine.list_users(
    "document:3",
    "public_viewer",
    ["group#member"],
    Map([]),
    [],
  )
  inspect(groups.join(","), content="group:all#member")
}

///|
test "list users userset inclusion through ttu" {
  let model =
    #|model
    #|  schema 1.1
    #|type user
    #|type folder
    #|  relations
    #|    define writer: [user]
    #|    define editor: [user]
    #|    define viewer: writer or editor
    #|type document
    #|  relations
    #|    define parent: [folder]
    #|    define viewer: viewer from parent
  let engine = engine_of(model, [
    tup("document:1", "parent", "folder:X"),
    tup("folder:X", "writer", "user:aardvark"),
    tup("folder:X", "editor", "user:badger"),
  ])
  let users = engine.list_users("document:1", "viewer", ["user"], Map([]), [])
  inspect(users.join(","), content="user:aardvark,user:badger")
  let writers = engine.list_users(
    "document:1",
    "viewer",
    ["folder#writer"],
    Map([]),
    [],
  )
  inspect(writers.join(","), content="folder:X#writer")
  let viewers = engine.list_users(
    "document:1",
    "viewer",
    ["folder#viewer"],
    Map([]),
    [],
  )
  inspect(viewers.join(","), content="folder:X#viewer")
}

///|
test "list validation errors" {
  let engine = engine_of(demo_model, demo_tuples())
  inspect(
    list_status(() => {
      engine.list_objects("unknown", "viewer", "user:a", Map([]), [])
    }),
    content="E2021",
  )
  inspect(
    list_status(() => {
      engine.list_objects("document", "unknown", "user:a", Map([]), [])
    }),
    content="E2022",
  )
  inspect(
    list_status(() => {
      engine.list_users("document:1", "viewer", ["unknown"], Map([]), [])
    }),
    content="E2021",
  )
  inspect(
    list_status(() => {
      engine.list_users("document:1", "viewer", ["document#unknown"], Map([]), [])
    }),
    content="E2022",
  )
}

///|
test "cycles resolve to false" {
  let model =
    #|model
    #|  schema 1.1
    #|type user
    #|type document
    #|  relations
    #|    define editor: [user, document#viewer]
    #|    define viewer: [document#editor] or editor
  let engine = engine_of(model, [
    tup("document:1", "editor", "document:1#viewer"),
    tup("document:1", "viewer", "document:1#editor"),
  ])
  inspect(engine.check("document:1", "viewer", "user:jon"), content="false")
}

///|
test "exclusion with cycle on subtract side is false" {
  let model =
    #|model
    #|  schema 1.1
    #|type user
    #|type document
    #|  relations
    #|    define restricted: [user, document#viewer]
    #|    define viewer: [user] but not restricted
  let engine = engine_of(model, [
    tup("document:1", "viewer", "user:jon"),
    tup("document:1", "restricted", "document:1#viewer"),
  ])
  inspect(engine.check("document:1", "viewer", "user:jon"), content="false")
}

///|
test "depth limit raises 2002" {
  let model = @fga.AuthModel::new("1.1")
  let resource = @fga.TypeDefinition::new("resource")
  resource.set_relation("a0", @fga.This, [
    @fga.TypeRestriction::{
      type_name: "user",
      relation: None,
      wildcard: false,
      condition: None,
    },
  ])
  let mut previous = "a0"
  for i in 1..<27 {
    let name = "a" + i.to_string()
    resource.set_relation(name, @fga.This, [
      @fga.TypeRestriction::{
        type_name: "resource",
        relation: Some(previous),
        wildcard: false,
        condition: None,
      },
    ])
    previous = name
  }
  resource.set_relation("can_view", @fga.Computed(previous), [])
  model.add_type(@fga.TypeDefinition::new("user"))
  model.add_type(resource)
  let store = @store.MemoryStore::new()
  for i in 1..<27 {
    let _ = store.write(
      tup(
        "resource:1",
        "a" + i.to_string(),
        "resource:1#a" + (i - 1).to_string(),
      ),
    )
  }
  let engine = @engine.Engine::new(model, store as &@fga.TupleReader)
  inspect(
    status_of(() => engine.check("resource:1", "can_view", "user:maria")),
    content="E2002",
  )
}

///|
test "explain produces witness path" {
  let engine = engine_of(demo_model, demo_tuples())
  let result = engine.explain_check(
    "document:1",
    "viewer",
    "user:alice",
    Map([]),
    [],
  )
  inspect(result.allowed, content="true")
  inspect(result.paths.length() > 0, content="true")
  inspect(result.paths[0].contains("document:1#viewer"), content="true")
}

///|
test "expand builds rewrite tree" {
  let engine = engine_of(demo_model, demo_tuples())
  let tree = engine.expand_json("document:1", "viewer", [])
  inspect(tree.stringify().contains("tupleToUserset"), content="true")
  inspect(tree.stringify().contains("folder:f1"), content="true")
}
