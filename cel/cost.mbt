///|
priv struct EvalState {
  mut cost : Int32
  limit : Int32
  mut interrupted : Bool
  local_timezone : String?
  cancelled : () -> Bool
}

///|
fn EvalState::check(self : EvalState) -> Unit raise @fga.FgaError {
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
    CUnary(_, inner) => constant_expr(inner)
    CBinary(_, a, b) => constant_expr(a) && constant_expr(b)
    CTernary(a, b, c) =>
      constant_expr(a) && constant_expr(b) && constant_expr(c)
    _ => false
  }
}
