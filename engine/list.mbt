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
fn concrete_users(
  reader : &@fga.TupleReader,
  type_name : String,
) -> Array[String] {
  let out : Array[String] = []
  let seen : Map[String, Unit] = Map([])
  for user in reader.all_users() {
    match @fga.parse_user_ref(user) {
      Some(r) =>
        if r.type_name == type_name && r.relation == None && r.id != "*" {
          add_unique(out, seen, user)
        }
      None => ()
    }
  }
  out
}

///|
/// List APIs report a contextual tuple whose condition does not bind to any
/// type restriction facet as a validation error (2000), while Check uses the
/// tuple error code (2027). Structural problems keep the tuple code.
fn validate_contextual_for_list(
  model : @fga.AuthModel,
  tuples : Array[@fga.Tuple],
) -> Unit raise @fga.FgaError {
  for tuple in tuples {
    validate_contextual_tuple(model, tuple) catch {
      @fga.FgaError(..) as err => {
        let conditional = match tuple.condition {
          Some(_) => true
          None => false
        }
        if conditional &&
          @fga.error_message(err).contains(
            "does not match the type restrictions",
          ) {
          raise @fga.fail(@fga.ERR_VALIDATION, @fga.error_message(err))
        } else {
          raise err
        }
      }
    }
  }
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
  validate_contextual_for_list(self.model, contextual_tuples)
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
/// (`group#member`). For concrete filters the result contains explicitly
/// related users plus `type:*` when the wildcard itself satisfies the relation;
/// wildcard coverage is never expanded into every possible user.
pub fn Engine::list_users(
  self : Engine,
  object : String,
  relation : String,
  filters : Array[String],
  context : Map[String, Json],
  contextual_tuples : Array[@fga.Tuple],
) -> Array[String] raise @fga.FgaError {
  validate_list_users_object(self.model, object, relation)
  validate_contextual_for_list(self.model, contextual_tuples)
  let parsed_filters : Array[@fga.UserRef] = []
  for filter in filters {
    parsed_filters.push(parse_user_filter(self.model, filter))
  }
  let reader = self.reader_with(contextual_tuples)
  let full = Engine::{ model: self.model, reader, match_wildcard_users: true, }
  let explicit = Engine::{
    model: self.model,
    reader,
    match_wildcard_users: false,
  }
  let results : Array[String] = []
  let seen_results : Map[String, Unit] = Map([])
  for filter in parsed_filters {
    match filter.relation {
      None => {
        let wildcard = filter.type_name + ":*"
        let wildcard_allowed = full.check_resolved(
          object, relation, wildcard, context,
        )
        if wildcard_allowed {
          add_unique(results, seen_results, wildcard)
        }
        // When a wildcard satisfies the relation, only users reachable through
        // explicit (non-wildcard) grants are enumerated; everyone else is
        // represented by the `type:*` marker. Without a surviving wildcard the
        // full resolver decides which concrete users are allowed.
        let evaluator = if wildcard_allowed { explicit } else { full }
        for candidate in concrete_users(reader, filter.type_name) {
          if evaluator.check_resolved(object, relation, candidate, context) {
            add_unique(results, seen_results, candidate)
          }
        }
      }
      Some(filter_relation) => {
        let candidates : Array[String] = []
        let seen_candidates : Map[String, Unit] = Map([])
        for candidate_object in reader.all_objects(filter.type_name) {
          add_unique(
            candidates,
            seen_candidates,
            candidate_object + "#" + filter_relation,
          )
        }
        for user in reader.all_users() {
          match @fga.parse_user_ref(user) {
            Some(r) =>
              if r.type_name == filter.type_name {
                match r.relation {
                  Some(user_relation) =>
                    if user_relation == filter_relation {
                      add_unique(candidates, seen_candidates, user)
                    }
                  None =>
                    if r.id != "*" {
                      add_unique(
                        candidates,
                        seen_candidates,
                        user + "#" + filter_relation,
                      )
                    }
                }
              }
            None => ()
          }
        }
        for candidate in candidates {
          if full.check_resolved(object, relation, candidate, context) {
            add_unique(results, seen_results, candidate)
          }
        }
      }
    }
  }
  sorted(results)
}
