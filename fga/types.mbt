// Core data model shared by the DSL parser, JSON transformer, validator,
// tuple store and authorization engine.
//
// The types follow the OpenFGA authorization model shape, but are
// independently implemented in MoonBit.

///|
/// A CEL runtime value. Durations are stored in nanoseconds and timestamps
/// in milliseconds since the Unix epoch.
pub enum CelValue {
  VInt(Int64)
  VUint(UInt64)
  VDouble(Double)
  VBool(Bool)
  VString(String)
  VDuration(Int64)
  VTimestamp(Int64)
  VList(Array[CelValue])
  VMap(Map[String, CelValue])
  VIp(String)
  VNull
}

///|
pub fn cel_value_type_name(value : CelValue) -> String {
  match value {
    VInt(_) => "int"
    VUint(_) => "uint"
    VDouble(_) => "double"
    VBool(_) => "bool"
    VString(_) => "string"
    VDuration(_) => "duration"
    VTimestamp(_) => "timestamp"
    VList(_) => "list"
    VMap(_) => "map"
    VIp(_) => "ipaddress"
    VNull => "null"
  }
}

///|
/// Structural equality with numeric coercion, used by CEL `==` and by the
/// store when de-duplicating tuples.
pub fn cel_value_eq(a : CelValue, b : CelValue) -> Bool {
  match (a, b) {
    (VNull, VNull) => true
    (VBool(x), VBool(y)) => x == y
    (VString(x), VString(y)) => x == y
    (VDuration(x), VDuration(y)) => x == y
    (VTimestamp(x), VTimestamp(y)) => x == y
    (VIp(x), VIp(y)) => x == y
    (VInt(x), VInt(y)) => x == y
    (VUint(x), VUint(y)) => x == y
    (VDouble(x), VDouble(y)) => x == y
    (VInt(x), VDouble(y)) => x.to_double() == y
    (VDouble(x), VInt(y)) => x == y.to_double()
    (VUint(x), VDouble(y)) => x.to_double() == y
    (VDouble(x), VUint(y)) => x == y.to_double()
    (VInt(x), VUint(y)) => if x < 0L { false } else { x.to_uint64() == y }
    (VUint(x), VInt(y)) => if y < 0L { false } else { x == y.to_uint64() }
    (VList(xs), VList(ys)) =>
      if xs.length() != ys.length() {
        false
      } else {
        let mut same = true
        for i in 0..<xs.length() {
          if !cel_value_eq(xs[i], ys[i]) {
            same = false
          }
        }
        same
      }
    (VMap(xs), VMap(ys)) =>
      if xs.length() != ys.length() {
        false
      } else {
        let mut same = true
        xs.each(fn(k, v) {
          match ys.get(k) {
            Some(other) => if !cel_value_eq(v, other) { same = false }
            None => same = false
          }
        })
        same
      }
    _ => false
  }
}

///|
pub fn cel_value_to_display(value : CelValue) -> String {
  match value {
    VInt(x) => x.to_string()
    VUint(x) => x.to_string() + "u"
    VDouble(x) => x.to_string()
    VBool(x) => x.to_string()
    VString(x) => "\"" + x + "\""
    VDuration(x) =>
      if x % 1000000000L == 0L {
        (x / 1000000000L).to_string() + "s"
      } else {
        x.to_string() + "ns"
      }
    VTimestamp(x) => x.to_string()
    VList(xs) => {
      let parts = xs.map(fn(v) { cel_value_to_display(v) })
      "[" + parts.join(", ") + "]"
    }
    VMap(m) => "{" + m.length().to_string() + " entries}"
    VIp(x) => x
    VNull => "null"
  }
}

///|
/// A typed wildcard, concrete user, userset or condition-restricted type
/// restriction from `directly_related_user_types`.
pub struct TypeRestriction {
  type_name : String
  relation : String?
  wildcard : Bool
  condition : String?
}

///|
/// Resolved form of a tuple user string: `type:id`, `type:*` or
/// `type:id#relation`.
pub struct UserRef {
  type_name : String
  id : String
  relation : String?
}

///|
pub fn parse_user_ref(user : String) -> UserRef? {
  let hash = user.find("#")
  let base = match hash {
    Some(i) => user[:i].to_owned()
    None => user
  }
  let relation = match hash {
    Some(i) => {
      let rel = user[i + 1:].to_owned()
      if rel == "" {
        return None
      }
      Some(rel)
    }
    None => None
  }
  match base.find(":") {
    None => None
    Some(colon) => {
      let type_name = base[:colon].to_owned()
      let id = base[colon + 1:].to_owned()
      if type_name == "" || id == "" {
        None
      } else {
        Some(UserRef::{ type_name, id, relation, })
      }
    }
  }
}

///|
pub fn object_type(object : String) -> String {
  match object.find(":") {
    Some(i) => object[:i].to_owned()
    None => object
  }
}

///|
pub fn object_id(object : String) -> String {
  match object.find(":") {
    Some(i) => object[i + 1:].to_owned()
    None => ""
  }
}

///|
pub fn user_type_name(user : String) -> String {
  match parse_user_ref(user) {
    Some(r) => r.type_name
    None => ""
  }
}

///|
/// Renders a user ref back to canonical OpenFGA syntax.
pub fn render_user_ref(u : UserRef) -> String {
  let base = u.type_name + ":" + u.id
  match u.relation {
    Some(r) => base + "#" + r
    None => base
  }
}

///|
pub fn tuple_user_matches(u : UserRef, user : String) -> Bool {
  u.type_name + ":" + u.id == user
}

///|
pub struct TupleCondition {
  name : String
  context : Map[String, CelValue]
}

///|
pub struct Tuple {
  object : String
  relation : String
  user : String
  condition : TupleCondition?
}

///|
pub fn Tuple::key(self : Tuple) -> String {
  let cond = match self.condition {
    None => ""
    Some(c) => "|" + c.name + "|" + c.context.size().to_string()
  }
  self.object + "#" + self.relation + "@" + self.user + cond
}

///|
pub fn Tuple::has_condition(self : Tuple) -> Bool {
  match self.condition {
    Some(_) => true
    None => false
  }
}

///|
pub fn Tuple::condition_name(self : Tuple) -> String? {
  match self.condition {
    Some(c) => Some(c.name)
    None => None
  }
}

///|
/// A condition parameter declaration such as `x: int` or `xs: list<string>`.
pub struct ConditionParam {
  name : String
  type_name : String
  generic_type : String?
}

///|
pub struct Condition {
  name : String
  expression : String
  parameters : Array[ConditionParam]
}

///|
pub fn Condition::find_param(
  self : Condition,
  name : String,
) -> ConditionParam? {
  for p in self.parameters {
    if p.name == name {
      return Some(p)
    }
  }
  None
}

///|
pub enum Userset {
  This
  Computed(String)
  TupleToUserset(String, String)
  Union(Array[Userset])
  Intersection(Array[Userset])
  Difference(Userset, Userset)
}

///|
pub struct TypeDefinition {
  name : String
  relations : Map[String, Userset]
  relation_order : Array[String]
  direct : Map[String, Array[TypeRestriction]]
}

///|
pub fn TypeDefinition::new(name : String) -> TypeDefinition {
  TypeDefinition::{
    name,
    relations: Map([]),
    relation_order: [],
    direct: Map([]),
  }
}

///|
pub fn TypeDefinition::set_relation(
  self : TypeDefinition,
  name : String,
  rewrite : Userset,
  restrictions : Array[TypeRestriction],
) -> Unit {
  if !self.relations.contains(name) {
    self.relation_order.push(name)
  }
  self.relations[name] = rewrite
  self.direct[name] = restrictions
}

///|
pub fn TypeDefinition::relation_rewrite(
  self : TypeDefinition,
  name : String,
) -> Userset? {
  self.relations.get(name)
}

///|
pub fn TypeDefinition::restrictions(
  self : TypeDefinition,
  name : String,
) -> Array[TypeRestriction] {
  match self.direct.get(name) {
    Some(xs) => xs
    None => []
  }
}

///|
pub fn TypeDefinition::has_direct(self : TypeDefinition, name : String) -> Bool {
  self.restrictions(name).length() > 0
}

///|
pub struct AuthModel {
  schema_version : String
  types : Array[TypeDefinition]
  conditions : Map[String, Condition]
  condition_order : Array[String]
}

///|
pub fn AuthModel::new(schema_version : String) -> AuthModel {
  AuthModel::{
    schema_version,
    types: [],
    conditions: Map([]),
    condition_order: [],
  }
}

///|
pub fn AuthModel::find_type(self : AuthModel, name : String) -> TypeDefinition? {
  for t in self.types {
    if t.name == name {
      return Some(t)
    }
  }
  None
}

///|
pub fn AuthModel::find_condition(self : AuthModel, name : String) -> Condition? {
  self.conditions.get(name)
}

///|
pub fn AuthModel::add_type(self : AuthModel, t : TypeDefinition) -> Unit {
  self.types.push(t)
}

///|
pub fn AuthModel::add_condition(self : AuthModel, c : Condition) -> Unit {
  if !self.conditions.contains(c.name) {
    self.condition_order.push(c.name)
  }
  self.conditions[c.name] = c
}

///|
/// Returns the rewrite for `type#relation`, raising a typed error when either
/// the type or the relation is missing.
pub fn AuthModel::relation(
  self : AuthModel,
  type_name : String,
  relation : String,
) -> Userset raise FgaError {
  match self.find_type(type_name) {
    None => raise fail(ERR_TYPE_NOT_FOUND, "type '" + type_name + "' not found")
    Some(t) =>
      match t.relations.get(relation) {
        None =>
          raise fail(
            ERR_RELATION_NOT_FOUND,
            "relation '" + relation + "' not found on type '" + type_name + "'",
          )
        Some(rw) => rw
      }
  }
}

///|
pub fn AuthModel::direct_restrictions(
  self : AuthModel,
  type_name : String,
  relation : String,
) -> Array[TypeRestriction] {
  match self.find_type(type_name) {
    None => []
    Some(t) => t.restrictions(relation)
  }
}

///|
/// Validates a concrete tuple user against the direct restrictions of a
/// relation. This is the type-restriction filter applied when reading tuples.
pub fn restrictions_allow(
  restrictions : Array[TypeRestriction],
  user : String,
) -> Bool {
  let ur = match parse_user_ref(user) {
    Some(r) => r
    None => return false
  }
  let is_wildcard = ur.id == "*"
  for r in restrictions {
    if r.type_name != ur.type_name {
      continue
    }
    match r.relation {
      Some(rel) =>
        // Userset restriction: user must be `type:id#rel` and match exactly.
        if ur.relation == Some(rel) && !is_wildcard {
          return true
        }
      None =>
        match ur.relation {
          Some(_) =>
            // Usersets are only allowed through a userset restriction.
            ()
          None =>
            if is_wildcard {
              if r.wildcard {
                return true
              }
            } else {
              return true
            }
        }
    }
  }
  false
}

///|
/// Returns the condition name permitted for a matching restriction facet, or
/// None when the facet is unconditional.
pub fn matching_restriction_condition(
  restrictions : Array[TypeRestriction],
  user : String,
) -> String? raise FgaError {
  let ur = match parse_user_ref(user) {
    Some(r) => r
    None => raise fail(ERR_INVALID_TUPLE, "invalid user '" + user + "'")
  }
  let is_wildcard = ur.id == "*"
  for r in restrictions {
    if r.type_name != ur.type_name {
      continue
    }
    match r.relation {
      Some(rel) =>
        if ur.relation == Some(rel) && !is_wildcard {
          return r.condition
        }
      None =>
        match ur.relation {
          Some(_) => ()
          None =>
            if is_wildcard {
              if r.wildcard {
                return r.condition
              }
            } else {
              return r.condition
            }
        }
    }
  }
  None
}

///|
/// True when the user string is syntactically valid OpenFGA user syntax.
pub fn is_valid_user(user : String) -> Bool {
  match parse_user_ref(user) {
    None => false
    Some(r) => if r.relation == Some("") { false } else { true }
  }
}

///|
pub fn is_valid_object(object : String) -> Bool {
  match object.find(":") {
    None => false
    Some(i) => i > 0 && i + 1 < object.length()
  }
}

///|
/// Trait used by the engine to read tuples. Implementations must return
/// tuples visible for the given object and relation (including wildcard and
/// userset tuples).
pub trait TupleReader {
  fn read(Self, String, String) -> Array[Tuple]
  fn read_userset(Self, String, String) -> Array[Tuple]
  fn all_objects(Self, String) -> Array[String]
  fn all_users(Self) -> Array[String]
}
