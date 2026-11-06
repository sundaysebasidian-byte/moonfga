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

///|
test "extensions are unique within each file but may repeat across files" {
  let first = "module shared\ntype user\ntype document\nextend type document\n relations\n  define viewer: [user]\n"
  let second = "extend type document\n relations\n  define editor: [user]\n"
  let error = try {
    ignore(
      @model.modules_to_model("schema: '1.2'\ncontents: [a.fga]", [
        @dsl.ModuleFile::{ name: "a.fga", contents: first + second, },
      ]),
    )
    None
  } catch {
    @fga.FgaError(..) as err => Some(err)
  }
  assert_true(error is Some(_))
  assert_true(
    @fga.error_message(error.unwrap()).contains(
      "'document' is already extended in file.",
    ),
  )
  let model = @model.modules_to_model(
    "schema: '1.2'\ncontents: [a.fga, b.fga]",
    [
      @dsl.ModuleFile::{ name: "a.fga", contents: first, },
      @dsl.ModuleFile::{ name: "b.fga", contents: "module shared\n" + second, },
    ],
  )
  let relations = model.find_type("document").unwrap().relations
  assert_true(relations.contains("viewer"))
  assert_true(relations.contains("editor"))
}

///|
test "fga.mod rejects cyclic aliases and bounds alias expansion" {
  for
    suffix in ["loop: &a [*a]", "loop: &a {nested: [*a]}", "contents: &a [*a]"] {
    let rejected = try {
      ignore(@model.parse_mod("schema: '1.2'\n" + suffix))
      false
    } catch {
      @fga.FgaError(..) => true
    }
    assert_true(rejected)
  }
  let mut nested = "x"
  for _ in 0..<66 {
    nested = "[" + nested + "]"
  }
  let too_deep = try {
    ignore(@model.parse_mod("schema: '1.2'\ncontents: []\nextra: " + nested))
    false
  } catch {
    @fga.FgaError(..) => true
  }
  assert_true(too_deep)
  let mut source = "schema: '1.2'\ncontents: []\na0: &a0 [x]\n"
  for i in 1..<15 {
    source += "a" +
      i.to_string() +
      ": &a" +
      i.to_string() +
      " [*a" +
      (i - 1).to_string() +
      ", *a" +
      (i - 1).to_string() +
      "]\n"
  }
  let rejected = try {
    ignore(@model.parse_mod(source))
    false
  } catch {
    @fga.FgaError(..) => true
  }
  assert_true(rejected)
}

///|
test "fga.mod accepts finite scalar and sequence aliases" {
  let paths = @model.parse_mod(
    "version: &v '1.2'\nschema: *v\nfiles: &files [a.fga]\ncontents: *files\ncopy: [*files, *files]",
  )
  assert_eq(paths, ["a.fga"])
}

///|
test "collect module diagnostics recovers across declarations and files" {
  let (_, diagnostics) = @model.modules_with_diagnostics(
    "schema: '1.2'\ncontents: [a.fga, b.fga, c.fga]",
    [
      @dsl.ModuleFile::{
        name: "a.fga",
        contents: "module alpha\ntype this\n relations\n  define this: [absent]\n",
      },
      @dsl.ModuleFile::{
        name: "b.fga",
        contents: "module beta\nextend type missing\ncondition duplicate(v: int) { v > 0 }\ncondition duplicate(v: int) { v > 0 }\n",
      },
      @dsl.ModuleFile::{ name: "c.fga", contents: "type user", },
    ],
  )
  assert_true(diagnostics.length() >= 6)
  assert_true(
    diagnostics.any(fn(d) {
      d.file == "a.fga" &&
      d.module_name == "alpha" &&
      d.line == 1 &&
      d.column == 5 &&
      d.error_type == "reserved-type-keywords"
    }),
  )
  assert_true(
    diagnostics.any(fn(d) {
      d.file == "b.fga" && d.message == "extended type missing does not exist"
    }),
  )
  assert_true(
    diagnostics.any(fn(d) {
      d.file == "b.fga" && d.message == "duplicate condition duplicate"
    }),
  )
  assert_true(
    diagnostics.any(fn(d) {
      d.file == "c.fga" && d.message == "file is not a module"
    }),
  )
}

///|
test "diagnostics retain extension file when lines overlap the base" {
  let (_, diagnostics) = @model.modules_with_diagnostics(
    "schema: '1.2'\ncontents: [a.fga, b.fga]",
    [
      @dsl.ModuleFile::{
        name: "a.fga",
        contents: "module alpha\ntype user\ntype doc\n relations\n  define owner: [user]\n",
      },
      @dsl.ModuleFile::{
        name: "b.fga",
        contents: "module beta\n\nextend type doc\n relations\n  define viewer: [unknown]\n",
      },
    ],
  )
  assert_eq(diagnostics.length(), 1)
  let d = diagnostics[0]
  assert_eq(d.file, "b.fga")
  assert_eq(d.module_name, "beta")
  assert_eq(d.line, 4)
  assert_eq(d.column, 18)
}

///|
test "missing module name is reported rather than accepted" {
  let (_, diagnostics) = @model.collect_module_diagnostics([
    @dsl.ModuleFile::{ name: "broken.fga", contents: "module", },
    @dsl.ModuleFile::{ name: "valid.fga", contents: "module valid\ntype user", },
  ])
  assert_eq(diagnostics.length(), 1)
  assert_eq(diagnostics[0].file, "broken.fga")
  assert_eq(diagnostics[0].error_type, "syntax")
}
