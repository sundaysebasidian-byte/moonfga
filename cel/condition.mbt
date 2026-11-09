// Evaluation entry point for OpenFGA conditions.

///|
/// Evaluates a condition expression against a request context.
///
/// Only supplied parameters are bound; unresolved reads raise errors that
/// deciding logical/macro values can absorb. Extra
/// context keys are ignored: a request context is shared by all conditions in
/// a model, so a condition only reads the parameters it declares. Missing
/// parameters use the validation code 2000, which is what OpenFGA returns for
/// an unsatisfiable condition evaluation.
pub fn eval_condition_with_limit(
  condition : @fga.Condition,
  context : Map[String, Json],
  max_cost : Int32,
  cancelled~ : () -> Bool = fn() { false },
  local_timezone~ : String? = None,
) -> Bool raise @fga.FgaError {
  if condition.parameters.is_empty() && !context.is_empty() {
    raise @fga.fail(
      @fga.ERR_VALIDATION,
      "no parameters defined for condition context",
    )
  }
  let env : Map[String, @fga.CelValue] = Map([])
  for param in condition.parameters {
    match context.get(param.name) {
      Some(value) => env[param.name] = coerce_context(param, value)
      None => ()
    }
  }
  let expression = compile(condition.expression)
  match
    eval_expr_with_limit(expression, env, max_cost, cancelled~, local_timezone~) {
    @fga.VBool(result) => {
      // The pinned server reports all missing declared parameters, even when
      // CEL itself resolves a deciding constant without accessing them.
      for param in condition.parameters {
        if !context.contains(param.name) {
          raise @fga.fail(
            @fga.ERR_VALIDATION,
            "missing context parameter '" + param.name + "'",
          )
        }
      }
      result
    }
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

///|
pub fn eval_condition(
  condition : @fga.Condition,
  context : Map[String, Json],
) -> Bool raise @fga.FgaError {
  eval_condition_with_limit(condition, context, 100)
}
