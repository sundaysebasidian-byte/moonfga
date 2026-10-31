// Human-readable witness paths for Check decisions.

///|
pub(all) struct ExplainResult {
  allowed : Bool
  paths : Array[String]
}

///|
fn witness_key(object : String, relation : String, subject : String) -> String {
  object + "#" + relation + "@" + subject
}

///|
fn concat_traces(prefix : String, traces : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for trace in traces {
    out.push(prefix + " -> " + trace)
  }
  out
}

///|
fn Engine::witness(
  self : Engine,
  object : String,
  relation : String,
  subject : String,
  context : Map[String, Json],
  depth : Int32,
  path : Array[String],
) -> Array[String] raise @fga.FgaError {
  if depth > 25 {
    return []
  }
  let key = path_key(object, relation)
  for seen in path {
    if seen == key {
      return []
    }
  }
  if is_userset_user(subject) && subject == key {
    return [witness_key(object, relation, subject)]
  }
  let rewrite = self.model.relation(@fga.object_type(object), relation)
  path.push(key)
  let result = self.witness_rewrite(
    object, relation, rewrite, subject, context, depth, path,
  )
  let _ = path.pop()
  result
}

///|
fn Engine::witness_rewrite(
  self : Engine,
  object : String,
  relation : String,
  rewrite : @fga.Userset,
  subject : String,
  context : Map[String, Json],
  depth : Int32,
  path : Array[String],
) -> Array[String] raise @fga.FgaError {
  match rewrite {
    This => self.witness_direct(object, relation, subject, context, depth, path)
    Computed(target) => {
      let child = self.witness(
        object,
        target,
        subject,
        context,
        depth + 1,
        path,
      )
      if child.length() == 0 {
        []
      } else {
        concat_traces(object + "#" + relation + " -> computed " + target, child)
      }
    }
    TupleToUserset(computed, tupleset) => {
      let type_name = @fga.object_type(object)
      let mut best : Array[String] = []
      for tuple in self.reader.read(object, tupleset) {
        match tuple_binding_spec(self.model, type_name, tupleset, tuple) {
          TupleBindingSpec::Invalid => continue
          binding => {
            if !self.condition_holds(tuple, binding, context) {
              continue
            }
            if !is_concrete_user(tuple.user) {
              continue
            }
            let child = self.witness(
              tuple.user,
              computed,
              subject,
              context,
              depth + 1,
              path,
            )
            if child.length() > 0 && best.length() == 0 {
              best = concat_traces(
                object + "#" + relation + " -> " + tuple.user + "#" + computed,
                child,
              )
            }
          }
        }
      }
      best
    }
    Union(children) => {
      let mut best : Array[String] = []
      for child in children {
        if best.length() > 0 {
          break
        }
        best = self.witness_rewrite(
          object, relation, child, subject, context, depth, path,
        )
      }
      best
    }
    Intersection(children) => {
      let all : Array[String] = []
      for child in children {
        let part = self.witness_rewrite(
          object, relation, child, subject, context, depth, path,
        )
        if part.length() == 0 {
          return []
        }
        for trace in part {
          all.push(trace)
        }
      }
      all
    }
    Difference(base, subtract) => {
      let base_part = self.witness_rewrite(
        object, relation, base, subject, context, depth, path,
      )
      if base_part.length() == 0 {
        return []
      }
      let subtract_part = self.witness_rewrite(
        object, relation, subtract, subject, context, depth, path,
      )
      if subtract_part.length() > 0 {
        []
      } else {
        base_part
      }
    }
  }
}

///|
fn Engine::witness_direct(
  self : Engine,
  object : String,
  relation : String,
  subject : String,
  context : Map[String, Json],
  depth : Int32,
  path : Array[String],
) -> Array[String] raise @fga.FgaError {
  let type_name = @fga.object_type(object)
  let traces : Array[String] = []
  for tuple in self.reader.read(object, relation) {
    let binding = tuple_binding_spec(self.model, type_name, relation, tuple)
    match binding {
      TupleBindingSpec::Invalid => continue
      _ => ()
    }
    if !self.condition_holds(tuple, binding, context) {
      continue
    }
    if tuple.user == subject {
      traces.push(witness_key(object, relation, tuple.user))
    } else {
      match @fga.parse_user_ref(tuple.user) {
        Some(rref) =>
          if is_wildcard_user(tuple.user) {
            if subject_matches_wildcard(subject, rref) {
              traces.push(
                witness_key(object, relation, subject) +
                " (wildcard " +
                tuple.user +
                ")",
              )
            }
          } else {
            match rref.relation {
              Some(userset_relation) => {
                let target = rref.type_name + ":" + rref.id
                let child = self.witness(
                  target,
                  userset_relation,
                  subject,
                  context,
                  depth + 1,
                  path,
                )
                for trace in child {
                  traces.push(
                    object +
                    "#" +
                    relation +
                    " -> " +
                    tuple.user +
                    " -> " +
                    trace,
                  )
                }
              }
              None => ()
            }
          }
        None => ()
      }
    }
  }
  traces
}

///|
/// Returns the decision plus witness paths explaining why it holds.
pub fn Engine::explain_check(
  self : Engine,
  object : String,
  relation : String,
  user : String,
  context : Map[String, Json],
  contextual_tuples : Array[@fga.Tuple],
) -> ExplainResult raise @fga.FgaError {
  validate_check_object(self.model, object, relation)
  validate_request_user(self.model, user)
  validate_contextual(self.model, contextual_tuples)
  let reader = self.reader_with(contextual_tuples)
  let engine = Engine::{
    model: self.model,
    reader,
    list_query: self.list_query,
    match_wildcard_users: self.match_wildcard_users,
  }
  let allowed = engine.check_resolved(object, relation, user, context)
  let paths = if allowed {
    let path : Array[String] = []
    let traces = engine.witness(object, relation, user, context, 0, path)
    if traces.length() == 0 {
      [object + "#" + relation + "@" + user]
    } else {
      traces
    }
  } else {
    []
  }
  ExplainResult::{ allowed, paths, }
}
