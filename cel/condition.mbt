// Evaluation entry point for OpenFGA conditions.

///|
/// Evaluates a condition expression against a request context.
///
/// Missing parameters are bound to `null`, mirroring how conditions guard
/// optional context values. Unknown context keys are rejected.
pub fn eval_condition(
  condition : @fga.Condition,
  context : Map[String, Json],
) -> Bool raise @fga.FgaError {
  let env : Map[String, @fga.CelValue] = Map([])
  let known : Map[String, Bool] = Map([])
  for param in condition.parameters {
    known[param.name] = true
    env[param.name] = match context.get(param.name) {
      Some(value) => coerce_context(param, value)
      None => @fga.VNull
    }
  }
  let mut unknown : String? = None
  context.each(fn(key, _) {
    if !known.contains(key) && unknown == None {
      unknown = Some(key)
    }
  })
  match unknown {
    Some(key) =>
      raise @fga.fail(
        @fga.ERR_VALIDATION,
        "unexpected context parameter '" +
        key +
        "' for condition '" +
        condition.name +
        "'",
      )
    None => ()
  }
  let expression = compile(condition.expression)
  match eval_expr(expression, env) {
    @fga.VBool(result) => result
    other =>
      raise @fga.fail(
        @fga.ERR_VALIDATION,
        "condition '" +
        condition.name +
        "' returned " +
        @fga.cel_value_type_name(other) +
        " instead of bool",
      )
  }
}
