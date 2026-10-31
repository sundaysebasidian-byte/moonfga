// Structural equality used by the DSL/JSON round-trip transformer tests.

///|
/// Deep JSON equality ignoring object key order and number representation.
pub fn json_eq(a : Json, b : Json) -> Bool {
  match (a, b) {
    (Null, Null) => true
    (True, True) => true
    (False, False) => true
    (String(x), String(y)) => x == y
    (Number(x, ..), Number(y, ..)) => x == y
    (Array(xs), Array(ys)) =>
      if xs.length() != ys.length() {
        false
      } else {
        let mut same = true
        for i in 0..<xs.length() {
          if !json_eq(xs[i], ys[i]) {
            same = false
          }
        }
        same
      }
    (Object(xs), Object(ys)) =>
      if xs.length() != ys.length() {
        false
      } else {
        let mut same = true
        xs.each(fn(k, v) {
          match ys.get(k) {
            Some(other) => if !json_eq(v, other) { same = false }
            None => same = false
          }
        })
        same
      }
    _ => false
  }
}

///|
fn option_string_eq(a : String?, b : String?) -> Bool {
  match (a, b) {
    (None, None) => true
    (Some(x), Some(y)) => x == y
    _ => false
  }
}

///|
fn restriction_eq(a : @fga.TypeRestriction, b : @fga.TypeRestriction) -> Bool {
  a.type_name == b.type_name &&
  a.wildcard == b.wildcard &&
  option_string_eq(a.relation, b.relation) &&
  option_string_eq(a.condition, b.condition)
}

///|
fn restrictions_eq(
  a : Array[@fga.TypeRestriction],
  b : Array[@fga.TypeRestriction],
) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for item in a {
    let mut found = false
    for other in b {
      if restriction_eq(item, other) {
        found = true
      }
    }
    if !found {
      return false
    }
  }
  true
}

///|
pub fn userset_eq(a : @fga.Userset, b : @fga.Userset) -> Bool {
  match (a, b) {
    (@fga.This, @fga.This) => true
    (@fga.Computed(x), @fga.Computed(y)) => x == y
    (@fga.TupleToUserset(ac, at), @fga.TupleToUserset(bc, bt)) =>
      ac == bc && at == bt
    (@fga.Union(xs), @fga.Union(ys)) => usersets_eq(xs, ys)
    (@fga.Intersection(xs), @fga.Intersection(ys)) => usersets_eq(xs, ys)
    (@fga.Difference(ab, as_), @fga.Difference(bb, bs)) =>
      userset_eq(ab, bb) && userset_eq(as_, bs)
    _ => false
  }
}

///|
fn usersets_eq(xs : Array[@fga.Userset], ys : Array[@fga.Userset]) -> Bool {
  if xs.length() != ys.length() {
    return false
  }
  let mut same = true
  for i in 0..<xs.length() {
    if !userset_eq(xs[i], ys[i]) {
      same = false
    }
  }
  same
}

///|
fn type_eq(a : @fga.TypeDefinition, b : @fga.TypeDefinition) -> Bool {
  if a.name != b.name {
    return false
  }
  if a.relations.length() != b.relations.length() {
    return false
  }
  for name in a.relation_order {
    match (a.relations.get(name), b.relations.get(name)) {
      (Some(rw_a), Some(rw_b)) =>
        if !userset_eq(rw_a, rw_b) ||
          !restrictions_eq(a.restrictions(name), b.restrictions(name)) {
          return false
        }
      _ => return false
    }
  }
  true
}

///|
fn parameter_eq(a : @fga.ConditionParam, b : @fga.ConditionParam) -> Bool {
  a.name == b.name &&
  a.type_name == b.type_name &&
  option_string_eq(a.generic_type, b.generic_type)
}

///|
fn params_eq(
  a : Array[@fga.ConditionParam],
  b : Array[@fga.ConditionParam],
) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for item in a {
    let mut found = false
    for other in b {
      if parameter_eq(item, other) {
        found = true
      }
    }
    if !found {
      return false
    }
  }
  true
}

///|
fn condition_eq(a : @fga.Condition, b : @fga.Condition) -> Bool {
  a.name == b.name &&
  a.expression.trim() == b.expression.trim() &&
  params_eq(a.parameters, b.parameters)
}

///|
/// Compares two authorization models semantically. Type order is significant;
/// relation and parameter order and metadata map order are not.
pub fn model_eq(a : @fga.AuthModel, b : @fga.AuthModel) -> Bool {
  if a.schema_version != b.schema_version ||
    a.types.length() != b.types.length() {
    return false
  }
  for i in 0..<a.types.length() {
    if !type_eq(a.types[i], b.types[i]) {
      return false
    }
  }
  if a.conditions.length() != b.conditions.length() {
    return false
  }
  let mut same = true
  a.conditions.each(fn(name, cond_a) {
    match b.conditions.get(name) {
      Some(cond_b) => if !condition_eq(cond_a, cond_b) { same = false }
      None => same = false
    }
  })
  same
}
