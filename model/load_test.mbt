///|
test "model_from_source accepts DSL and JSON" {
  let from_dsl = @model.model_from_source(demo_dsl()) catch {
    @fga.FgaError(..) as err => abort(@fga.error_message(err))
  }
  let from_json = @model.model_from_source(demo_json()) catch {
    @fga.FgaError(..) as err => abort(@fga.error_message(err))
  }
  inspect(@model.model_eq(from_dsl, from_json), content="true")
}

///|
test "model_from_source reports DSL syntax errors" {
  let rejected = try {
    let _ = @model.model_from_source("model\n  schema 1.1\ntype\n")
    false
  } catch {
    @fga.FgaError(..) => true
  }
  inspect(rejected, content="true")
}

///|
test "json export omits empty type definitions" {
  let model = @model.dsl_to_model("model\n  schema 1.1\n") catch {
    @fga.FgaError(..) as err => abort(@fga.error_message(err))
  }
  let encoded = @model.model_to_json(model)
  let expected = @json.parse("{\"schema_version\":\"1.1\"}") catch {
    _ => abort("bad fixture")
  }
  inspect(@model.json_eq(encoded, expected), content="true")
}

///|
test "json export lists metadata for computed relations" {
  let model = @model.dsl_to_model(
    "model\n  schema 1.1\n\ntype user\n  relations\n    define follower: [user]\n    define viewer: follower\n",
  ) catch {
    @fga.FgaError(..) as err => abort(@fga.error_message(err))
  }
  let expected = @json.parse(
    "{\"schema_version\":\"1.1\",\"type_definitions\":[{\"type\":\"user\",\"relations\":{\"follower\":{\"this\":{}},\"viewer\":{\"computedUserset\":{\"relation\":\"follower\"}}},\"metadata\":{\"relations\":{\"follower\":{\"directly_related_user_types\":[{\"type\":\"user\"}]},\"viewer\":{\"directly_related_user_types\":[]}}}}]}",
  ) catch {
    _ => abort("bad fixture")
  }
  inspect(@model.json_eq(@model.model_to_json(model), expected), content="true")
}
