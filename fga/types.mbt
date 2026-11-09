// Core data model shared by the DSL parser, JSON transformer, validator,
// tuple store and authorization engine.
//
// The types follow the OpenFGA authorization model shape, but are
// independently implemented in MoonBit.

///|
/// A CEL runtime value. Durations are stored in nanoseconds and timestamps
/// in milliseconds since the Unix epoch, with an optional sub-millisecond
/// nanosecond remainder for precise RFC3339 inputs.
pub(all) enum CelValue {
  VInt(Int64)
  VUint(UInt64)
  VDouble(Double)
  VBool(Bool)
  VString(String)
  VBytes(Bytes)
  VType(String)
  VProtoEmpty
  VProtoFields(String, CelValue?)
  VKeyMap(Array[(CelValue, CelValue)])
  VDuration(Int64)
  VTimestamp(Int64)
  VTimestampWide(Int64, Int32)
  VTimestampPrecise(Int64, Int32, Int32)
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
    VBytes(_) => "bytes"
    VType(_) => "type"
    VProtoEmpty => "google.protobuf.Empty"
    VProtoFields(_, _) => "google.protobuf.Struct.FieldsEntry"
    VKeyMap(_) => "map"
    VDuration(_) => "duration"
    VTimestamp(_) | VTimestampWide(_, _) | VTimestampPrecise(_, _, _) =>
      "timestamp"
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
  match (a.timestamp_seconds(), b.timestamp_seconds()) {
    (Some(x), Some(y)) => return x == y
    _ => ()
  }
  match (a, b) {
    (VNull, VNull) | (VProtoEmpty, VProtoEmpty) => true
    (VBool(x), VBool(y)) => x == y
    (VString(x), VString(y)) => x == y
    (VBytes(x), VBytes(y)) => x == y
    (VType(x), VType(y)) => x == y
    (VProtoFields(k, v), VProtoFields(k2, v2)) =>
      k == k2 &&
      (match (v, v2) {
        (None, None) => true
        (Some(x), Some(y)) => cel_value_eq(x, y)
        _ => false
      })
    (VKeyMap(xs), VKeyMap(ys)) =>
      xs.length() == ys.length() &&
      xs.all(e => {
        match cel_map_find(ys, e.0) {
          Some(v) => cel_value_eq(e.1, v)
          None => false
        }
      })
    (VDuration(x), VDuration(y)) => x == y
    (VTimestamp(x), VTimestamp(y)) => x == y
    (VIp(x), VIp(y)) => x == y
    (VInt(x), VInt(y)) => x == y
    (VUint(x), VUint(y)) => x == y
    (VDouble(x), VDouble(y)) => x == y
    (VInt(_), VDouble(_))
    | (VDouble(_), VInt(_))
    | (VUint(_), VDouble(_))
    | (VDouble(_), VUint(_))
    | (VInt(_), VUint(_))
    | (VUint(_), VInt(_)) => cel_numeric_compare(a, b) == Some(0)
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
    VBytes(x) => x.to_string()
    VType(x) => x
    VProtoEmpty => "google.protobuf.Empty{}"
    VProtoFields(_, _) => "google.protobuf.Struct.FieldsEntry{}"
    VKeyMap(xs) => "{" + xs.length().to_string() + " entries}"
    VDuration(x) =>
      if x % 1000000000L == 0L {
        (x / 1000000000L).to_string() + "s"
      } else {
        x.to_string() + "ns"
      }
    VTimestamp(x) => x.to_string()
    VTimestampWide(s, ns) => s.to_string() + "s+" + ns.to_string() + "ns"
    VTimestampPrecise(x, sub, _) =>
      x.to_string() + "ms+" + sub.to_string() + "ns"
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
pub(all) struct TypeRestriction {
  type_name : String
  relation : String?
  wildcard : Bool
  condition : String?
}

///|
/// Resolved form of a tuple user string: `type:id`, `type:*` or
/// `type:id#relation`.
pub(all) struct UserRef {
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
pub(all) struct TupleCondition {
  name : String
  context : Map[String, CelValue]
}

///|
pub(all) struct Tuple {
  object : String
  relation : String
  user : String
  condition : TupleCondition?
}

///|
pub fn Tuple::key(self : Tuple) -> String {
  let cond = match self.condition {
    None => ""
    Some(c) => "|" + c.name + "|" + c.context.length().to_string()
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
pub(all) struct ConditionParam {
  name : String
  type_name : String
  generic_type : String?
}

///|
pub(all) struct Condition {
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
pub(all) enum Userset {
  This
  Computed(String)
  TupleToUserset(String, String)
  Union(Array[Userset])
  Intersection(Array[Userset])
  Difference(Userset, Userset)
}

///|
pub(all) struct TypeDefinition {
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
pub(all) struct Span {
  line : Int32
  column : Int32
}

///|
pub(all) struct AuthModel {
  schema_version : String
  types : Array[TypeDefinition]
  conditions : Map[String, Condition]
  condition_order : Array[String]
  spans : Map[String, Span]
  metadata : Map[String, Json]
}

///|
pub fn AuthModel::new(schema_version : String) -> AuthModel {
  AuthModel::{
    schema_version,
    types: [],
    conditions: Map([]),
    condition_order: [],
    spans: Map([]),
    metadata: Map([]),
  }
}

///|
pub fn AuthModel::set_span(
  self : AuthModel,
  key : String,
  line : Int32,
  column : Int32,
) -> Unit {
  self.spans[key] = Span::{ line, column, }
}

///|
pub fn AuthModel::span(self : AuthModel, key : String) -> Span? {
  self.spans.get(key)
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
/// True when an identifier contains no separators or whitespace.
fn is_clean_ident(value : String) -> Bool {
  if value == "" {
    return false
  }
  for c in value.iter() {
    if c == ':' ||
      c == '#' ||
      c == ' ' ||
      c == '\t' ||
      c == '\n' ||
      c == '\r' ||
      c == '\u000B' ||
      c == '\u000C' {
      return false
    }
  }
  true
}

///|
/// True when the user string is syntactically valid OpenFGA user syntax.
pub fn is_valid_user(user : String) -> Bool {
  let mut bytes = 0
  for c in user.iter() {
    let n = c.to_int()
    bytes += if n < 128 {
      1
    } else if n < 2048 {
      2
    } else if n < 65536 {
      3
    } else {
      4
    }
    if bytes > 512 {
      return false
    }
  }
  match parse_user_ref(user) {
    None => false
    Some(r) => {
      if !is_clean_ident(r.type_name) || !is_clean_ident(r.id) {
        return false
      }
      match r.relation {
        Some(rel) => is_clean_ident(rel) && r.id != "*"
        None => true
      }
    }
  }
}

///|
pub fn is_valid_object(object : String) -> Bool {
  if object.char_length() > 256 {
    return false
  }
  match object.find(":") {
    None => false
    Some(i) => {
      let type_name = object[:i].to_owned()
      let id = object[i + 1:].to_owned()
      is_clean_ident(type_name) && is_clean_ident(id)
    }
  }
}

///|
/// Trait used by the engine to read tuples. Implementations must return
/// tuples visible for the given object and relation (including wildcard and
/// userset tuples). Returned arrays must be caller-owned; all methods must see
/// a consistent snapshot during evaluation. Empty results mean no matching
/// data, never a backend failure. This synchronous trait has no error channel:
/// fallible hosts must load a snapshot successfully before creating an Engine.
/// See examples/tuple-reader for a standalone host and executable contract.
pub(open) trait TupleReader {
  fn read(Self, String, String) -> Array[Tuple]
  fn read_userset(Self, String, String) -> Array[Tuple]
  fn all_objects(Self, String) -> Array[String]
  fn all_users(Self) -> Array[String]
}

///|
/// Timestamp components: epoch milliseconds and a non-negative nanosecond
/// remainder below one millisecond.
pub fn CelValue::timestamp_parts(self : CelValue) -> (Int64, Int32)? {
  match self {
    VTimestamp(ms) => Some((ms, 0))
    VTimestampPrecise(ms, sub, _) => Some((ms, sub))
    _ => None
  }
}

///|
/// Normalizes a timestamp remainder without narrowing the supported year range.
pub fn timestamp_value(
  ms : Int64,
  remainder : Int64,
  offset~ : Int32 = 0,
) -> CelValue {
  let carry = if remainder >= 0L {
    remainder / 1000000L
  } else {
    (remainder - 999999L) / 1000000L
  }
  let sub = (remainder - carry * 1000000L).to_int()
  if sub == 0 && offset == 0 {
    VTimestamp(ms + carry)
  } else {
    VTimestampPrecise(ms + carry, sub, offset)
  }
}

///|
/// Preserved numeric timezone offset used by CEL string(timestamp).
pub fn CelValue::timestamp_offset(self : CelValue) -> Int32 {
  match self {
    VTimestampPrecise(_, _, offset) => offset
    _ => 0
  }
}

///|
/// Typed keys take precedence; cross-numeric fallback must be exact, rather
/// than using CEL's mixed-double value-equality rounding.
pub fn cel_map_find(
  entries : Array[(CelValue, CelValue)],
  key : CelValue,
) -> CelValue? {
  for (candidate, value) in entries {
    if cel_value_type_name(candidate) == cel_value_type_name(key) &&
      cel_value_eq(candidate, key) {
      return Some(value)
    }
  }
  for (candidate, value) in entries {
    if !(candidate is VDouble(_)) && numeric_compare(candidate, key) == Some(0) {
      return Some(value)
    }
  }
  None
}

///|
/// Epoch seconds and normalized nanoseconds; unlike milliseconds these cover
/// every protobuf int64 timestamp. Comparison follows Go's internal epoch.
pub fn CelValue::timestamp_seconds(self : CelValue) -> (Int64, Int32)? {
  match self {
    VTimestampWide(s, ns) => Some((s, ns))
    _ =>
      self
      .timestamp_parts()
      .map(p => {
        let seconds = p.0 / 1000L - (if p.0 % 1000L < 0L { 1L } else { 0L })
        (seconds, ((p.0 % 1000L + 1000L) % 1000L * 1000000L).to_int() + p.1)
      })
  }
}

///|
pub fn timestamp_from_seconds(
  seconds : Int64,
  nanos : Int64,
  offset~ : Int32 = 0,
) -> CelValue {
  let carry = nanos / 1000000000L -
    (if nanos % 1000000000L < 0L { 1L } else { 0L })
  let s = seconds + carry
  let ns = ((nanos % 1000000000L + 1000000000L) % 1000000000L).to_int()
  if s >= -9223372036854775L && s <= 9223372036854774L {
    timestamp_value(s * 1000L, ns.to_int64(), offset~)
  } else {
    VTimestampWide(s, ns)
  }
}
