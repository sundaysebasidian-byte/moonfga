///|
priv struct EvalState {
  mut cost : Int32
  limit : Int32
  mut interrupted : Bool
  local_timezone : String?
  budget : @fga.ExecutionBudget?
  cancelled : () -> Bool
}

///|
fn EvalState::check(self : EvalState) -> Unit raise @fga.FgaError {
  match self.budget {
    Some(b) => b.check()
    None => ()
  }
  if self.interrupted || (self.cancelled)() {
    self.interrupted = true
    raise eval_error("condition evaluation interrupted or cost limit exceeded")
  }
}

///|
fn EvalState::charge(
  self : EvalState,
  amount : Int32,
) -> Unit raise @fga.FgaError {
  self.check()
  if amount > self.limit - self.cost {
    self.interrupted = true
    raise eval_error("condition evaluation cost limit exceeded")
  }
  self.cost += amount
}

///|
fn constant_expr(expr : CelExpr) -> Bool {
  match expr {
    CLiteral(_) => true
    CList(items) => items.all(constant_expr)
    CMap(entries) => entries.all(e => constant_expr(e.0) && constant_expr(e.1))
    _ => false
  }
}
