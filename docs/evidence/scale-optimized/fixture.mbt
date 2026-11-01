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
  let n = number(args[args.length() - 2])
  let fan = number(args[args.length() - 1])
  let store = @store.MemoryStore::new()
  let tuple = fn(o, u) {
    @fga.Tuple::{
      object: o,
      relation: if o.has_prefix("group:") {
        "member"
      } else {
        "viewer"
      },
      user: u,
      condition: None,
    }
  }
  // 20 levels, exact tuple count; deterministic LCG chooses unrelated users.
  for i in 0..<20 {
    let _ = store.write(
      tuple(
        "group:" + i.to_string(),
        if i == 0 {
          "user:alice"
        } else {
          "group:" + (i - 1).to_string() + "#member"
        },
      ),
    )
  }
  let mut seed = 20261101U
  for i in 20..<n {
    seed = seed * 1664525U + 1013904223U
    let _ = store.write(
      if i < fan + 20 {
        tuple("document:" + (i - 20).to_string(), "group:19#member")
      } else {
        tuple(
          "group:noise" + i.to_string(),
          "user:" + (seed % 997U).to_string(),
        )
      },
    )
  }
  let model = @dsl.parse_model(
    "model\n  schema 1.1\ntype user\ntype group\n  relations\n    define member: [user, group#member]\ntype document\n  relations\n    define viewer: [group#member]",
  ) catch {
    _ => abort("model")
  }
  let engine = @engine.Engine::new(model, store as &@fga.TupleReader)
  for i in 0..<33 {
    let clock = @bench.monotonic_clock_start()
    let ok = engine.check("document:0", "viewer", "user:alice") catch {
      _ => abort("check")
    }
    let us = @bench.monotonic_clock_end(clock)
    if !ok {
      abort("check result")
    }
    if i >= 3 {
      println("check," + us.to_string())
    }
  }
  for i in 0..<33 {
    let clock = @bench.monotonic_clock_start()
    let objects = engine.list_objects(
      "document",
      "viewer",
      "user:alice",
      Map([]),
      [],
    ) catch {
      _ => abort("list")
    }
    let us = @bench.monotonic_clock_end(clock)
    if objects.length() != fan {
      abort("list result")
    }
    if i >= 3 {
      println("list," + us.to_string())
    }
  }
}
