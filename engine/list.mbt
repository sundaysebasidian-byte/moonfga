// ListObjects and ListUsers.
//
// Candidates are discovered from the tuple index and then evaluated with the
// same resolution algorithm as Check, so wildcards, usersets, conditions and
// exclusions behave consistently across the three APIs. Userset subjects are
// checked with the same resolver: a relation includes its own userset, and
// computed/union/difference rewrites include the usersets they structurally
// contain.

///|
fn add_unique(
  out : Array[String],
  seen : Map[String, Unit],
  value : String,
) -> Unit {
  if !seen.contains(value) {
    seen[value] = ()
    out.push(value)
  }
}

///|
fn sorted(values : Array[String]) -> Array[String] {
  let copy = values.copy()
  // `String::compare` orders by length first; API output is lexicographic.
  copy.sort_by(fn(a, b) { a.lexical_compare(b) })
  copy
}

///|
/// Lists object IDs of `type_name` for which `user` has `relation`.
pub fn Engine::list_objects(
  self : Engine,
  type_name : String,
  relation : String,
  user : String,
  context : Map[String, Json],
  contextual_tuples : Array[@fga.Tuple],
) -> Array[String] raise @fga.FgaError {
  validate_object_type_relation(self.model, type_name, relation)
  validate_request_user(self.model, user)
  validate_contextual(self.model, contextual_tuples)
  let reader = self.reader_with(contextual_tuples)
  let engine = Engine::{
    model: self.model,
    reader,
    match_wildcard_users: self.match_wildcard_users,
  }
  let results : Array[String] = []
  for object in reader.all_objects(type_name) {
    let allowed = engine.check_resolved(object, relation, user, context)
    if allowed {
      results.push(object)
    }
  }
  sorted(results)
}

///|
/// Lists subjects that satisfy `object#relation` for each requested filter.
///
/// A filter is either a concrete type (`user`) or a userset filter
/// (`group#member`). For concrete filters the result contains explicit users
/// plus `type:*` when a wildcard applies; wildcard coverage is never expanded
/// into every possible user.
pub fn Engine::list_users(
  self : Engine,
  object : String,
  relation : String,
  filters : Array[String],
  context : Map[String, Json],
  contextual_tuples : Array[@fga.Tuple],
) -> Array[String] raise @fga.FgaError {
  validate_list_users_object(self.model, object, relation)
  validate_contextual(self.model, contextual_tuples)
  let parsed_filters : Array[@fga.UserRef] = []
  for filter in filters {
    parsed_filters.push(parse_user_filter(self.model, filter))
  }
  let reader = self.reader_with(contextual_tuples)
  let engine = Engine::{
    model: self.model,
    reader,
    match_wildcard_users: false,
  }
  let candidates : Array[String] = []
  let seen : Map[String, Unit] = Map([])
  let all_users = reader.all_users()
  for filter in parsed_filters {
    match filter.relation {
      None => {
        let wildcard = filter.type_name + ":*"
        add_unique(candidates, seen, wildcard)
        for user in all_users {
          match @fga.parse_user_ref(user) {
            Some(r) =>
              if r.type_name == filter.type_name &&
                r.relation == None &&
                r.id != "*" {
                add_unique(candidates, seen, user)
              }
            None => ()
          }
        }
      }
      Some(filter_relation) => {
        for candidate_object in reader.all_objects(filter.type_name) {
          add_unique(candidates, seen, candidate_object + "#" + filter_relation)
        }
        for user in all_users {
          match @fga.parse_user_ref(user) {
            Some(r) =>
              if r.type_name != filter.type_name {
                ()
              } else {
                match r.relation {
                  Some(rel) =>
                    if rel == filter_relation {
                      add_unique(candidates, seen, user)
                    }
                  None =>
                    if r.id != "*" {
                      add_unique(candidates, seen, user + "#" + filter_relation)
                    }
                }
              }
            None => ()
          }
        }
      }
    }
  }
  let results : Array[String] = []
  for candidate in candidates {
    let allowed = engine.check_resolved(object, relation, candidate, context)
    if allowed {
      results.push(candidate)
    }
  }
  sorted(results)
}
