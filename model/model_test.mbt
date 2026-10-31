///|
fn demo_dsl() -> String {
  "model\n" +
  "  schema 1.1\n" +
  "\n" +
  "type user\n" +
  "\n" +
  "type group\n" +
  "  relations\n" +
  "    define member: [user]\n" +
  "\n" +
  "type document\n" +
  "  relations\n" +
  "    define parent: [document]\n" +
  "    define editor: [user, user:*, group#member]\n" +
  "    define viewer: [user with cond] or editor\n" +
  "    define banned: [user]\n" +
  "    define can_view: viewer but not banned\n" +
  "    define viewer_from_parent: viewer from parent\n" +
  "\n" +
  "condition cond(x: int, tags: list<string>) {\n" +
  "  x > 0 && tags.exists(t, t != \"\")\n" +
  "}\n"
}

///|
fn demo_json() -> String {
  "{\n" +
  "  \"schema_version\": \"1.1\",\n" +
  "  \"type_definitions\": [\n" +
  "    {\"type\": \"user\", \"relations\": {}, \"metadata\": null},\n" +
  "    {\n" +
  "      \"type\": \"group\",\n" +
  "      \"relations\": {\"member\": {\"this\": {}}},\n" +
  "      \"metadata\": {\"relations\": {\"member\": {\"directly_related_user_types\": [{\"type\": \"user\"}]}}}\n" +
  "    },\n" +
  "    {\n" +
  "      \"type\": \"document\",\n" +
  "      \"relations\": {\n" +
  "        \"parent\": {\"this\": {}},\n" +
  "        \"editor\": {\"this\": {}},\n" +
  "        \"viewer\": {\"union\": {\"child\": [{\"this\": {}}, {\"computedUserset\": {\"relation\": \"editor\"}}]}},\n" +
  "        \"banned\": {\"this\": {}},\n" +
  "        \"can_view\": {\"difference\": {\"base\": {\"computedUserset\": {\"relation\": \"viewer\"}}, \"subtract\": {\"computedUserset\": {\"relation\": \"banned\"}}}},\n" +
  "        \"viewer_from_parent\": {\"tupleToUserset\": {\"tupleset\": {\"relation\": \"parent\"}, \"computedUserset\": {\"relation\": \"viewer\"}}}\n" +
  "      },\n" +
  "      \"metadata\": {\"relations\": {\n" +
  "        \"parent\": {\"directly_related_user_types\": [{\"type\": \"document\"}]},\n" +
  "        \"editor\": {\"directly_related_user_types\": [{\"type\": \"user\"}, {\"type\": \"user\", \"wildcard\": {}}, {\"type\": \"group\", \"relation\": \"member\"}]},\n" +
  "        \"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"cond\"}]},\n" +
  "        \"banned\": {\"directly_related_user_types\": [{\"type\": \"user\"}]}\n" +
  "      }}\n" +
  "    }\n" +
  "  ],\n" +
  "  \"conditions\": {\n" +
  "    \"cond\": {\n" +
  "      \"name\": \"cond\",\n" +
  "      \"expression\": \"x > 0 && tags.exists(t, t != \\\"\\\")\",\n" +
  "      \"parameters\": {\n" +
  "        \"x\": {\"type_name\": \"TYPE_NAME_INT\"},\n" +
  "        \"tags\": {\"type_name\": \"TYPE_NAME_LIST\", \"generic_types\": [{\"type_name\": \"TYPE_NAME_STRING\"}]}\n" +
  "      }\n" +
  "    }\n" +
  "  }\n" +
  "}\n"
}

///|
test "dsl to json matches expected shape" {
  let model = @model.dsl_to_model(demo_dsl())
  let encoded = @model.model_to_json(model)
  let expected = @json.parse(demo_json()) catch {
    _ => abort("invalid test JSON")
  }
  inspect(@model.json_eq(encoded, expected), content="true")
}

///|
test "json to dsl round-trips through the parser" {
  let from_json = @model.json_to_model(demo_json()) catch {
    @fga.FgaError(..) as e => abort(@fga.error_message(e))
  }
  let from_dsl = @model.dsl_to_model(demo_dsl())
  inspect(@model.model_eq(from_json, from_dsl), content="true")
  let printed = @model.json_to_dsl(demo_json()) catch {
    _ => abort("json to dsl failed")
  }
  let reparsed = @model.dsl_to_model(printed)
  inspect(@model.model_eq(reparsed, from_dsl), content="true")
}

///|
test "json to parser round-trip equals model" {
  let json = @model.dsl_to_json(demo_dsl())
  let reparsed = @model.json_to_model(json) catch {
    @fga.FgaError(..) as e => abort(@fga.error_message(e))
  }
  let original = @model.dsl_to_model(demo_dsl())
  inspect(@model.model_eq(reparsed, original), content="true")
}

///|
test "empty authorization model" {
  let value = @json.parse("{\"schema_version\": \"1.1\"}") catch {
    _ => abort("invalid JSON")
  }
  let model = @model.model_from_json(value)
  inspect(model.types.length(), content="0")
  inspect(model.conditions.length(), content="0")
}
