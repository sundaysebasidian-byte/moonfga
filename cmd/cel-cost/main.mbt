///|
fn run_case(c : Json) -> Json {
  let result : Map[String, Json] = Map([])
  let source = @fga.json_get_string(c, "expression").unwrap()
  let expr = @cel.compile(source) catch {
    e =>
      return Json::object(
        Map([
          ("category", Json::string("compile")),
          ("error", Json::string(@fga.error_message(e))),
        ]),
      )
  }
  let env : Map[String, @fga.CelValue] = Map([])
  match @fga.json_object_get(c, "context") {
    Some(Object(m)) =>
      m.each(fn(k, v) {
        env[k] = if k == "n" {
          match v {
            Number(x, ..) => @fga.VInt(x.to_int64())
            _ => abort("n must be a number")
          }
        } else {
          @fga.json_to_cel_value_raw(v)
        }
      })
    _ => ()
  }
  let limit = match @fga.json_object_get(c, "limit") {
    Some(Number(x, ..)) => x.to_int()
    _ => 2147483647
  }
  try {
    let (value, cost) = @cel.eval_expr_with_cost(expr, env, limit)
    result["category"] = Json::string("ok")
    result["value"] = Json::string(@fga.cel_value_to_json(value).stringify())
    result["cost"] = Json::number(cost.to_double())
  } catch {
    e => {
      result["category"] = Json::string("evaluation")
      result["error"] = Json::string(@fga.error_message(e))
    }
  }
  Json::object(result)
}

///|
fn main {
  let input = @fs.read_file_to_string(@env.args()[1]) catch {
    _ => abort("cost corpus read failed")
  }
  let data = @json.parse(input) catch { _ => abort("cost corpus parse failed") }
  let cases = match data {
    Array(xs) => xs
    _ => abort("expected corpus array")
  }
  println(Json::array(cases.map(run_case)).stringify())
}
