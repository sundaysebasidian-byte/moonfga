// Minimal library embedding example: build a model, write a tuple, check it.

///|
fn main {
  let model = @dsl.parse_model(
    "model\n  schema 1.1\n\ntype user\n\ntype group\n  relations\n    define member: [user]\n\ntype document\n  relations\n    define viewer: [user, group#member]\n",
  ) catch {
    @fga.FgaError(..) as err => {
      println("model error: " + @fga.error_message(err))
      return
    }
  }
  let store = @store.MemoryStore::new()
  let _ = store.write(@fga.Tuple::{
    object: "group:eng",
    relation: "member",
    user: "user:anne",
    condition: None,
  })
  let _ = store.write(@fga.Tuple::{
    object: "document:roadmap",
    relation: "viewer",
    user: "group:eng#member",
    condition: None,
  })
  let engine = @engine.Engine::new(model, store as &@fga.TupleReader)
  let allowed = engine.check("document:roadmap", "viewer", "user:anne") catch {
    @fga.FgaError(..) as err => {
      println("check error: " + @fga.error_message(err))
      return
    }
  }
  println("anne can view roadmap: " + allowed.to_string())
}
