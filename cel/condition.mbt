// Evaluation entry point for OpenFGA conditions.

///|
/// Evaluates a condition expression against a request context.
///
/// Every declared parameter must be present in the merged context; unknown
/// context keys are rejected. Both errors use the validation code 2000, which
/// is what OpenFGA returns for an unsatisfiable condition evaluation.
pub fn eval_condition(
  condition : @fga.Condition,
  context : Map[String, Json],
) -> Bool raise @fga.FgaError {
  let env : Map[String, @fga.CelValue] = Map([])
  let known : Map[String, Bool] = Map([])
  for param in condition.parameters {
    known[param.name] = true
    let value = match context.get(param.name) {
      Some(value) => coerce_context(param, value)
      None =>
        raise @fga.fail(
          @fga.ERR_VALIDATION,
          "missing context parameter '" +
          param.name +
          "' for condition '" +
          condition.name +
          "'",
        )
    }
    env[param.name] = value
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
