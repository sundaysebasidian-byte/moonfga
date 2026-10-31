// Relation rewrite evaluation for Check, ListObjects and ListUsers.
//
// Outcomes distinguish "false" from "a cycle was encountered": OpenFGA treats
// a resolution cycle as a failed check (false), even when the cycle appears on
// the subtract side of an exclusion, so the cycle flag must survive unions and
// differences instead of being flattened into a boolean.

///|
pub struct Engine {
  priv model : @fga.AuthModel
  priv reader : &@fga.TupleReader
  // ListUsers enumerates concrete users from the tuple graph; users covered
  // only by a wildcard must not be reported individually.
  priv list_query : Bool
  priv match_wildcard_users : Bool
}

///|
/// Creates a read-only evaluator over a model and tuple reader.
/// Mutations to the reader are visible to subsequent requests.
pub fn Engine::new(
  model : @fga.AuthModel,
  reader : &@fga.TupleReader,
) -> Engine {
  Engine::{ model, reader, list_query: false, match_wildcard_users: true, }
}

///|
pub(all) struct CheckRequest {
  object : String
  relation : String
  user : String
  context : Map[String, Json]
  contextual_tuples : Array[@fga.Tuple]
}

///|
/// Creates a request with empty context and no contextual tuples.
pub fn CheckRequest::new(
  object : String,
  relation : String,
  user : String,
) -> CheckRequest {
  CheckRequest::{
    object,
    relation,
    user,
    context: Map([]),
    contextual_tuples: [],
  }
}

///|
pub(all) struct CheckResult {
  allowed : Bool?
  error_code : Int32?
  error_message : String?
}

///|
fn check_result_allowed(value : Bool) -> CheckResult {
  CheckResult::{ allowed: Some(value), error_code: None, error_message: None, }
}

///|
fn check_result_error(err : @fga.FgaError) -> CheckResult {
  CheckResult::{
    allowed: None,
    error_code: Some(@fga.error_code(err)),
    error_message: Some(@fga.error_message(err)),
  }
}

///|
priv enum Outcome {
  OTrue
  OFalse
  OCycle
}

///|
fn outcome_to_bool(outcome : Outcome) -> Bool {
  match outcome {
    OTrue => true
    OFalse => false
    OCycle => false
  }
}

///|
fn path_key(object : String, relation : String) -> String {
  object + "#" + relation
}

///|
fn is_concrete_user(user : String) -> Bool {
  match @fga.parse_user_ref(user) {
    Some(r) => r.relation == None && r.id != "*"
    None => false
  }
}

///|
fn is_wildcard_user(user : String) -> Bool {
  match @fga.parse_user_ref(user) {
    Some(r) => r.relation == None && r.id == "*"
    None => false
  }
}

///|
fn is_userset_user(user : String) -> Bool {
  match @fga.parse_user_ref(user) {
    Some(r) =>
      match r.relation {
        Some(_) => true
        None => false
      }
    None => false
  }
}

///|
fn subject_matches_wildcard(subject : String, wildcard : @fga.UserRef) -> Bool {
  match @fga.parse_user_ref(subject) {
    Some(r) =>
      r.type_name == wildcard.type_name && r.relation == None && r.id != "*"
    None => false
  }
}

///|
fn condition_context_map(tuple : @fga.Tuple) -> Map[String, Json] {
  let out : Map[String, Json] = Map([])
  match tuple.condition {
    None => ()
    Some(cond) =>
      cond.context.each(fn(key, value) {
        if key != "expression" && key != "parameters" {
          out[key] = @fga.cel_value_to_json(value)
        }
      })
  }
  out
}

///|
fn infer_parameter_type(value : Json) -> @fga.ConditionParam {
  match value {
    String(_) =>
      @fga.ConditionParam::{
        name: "",
        type_name: "string",
        generic_type: None,
      }
    True | False =>
      @fga.ConditionParam::{ name: "", type_name: "bool", generic_type: None, }
    Number(_) =>
      @fga.ConditionParam::{
        name: "",
        type_name: "double",
        generic_type: None,
      }
    Array(xs) =>
      if xs.length() == 0 {
        @fga.ConditionParam::{
          name: "",
          type_name: "list",
          generic_type: Some("string"),
        }
      } else {
        let inner = match infer_parameter_type(xs[0]) {
          p => p.type_name
        }
        @fga.ConditionParam::{
          name: "",
          type_name: "list",
          generic_type: Some(inner),
        }
      }
    Object(_) =>
      @fga.ConditionParam::{
        name: "",
        type_name: "map",
        generic_type: Some("string"),
      }
    Null =>
      @fga.ConditionParam::{
        name: "",
        type_name: "string",
        generic_type: None,
      }
  }
}

///|
/// Evaluates an inline `$expression` condition stored on a tuple. The tuple
/// context carries the expression source and optionally declared parameter
/// types; values come from the merged request context.
fn eval_inline_expression(
  tuple : @fga.Tuple,
  request_context : Map[String, Json],
) -> Bool raise @fga.FgaError {
  let cond = match tuple.condition {
    Some(c) => c
    None =>
      raise @fga.fail(
        @fga.ERR_VALIDATION,
        "inline expression tuple is missing its condition",
      )
  }
  let expression = match cond.context.get("expression") {
    Some(@fga.VString(s)) => s
    _ =>
      raise @fga.fail(
        @fga.ERR_VALIDATION,
        "inline expression tuple requires a string 'expression'",
      )
  }
  let declared : Array[@fga.ConditionParam] = []
  match cond.context.get("parameters") {
    Some(@fga.VMap(types)) =>
      types.each(fn(name, ty) {
        match ty {
          @fga.VString(type_name) =>
            declared.push(@fga.ConditionParam::{
              name,
              type_name,
              generic_type: None,
            })
          _ =>
            declared.push(@fga.ConditionParam::{
              name,
              type_name: "string",
              generic_type: None,
            })
        }
      })
    _ => ()
  }
  let merged : Map[String, Json] = Map([])
  condition_context_map(tuple).each(fn(k, v) { merged[k] = v })
  request_context.each(fn(k, v) { merged[k] = v })
  let parameters : Array[@fga.ConditionParam] = []
  for p in declared {
    parameters.push(p)
  }
  let declared_names : Map[String, Unit] = Map([])
  for p in declared {
    declared_names[p.name] = ()
  }
  merged.each(fn(name, value) {
    if !declared_names.contains(name) {
      let inferred = infer_parameter_type(value)
      parameters.push(@fga.ConditionParam::{
        name,
        type_name: inferred.type_name,
        generic_type: inferred.generic_type,
      })
    }
  })
  let condition = @fga.Condition::{
    name: INLINE_EXPRESSION,
    expression,
    parameters,
  }
  @cel.eval_condition(condition, merged)
}

///|
fn eval_named_condition(
  model : @fga.AuthModel,
  tuple : @fga.Tuple,
  name : String,
  request_context : Map[String, Json],
) -> Bool raise @fga.FgaError {
  let condition = match model.find_condition(name) {
    Some(c) => c
    None =>
      raise @fga.fail(@fga.ERR_VALIDATION, "condition '" + name + "' not found")
  }
  let merged = condition_context_map(tuple)
  request_context.each(fn(k, v) { merged[k] = v })
  @cel.eval_condition(condition, merged)
}

///|
fn Engine::condition_holds(
  self : Engine,
  tuple : @fga.Tuple,
  binding : TupleBindingSpec,
  context : Map[String, Json],
) -> Bool raise @fga.FgaError {
  match binding {
    TupleBindingSpec::Unconditional => true
    TupleBindingSpec::Invalid => false
    TupleBindingSpec::Condition(name) =>
      if name == INLINE_EXPRESSION {
        eval_inline_expression(tuple, context)
      } else {
        eval_named_condition(self.model, tuple, name, context)
      }
  }
}

///|
fn Engine::resolve(
  self : Engine,
  object : String,
  relation : String,
  subject : String,
  context : Map[String, Json],
  depth : Int32,
  path : Array[String],
) -> Outcome raise @fga.FgaError {
  if depth > @fga.MAX_RESOLUTION_DEPTH {
    raise @fga.fail(
      @fga.ERR_RESOLUTION_TOO_COMPLEX,
      "resolution depth exceeded " +
      @fga.MAX_RESOLUTION_DEPTH.to_string() +
      " while resolving " +
      object +
      "#" +
      relation,
    )
  }
  let key = path_key(object, relation)
  for seen in path {
    if seen == key {
      return OCycle
    }
  }
  if is_userset_user(subject) && subject == key {
    return OTrue
  }
  // Relations referenced through computed usersets or tuple-to-userset may be
  // absent on one of several parent types; OpenFGA treats that branch as false
  // instead of failing the whole request.
  let rewrite = match self.model.find_type(@fga.object_type(object)) {
    None => return OFalse
    Some(td) =>
      match td.relation_rewrite(relation) {
        None => return OFalse
        Some(rewrite) => rewrite
      }
  }
  path.push(key)
  defer {
    let _ = path.pop()
  }
  self.resolve_rewrite(object, relation, rewrite, subject, context, depth, path)
}

///|
fn Engine::resolve_rewrite(
  self : Engine,
  object : String,
  relation : String,
  rewrite : @fga.Userset,
  subject : String,
  context : Map[String, Json],
  depth : Int32,
  path : Array[String],
) -> Outcome raise @fga.FgaError {
  match rewrite {
    This => self.resolve_direct(object, relation, subject, context, depth, path)
    Computed(target) =>
      self.resolve(object, target, subject, context, depth + 1, path)
    TupleToUserset(computed, tupleset) =>
      self.resolve_ttu(
        object, tupleset, computed, subject, context, depth, path,
      )
    Union(children) => {
      let mut pending_error : @fga.FgaError? = None
      let mut saw_cycle = false
      for child in children {
        try {
          match
            self.resolve_rewrite(
              object, relation, child, subject, context, depth, path,
            ) {
            OTrue => return OTrue
            OFalse => ()
            OCycle => saw_cycle = true
          }
        } catch {
          err => if pending_error is None { pending_error = Some(err) }
        }
      }
      if saw_cycle {
        OCycle
      } else {
        match pending_error {
          Some(err) => raise err
          None => OFalse
        }
      }
    }
    Intersection(children) => {
      if !self.match_wildcard_users {
        // Enumeration needs an explicit witness in any operand, while every
        // operand must authorize the candidate (including through wildcards).
        let full = Engine::{ ..self, match_wildcard_users: true, }
        match
          full.resolve_rewrite(
            object, relation, rewrite, subject, context, depth, path,
          ) {
          OTrue =>
            return self.resolve_rewrite(
              object,
              relation,
              @fga.Union(children),
              subject,
              context,
              depth,
              path,
            )
          outcome => return outcome
        }
      }
      let mut pending_error : @fga.FgaError? = None
      let mut saw_cycle = false
      for child in children {
        try {
          match
            self.resolve_rewrite(
              object, relation, child, subject, context, depth, path,
            ) {
            OFalse => return OFalse
            OTrue => ()
            OCycle => saw_cycle = true
          }
        } catch {
          err => if pending_error is None { pending_error = Some(err) }
        }
      }
      if saw_cycle {
        OCycle
      } else {
        match pending_error {
          Some(err) => raise err
          None => OTrue
        }
      }
    }
    Difference(base, subtract) =>
      self.resolve_difference(
        object, relation, base, subtract, subject, context, depth, path,
      )
  }
}

///|
fn Engine::resolve_direct(
  self : Engine,
  object : String,
  relation : String,
  subject : String,
  context : Map[String, Json],
  depth : Int32,
  path : Array[String],
) -> Outcome raise @fga.FgaError {
  let type_name = @fga.object_type(object)
  let tuples = self.reader.read(object, relation)
  let mut pending_error : @fga.FgaError? = None
  let mut saw_cycle = false
  let mut allowed = false
  for tuple in tuples {
    let parsed_user = match @fga.parse_user_ref(tuple.user) {
      Some(r) => r
      None => continue
    }
    let binding = tuple_binding_for_user(
      self.model,
      type_name,
      relation,
      tuple,
      parsed_user,
    )
    match binding {
      TupleBindingSpec::Invalid => continue
      _ => ()
    }
    // The condition of a concrete tuple is only evaluated when the tuple user
    // matches the subject. OpenFGA does not surface a condition error for a
    // tuple that cannot contribute to this request.
    if tuple.user == subject {
      let holds = self.condition_holds(tuple, binding, context) catch {
        err => {
          if pending_error is None {
            pending_error = Some(err)
          }
          false
        }
      }
      if holds {
        if !self.list_query {
          return OTrue
        }
        allowed = true
      }
      continue
    }
    let rref = parsed_user
    if rref.id == "*" && rref.relation == None {
      if self.match_wildcard_users && subject_matches_wildcard(subject, rref) {
        let holds = self.condition_holds(tuple, binding, context) catch {
          err => {
            if pending_error is None {
              pending_error = Some(err)
            }
            false
          }
        }
        if holds {
          if !self.list_query {
            return OTrue
          }
          allowed = true
        }
      }
    } else {
      match rref.relation {
        Some(userset_relation) => {
          // A userset edge condition gates traversal regardless of the
          // concrete subject inside the referenced userset.
          let holds = self.condition_holds(tuple, binding, context) catch {
            err => {
              if pending_error is None {
                pending_error = Some(err)
              }
              false
            }
          }
          if !holds {
            continue
          }
          let target = rref.type_name + ":" + rref.id
          let child = self.resolve(
            target,
            userset_relation,
            subject,
            context,
            depth + 1,
            path,
          ) catch {
            err => {
              if pending_error is None {
                pending_error = Some(err)
              }
              OFalse
            }
          }
          match child {
            OTrue =>
              if !self.list_query {
                return OTrue
              } else {
                allowed = true
              }
            OCycle => saw_cycle = true
            OFalse => ()
          }
        }
        None => ()
      }
    }
  }
  // List readers consume both streams: a successful stored grant must not
  // conceal an invalid/missing contextual condition in another direct tuple.
  if self.list_query {
    match pending_error {
      Some(err) => raise err
      None => ()
    }
    if allowed {
      return OTrue
    }
  }
  if saw_cycle {
    OCycle
  } else {
    match pending_error {
      Some(err) => raise err
      None => OFalse
    }
  }
}

///|
fn Engine::resolve_ttu(
  self : Engine,
  object : String,
  tupleset : String,
  computed : String,
  subject : String,
  context : Map[String, Json],
  depth : Int32,
  path : Array[String],
) -> Outcome raise @fga.FgaError {
  let type_name = @fga.object_type(object)
  let tuples = self.reader.read(object, tupleset)
  let mut pending_error : @fga.FgaError? = None
  let mut saw_cycle = false
  for tuple in tuples {
    let binding = tuple_binding_spec(self.model, type_name, tupleset, tuple)
    match binding {
      TupleBindingSpec::Invalid => continue
      _ => ()
    }
    let holds = self.condition_holds(tuple, binding, context) catch {
      err => {
        if pending_error is None {
          pending_error = Some(err)
        }
        false
      }
    }
    if !holds {
      continue
    }
    if !is_concrete_user(tuple.user) {
      // Tuple-to-userset only follows concrete objects.
      continue
    }
    let child = self.resolve(
      tuple.user,
      computed,
      subject,
      context,
      depth + 1,
      path,
    ) catch {
      err => {
        if pending_error is None {
          pending_error = Some(err)
        }
        OFalse
      }
    }
    match child {
      OTrue => return OTrue
      OCycle => saw_cycle = true
      OFalse => ()
    }
  }
  if saw_cycle {
    OCycle
  } else {
    match pending_error {
      Some(err) => raise err
      None => OFalse
    }
  }
}

///|
fn Engine::resolve_difference(
  self : Engine,
  object : String,
  relation : String,
  base : @fga.Userset,
  subtract : @fga.Userset,
  subject : String,
  context : Map[String, Json],
  depth : Int32,
  path : Array[String],
) -> Outcome raise @fga.FgaError {
  let subtract_engine = Engine::{ ..self, match_wildcard_users: true, }
  let mut base_error : @fga.FgaError? = None
  let base_outcome = self.resolve_rewrite(
    object, relation, base, subject, context, depth, path,
  ) catch {
    err => {
      base_error = Some(err)
      OFalse
    }
  }
  match base_outcome {
    OFalse =>
      if base_error is Some(_) {
        // The base failed, but a true subtract side would still make the
        // difference false; evaluate it before surfacing the base error.
        let sub_outcome = subtract_engine.resolve_rewrite(
          object, relation, subtract, subject, context, depth, path,
        )
        match sub_outcome {
          OTrue => OFalse
          OCycle => OCycle
          OFalse =>
            match base_error {
              Some(err) => raise err
              None => OFalse
            }
        }
      } else {
        OFalse
      }
    OCycle => OCycle
    OTrue => {
      let sub_outcome = subtract_engine.resolve_rewrite(
        object, relation, subtract, subject, context, depth, path,
      )
      match sub_outcome {
        OTrue => OFalse
        OFalse => OTrue
        OCycle => OCycle
      }
    }
  }
}

///|
fn validate_contextual(
  model : @fga.AuthModel,
  tuples : Array[@fga.Tuple],
) -> Unit raise @fga.FgaError {
  for tuple in tuples {
    validate_contextual_tuple(model, tuple)
  }
}

///|
fn Engine::reader_with(
  self : Engine,
  contextual_tuples : Array[@fga.Tuple],
  shadow~ : Bool = true,
) -> &@fga.TupleReader {
  if contextual_tuples.length() == 0 {
    self.reader
  } else {
    let wrapper = @store.ContextualStore::new(
      self.reader,
      contextual_tuples,
      shadow~,
    )
    wrapper as &@fga.TupleReader
  }
}

///|
fn Engine::check_resolved(
  self : Engine,
  object : String,
  relation : String,
  user : String,
  context : Map[String, Json],
) -> Bool raise @fga.FgaError {
  let path : Array[String] = []
  let outcome = self.resolve(object, relation, user, context, 0, path)
  outcome_to_bool(outcome)
}

///|
/// Evaluates a Check request without contextual tuples or extra context.
pub fn Engine::check(
  self : Engine,
  object : String,
  relation : String,
  user : String,
) -> Bool raise @fga.FgaError {
  self.check_with(object, relation, user, Map([]), [])
}

///|
/// Evaluates a Check request with request context and contextual tuples.
pub fn Engine::check_with(
  self : Engine,
  object : String,
  relation : String,
  user : String,
  context : Map[String, Json],
  contextual_tuples : Array[@fga.Tuple],
) -> Bool raise @fga.FgaError {
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
  engine.check_resolved(object, relation, user, context)
}

///|
/// Evaluates a request; validation and condition failures raise FgaError.
pub fn Engine::check_request(
  self : Engine,
  request : CheckRequest,
) -> Bool raise @fga.FgaError {
  self.check_with(
    request.object,
    request.relation,
    request.user,
    request.context,
    request.contextual_tuples,
  )
}

///|
/// Evaluates several independent Check requests. Failures are captured per
/// request so a batch can report every invalid tuple.
pub fn Engine::batch_check(
  self : Engine,
  requests : Array[CheckRequest],
) -> Array[CheckResult] {
  let results : Array[CheckResult] = []
  for request in requests {
    let result = check_result_allowed(self.check_request(request)) catch {
      err => check_result_error(err)
    }
    results.push(result)
  }
  results
}
