///|
test "module extensions resolve before their bases and preserve metadata" {
  let model = @model.modules_to_model(
    "schema: '1.2'\ncontents: [team.fga, core.fga]",
    [
      @dsl.ModuleFile::{
        name: "team.fga",
        contents: "module team\nextend type document\n relations\n  define viewer: [user]\n",
      },
      @dsl.ModuleFile::{
        name: "core.fga",
        contents: "module core\ntype user\ntype document\n",
      },
    ],
  )
  let encoded = @model.model_to_json(model)
  assert_true(
    @model.json_eq(
      encoded,
      @model.model_to_json(@model.model_from_json(encoded)),
    ),
  )
  assert_true(model.find_type("document").unwrap().relations.contains("viewer"))
  assert_true(model.metadata.contains("rel:document:viewer"))
}

///|
test "module collisions missing targets and cycles fail with source positions" {
  for
    contents in [
      "module second\ntype user", "module second\nextend type absent", "module second\nextend type user\n relations\n  define viewer: viewer",
      "module second\nextend type user\n relations\n  define base: [user]",
    ] {
    let error = try {
      let _ = @model.modules_to_model(
        "schema: '1.2'\ncontents: [a.fga, b.fga]",
        [
          @dsl.ModuleFile::{
            name: "a.fga",
            contents: "module first\ntype user\n relations\n  define base: [user]",
          },
          @dsl.ModuleFile::{ name: "b.fga", contents, },
        ],
      )
      None
    } catch {
      @fga.FgaError(..) as err => Some(err)
    }
    let err = error.unwrap()
    assert_true(@fga.error_message(err).contains("second"))
    assert_true(@fga.error_message(err).contains("b.fga"))
    match err {
      @fga.FgaError(line~, column~, ..) => {
        assert_true(line > 0)
        assert_true(column > 0)
      }
    }
  }
}

///|
test "fga.mod blocks path traversal invalid schema and duplicate inputs" {
  for
    path in [
      "../a.fga", "a/../b.fga", "/a.fga", "a\\b.fga", "%2e%2e/a.fga", "C:a.fga",
      "a.txt",
    ] {
    let rejected = try {
      let _ = @model.parse_mod("schema: '1.2'\ncontents: ['" + path + "']")
      false
    } catch {
      @fga.FgaError(..) => true
    }
    assert_true(rejected)
  }
  for
    source in [
      "schema: '1.1'\ncontents: [a.fga]", "schema: '1.2'\ncontents: [a.fga, a.fga]",
      "schema: '1.2'\ncontents: [true]", "schema: '1.2'\ncontents: [missing.fga]",
    ] {
    let rejected = try {
      let _ = @model.modules_to_model(source, [])
      false
    } catch {
      @fga.FgaError(..) => true
    }
    assert_true(rejected)
  }
}
