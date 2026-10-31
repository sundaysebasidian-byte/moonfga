///|
fn run_case(c : Json) -> Json raise @fga.FgaError {
  let model = @model.model_from_json(@fga.json_object_get(c, "model").unwrap())
  let store = @store.MemoryStore::new()
  let _ = store.write_all(
    @fga.tuples_from_json(@fga.json_object_get(c, "tuples")),
  )
  let engine = @engine.Engine::new(model, store as &@fga.TupleReader)
  let object = @fga.json_get_string(c, "object").unwrap()
  let user = @fga.json_get_string(c, "user").unwrap()
  let relation = @fga.json_get_string(c, "relation").unwrap()
  let contextual = @fga.tuples_from_json(@fga.json_object_get(c, "contextual"))
  let context = match @fga.json_object_get(c, "context") {
    Some(Object(m)) => m
    _ => Map([])
  }
  let result : Map[String, Json] = Map([])
  result["check"] = Json::boolean(
    engine.check_with(object, relation, user, context, contextual),
  ) catch {
    e => Json::string("E" + @fga.error_code(e).to_string())
  }
  result["list_objects"] = Json::array(
    engine
    .list_objects(@fga.object_type(object), relation, user, context, contextual)
    .map(Json::string),
  ) catch {
    e => Json::string("E" + @fga.error_code(e).to_string())
  }
  result["list_users"] = Json::array(
    engine
    .list_users(object, relation, ["user"], context, contextual)
    .map(Json::string),
  ) catch {
    e => Json::string("E" + @fga.error_code(e).to_string())
  }
  Json::object(result)
}

///|
fn main {
  let input = @fs.read_file_to_string(@env.args()[1]) catch {
    _ => abort("oracle input read/parse failed")
  }
  let data = @json.parse(input) catch {
    _ => abort("oracle input read/parse failed")
  }
  let cases = match data {
    Array(xs) => xs
    _ => abort("expected cases array")
  }
  let results = cases.map(fn(c) {
    run_case(c) catch {
      e => abort(@fga.format_error(e))
    }
  })
  println(Json::array(results).stringify())
}
