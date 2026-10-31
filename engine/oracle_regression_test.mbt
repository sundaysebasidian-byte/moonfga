// Original seeded oracle counterexamples, frozen against OpenFGA v1.22.1.
// Each case asserts the complete ListUsers result, including wildcard markers.

///|
test "official v1.22.1 ListUsers seed 314159 case 29" {
  let engine = engine_of(
    "model\n  schema 1.1\ntype user\ntype group\n  relations\n    define member: [user, group#member]\ntype document\n  relations\n    define reader: [user, user:*, group#member]\n    define writer: [user, user:*, group#member]\n    define blocked: [user, user:*, group#member]\n    define parent: [document]\n    define viewer: ((reader and writer) or viewer from parent)",
    [
      tup("group:1", "member", "user:1"),
      tup("group:1", "member", "user:2"),
      tup("group:1", "member", "user:3"),
      tup("group:1", "member", "group:0#member"),
      tup("group:2", "member", "user:3"),
      tup("document:0", "reader", "user:*"),
      tup("document:0", "writer", "user:2"),
      tup("document:0", "writer", "user:*"),
      tup("document:0", "blocked", "user:1"),
      tup("document:0", "blocked", "user:*"),
      tup("document:0", "blocked", "group:2#member"),
      tup("document:1", "reader", "user:3"),
      tup("document:1", "blocked", "user:3"),
      tup("document:2", "reader", "user:0"),
      tup("document:2", "writer", "user:0"),
      tup("document:2", "writer", "user:1"),
      tup("document:2", "writer", "user:3"),
      tup("document:2", "blocked", "user:0"),
      tup("document:2", "blocked", "user:2"),
      tup("document:2", "blocked", "user:*"),
      tup("document:2", "parent", "document:1"),
      tup("document:3", "reader", "user:0"),
      tup("document:3", "reader", "user:*"),
      tup("document:3", "reader", "group:2#member"),
      tup("document:3", "writer", "user:*"),
      tup("document:3", "blocked", "user:*"),
      tup("document:3", "parent", "document:2"),
    ],
  )
  assert_eq(engine.list_users("document:3", "viewer", ["user"], Map([]), []), [
    "user:*", "user:0", "user:3",
  ])
}

///|
test "official v1.22.1 ListUsers seed 314159 case 173" {
  let engine = engine_of(
    "model\n  schema 1.1\ntype user\ntype group\n  relations\n    define member: [user, group#member]\ntype document\n  relations\n    define reader: [user, user:*, group#member]\n    define writer: [user, user:*, group#member]\n    define blocked: [user, user:*, group#member]\n    define parent: [document]\n    define viewer: (reader and writer)",
    [
      tup("group:0", "member", "user:0"),
      tup("group:0", "member", "user:1"),
      tup("group:0", "member", "user:2"),
      tup("group:1", "member", "group:0#member"),
      tup("group:2", "member", "user:0"),
      tup("group:2", "member", "user:1"),
      tup("group:2", "member", "user:2"),
      tup("document:0", "reader", "user:3"),
      tup("document:0", "reader", "user:*"),
      tup("document:0", "writer", "user:*"),
      tup("document:1", "reader", "user:1"),
      tup("document:1", "reader", "group:2#member"),
      tup("document:1", "writer", "user:1"),
      tup("document:1", "blocked", "user:3"),
      tup("document:1", "blocked", "user:*"),
      tup("document:1", "parent", "document:0"),
      tup("document:2", "blocked", "user:2"),
      tup("document:2", "blocked", "group:2#member"),
      tup("document:2", "parent", "document:1"),
      tup("document:3", "writer", "user:0"),
      tup("document:3", "writer", "user:3"),
      tup("document:3", "writer", "group:2#member"),
    ],
  )
  assert_eq(engine.list_users("document:0", "viewer", ["user"], Map([]), []), [
    "user:*", "user:3",
  ])
}

///|
test "official v1.22.1 ListUsers seed 314159 case 241" {
  let engine = engine_of(
    "model\n  schema 1.1\ntype user\ntype group\n  relations\n    define member: [user, group#member]\ntype document\n  relations\n    define reader: [user, user:*, group#member]\n    define writer: [user, user:*, group#member]\n    define blocked: [user, user:*, group#member]\n    define parent: [document]\n    define viewer: (reader and writer)",
    [
      tup("group:0", "member", "user:1"),
      tup("group:1", "member", "user:1"),
      tup("group:1", "member", "group:0#member"),
      tup("group:2", "member", "user:2"),
      tup("group:2", "member", "user:3"),
      tup("group:2", "member", "group:1#member"),
      tup("document:0", "reader", "user:1"),
      tup("document:0", "reader", "user:*"),
      tup("document:0", "writer", "user:*"),
      tup("document:0", "writer", "group:2#member"),
      tup("document:1", "reader", "user:2"),
      tup("document:1", "writer", "user:0"),
      tup("document:1", "blocked", "user:0"),
      tup("document:1", "blocked", "user:3"),
      tup("document:2", "reader", "user:1"),
      tup("document:3", "writer", "user:2"),
      tup("document:3", "blocked", "user:0"),
      tup("document:3", "blocked", "user:*"),
      tup("document:3", "blocked", "group:2#member"),
    ],
  )
  assert_eq(engine.list_users("document:0", "viewer", ["user"], Map([]), []), [
    "user:*", "user:1", "user:2", "user:3",
  ])
}

///|
test "official v1.22.1 ListUsers seed 314159 case 531" {
  let engine = engine_of(
    "model\n  schema 1.1\ntype user\ntype group\n  relations\n    define member: [user, group#member]\ntype document\n  relations\n    define reader: [user, user:*, group#member]\n    define writer: [user, user:*, group#member]\n    define blocked: [user, user:*, group#member]\n    define parent: [document]\n    define viewer: (reader and writer)",
    [
      tup("group:0", "member", "user:3"),
      tup("group:1", "member", "user:0"),
      tup("group:1", "member", "group:0#member"),
      tup("group:2", "member", "group:1#member"),
      tup("document:0", "reader", "user:3"),
      tup("document:0", "reader", "user:*"),
      tup("document:0", "writer", "user:2"),
      tup("document:0", "writer", "user:3"),
      tup("document:0", "writer", "user:*"),
      tup("document:0", "blocked", "user:0"),
      tup("document:0", "blocked", "user:*"),
      tup("document:0", "blocked", "group:2#member"),
      tup("document:1", "writer", "group:2#member"),
      tup("document:1", "blocked", "user:2"),
      tup("document:1", "blocked", "user:3"),
      tup("document:1", "blocked", "user:*"),
      tup("document:1", "parent", "document:0"),
      tup("document:2", "reader", "user:1"),
      tup("document:2", "reader", "user:3"),
      tup("document:2", "reader", "group:2#member"),
      tup("document:2", "writer", "user:1"),
      tup("document:2", "writer", "user:*"),
      tup("document:2", "blocked", "user:3"),
      tup("document:2", "parent", "document:1"),
      tup("document:3", "reader", "user:2"),
      tup("document:3", "blocked", "group:2#member"),
      tup("document:3", "parent", "document:2"),
    ],
  )
  assert_eq(engine.list_users("document:0", "viewer", ["user"], Map([]), []), [
    "user:*", "user:2", "user:3",
  ])
}

///|
test "official v1.22.1 ListUsers seed 314159 case 587" {
  let engine = engine_of(
    "model\n  schema 1.1\ntype user\ntype group\n  relations\n    define member: [user, group#member]\ntype document\n  relations\n    define reader: [user, user:*, group#member]\n    define writer: [user, user:*, group#member]\n    define blocked: [user, user:*, group#member]\n    define parent: [document]\n    define viewer: (reader and writer)",
    [
      tup("group:0", "member", "user:2"),
      tup("group:0", "member", "user:3"),
      tup("group:1", "member", "user:2"),
      tup("group:2", "member", "user:1"),
      tup("group:2", "member", "user:2"),
      tup("group:2", "member", "user:3"),
      tup("group:2", "member", "group:1#member"),
      tup("document:0", "reader", "user:1"),
      tup("document:0", "writer", "user:0"),
      tup("document:0", "writer", "user:1"),
      tup("document:0", "writer", "group:2#member"),
      tup("document:0", "blocked", "user:0"),
      tup("document:0", "blocked", "user:1"),
      tup("document:1", "reader", "user:0"),
      tup("document:1", "reader", "user:2"),
      tup("document:1", "writer", "user:2"),
      tup("document:1", "writer", "user:*"),
      tup("document:1", "blocked", "group:2#member"),
      tup("document:2", "reader", "user:*"),
      tup("document:2", "writer", "user:*"),
      tup("document:2", "writer", "group:2#member"),
      tup("document:2", "blocked", "user:2"),
      tup("document:2", "blocked", "user:*"),
      tup("document:3", "reader", "user:*"),
      tup("document:3", "writer", "user:0"),
      tup("document:3", "blocked", "user:3"),
      tup("document:3", "parent", "document:2"),
    ],
  )
  assert_eq(engine.list_users("document:2", "viewer", ["user"], Map([]), []), [
    "user:*", "user:1", "user:2", "user:3",
  ])
}

///|
test "official v1.22.1 ListUsers seed 314159 case 663" {
  let engine = engine_of(
    "model\n  schema 1.1\ntype user\ntype group\n  relations\n    define member: [user, group#member]\ntype document\n  relations\n    define reader: [user, user:*, group#member]\n    define writer: [user, user:*, group#member]\n    define blocked: [user, user:*, group#member]\n    define parent: [document]\n    define viewer: (reader and writer)",
    [
      tup("group:0", "member", "user:0"),
      tup("group:0", "member", "user:1"),
      tup("group:0", "member", "user:2"),
      tup("group:1", "member", "user:1"),
      tup("group:1", "member", "user:2"),
      tup("group:1", "member", "user:3"),
      tup("group:1", "member", "group:0#member"),
      tup("group:2", "member", "user:1"),
      tup("group:2", "member", "group:1#member"),
      tup("document:0", "reader", "user:1"),
      tup("document:1", "reader", "user:*"),
      tup("document:1", "reader", "group:2#member"),
      tup("document:1", "writer", "user:1"),
      tup("document:1", "writer", "user:*"),
      tup("document:2", "writer", "user:3"),
      tup("document:2", "blocked", "user:1"),
      tup("document:3", "reader", "user:2"),
      tup("document:3", "writer", "user:0"),
      tup("document:3", "writer", "user:2"),
      tup("document:3", "writer", "group:2#member"),
      tup("document:3", "blocked", "user:3"),
      tup("document:3", "parent", "document:2"),
    ],
  )
  assert_eq(engine.list_users("document:1", "viewer", ["user"], Map([]), []), [
    "user:*", "user:0", "user:1", "user:2", "user:3",
  ])
}

///|
test "official v1.22.1 ListUsers seed 314159 case 679" {
  let engine = engine_of(
    "model\n  schema 1.1\ntype user\ntype group\n  relations\n    define member: [user, group#member]\ntype document\n  relations\n    define reader: [user, user:*, group#member]\n    define writer: [user, user:*, group#member]\n    define blocked: [user, user:*, group#member]\n    define parent: [document]\n    define viewer: ((reader but not blocked) or viewer from parent)",
    [
      tup("group:0", "member", "user:2"),
      tup("group:0", "member", "user:3"),
      tup("group:1", "member", "user:0"),
      tup("group:1", "member", "user:2"),
      tup("group:1", "member", "group:0#member"),
      tup("group:2", "member", "user:0"),
      tup("document:0", "reader", "user:0"),
      tup("document:0", "reader", "user:1"),
      tup("document:0", "writer", "user:0"),
      tup("document:0", "writer", "user:2"),
      tup("document:0", "writer", "user:*"),
      tup("document:1", "reader", "user:0"),
      tup("document:1", "reader", "user:2"),
      tup("document:1", "reader", "user:3"),
      tup("document:1", "reader", "user:*"),
      tup("document:1", "reader", "group:2#member"),
      tup("document:1", "writer", "user:1"),
      tup("document:1", "writer", "user:3"),
      tup("document:1", "writer", "group:2#member"),
      tup("document:1", "blocked", "group:2#member"),
      tup("document:2", "reader", "user:*"),
      tup("document:2", "writer", "user:1"),
      tup("document:2", "writer", "user:*"),
      tup("document:2", "blocked", "user:2"),
      tup("document:3", "reader", "user:1"),
      tup("document:3", "reader", "user:2"),
      tup("document:3", "reader", "group:2#member"),
      tup("document:3", "blocked", "user:0"),
      tup("document:3", "blocked", "user:*"),
      tup("document:3", "parent", "document:2"),
    ],
  )
  assert_eq(engine.list_users("document:3", "viewer", ["user"], Map([]), []), [
    "user:*",
  ])
}

///|
test "official v1.22.1 ListUsers seed 314159 case 936" {
  let engine = engine_of(
    "model\n  schema 1.1\ntype user\ntype group\n  relations\n    define member: [user, group#member]\ntype document\n  relations\n    define reader: [user, user:*, group#member]\n    define writer: [user, user:*, group#member]\n    define blocked: [user, user:*, group#member]\n    define parent: [document]\n    define viewer: (reader and writer)",
    [
      tup("group:0", "member", "user:1"),
      tup("group:1", "member", "user:3"),
      tup("group:2", "member", "user:3"),
      tup("group:2", "member", "group:1#member"),
      tup("document:0", "reader", "user:2"),
      tup("document:0", "reader", "user:*"),
      tup("document:0", "reader", "group:2#member"),
      tup("document:0", "writer", "user:0"),
      tup("document:0", "writer", "user:1"),
      tup("document:0", "blocked", "user:0"),
      tup("document:0", "blocked", "user:1"),
      tup("document:0", "blocked", "group:2#member"),
      tup("document:1", "reader", "user:2"),
      tup("document:1", "writer", "user:3"),
      tup("document:1", "writer", "user:*"),
      tup("document:1", "parent", "document:0"),
      tup("document:2", "reader", "user:1"),
      tup("document:2", "reader", "user:2"),
      tup("document:2", "writer", "user:3"),
      tup("document:3", "reader", "user:0"),
      tup("document:3", "reader", "user:2"),
      tup("document:3", "reader", "user:3"),
      tup("document:3", "reader", "user:*"),
      tup("document:3", "reader", "group:2#member"),
      tup("document:3", "writer", "user:*"),
      tup("document:3", "blocked", "user:1"),
      tup("document:3", "blocked", "user:3"),
      tup("document:3", "parent", "document:2"),
    ],
  )
  assert_eq(engine.list_users("document:3", "viewer", ["user"], Map([]), []), [
    "user:*", "user:0", "user:2", "user:3",
  ])
}

///|
test "official v1.22.1 ListUsers seed 314159 case 988" {
  let engine = engine_of(
    "model\n  schema 1.1\ntype user\ntype group\n  relations\n    define member: [user, group#member]\ntype document\n  relations\n    define reader: [user, user:*, group#member]\n    define writer: [user, user:*, group#member]\n    define blocked: [user, user:*, group#member]\n    define parent: [document]\n    define viewer: (reader and writer)",
    [
      tup("group:0", "member", "user:1"),
      tup("group:1", "member", "user:1"),
      tup("group:2", "member", "user:2"),
      tup("document:0", "reader", "user:3"),
      tup("document:0", "reader", "user:*"),
      tup("document:0", "writer", "user:*"),
      tup("document:0", "blocked", "group:2#member"),
      tup("document:1", "writer", "user:2"),
      tup("document:1", "writer", "user:*"),
      tup("document:1", "writer", "group:2#member"),
      tup("document:2", "reader", "user:1"),
      tup("document:2", "reader", "user:2"),
      tup("document:2", "blocked", "user:1"),
      tup("document:2", "parent", "document:1"),
      tup("document:3", "reader", "user:3"),
      tup("document:3", "writer", "user:0"),
      tup("document:3", "writer", "user:3"),
      tup("document:3", "writer", "group:2#member"),
      tup("document:3", "parent", "document:2"),
    ],
  )
  assert_eq(engine.list_users("document:0", "viewer", ["user"], Map([]), []), [
    "user:*", "user:3",
  ])
}
