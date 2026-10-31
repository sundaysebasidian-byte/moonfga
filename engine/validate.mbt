// Validation of tuples and request shapes against an authorization model.
//
// Check and ListObjects report request validation failures as 2000, while
// contextual tuples that violate the model use the invalid-tuple code 2027.
// ListObjects and ListUsers use the more specific 2021/2022 codes for unknown
// types and relations in the request itself.

///|
pub const INLINE_EXPRESSION : String = "$expression"

///|
fn fail_tuple(message : String) -> @fga.FgaError {
  @fga.fail(@fga.ERR_INVALID_TUPLE, message)
}

///|
fn user_ref_for(
  model : @fga.AuthModel,
  user : String,
  code : Int32,
) -> @fga.UserRef raise @fga.FgaError {
  let r = match @fga.parse_user_ref(user) {
    Some(r) => r
    None => raise @fga.fail(code, "invalid user '" + user + "'")
  }
  if !@fga.is_valid_user(user) {
    raise @fga.fail(code, "invalid user '" + user + "'")
  }
  match model.find_type(r.type_name) {
    None =>
      raise @fga.fail(
        code,
        "type '" + r.type_name + "' referenced by user '" + user + "' not found",
      )
    Some(td) =>
      match r.relation {
        None => ()
        Some(rel) =>
          if !td.relations.contains(rel) {
            raise @fga.fail(
              code,
              "relation '" +
              rel +
              "' referenced by user '" +
              user +
              "' not found",
            )
          }
      }
  }
  r
}

///|
/// Validates a check/ListObjects request user. Wildcard users are allowed.
pub fn validate_request_user(
  model : @fga.AuthModel,
  user : String,
) -> Unit raise @fga.FgaError {
  let _ = user_ref_for(model, user, @fga.ERR_VALIDATION)
}

///|
/// Validates `object` and `relation` for Check, using 2000 for every failure.
pub fn validate_check_object(
  model : @fga.AuthModel,
  object : String,
  relation : String,
) -> Unit raise @fga.FgaError {
  if !@fga.is_valid_object(object) {
    raise @fga.fail(@fga.ERR_VALIDATION, "invalid object '" + object + "'")
  }
  let type_name = @fga.object_type(object)
  match model.find_type(type_name) {
    None =>
      raise @fga.fail(@fga.ERR_VALIDATION, "type '" + type_name + "' not found")
    Some(td) =>
      if !td.relations.contains(relation) {
        raise @fga.fail(
          @fga.ERR_VALIDATION,
          "relation '" + relation + "' not found on type '" + type_name + "'",
        )
      }
  }
}

///|
/// Validates the type and relation of a ListObjects request.
pub fn validate_object_type_relation(
  model : @fga.AuthModel,
  type_name : String,
  relation : String,
) -> Unit raise @fga.FgaError {
  match model.find_type(type_name) {
    None =>
      raise @fga.fail(
        @fga.ERR_TYPE_NOT_FOUND,
        "type '" + type_name + "' not found",
      )
    Some(td) =>
      if !td.relations.contains(relation) {
        raise @fga.fail(
          @fga.ERR_RELATION_NOT_FOUND,
          "relation '" + relation + "' not found on type '" + type_name + "'",
        )
      }
  }
}

///|
/// Validates the target object of a ListUsers request.
pub fn validate_list_users_object(
  model : @fga.AuthModel,
  object : String,
  relation : String,
) -> Unit raise @fga.FgaError {
  if !@fga.is_valid_object(object) {
    raise @fga.fail(@fga.ERR_VALIDATION, "invalid object '" + object + "'")
  }
  let type_name = @fga.object_type(object)
  match model.find_type(type_name) {
    None =>
      raise @fga.fail(
        @fga.ERR_TYPE_NOT_FOUND,
        "type '" + type_name + "' not found",
      )
    Some(td) =>
      if !td.relations.contains(relation) {
        raise @fga.fail(
          @fga.ERR_RELATION_NOT_FOUND,
          "relation '" + relation + "' not found on type '" + type_name + "'",
        )
      }
  }
}

///|
/// Parses a ListUsers filter such as `user` or `group#member`.
pub fn parse_user_filter(
  model : @fga.AuthModel,
  filter : String,
) -> @fga.UserRef raise @fga.FgaError {
  let hash = filter.find("#")
  let type_name = match hash {
    Some(i) => filter[:i].to_owned()
    None => filter
  }
  let relation = match hash {
    Some(i) =>
      if filter[i + 1:].to_owned() == "" {
        raise @fga.fail(
          @fga.ERR_TYPE_NOT_FOUND,
          "invalid user filter '" + filter + "'",
        )
      } else {
        Some(filter[i + 1:].to_owned())
      }
    None => None
  }
  if type_name == "" || type_name.contains(":") {
    raise @fga.fail(
      @fga.ERR_TYPE_NOT_FOUND,
      "invalid user filter '" + filter + "'",
    )
  }
  match model.find_type(type_name) {
    None =>
      raise @fga.fail(
        @fga.ERR_TYPE_NOT_FOUND,
        "type '" + type_name + "' not found",
      )
    Some(td) =>
      match relation {
        None => ()
        Some(rel) =>
          if !td.relations.contains(rel) {
            raise @fga.fail(
              @fga.ERR_RELATION_NOT_FOUND,
              "relation '" + rel + "' not found on type '" + type_name + "'",
            )
          }
      }
  }
  @fga.UserRef::{ type_name, id: "", relation, }
}

///|
pub fn validate_contextual_tuple(
  model : @fga.AuthModel,
  tuple : @fga.Tuple,
) -> Unit raise @fga.FgaError {
  if !@fga.is_valid_object(tuple.object) {
    raise fail_tuple("invalid object '" + tuple.object + "'")
  }
  let type_name = @fga.object_type(tuple.object)
  let td = match model.find_type(type_name) {
    None =>
      raise fail_tuple(
        "type '" +
        type_name +
        "' referenced by object '" +
        tuple.object +
        "' not found",
      )
    Some(td) => td
  }
  if !td.relations.contains(tuple.relation) {
    raise fail_tuple(
      "relation '" + tuple.relation + "' not found on type '" + type_name + "'",
    )
  }
  let user_ref = user_ref_for(model, tuple.user, @fga.ERR_INVALID_TUPLE)
  if user_ref.id == "*" && user_ref.relation != None {
    raise fail_tuple("wildcard users cannot have a relation")
  }
  let binding = tuple_binding_spec(model, type_name, tuple.relation, tuple)
  match binding {
    TupleBindingSpec::Invalid =>
      raise fail_tuple(
        "tuple user '" +
        tuple.user +
        "' does not match the type restrictions of " +
        type_name +
        "#" +
        tuple.relation,
      )
    TupleBindingSpec::Unconditional | TupleBindingSpec::Condition(_) => ()
  }
  match tuple.condition {
    None => ()
    Some(cond) =>
      if cond.name == INLINE_EXPRESSION {
        match cond.context.get("expression") {
          Some(@fga.VString(_)) => ()
          _ =>
            raise fail_tuple(
              "inline expression tuple requires a string 'expression' context value",
            )
        }
      } else {
        match model.find_condition(cond.name) {
          None => raise fail_tuple("condition '" + cond.name + "' not found")
          Some(declared) =>
            for key in cond.context.keys() {
              if declared.find_param(key) is None {
                raise fail_tuple(
                  "condition '" + cond.name + "' has no parameter '" + key + "'",
                )
              }
            }
        }
      }
  }
}

///|
/// Binding of a tuple user to one of the relation's direct type restrictions,
/// including the condition attached to the matching facet.
pub(all) enum TupleBindingSpec {
  Invalid
  Unconditional
  Condition(String)
}

///|
/// Finds the restriction facet matching the tuple user shape.
///
/// A conditional restriction only binds a tuple carrying that exact condition;
/// an unconditional facet only binds tuples without a condition. This mirrors
/// OpenFGA's condition/type-restriction pairing.
pub fn tuple_binding_spec(
  model : @fga.AuthModel,
  type_name : String,
  relation : String,
  tuple : @fga.Tuple,
) -> TupleBindingSpec {
  let restrictions = model.direct_restrictions(type_name, relation)
  let ur = match @fga.parse_user_ref(tuple.user) {
    Some(r) => r
    None => return TupleBindingSpec::Invalid
  }
  let is_wildcard = ur.id == "*" && ur.relation == None
  let tuple_condition = match tuple.condition {
    None => None
    Some(c) => Some(c.name)
  }
  for r in restrictions {
    if r.type_name != ur.type_name {
      continue
    }
    let shape_matches = match r.relation {
      Some(rel) => ur.relation == Some(rel) && !is_wildcard
      None =>
        if ur.relation != None {
          false
        } else {
          r.wildcard == is_wildcard
        }
    }
    if !shape_matches {
      continue
    }
    match (tuple_condition, r.condition) {
      (None, None) => return TupleBindingSpec::Unconditional
      (Some(tc), Some(rc)) =>
        if tc == rc {
          return TupleBindingSpec::Condition(rc)
        }
      _ => ()
    }
  }
  TupleBindingSpec::Invalid
}
