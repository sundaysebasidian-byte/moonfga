// Semantic validation of authorization models.
//
// Structural checks mirror OpenFGA's model validation: every referenced type,
// relation and condition must exist, tuple-to-userset relations must be
// direct-only, relations need a reachable entry point, and declarations must
// not be duplicated. Issues carry the best available source position.

///|
const INLINE_EXPRESSION_NAME : String = "$expression"

///|
fn is_parameter_type(name : String) -> Bool {
  name == "bool" ||
  name == "string" ||
  name == "int" ||
  name == "uint" ||
  name == "double" ||
  name == "duration" ||
  name == "timestamp" ||
  name == "ipaddress"
}

///|
pub(all) struct ValidationIssue {
  code : Int32
  message : String
  line : Int32
  column : Int32
  symbol : String
}

///|
pub fn format_issue(issue : ValidationIssue) -> String {
  if issue.line >= 0 {
    "E" +
    issue.code.to_string() +
    " at " +
    issue.line.to_string() +
    ":" +
    issue.column.to_string() +
    ": " +
    issue.message
  } else {
    "E" + issue.code.to_string() + ": " + issue.message
  }
}

///|
fn issue_at(
  issues : Array[ValidationIssue],
  model : @fga.AuthModel,
  key : String,
  message : String,
  symbol : String,
) -> Unit {
  let (line, column) = match model.span(key) {
    Some(span) => (span.line, span.column)
    None => (-1, -1)
  }
  let source = match model.metadata.get(key) {
    Some(meta) => Some(meta)
    None => {
      let parts = key.split(":").to_array()
      if parts.length() > 1 {
        model.metadata.get("type:" + parts[1].to_owned())
      } else {
        None
      }
    }
  }
  issues.push(ValidationIssue::{
    code: @fga.ERR_VALIDATION,
    message: match source {
      Some(Object(meta)) =>
        "[" + Json::object(meta).stringify() + "] " + message
      _ => message
    },
    line,
    column,
    symbol,
  })
}

///|
fn is_name_char(c : Char) -> Bool {
  c != ':' &&
  c != '#' &&
  c != '@' &&
  c != '*' &&
  c != ' ' &&
  c != '\t' &&
  c != '\r' &&
  c != '\n'
}

///|
fn name_matches(value : String, max_length : Int32) -> Bool {
  let length = value.length()
  if length == 0 || length > max_length {
    return false
  }
  for i in 0..<length {
    let c = match value.get_char(i) {
      Some(c) => c
      None => return false
    }
    if !is_name_char(c) {
      return false
    }
  }
  true
}

///|
fn restriction_label(r : @fga.TypeRestriction) -> String {
  let base = if r.wildcard {
    r.type_name + ":*"
  } else {
    match r.relation {
      Some(relation) => r.type_name + "#" + relation
      None => r.type_name
    }
  }
  match r.condition {
    Some(condition) => base + " with " + condition
    None => base
  }
}

///|
fn same_userset(a : @fga.Userset, b : @fga.Userset) -> Bool {
  match (a, b) {
    (This, This) => true
    (Computed(x), Computed(y)) => x == y
    (TupleToUserset(xc, xt), TupleToUserset(yc, yt)) => xc == yc && xt == yt
    (Union(xs), Union(ys)) =>
      if xs.length() != ys.length() {
        false
      } else {
        let mut same = true
        for i in 0..<xs.length() {
          if !same_userset(xs[i], ys[i]) {
            same = false
          }
        }
        same
      }
    (Intersection(xs), Intersection(ys)) =>
      if xs.length() != ys.length() {
        false
      } else {
        let mut same = true
        for i in 0..<xs.length() {
          if !same_userset(xs[i], ys[i]) {
            same = false
          }
        }
        same
      }
    (Difference(xb, xs), Difference(yb, ys)) =>
      same_userset(xb, yb) && same_userset(xs, ys)
    _ => false
  }
}

///|
/// Validates the relations of one type. Returns true when the relation had no
/// structural errors and can therefore be considered by the entry-point pass.
fn validate_restrictions(
  model : @fga.AuthModel,
  type_name : String,
  relation : String,
  restrictions : Array[@fga.TypeRestriction],
  used_conditions : Map[String, Unit],
  issues : Array[ValidationIssue],
) -> Bool {
  let key = "rel:" + type_name + ":" + relation
  let seen : Map[String, Unit] = Map([])
  let mut valid = true
  for r in restrictions {
    let label = restriction_label(r)
    if seen.contains(label) {
      valid = false
      issue_at(
        issues,
        model,
        key,
        "the type restriction `" +
        label +
        "` is a duplicate in the relation `" +
        relation +
        "`.",
        label,
      )
      continue
    }
    seen[label] = ()
    if r.relation != None && r.wildcard {
      valid = false
      issue_at(
        issues,
        model,
        key,
        "the type restriction `" +
        label +
        "` cannot be both a userset and a wildcard.",
        label,
      )
    }
    match model.find_type(r.type_name) {
      None => {
        valid = false
        issue_at(
          issues,
          model,
          key,
          "`" + r.type_name + "` is not a valid type.",
          r.type_name,
        )
      }
      Some(target) =>
        match r.relation {
          Some(target_relation) =>
            if !target.relations.contains(target_relation) {
              valid = false
              issue_at(
                issues,
                model,
                key,
                "`" +
                target_relation +
                "` is not a valid relation for `" +
                r.type_name +
                "`.",
                target_relation,
              )
            }
          None => ()
        }
    }
    match r.condition {
      Some(condition) =>
        if condition != INLINE_EXPRESSION_NAME {
          match model.find_condition(condition) {
            None => {
              valid = false
              issue_at(
                issues,
                model,
                key,
                "`" + condition + "` is not a defined condition in the model.",
                condition,
              )
            }
            Some(_) => used_conditions[condition] = ()
          }
        }
      None => ()
    }
  }
  valid
}

///|
/// Validates a relation rewrite. Returns true when no structural error was
/// found in this rewrite tree.
fn validate_rewrite(
  model : @fga.AuthModel,
  td : @fga.TypeDefinition,
  relation : String,
  rewrite : @fga.Userset,
  issues : Array[ValidationIssue],
) -> Bool {
  let key = "rel:" + td.name + ":" + relation
  match rewrite {
    This => true
    Computed(target) =>
      if !td.relations.contains(target) {
        issue_at(
          issues,
          model,
          key,
          "the relation `" + target + "` does not exist.",
          target,
        )
        false
      } else {
        true
      }
    TupleToUserset(computed, tupleset) => {
      let mut valid = true
      let tupleset_rewrite = td.relations.get(tupleset)
      let tupleset_ok = match tupleset_rewrite {
        None => {
          valid = false
          issue_at(
            issues,
            model,
            key,
            "`" + tupleset + "` is not a valid relation for `" + td.name + "`.",
            tupleset,
          )
          false
        }
        Some(rw) => {
          let restrictions = td.restrictions(tupleset)
          let direct = match rw {
            This =>
              restrictions.length() > 0 &&
              restrictions.all(fn(r) { r.relation == None && !r.wildcard })
            _ => false
          }
          if !direct {
            valid = false
            issue_at(
              issues,
              model,
              key,
              "`" +
              tupleset +
              "` relation used inside from allows only direct relation.",
              tupleset,
            )
          }
          direct
        }
      }
      if tupleset_ok {
        for r in td.restrictions(tupleset) {
          let exists = match model.find_type(r.type_name) {
            None => false
            Some(target_type) => target_type.relations.contains(computed)
          }
          if !exists {
            valid = false
            issue_at(
              issues,
              model,
              key,
              "the `" +
              computed +
              "` relation definition on type `" +
              td.name +
              "` is not valid: `" +
              computed +
              "` does not exist on `" +
              tupleset +
              "`, which is of type `" +
              r.type_name +
              "`.",
              computed,
            )
          }
        }
      }
      valid
    }
    Union(children) => {
      let mut valid = true
      let seen : Array[@fga.Userset] = []
      for child in children {
        let mut duplicate = false
        for earlier in seen {
          if same_userset(child, earlier) {
            duplicate = true
          }
        }
        if duplicate {
          valid = false
          issue_at(
            issues,
            model,
            key,
            "a child of the relation `" +
            relation +
            "` is duplicated in a union.",
            relation,
          )
        } else {
          seen.push(child)
        }
        if !validate_rewrite(model, td, relation, child, issues) {
          valid = false
        }
      }
      valid
    }
    Intersection(children) => {
      let mut valid = true
      let seen : Array[@fga.Userset] = []
      for child in children {
        let mut duplicate = false
        for earlier in seen {
          if same_userset(child, earlier) {
            duplicate = true
          }
        }
        if duplicate {
          valid = false
          issue_at(
            issues,
            model,
            key,
            "a child of the relation `" +
            relation +
            "` is duplicated in an intersection.",
            relation,
          )
        } else {
          seen.push(child)
        }
        if !validate_rewrite(model, td, relation, child, issues) {
          valid = false
        }
      }
      valid
    }
    Difference(base, subtract) => {
      let base_ok = validate_rewrite(model, td, relation, base, issues)
      let subtract_ok = validate_rewrite(model, td, relation, subtract, issues)
      base_ok && subtract_ok
    }
  }
}

///|
priv enum EntryState {
  EYes
  ENo
  ETainted
  EVisiting
}

///|
fn entry_state(
  model : @fga.AuthModel,
  type_name : String,
  relation : String,
  memo : Map[String, EntryState],
) -> EntryState {
  let key = type_name + "#" + relation
  match memo.get(key) {
    Some(EYes) => return EYes
    Some(ENo) => return ENo
    Some(ETainted) => return ETainted
    Some(EVisiting) => return ENo
    None => ()
  }
  let td = match model.find_type(type_name) {
    Some(td) => td
    None => return ETainted
  }
  let rewrite = match td.relations.get(relation) {
    Some(rw) => rw
    None => return ETainted
  }
  memo[key] = EVisiting
  let state = entry_rewrite(model, td, relation, rewrite, memo)
  memo[key] = match state {
    EYes => EYes
    ENo => ENo
    _ => ETainted
  }
  state
}

///|
fn entry_rewrite(
  model : @fga.AuthModel,
  td : @fga.TypeDefinition,
  relation : String,
  rewrite : @fga.Userset,
  memo : Map[String, EntryState],
) -> EntryState {
  match rewrite {
    This => {
      let restrictions = td.restrictions(relation)
      let mut state = ENo
      for r in restrictions {
        match model.find_type(r.type_name) {
          None => state = ETainted
          Some(target) =>
            match r.relation {
              Some(target_relation) =>
                if target.relations.contains(target_relation) {
                  match entry_state(model, target.name, target_relation, memo) {
                    EYes => return EYes
                    ENo => ()
                    _ => state = ETainted
                  }
                } else {
                  state = ETainted
                }
              None => return EYes
            }
        }
      }
      state
    }
    Computed(target) => entry_state(model, td.name, target, memo)
    TupleToUserset(computed, tupleset) => {
      let tupleset_rewrite = td.relations.get(tupleset)
      let restrictions = td.restrictions(tupleset)
      let direct = match tupleset_rewrite {
        Some(This) =>
          restrictions.length() > 0 &&
          restrictions.all(fn(r) { r.relation == None && !r.wildcard })
        _ => false
      }
      if !direct {
        return ETainted
      }
      let mut state = ENo
      for r in restrictions {
        match model.find_type(r.type_name) {
          None => state = ETainted
          Some(target) =>
            if target.relations.contains(computed) {
              match entry_state(model, target.name, computed, memo) {
                EYes => return EYes
                ENo => ()
                _ => state = ETainted
              }
            } else {
              state = ETainted
            }
        }
      }
      state
    }
    Union(children) => {
      let mut state = ENo
      for child in children {
        match entry_rewrite(model, td, relation, child, memo) {
          EYes => return EYes
          ENo => ()
          _ => state = ETainted
        }
      }
      state
    }
    Intersection(children) => {
      let mut state = EYes
      for child in children {
        match entry_rewrite(model, td, relation, child, memo) {
          ENo => return ENo
          EYes => ()
          _ => state = ETainted
        }
      }
      state
    }
    Difference(base, _subtract) =>
      entry_rewrite(model, td, relation, base, memo)
  }
}

///|
fn collect_idents(expr : @cel.CelExpr, out : Map[String, Unit]) -> Unit {
  match expr {
    @cel.CLiteral(_) => ()
    @cel.CIdent(name) => out[name] = ()
    @cel.CUnary(_, inner) => collect_idents(inner, out)
    @cel.CBinary(_, left, right) => {
      collect_idents(left, out)
      collect_idents(right, out)
    }
    @cel.CTernary(condition, then_value, else_value) => {
      collect_idents(condition, out)
      collect_idents(then_value, out)
      collect_idents(else_value, out)
    }
    @cel.CCall(_, args) =>
      for arg in args {
        collect_idents(arg, out)
      }
    @cel.CMethod(target, _, args) => {
      collect_idents(target, out)
      for arg in args {
        collect_idents(arg, out)
      }
    }
    @cel.CIndex(target, index) => {
      collect_idents(target, out)
      collect_idents(index, out)
    }
    @cel.CList(items) =>
      for item in items {
        collect_idents(item, out)
      }
    @cel.CMap(entries) =>
      for entry in entries {
        collect_idents(entry.0, out)
        collect_idents(entry.1, out)
      }
  }
}

///|
fn validate_condition(
  model : @fga.AuthModel,
  condition : @fga.Condition,
  used : Bool,
  issues : Array[ValidationIssue],
) -> Unit {
  let key = "condition:" + condition.name
  if !name_matches(condition.name, 50) {
    issue_at(
      issues,
      model,
      key,
      "condition '" + condition.name + "' does not match naming rules.",
      condition.name,
    )
  }
  let params : Map[String, @fga.ConditionParam] = Map([])
  for param in condition.parameters {
    if params.contains(param.name) {
      issue_at(
        issues,
        model,
        key,
        "condition '" +
        condition.name +
        "' has more than one parameter named '" +
        param.name +
        "'.",
        param.name,
      )
    } else {
      params[param.name] = param
    }
    if param.type_name == "list" || param.type_name == "map" {
      match param.generic_type {
        Some(inner) =>
          if !is_parameter_type(inner) {
            issue_at(
              issues,
              model,
              key,
              "invalid condition parameter type '" + inner + "'.",
              inner,
            )
          }
        None =>
          issue_at(
            issues,
            model,
            key,
            "condition parameter '" +
            param.name +
            "' of type " +
            param.type_name +
            " requires an element type.",
            param.name,
          )
      }
    } else if !is_parameter_type(param.type_name) {
      issue_at(
        issues,
        model,
        key,
        "invalid condition parameter type '" + param.type_name + "'.",
        param.type_name,
      )
    }
  }
  if condition.expression.trim().to_owned() == "" {
    issue_at(
      issues,
      model,
      key,
      "condition '" + condition.name + "' has an empty expression.",
      condition.name,
    )
  } else {
    let expr = Some(@cel.compile(condition.expression)) catch {
      @fga.FgaError(..) as err => {
        issue_at(
          issues,
          model,
          key,
          "condition '" +
          condition.name +
          "' expression is invalid: " +
          @fga.error_message(err),
          condition.name,
        )
        None
      }
    }
    match expr {
      Some(ast) => {
        let idents : Map[String, Unit] = Map([])
        collect_idents(ast, idents)
        idents.each(fn(name, _) {
          if !params.contains(name) {
            issue_at(
              issues,
              model,
              key,
              "condition '" +
              condition.name +
              "' references undefined parameter `" +
              name +
              "`.",
              name,
            )
          }
        })
      }
      None => ()
    }
  }
  if !used {
    issue_at(
      issues,
      model,
      key,
      "`" + condition.name + "` condition is not used in the model.",
      condition.name,
    )
  }
}

///|
/// Returns every semantic issue found in the model. An empty array means the
/// model is valid.
pub fn validate_model(model : @fga.AuthModel) -> Array[ValidationIssue] {
  let issues : Array[ValidationIssue] = []
  if model.schema_version != "1.1" && model.schema_version != "1.2" {
    issues.push(ValidationIssue::{
      code: @fga.ERR_VALIDATION,
      message: "invalid schema " +
      model.schema_version +
      " (only 1.1 and 1.2 are supported)",
      line: -1,
      column: -1,
      symbol: model.schema_version,
    })
  }
  let seen_types : Map[String, Unit] = Map([])
  let used_conditions : Map[String, Unit] = Map([])
  let structurally_valid : Map[String, Unit] = Map([])
  for td in model.types {
    let type_key = "type:" + td.name
    if seen_types.contains(td.name) {
      issue_at(
        issues,
        model,
        type_key,
        "the type `" + td.name + "` is a duplicate.",
        td.name,
      )
    } else {
      seen_types[td.name] = ()
    }
    if td.name == "self" || td.name == "this" {
      issue_at(
        issues,
        model,
        type_key,
        "a type cannot be named '" + td.name + "'.",
        td.name,
      )
    } else if !name_matches(td.name, 254) {
      issue_at(
        issues,
        model,
        type_key,
        "type '" + td.name + "' does not match naming rules.",
        td.name,
      )
    }
    let seen_relations : Map[String, Unit] = Map([])
    for relation in td.relation_order {
      let relation_key = "rel:" + td.name + ":" + relation
      if seen_relations.contains(relation) {
        issue_at(
          issues,
          model,
          relation_key,
          "relation '" +
          relation +
          "' is defined more than once on type '" +
          td.name +
          "'.",
          relation,
        )
      } else {
        seen_relations[relation] = ()
      }
      if relation == "self" || relation == "this" {
        issue_at(
          issues,
          model,
          relation_key,
          "a relation cannot be named '" + relation + "'.",
          relation,
        )
      } else if !name_matches(relation, 50) {
        issue_at(
          issues,
          model,
          relation_key,
          "relation '" +
          relation +
          "' of type '" +
          td.name +
          "' does not match naming rules.",
          relation,
        )
      }
      let restrictions_ok = validate_restrictions(
        model,
        td.name,
        relation,
        td.restrictions(relation),
        used_conditions,
        issues,
      )
      let rewrite_ok = match td.relations.get(relation) {
        None => false
        Some(rewrite) => validate_rewrite(model, td, relation, rewrite, issues)
      }
      if restrictions_ok && rewrite_ok {
        structurally_valid[td.name + "#" + relation] = ()
      }
    }
  }
  let entry_memo : Map[String, EntryState] = Map([])
  for td in model.types {
    for relation in td.relation_order {
      if !structurally_valid.contains(td.name + "#" + relation) {
        continue
      }
      match entry_state(model, td.name, relation, entry_memo) {
        ENo =>
          issue_at(
            issues,
            model,
            "rel:" + td.name + ":" + relation,
            "`" +
            relation +
            "` is an impossible relation for `" +
            td.name +
            "` (" +
            (if td.relations[relation] is @fga.Computed(_) {
              "potential loop"
            } else {
              "no entrypoint"
            }) +
            ").",
            relation,
          )
        _ => ()
      }
    }
  }
  let seen_conditions : Map[String, Unit] = Map([])
  for name in model.condition_order {
    if seen_conditions.contains(name) {
      issue_at(
        issues,
        model,
        "condition:" + name,
        "condition '" + name + "' is defined more than once.",
        name,
      )
      continue
    }
    seen_conditions[name] = ()
    match model.find_condition(name) {
      None => ()
      Some(condition) =>
        validate_condition(
          model,
          condition,
          used_conditions.contains(name),
          issues,
        )
    }
  }
  issues
}

///|
/// Raises the first semantic issue as an `FgaError` with its position.
pub fn validate_or_fail(model : @fga.AuthModel) -> Unit raise @fga.FgaError {
  let issues = validate_model(model)
  if issues.length() > 0 {
    let first = issues[0]
    raise @fga.fail_at(first.code, first.message, first.line, first.column)
  }
}
