///|
fn number(s : String) -> Int32 {
  let mut n = 0
  for c in s.iter() {
    n = n * 10 + c.to_int() - 48
  }
  n
}

///|
fn main {
  let args = @env.args()
  let n = number(args[args.length() - 3])
  let shape = args[args.length() - 2]
  let op = args[args.length() - 1]
  let depth = if shape == "group20" || shape == "ttu20" { 20 } else { 2 }
  let fan = if shape == "fan128" {
    128
  } else if shape == "fan16" {
    16
  } else {
    4
  }
  let group = shape.has_prefix("group")
  let ttu = shape.has_prefix("ttu")
  let wild = shape == "wildcard"
  let abac = shape == "abac"
  let both = shape == "intersection"
  let diff = shape == "difference"
  let model_text = "model\n  schema 1.1\ntype user\ntype group\n  relations\n    define member: [user, group#member]\ntype document\n  relations\n    define parent: [document]\n    define blocked: [user]\n    define editor: [user]\n    define reader: [user" +
    (if abac { " with enabled" } else { "" }) +
    ", user:*, group#member" +
    "]\n    define viewer: " +
    (if ttu {
      "reader or viewer from parent"
    } else if both {
      "reader and editor"
    } else if diff {
      "reader but not blocked"
    } else {
      "reader"
    }) +
    (if abac {
      "\ncondition enabled(hour: int) { hour >= 9 && hour < 17 }"
    } else {
      ""
    })
  let model = @dsl.parse_model(model_text) catch {
    e => abort(@fga.format_error(e))
  }
  let store = @store.MemoryStore::new()
  let put = fn(o, r, u) {
    let _ = store.write(@fga.Tuple::{
      object: o,
      relation: r,
      user: u,
      condition: if abac && r == "reader" {
        Some(@fga.TupleCondition::{ name: "enabled", context: Map([]), })
      } else {
        None
      },
    })
  }
  let ctx = Map([("hour", Json::number(10.0))])
  // Shared chain, fan users per leaf, many documents per subject. Rare is disjoint.
  let users = if wild { 1 } else { fan }
  if group || ttu {
    for j in 0..<users {
      put(
        if group {
          "group:0"
        } else {
          "document:base0"
        },
        if group {
          "member"
        } else {
          "reader"
        },
        "user:" + j.to_string(),
      )
    }
    for j in 1..<depth {
      put(
        (if group { "group:" } else { "document:base" }) + j.to_string(),
        if group {
          "member"
        } else {
          "parent"
        },
        (if group { "group:" } else { "document:base" }) +
        (j - 1).to_string() +
        (if group { "#member" } else { "" }),
      )
    }
  }
  let per = if group || ttu {
    1
  } else if both {
    users * 2
  } else if diff {
    users + 1
  } else {
    users
  }
  let docs = (n / 2 - store.length()) / per
  for i in 0..<docs {
    let o = "document:" + i.to_string()
    if group || ttu {
      put(
        o,
        if group {
          "reader"
        } else {
          "parent"
        },
        (if group { "group:" } else { "document:base" }) +
        (depth - 1).to_string() +
        (if group { "#member" } else { "" }),
      )
    } else {
      for j in 0..<users {
        put(o, "reader", if wild { "user:*" } else { "user:" + j.to_string() })
        if both {
          put(o, "editor", "user:" + j.to_string())
        }
      }
      if diff {
        put(o, "blocked", "user:blocked")
      }
    }
  }
  put("document:rare", "reader", "user:rare")
  if both {
    put("document:rare", "editor", "user:rare")
  }
  let mut seed = 20261106U
  while store.length() < n {
    seed = seed * 1664525U + 1013904223U
    put(
      "group:noise" + store.length().to_string(),
      "member",
      "user:noise" + (seed % 997U).to_string(),
    )
  }
  if store.length() != n {
    abort("tuple count")
  }
  let engine = @engine.Engine::new(model, store as &@fga.TupleReader)
  for i in 0..<35 {
    let start = @bench.monotonic_clock_start()
    let count = if op == "check_hit" || op == "check_miss" {
      if (engine.check_with(
          "document:0",
          "viewer",
          if op == "check_hit" {
            "user:0"
          } else {
            "user:absent"
          },
          ctx,
          [],
        ) catch {
          e => abort(@fga.format_error(e))
        }) {
        1
      } else {
        0
      }
    } else if op == "objects_many" || op == "objects_few" {
      (engine.list_objects(
        "document",
        "viewer",
        if op == "objects_many" {
          "user:0"
        } else {
          "user:rare"
        },
        ctx,
        [],
      ) catch {
        e => abort(@fga.format_error(e))
      }).length()
    } else {
      (engine.list_users(
        if op == "users_many" {
          "document:0"
        } else {
          "document:rare"
        },
        "viewer",
        ["user"],
        ctx,
        [],
      ) catch {
        e => abort(@fga.format_error(e))
      }).length()
    }
    let elapsed = @bench.monotonic_clock_end(start)
    let expected = if op == "check_hit" {
      1
    } else if op == "check_miss" {
      if wild {
        1
      } else {
        0
      }
    } else if op == "objects_many" {
      docs + (if ttu { depth } else { 0 })
    } else if op == "objects_few" {
      if wild {
        docs + 1
      } else {
        1
      }
    } else if op == "users_many" {
      users
    } else {
      1
    }
    if count != expected {
      abort(
        "result " +
        op +
        ": " +
        count.to_string() +
        " expected " +
        expected.to_string(),
      )
    }
    println(
      "sample," +
      i.to_string() +
      "," +
      elapsed.to_string() +
      "," +
      count.to_string(),
    )
  }
}
