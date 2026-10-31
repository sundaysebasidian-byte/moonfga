// Canonical DSL rendering. The output is stable and re-parses to the same
// authorization model.

///|
fn restriction_to_dsl(r : @fga.TypeRestriction) -> String {
  let mut text = r.type_name
  match r.relation {
    Some(rel) => text = text + "#" + rel
    None => if r.wildcard { text = text + ":*" }
  }
  match r.condition {
    Some(cond) => text + " with " + cond
    None => text
  }
}

///|
fn restrictions_to_dsl(restrictions : Array[@fga.TypeRestriction]) -> String {
  let parts = restrictions.map(fn(r) { restriction_to_dsl(r) })
  "[" + parts.join(", ") + "]"
}

///|
fn userset_precedence(us : @fga.Userset) -> Int32 {
  match us {
    @fga.Union(_) => 1
    @fga.Intersection(_) => 2
    @fga.Difference(_, _) => 3
    _ => 4
  }
}

///|
fn userset_is_this(us : @fga.Userset) -> Bool {
  match us {
    @fga.This => true
    _ => false
  }
}

///|
fn render_userset(
  us : @fga.Userset,
  restrictions : Array[@fga.TypeRestriction],
  min_precedence : Int32,
) -> String {
  let precedence = userset_precedence(us)
  let text = match us {
    @fga.This => restrictions_to_dsl(restrictions)
    @fga.Computed(name) => name
    @fga.TupleToUserset(computed, tupleset) => computed + " from " + tupleset
    @fga.Union(children) => {
      let parts : Array[String] = []
      let mut direct_printed = false
      for child in children {
        if userset_is_this(child) {
          if !direct_printed {
            parts.push(restrictions_to_dsl(restrictions))
            direct_printed = true
          }
        } else {
          parts.push(render_userset(child, restrictions, 2))
        }
      }
      if parts.length() == 0 {
        restrictions_to_dsl(restrictions)
      } else {
        parts.join(" or ")
      }
    }
    @fga.Intersection(children) => {
      let parts = children.map(fn(child) {
        render_userset(child, restrictions, 3)
      })
      parts.join(" and ")
    }
    @fga.Difference(left, right) =>
      render_userset(left, restrictions, 3) +
      " but not " +
      render_userset(right, restrictions, 4)
  }
  if precedence < min_precedence {
    "(" + text + ")"
  } else {
    text
  }
}

///|
fn type_to_dsl(td : @fga.TypeDefinition) -> String {
  let sb = StringBuilder()
  sb.write_string("type " + td.name)
  if td.relation_order.length() > 0 {
    sb.write_string("\n  relations")
    for name in td.relation_order {
      let rewrite = match td.relations.get(name) {
        Some(rw) => rw
        None => @fga.This
      }
      let restrictions = td.restrictions(name)
      sb.write_string(
        "\n    define " + name + ": " + render_userset(rewrite, restrictions, 1),
      )
    }
  }
  sb.to_string()
}

///|
fn condition_param_to_dsl(p : @fga.ConditionParam) -> String {
  let type_text = match p.generic_type {
    Some(inner) => p.type_name + "<" + inner + ">"
    None => p.type_name
  }
  p.name + ": " + type_text
}

///|
fn condition_to_dsl(c : @fga.Condition) -> String {
  let params = c.parameters.map(fn(p) { condition_param_to_dsl(p) })
  "condition " +
  c.name +
  "(" +
  params.join(", ") +
  ") {\n  " +
  c.expression +
  "\n}"
}

///|
/// Renders an authorization model as schema 1.1 DSL.
pub fn to_dsl(model : @fga.AuthModel) -> String {
  let sb = StringBuilder()
  sb.write_string("model\n  schema " + model.schema_version)
  for td in model.types {
    sb.write_string("\n\n" + type_to_dsl(td))
  }
  for name in model.condition_order {
    match model.conditions.get(name) {
      Some(c) => sb.write_string("\n\n" + condition_to_dsl(c))
      None => ()
    }
  }
  sb.write_string("\n")
  sb.to_string()
}
