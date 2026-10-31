///|
fn sample_model_source() -> String {
  "model\n" +
  "  schema 1.1\n" +
  "\n" +
  "type user\n" +
  "\n" +
  "type group\n" +
  "  relations\n" +
  "    define member: [user]\n" +
  "\n" +
  "type folder\n" +
  "\n" +
  "type document\n" +
  "  relations\n" +
  "    define owner: [user]\n" +
  "    define editor: [user, group#member]\n" +
  "    define viewer: [user, user:*] or editor or owner\n" +
  "    define banned: [user]\n" +
  "    define can_view: viewer but not banned\n" +
  "    define parent: [folder]\n" +
  "    define viewer_from_parent: viewer from parent\n"
}

///|
test "parse model structure" {
  let model = @dsl.parse_model(sample_model_source())
  inspect(model.schema_version, content="1.1")
  inspect(model.types.length(), content="4")
  let document = model.find_type("document").unwrap()
  inspect(document.relation_order.length(), content="7")
  let viewer = document.restrictions("viewer")
  inspect(viewer.length(), content="2")
  inspect(viewer[0].type_name, content="user")
  inspect(viewer[1].type_name, content="user")
  inspect(viewer[1].wildcard, content="true")
  let editor = document.restrictions("editor")
  inspect(editor.length(), content="2")
  inspect(editor[1].type_name, content="group")
  match editor[1].relation {
    Some(rel) => inspect(rel, content="member")
    None => abort("expected userset relation")
  }
  let from_parent = document.relation_rewrite("viewer_from_parent").unwrap()
  match from_parent {
    @fga.TupleToUserset(computed, tupleset) => {
      inspect(computed, content="viewer")
      inspect(tupleset, content="parent")
    }
    _ => abort("expected tuple to userset")
  }
}

///|
test "dsl printing is stable and re-parses" {
  let model = @dsl.parse_model(sample_model_source())
  let printed = @dsl.to_dsl(model)
  let reparsed = @dsl.parse_model(printed)
  inspect(@dsl.to_dsl(reparsed), content=printed)
  inspect(
    printed.contains("define viewer: [user, user:*] or editor or owner"),
    content="true",
  )
  inspect(
    printed.contains("define can_view: viewer but not banned"),
    content="true",
  )
  inspect(
    printed.contains("define viewer_from_parent: viewer from parent"),
    content="true",
  )
}

///|
test "operator precedence and parentheses" {
  let model = @dsl.parse_model(
    "model\n  schema 1.1\n\ntype doc\n  relations\n    define a: [user]\n    define b: [user]\n    define c: [user]\n    define d: [user]\n    define mixed: a or b and c but not d\n    define grouped: (a or b) and c\n",
  )
  let doc = model.find_type("doc").unwrap()
  match doc.relation_rewrite("mixed").unwrap() {
    @fga.Union(children) => {
      inspect(children.length(), content="2")
      match children[1] {
        @fga.Intersection(children2) =>
          match children2[1] {
            @fga.Difference(_, _) => inspect("ok", content="ok")
            _ => abort("expected difference")
          }
        _ => abort("expected intersection")
      }
    }
    _ => abort("expected union")
  }
  let printed = @dsl.to_dsl(model)
  inspect(
    printed.contains("define mixed: a or b and c but not d"),
    content="true",
  )
  inspect(printed.contains("define grouped: (a or b) and c"), content="true")
}

///|
test "conditions" {
  let source = "model\n  schema 1.1\n\ntype user\n\ntype document\n  relations\n    define viewer: [user with in_office]\n\ncondition in_office(hour: int, location: string, tags: list<string>, meta: map<int>) {\n  hour >= 9 && location == \"office\" && tags.size() > 0\n}\n"
  let model = @dsl.parse_model(source)
  let condition = model.find_condition("in_office").unwrap()
  inspect(condition.parameters.length(), content="4")
  match condition.parameters[2].generic_type {
    Some(t) => inspect(t, content="string")
    None => abort("expected generic type")
  }
  inspect(condition.expression.contains("hour >= 9"), content="true")
  let viewer = model.find_type("document").unwrap().restrictions("viewer")
  match viewer[0].condition {
    Some(cond) => inspect(cond, content="in_office")
    None => abort("expected condition")
  }
  let printed = @dsl.to_dsl(model)
  inspect(
    printed.contains(
      "condition in_office(hour: int, location: string, tags: list<string>, meta: map<int>)",
    ),
    content="true",
  )
  let reparsed = @dsl.parse_model(printed)
  inspect(@dsl.to_dsl(reparsed), content=printed)
}

///|
test "comments are ignored but usersets are not" {
  let source = "model\n  schema 1.1\n\n# leading comment\ntype user\n\ntype group\n  relations\n    define member: [user] # trailing\n\ntype doc\n  relations\n    define viewer: [group#member]\n"
  let model = @dsl.parse_model(source)
  let doc = model.find_type("doc").unwrap()
  let viewer = doc.restrictions("viewer")
  inspect(viewer[0].type_name, content="group")
  match viewer[0].relation {
    Some(rel) => inspect(rel, content="member")
    None => abort("expected userset relation")
  }
}

///|
test "schema 1.0 is rejected" {
  let result = try {
    let _ = @dsl.parse_model("model\n  schema 1.0\n\ntype user\n")
    false
  } catch {
    @fga.FgaError(_) => true
  }
  inspect(result, content="true")
}

///|
test "duplicate type is rejected" {
  let result = try {
    let _ = @dsl.parse_model("model\n  schema 1.1\n\ntype user\n\ntype user\n")
    false
  } catch {
    @fga.FgaError(_) => true
  }
  inspect(result, content="true")
}

///|
test "unknown condition parameter type is rejected" {
  let result = try {
    let _ = @dsl.parse_model(
      "model\n  schema 1.1\n\ntype user\n\ncondition c(x: blob) {\n  true\n}\n",
    )
    false
  } catch {
    @fga.FgaError(_) => true
  }
  inspect(result, content="true")
}

///|
test "module header is accepted" {
  let model = @dsl.parse_model("module example\n\ntype user\n")
  inspect(model.types.length(), content="1")
}
