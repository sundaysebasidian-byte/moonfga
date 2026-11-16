///|
/// Binds a per-request cooperative budget, also shared by all condition evaluations.
/// The host can supply a monotonic-clock deadline through the budget predicate.
pub fn Engine::with_budget(
  self : Engine,
  budget : @fga.ExecutionBudget,
) -> Engine {
  { ..self, budget: Some(budget), }
}

///|
fn Engine::step(self : Engine) -> Unit raise @fga.FgaError {
  match self.budget {
    Some(b) => b.step()
    None => ()
  }
}

///|
fn Engine::check_budget(self : Engine) -> Unit raise @fga.FgaError {
  match self.budget {
    Some(b) => b.check()
    None => ()
  }
}
