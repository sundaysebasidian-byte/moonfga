// Conversion between OpenFGA AuthorizationModel JSON and the internal AST.

///|
fn invalid(message : String) -> @fga.FgaError {
  @fga.fail(@fga.ERR_VALIDATION, message)
}

///|
fn as_object(
  value : Json,
  what : String,
) -> Map[String, Json] raise @fga.FgaError {
  match value {
    Object(m) => m
    _ => raise invalid(what + " must be an object")
  }
}

///|
fn as_array(value : Json, what : String) -> Array[Json] raise @fga.FgaError {
  match value {
    Array(xs) => xs
    _ => raise invalid(what + " must be an array")
  }
}

///|
fn as_string(value : Json, what : String) -> String raise @fga.FgaError {
  match value {
    String(s) => s
    _ => raise invalid(what + " must be a string")
  }
}

///|
fn required(
  obj : Map[String, Json],
  key : String,
  what : String,
) -> Json raise @fga.FgaError {
  match obj.get(key) {
    Some(v) => v
    None => raise invalid(what + " is missing '" + key + "'")
  }
}

///|
fn optional_string(
  obj : Map[String, Json],
  key : String,
) -> String? raise @fga.FgaError {
  match obj.get(key) {
    Some(v) =>
      match v {
        Null => None
        String(s) => Some(s)
        _ => raise invalid("'" + key + "' must be a string")
      }
    None => None
  }
}

///|
fn base_type_from_json(name : String) -> String raise @fga.FgaError {
  match name {
    "TYPE_NAME_ANY" => "any"
    "TYPE_NAME_BOOL" => "bool"
    "TYPE_NAME_STRING" => "string"
    "TYPE_NAME_INT" => "int"
    "TYPE_NAME_UINT" => "uint"
    "TYPE_NAME_DOUBLE" => "double"
    "TYPE_NAME_DURATION" => "duration"
    "TYPE_NAME_TIMESTAMP" => "timestamp"
    "TYPE_NAME_IPADDRESS" => "ipaddress"
    "TYPE_NAME_LIST" => "list"
    "TYPE_NAME_MAP" => "map"
    _ => raise invalid("unsupported condition parameter type '" + name + "'")
  }
}

///|
fn base_type_to_json(name : String) -> String raise @fga.FgaError {
  match name {
    "any" => "TYPE_NAME_ANY"
    "bool" => "TYPE_NAME_BOOL"
    "string" => "TYPE_NAME_STRING"
    "int" => "TYPE_NAME_INT"
    "uint" => "TYPE_NAME_UINT"
    "double" => "TYPE_NAME_DOUBLE"
    "duration" => "TYPE_NAME_DURATION"
    "timestamp" => "TYPE_NAME_TIMESTAMP"
    "ipaddress" => "TYPE_NAME_IPADDRESS"
    "list" => "TYPE_NAME_LIST"
    "map" => "TYPE_NAME_MAP"
    _ => raise invalid("unsupported condition parameter type '" + name + "'")
  }
}

///|
fn parse_restriction(value : Json) -> @fga.TypeRestriction raise @fga.FgaError {
  let obj = as_object(value, "directly_related_user_types entry")
  let type_name = as_string(
    required(obj, "type", "type restriction"),
    "type restriction type",
  )
  let relation = optional_string(obj, "relation")
  let wildcard = obj.contains("wildcard")
  let condition = optional_string(obj, "condition")
  @fga.TypeRestriction::{ type_name, relation, wildcard, condition, }
}

///|
fn parse_rewrite(value : Json) -> @fga.Userset raise @fga.FgaError {
  let obj = as_object(value, "relation rewrite")
  if obj.contains("this") {
    @fga.This
  } else if obj.contains("computedUserset") {
    let inner = as_object(
      required(obj, "computedUserset", "computed userset"),
      "computedUserset",
    )
    @fga.Computed(
      as_string(
        required(inner, "relation", "computed userset"),
        "computed relation",
      ),
    )
  } else if obj.contains("tupleToUserset") {
    let inner = as_object(
      required(obj, "tupleToUserset", "tuple to userset"),
      "tupleToUserset",
    )
    let tupleset = as_object(
      required(inner, "tupleset", "tupleToUserset"),
      "tupleset",
    )
    let computed = as_object(
      required(inner, "computedUserset", "tupleToUserset"),
      "computedUserset",
    )
    @fga.TupleToUserset(
      as_string(
        required(computed, "relation", "computed userset"),
        "computed relation",
      ),
      as_string(required(tupleset, "relation", "tupleset"), "tupleset relation"),
    )
  } else if obj.contains("union") {
    let inner = as_object(required(obj, "union", "union rewrite"), "union")
    let children = as_array(
      required(inner, "child", "union rewrite"),
      "union child",
    )
    let rewrites : Array[@fga.Userset] = []
    for child in children {
      rewrites.push(parse_rewrite(child))
    }
    @fga.Union(rewrites)
  } else if obj.contains("intersection") {
    let inner = as_object(
      required(obj, "intersection", "intersection rewrite"),
      "intersection",
    )
    let children = as_array(
      required(inner, "child", "intersection rewrite"),
      "intersection child",
    )
    let rewrites : Array[@fga.Userset] = []
    for child in children {
      rewrites.push(parse_rewrite(child))
    }
    @fga.Intersection(rewrites)
  } else if obj.contains("difference") {
    let inner = as_object(
      required(obj, "difference", "difference rewrite"),
      "difference",
    )
    @fga.Difference(
      parse_rewrite(required(inner, "base", "difference rewrite")),
      parse_rewrite(required(inner, "subtract", "difference rewrite")),
    )
  } else {
    raise invalid("unknown relation rewrite")
  }
}

///|
fn parse_condition_parameter(
  value : Json,
) -> @fga.ConditionParam raise @fga.FgaError {
  let obj = as_object(value, "condition parameter")
  let type_name = base_type_from_json(
    as_string(
      required(obj, "type_name", "condition parameter"),
      "parameter type_name",
    ),
  )
  let generic_type = match obj.get("generic_types") {
    None => None
    Some(Null) => None
    Some(v) => {
      let items = as_array(v, "generic_types")
      if items.length() == 0 {
        None
      } else {
        if items.length() != 1 {
          raise invalid("expected one generic parameter")
        }
        let inner = parse_condition_parameter(items[0])
        Some(
          match inner.generic_type {
            Some(t) => inner.type_name + "<" + t + ">"
            None => inner.type_name
          },
        )
      }
    }
  }
  @fga.ConditionParam::{ name: "", type_name, generic_type, }
}

///|
fn parse_condition(
  name : String,
  value : Json,
) -> @fga.Condition raise @fga.FgaError {
  let obj = as_object(value, "condition '" + name + "'")
  let expression = as_string(
    required(obj, "expression", "condition '" + name + "'"),
    "condition expression",
  )
  let parameters : Array[@fga.ConditionParam] = []
  match obj.get("parameters") {
    None => ()
    Some(Null) => ()
    Some(v) => {
      let params = as_object(v, "condition parameters")
      for param_name in params.keys() {
        match params.get(param_name) {
          Some(param_value) => {
            let param = parse_condition_parameter(param_value)
            parameters.push(@fga.ConditionParam::{
              name: param_name,
              type_name: param.type_name,
              generic_type: param.generic_type,
            })
          }
          None => ()
        }
      }
    }
  }
  @fga.Condition::{ name, expression, parameters, }
}

///|
/// Imports an AuthorizationModel JSON value.
pub fn model_from_json(value : Json) -> @fga.AuthModel raise @fga.FgaError {
  let obj = as_object(value, "authorization model")
  let schema_version = match obj.get("schema_version") {
    Some(v) => as_string(v, "schema_version")
    None => "1.1"
  }
  let model = @fga.AuthModel::new(schema_version)
  match obj.get("type_definitions") {
    None => ()
    Some(Null) => ()
    Some(v) =>
      for type_value in as_array(v, "type_definitions") {
        let type_obj = as_object(type_value, "type definition")
        let type_name = as_string(
          required(type_obj, "type", "type definition"),
          "type definition name",
        )
        let td = @fga.TypeDefinition::new(type_name)
        let relation_metadata : Map[String, Json] = match
          type_obj.get("metadata") {
          None => Map([])
          Some(Null) => Map([])
          Some(meta_value) => {
            let meta = as_object(meta_value, "type metadata")
            match meta.get("relations") {
              None => Map([])
              Some(Null) => Map([])
              Some(rels) => as_object(rels, "type metadata relations")
            }
          }
        }
        match type_obj.get("relations") {
          None => ()
          Some(Null) => ()
          Some(rels_value) => {
            let rels = as_object(rels_value, "type relations")
            for rel_name in rels.keys() {
              match rels.get(rel_name) {
                Some(rel_value) => {
                  let restrictions : Array[@fga.TypeRestriction] = match
                    relation_metadata.get(rel_name) {
                    None => []
                    Some(meta_value) => {
                      let meta = as_object(meta_value, "relation metadata")
                      match meta.get("directly_related_user_types") {
                        None => []
                        Some(Null) => []
                        Some(list) => {
                          let parsed : Array[@fga.TypeRestriction] = []
                          for
                            item in as_array(
                              list, "directly_related_user_types",
                            ) {
                            parsed.push(parse_restriction(item))
                          }
                          parsed
                        }
                      }
                    }
                  }
                  td.set_relation(
                    rel_name,
                    parse_rewrite(rel_value),
                    restrictions,
                  )
                }
                None => ()
              }
            }
          }
        }
        match type_obj.get("metadata") {
          Some(Object(meta)) => {
            let base = meta.copy()
            base.remove("relations") |> ignore
            if base.length() > 0 {
              model.metadata["type:" + type_name] = Json::object(base)
            }
            relation_metadata.each(fn(rel, value) {
              if value is Object(rmeta) {
                let extra = rmeta.copy()
                extra.remove("directly_related_user_types") |> ignore
                if extra.length() > 0 {
                  model.metadata["rel:" + type_name + ":" + rel] = Json::object(
                    extra,
                  )
                }
              }
            })
          }
          _ => ()
        }
        model.add_type(td)
      }
  }
  match obj.get("conditions") {
    None => ()
    Some(Null) => ()
    Some(v) => {
      let conditions = as_object(v, "conditions")
      for name in conditions.keys() {
        match conditions.get(name) {
          Some(cond_value) => {
            model.add_condition(parse_condition(name, cond_value))
            if cond_value is Object(cobj) {
              if cobj.get("metadata") is Some(meta) {
                model.metadata["condition:" + name] = meta
              }
            }
          }
          None => ()
        }
      }
    }
  }
  model
}

///|
fn rewrite_to_json(us : @fga.Userset) -> Json {
  match us {
    @fga.This => Json::object(Map([("this", Json::object(Map([])))]))
    @fga.Computed(relation) =>
      Json::object(
        Map([
          (
            "computedUserset",
            Json::object(Map([("relation", Json::string(relation))])),
          ),
        ]),
      )
    @fga.TupleToUserset(computed, tupleset) =>
      Json::object(
        Map([
          (
            "tupleToUserset",
            Json::object(
              Map([
                (
                  "tupleset",
                  Json::object(Map([("relation", Json::string(tupleset))])),
                ),
                (
                  "computedUserset",
                  Json::object(Map([("relation", Json::string(computed))])),
                ),
              ]),
            ),
          ),
        ]),
      )
    @fga.Union(children) =>
      Json::object(
        Map([
          (
            "union",
            Json::object(
              Map([
                (
                  "child",
                  Json::array(children.map(fn(c) { rewrite_to_json(c) })),
                ),
              ]),
            ),
          ),
        ]),
      )
    @fga.Intersection(children) =>
      Json::object(
        Map([
          (
            "intersection",
            Json::object(
              Map([
                (
                  "child",
                  Json::array(children.map(fn(c) { rewrite_to_json(c) })),
                ),
              ]),
            ),
          ),
        ]),
      )
    @fga.Difference(base, subtract) =>
      Json::object(
        Map([
          (
            "difference",
            Json::object(
              Map([
                ("base", rewrite_to_json(base)),
                ("subtract", rewrite_to_json(subtract)),
              ]),
            ),
          ),
        ]),
      )
  }
}

///|
fn restriction_to_json(r : @fga.TypeRestriction) -> Json {
  let fields : Array[(String, Json)] = [("type", Json::string(r.type_name))]
  match r.relation {
    Some(rel) => fields.push(("relation", Json::string(rel)))
    None => ()
  }
  if r.wildcard {
    fields.push(("wildcard", Json::object(Map([]))))
  }
  match r.condition {
    Some(cond) => fields.push(("condition", Json::string(cond)))
    None => ()
  }
  Json::object(Map(fields))
}

///|
fn type_to_json(td : @fga.TypeDefinition) -> Json {
  let relations = Map([])
  for name in td.relation_order {
    match td.relations.get(name) {
      Some(rewrite) => relations[name] = rewrite_to_json(rewrite)
      None => ()
    }
  }
  let metadata_relations = Map([])
  for name in td.relation_order {
    let restrictions = td.restrictions(name)
    let items : Array[Json] = []
    for r in restrictions {
      items.push(restriction_to_json(r))
    }
    metadata_relations[name] = Json::object(
      Map([("directly_related_user_types", Json::array(items))]),
    )
  }
  let metadata = if td.relation_order.length() == 0 {
    Json::null()
  } else {
    Json::object(Map([("relations", Json::object(metadata_relations))]))
  }
  Json::object(
    Map([
      ("type", Json::string(td.name)),
      ("relations", Json::object(relations)),
      ("metadata", metadata),
    ]),
  )
}

///|
fn parameter_to_json(p : @fga.ConditionParam) -> Json raise @fga.FgaError {
  let fields : Array[(String, Json)] = [
    ("type_name", Json::string(base_type_to_json(p.type_name))),
  ]
  match p.generic_type {
    Some(inner) =>
      fields.push(
        (
          "generic_types",
          Json::array([parameter_to_json(parameter_from_type_text(inner))]),
        ),
      )
    None => ()
  }
  Json::object(Map(fields))
}

///|
fn condition_to_json(c : @fga.Condition) -> Json raise @fga.FgaError {
  let parameters = Map([])
  for p in c.parameters {
    parameters[p.name] = parameter_to_json(p)
  }
  Json::object(
    Map([
      ("name", Json::string(c.name)),
      ("expression", Json::string(c.expression)),
      ("parameters", Json::object(parameters)),
    ]),
  )
}

///|
/// Exports an authorization model as an AuthorizationModel JSON value.
pub fn model_to_json(model : @fga.AuthModel) -> Json raise @fga.FgaError {
  let type_definitions : Array[Json] = []
  for td in model.types {
    let value = type_to_json(td)
    if value is Object(obj) {
      let meta = match obj.get("metadata") {
        Some(Object(m)) => m
        _ => Map([])
      }
      if model.metadata.get("type:" + td.name) is Some(Object(extra)) {
        extra.each(fn(k, v) { meta[k] = v })
      }
      if meta.get("relations") is Some(Object(rels)) {
        for rel in td.relation_order {
          if rels.get(rel) is Some(Object(rmeta)) {
            if model.metadata.get("rel:" + td.name + ":" + rel)
              is Some(Object(extra)) {
              extra.each(fn(k, v) { rmeta[k] = v })
            }
          }
        }
      }
      if meta.length() > 0 {
        obj["metadata"] = Json::object(meta)
      }
    }
    type_definitions.push(value)
  }
  let fields : Array[(String, Json)] = [
    ("schema_version", Json::string(model.schema_version)),
  ]
  if type_definitions.length() > 0 {
    fields.push(("type_definitions", Json::array(type_definitions)))
  }
  if model.condition_order.length() > 0 {
    let conditions = Map([])
    for name in model.condition_order {
      match model.conditions.get(name) {
        Some(c) => {
          let value = condition_to_json(c)
          if value is Object(obj) {
            if model.metadata.get("condition:" + name) is Some(meta) {
              obj["metadata"] = meta
            }
          }
          conditions[name] = value
        }
        None => ()
      }
    }
    fields.push(("conditions", Json::object(conditions)))
  }
  Json::object(Map(fields))
}

///|
pub fn model_to_json_string(
  model : @fga.AuthModel,
) -> String raise @fga.FgaError {
  model_to_json(model).stringify(indent=2)
}

///|
fn parameter_from_type_text(text : String) -> @fga.ConditionParam {
  match text.find("<") {
    Some(i) =>
      {
        name: "",
        type_name: text[:i].to_owned(),
        generic_type: Some(text[i + 1:text.length() - 1].to_owned()),
      }
    None => { name: "", type_name: text, generic_type: None, }
  }
}
