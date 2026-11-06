///|
fn parsed(source : String) -> @fga.AuthModel {
  @dsl.parse_model(source) catch {
    @fga.FgaError(..) as err => abort(@fga.format_error(err))
  }
}

///|
fn issues_of(source : String) -> Array[@validate.ValidationIssue] {
  @validate.validate_model(parsed(source))
}

///|
test "valid model has no issues" {
  let source =
    #|model
    #|  schema 1.1
    #|type user
    #|type group
    #|  relations
    #|    define member: [user, user:*]
    #|type folder
    #|  relations
    #|    define owner: [user]
    #|    define viewer: [user, group#member] or owner
    #|type document
    #|  relations
    #|    define editor: [user]
    #|    define parent: [folder]
    #|    define viewer: [user with in_office] or editor or viewer from parent
    #|condition in_office(hour: int) {
    #|  hour >= 9 && hour < 17
    #|}
  inspect(issues_of(source).length(), content="0")
}

///|
test "unknown type and relation are reported with positions" {
  let source =
    #|model
    #|  schema 1.1
    #|type user
    #|type document
    #|  relations
    #|    define viewer: [unknown]
  let issues = issues_of(source)
  inspect(issues.length(), content="1")
  inspect(issues[0].message, content="`unknown` is not a valid type.")
  inspect(issues[0].line, content="6")
  inspect(issues[0].column, content="12")
  inspect(issues[0].symbol, content="unknown")

  let missing_source =
    #|model
    #|  schema 1.1
    #|type user
    #|type document
    #|  relations
    #|    define editor: [user]
    #|    define viewer: editorx
  let missing = issues_of(missing_source)
  inspect(missing.length(), content="1")
  inspect(missing[0].message, content="the relation `editorx` does not exist.")
}

///|
test "tuple to userset requires a direct tupleset and existing computed relation" {
  let not_direct_source =
    #|model
    #|  schema 1.1
    #|type user
    #|type folder
    #|  relations
    #|    define parent: [folder] or parent from parent
    #|    define viewer: viewer from parent
  let not_direct = issues_of(not_direct_source)
  inspect(not_direct.length(), content="2")
  inspect(
    not_direct.all(fn(issue) {
      issue.message.contains("allows only direct relation")
    }),
    content="true",
  )

  let missing_source =
    #|model
    #|  schema 1.1
    #|type user
    #|type group
    #|type org
    #|  relations
    #|    define parent: [group]
    #|    define viewer: viewer from parent
  let missing = issues_of(missing_source)
  inspect(missing.length(), content="1")
  inspect(
    missing[0].message.contains("`viewer` does not exist"),
    content="true",
  )
}

///|
test "duplicates are reported" {
  let source =
    #|model
    #|  schema 1.1
    #|type user
    #|type document
    #|  relations
    #|    define viewer: [user, user]
    #|    define editor: [user] or [user]
  let issues = issues_of(source)
  inspect(issues.length(), content="3")
  inspect(issues[0].message.contains("`user` is a duplicate"), content="true")
  inspect(
    issues.any(fn(issue) { issue.message.contains("duplicated in a union") }),
    content="true",
  )
}

///|
test "impossible relations are detected" {
  let source =
    #|model
    #|  schema 1.1
    #|type user
    #|type document
    #|  relations
    #|    define admin: [user]
    #|    define reader: writer
    #|    define writer: reader
    #|    define action: admin and writer
  let issues = issues_of(source)
  // reader and writer loop; action intersects admin with an impossible one.
  inspect(issues.length(), content="3")
  inspect(
    issues.all(fn(issue) { issue.message.contains("impossible") }),
    content="true",
  )
}

///|
test "self referencing userset with an entry point is valid" {
  let source =
    #|model
    #|  schema 1.1
    #|type user
    #|type document
    #|  relations
    #|    define editor: [user]
    #|    define viewer: [document#viewer] or editor
  inspect(issues_of(source).length(), content="0")
}

///|
test "condition references and parameters are validated" {
  let undefined_source =
    #|model
    #|  schema 1.1
    #|type user
    #|type document
    #|  relations
    #|    define viewer: [user with missing]
  let undefined_condition = issues_of(undefined_source)
  inspect(undefined_condition.length(), content="1")
  inspect(
    undefined_condition[0].message.contains("not a defined condition"),
    content="true",
  )

  let unused_source =
    #|model
    #|  schema 1.1
    #|type user
    #|type document
    #|  relations
    #|    define viewer: [user]
    #|condition unused(x: int) {
    #|  x > 1
    #|}
  let unused = issues_of(unused_source)
  inspect(unused.length(), content="1")
  inspect(unused[0].message.contains("is not used"), content="true")

  let bad_param_source =
    #|model
    #|  schema 1.1
    #|type user
    #|type document
    #|  relations
    #|    define viewer: [user with c]
    #|condition c(x: int) {
    #|  y > 1
    #|}
  let bad_param = issues_of(bad_param_source)
  inspect(bad_param.length(), content="1")
  inspect(
    bad_param[0].message.contains("undefined parameter `y`"),
    content="true",
  )

  let bad_expression_source =
    #|model
    #|  schema 1.1
    #|type user
    #|type document
    #|  relations
    #|    define viewer: [user with c]
    #|condition c(x: int) {
    #|  x >
    #|}
  let bad_expression = issues_of(bad_expression_source)
  inspect(bad_expression.length(), content="1")
  inspect(
    bad_expression[0].message.contains("expression is invalid"),
    content="true",
  )
}

///|
test "inline expression restrictions are legal" {
  let source =
    #|model
    #|  schema 1.1
    #|type user
    #|type group
    #|  relations
    #|    define member: [user]
    #|type document
    #|  relations
    #|    define viewer: [group#member with $expression]
    #|condition unused(x: int) {
    #|  x > 1
    #|}
  let issues = issues_of(source)
  // The only declaration is genuinely unused; $expression is not a condition.
  inspect(issues.length(), content="1")
  inspect(
    issues[0].message.contains("`unused` condition is not used"),
    content="true",
  )
}

///|
test "programmatic models are validated" {
  let model = @fga.AuthModel::new("1.1")
  let user = @fga.TypeDefinition::new("user")
  model.add_type(user)
  model.add_type(@fga.TypeDefinition::new("user"))
  let condition = @fga.Condition::{
    name: "c",
    expression: "x == 1",
    parameters: [
      @fga.ConditionParam::{ name: "x", type_name: "list", generic_type: None, },
    ],
  }
  model.add_condition(condition)
  model.add_condition(condition)
  let issues = @validate.validate_model(model)
  inspect(issues.length() >= 2, content="true")
  inspect(
    issues.any(fn(issue) { issue.message.contains("is a duplicate") }),
    content="true",
  )
  inspect(
    issues.any(fn(issue) { issue.message.contains("requires an element type") }),
    content="true",
  )
}

///|
test "unknown tupleset type also reports the missing computed relation" {
  let model = @dsl.merge_modules([
    @dsl.ModuleFile::{
      name: "employee.fga",
      contents: "module employee\n\ntype employe\n  relations\n    define can_manage: manager or can_manage from manager\n    define manager: [employee]\n",
    },
  ])
  let issues = @validate.validate_model(model)
  assert_eq(issues.length(), 2)
  assert_true(
    issues.any(i => {
      i.message.contains(
        "`can_manage` does not exist on `manager`, which is of type `employee`.",
      )
    }),
  )
  assert_true(
    issues.any(i => i.message.contains("`employee` is not a valid type.")),
  )
}
