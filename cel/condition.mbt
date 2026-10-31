// Evaluation entry point for OpenFGA conditions.

///|
/// Evaluates a condition expression against a request context.
///
/// Every declared parameter must be present in the merged context. Extra
/// context keys are ignored: a request context is shared by all conditions in
/// a model, so a condition only reads the parameters it declares. Missing
/// parameters use the validation code 2000, which is what OpenFGA returns for
/// an unsatisfiable condition evaluation.
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
