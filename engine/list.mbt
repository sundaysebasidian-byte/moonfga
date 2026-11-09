// ListObjects and ListUsers.
//
// ListObjects propagates reverse proofs; ListUsers expands result sets.
// Neither API enumerates every candidate and invokes Check.

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
  let reader = self.reader_with(contextual_tuples, shadow=false)
  let engine = Engine::{
    model: self.model,
    reader,
    traces: None,
    list_query: true,
    match_wildcard_users: self.match_wildcard_users,
    condition_cost_limit: self.condition_cost_limit,
    condition_cancelled: self.condition_cancelled,
    condition_local_timezone: self.condition_local_timezone,
  }
  engine.reverse_objects(type_name, relation, user, context)
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
  let reader = self.reader_with(contextual_tuples, shadow=false)
  let engine = Engine::{
    model: self.model,
    reader,
    traces: None,
    list_query: true,
    match_wildcard_users: true,
    condition_cost_limit: self.condition_cost_limit,
    condition_cancelled: self.condition_cancelled,
    condition_local_timezone: self.condition_local_timezone,
  }
  let results : Array[String] = []
  let seen : Map[String, Unit] = Map([])
  for filter in parsed_filters {
    let expanded = engine.expand_users(object, relation, filter, context, 0, [])
    match expanded.error {
      Some(err) => raise err
      None => ()
    }
    expanded.found.each(fn(user, allowed) {
      if allowed {
        add_unique(results, seen, user)
      }
    })
  }
  sorted(results)
}
