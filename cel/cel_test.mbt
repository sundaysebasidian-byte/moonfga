///|
fn eval_source(source : String, env : Map[String, @fga.CelValue]) -> String {
  try {
    let expr = @cel.compile(source)
    @fga.cel_value_to_display(@cel.eval_expr(expr, env))
  } catch {
    @fga.FgaError(..) as e => "error: " + @fga.error_message(e)
  }
}

///|
fn eval_empty(source : String) -> String {
  eval_source(source, Map([]))
}

///|
test "arithmetic and logic" {
  inspect(eval_empty("1 + 2 * 3"), content="7")
  inspect(eval_empty("(1 + 2) * 3"), content="9")
  inspect(eval_empty("7 / 2"), content="3")
  inspect(eval_empty("7 % 4"), content="3")
  inspect(eval_empty("1.5 + 2"), content="3.5")
  inspect(eval_empty("true && !false"), content="true")
  inspect(eval_empty("false || 3 > 2"), content="true")
  inspect(eval_empty("1 < 2 ? \"yes\" : \"no\""), content="\"yes\"")
  inspect(eval_empty("1 / 0"), content="error: division by zero")
}

///|
test "string operations" {
  inspect(eval_empty("\"office\".startsWith(\"off\")"), content="true")
  inspect(eval_empty("\"office\".endsWith(\"ice\")"), content="true")
  inspect(eval_empty("\"office\".contains(\"ffi\")"), content="true")
  inspect(eval_empty("\"123\".matches(\"[0-9]+\")"), content="true")
  inspect(eval_empty("\"abc\".matches(\"[0-9]\")"), content="false")
  inspect(eval_empty("\"hello\".size()"), content="5")
  inspect(eval_empty("\"a\" + \"b\""), content="\"ab\"")
}

///|
test "lists maps and comprehensions" {
  inspect(eval_empty("[1, 2, 3].size()"), content="3")
  inspect(eval_empty("[1, 2, 3].exists(x, x > 2)"), content="true")
  inspect(eval_empty("[1, 2, 3].exists_one(x, x == 2)"), content="true")
  inspect(eval_empty("[1, 2, 3].all(x, x > 0)"), content="true")
  inspect(eval_empty("[1, 2, 3][1]"), content="2")
  inspect(eval_empty("\"a\" in [\"a\", \"b\"]"), content="true")
  inspect(eval_empty("{\"key\": \"value\"}[\"key\"]"), content="\"value\"")
  inspect(eval_empty("\"key\" in {\"key\": 1}"), content="true")
}

///|
test "timestamp duration and ipaddress" {
  inspect(
    eval_empty(
      "timestamp(\"2023-10-11T10:00:00.000Z\") > timestamp(\"2023-10-11T09:00:00Z\")",
    ),
    content="true",
  )
  inspect(
    eval_empty(
      "timestamp(\"2023-10-11T10:00:00Z\") == timestamp(\"2023-10-11T11:00:00+01:00\")",
    ),
    content="true",
  )
  inspect(
    eval_empty("duration(\"1h30m\") == duration(\"90m\")"),
    content="true",
  )
  inspect(eval_empty("duration(\"500ms\") < duration(\"1s\")"), content="true")
  inspect(
    eval_empty(
      "timestamp(\"2023-10-11T10:00:00Z\") + duration(\"1h\") == timestamp(\"2023-10-11T11:00:00Z\")",
    ),
    content="true",
  )
  inspect(
    eval_empty("ipaddress(\"10.1.2.3\").in_cidr(\"10.0.0.0/8\")"),
    content="true",
  )
  inspect(
    eval_empty("ipaddress(\"192.168.1.1\").in_cidr(\"10.0.0.0/8\")"),
    content="false",
  )
  inspect(
    eval_empty("ipaddress(\"2001:db8::1\").in_cidr(\"2001:db8::/32\")"),
    content="true",
  )
}

///|
fn context_value() -> Map[String, Json] {
  Map([
    ("x", Json::number(10.0)),
    ("tags", Json::array([Json::string("a"), Json::string("b")])),
  ])
}

///|
fn test_condition() -> @fga.Condition {
  @fga.Condition::{
    name: "c",
    expression: "x < 100 && \"a\" in tags",
    parameters: [
      @fga.ConditionParam::{ name: "x", type_name: "int", generic_type: None, },
      @fga.ConditionParam::{
        name: "tags",
        type_name: "list",
        generic_type: Some("string"),
      },
    ],
  }
}

///|
test "typed condition evaluation" {
  let result = @cel.eval_condition(test_condition(), context_value()) catch {
    @fga.FgaError(..) as e => abort(@fga.error_message(e))
  }
  inspect(result, content="true")
}

///|
test "condition errors" {
  let condition = test_condition()
  let missing = try {
    let _ = @cel.eval_condition(condition, Map([("x", Json::number(10.0))]))
    "no error"
  } catch {
    @fga.FgaError(..) => "error"
  }
  inspect(missing, content="error")
  // Extra context keys are shared by other conditions and must be ignored.
  let extra = try {
    let context = context_value()
    context["extra"] = Json::string("x")
    let _ = @cel.eval_condition(condition, context)
    "no error"
  } catch {
    @fga.FgaError(..) => "error"
  }
  inspect(extra, content="no error")
  let bad_type = try {
    let _ = @cel.eval_condition(
      condition,
      Map([("x", Json::string("ten")), ("tags", Json::array([]))]),
    )
    "no error"
  } catch {
    @fga.FgaError(..) => "error"
  }
  inspect(bad_type, content="error")
}
