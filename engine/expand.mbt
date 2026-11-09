// Expand turns a relation rewrite into a tree for debugging and for clients
// that need the raw userset structure rather than an authorization decision.

///|
fn expand_rewrite(
  engine : Engine,
  object : String,
  relation : String,
  rewrite : @fga.Userset,
  depth : Int32,
  path : Array[String],
) -> Json raise @fga.FgaError {
  match rewrite {
    This =>
      Json::object(
        Map([
          ("type", Json::string("leaf")),
          ("users", Json::array(users_json(engine, object, relation))),
        ]),
      )
    Computed(target) => {
      let child = expand_relation(engine, object, target, depth + 1, path)
      Json::object(
        Map([
          ("type", Json::string("computed")),
          ("relation", Json::string(target)),
          ("child", child),
        ]),
      )
    }
    TupleToUserset(computed, tupleset) => {
      let children : Array[Json] = []
      let type_name = @fga.object_type(object)
      for tuple in engine.reader.read(object, tupleset) {
        match tuple_binding_spec(engine.model, type_name, tupleset, tuple) {
          TupleBindingSpec::Invalid => continue
          _ =>
            if is_concrete_user(tuple.user) {
              children.push(
                Json::object(
                  Map([
                    ("target", Json::string(tuple.user)),
                    (
                      "child",
                      expand_relation(
                        engine,
                        tuple.user,
                        computed,
                        depth + 1,
                        path,
                      ),
                    ),
                  ]),
                ),
              )
            }
        }
      }
      Json::object(
        Map([
          ("type", Json::string("tupleToUserset")),
          ("tupleset", Json::string(tupleset)),
          ("computed", Json::string(computed)),
          ("children", Json::array(children)),
        ]),
      )
    }
    Union(children) => {
      let nodes : Array[Json] = []
      for child in children {
        nodes.push(expand_rewrite(engine, object, relation, child, depth, path))
      }
      Json::object(
        Map([("type", Json::string("union")), ("children", Json::array(nodes))]),
      )
    }
    Intersection(children) => {
      let nodes : Array[Json] = []
      for child in children {
        nodes.push(expand_rewrite(engine, object, relation, child, depth, path))
      }
      Json::object(
        Map([
          ("type", Json::string("intersection")),
          ("children", Json::array(nodes)),
        ]),
      )
    }
    Difference(base, subtract) => {
      let base_node = expand_rewrite(
        engine, object, relation, base, depth, path,
      )
      let subtract_node = expand_rewrite(
        engine, object, relation, subtract, depth, path,
      )
      Json::object(
        Map([
          ("type", Json::string("difference")),
          ("base", base_node),
          ("subtract", subtract_node),
        ]),
      )
    }
  }
}

///|
fn users_json(
  engine : Engine,
  object : String,
  relation : String,
) -> Array[Json] {
  let type_name = @fga.object_type(object)
  let users : Array[Json] = []
  for tuple in engine.reader.read(object, relation) {
    match tuple_binding_spec(engine.model, type_name, relation, tuple) {
      TupleBindingSpec::Invalid => ()
      _ => users.push(Json::string(tuple.user))
    }
  }
  users
}

///|
fn expand_relation(
  engine : Engine,
  object : String,
  relation : String,
  depth : Int32,
  path : Array[String],
) -> Json raise @fga.FgaError {
  if depth > 25 {
    return Json::object(Map([("type", Json::string("depth_limit"))]))
  }
  let key = path_key(object, relation)
  for seen in path {
    if seen == key {
      return Json::object(Map([("type", Json::string("cycle"))]))
    }
  }
  let rewrite = engine.model.relation(@fga.object_type(object), relation)
  path.push(key)
  let result = expand_rewrite(engine, object, relation, rewrite, depth, path)
  let _ = path.pop()
  result
}

///|
/// Expands `object#relation` into a JSON userset tree.
pub fn Engine::expand_json(
  self : Engine,
  object : String,
  relation : String,
  contextual_tuples : Array[@fga.Tuple],
) -> Json raise @fga.FgaError {
  validate_check_object(self.model, object, relation)
  validate_contextual(self.model, contextual_tuples)
  let reader = self.reader_with(contextual_tuples)
  let engine = Engine::{
    model: self.model,
    reader,
    traces: self.traces,
    list_query: self.list_query,
    match_wildcard_users: self.match_wildcard_users,
    condition_cost_limit: self.condition_cost_limit,
    condition_cancelled: self.condition_cancelled,
    condition_local_timezone: self.condition_local_timezone,
  }
  expand_relation(engine, object, relation, 0, [])
}
