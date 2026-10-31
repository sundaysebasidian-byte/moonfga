///|
test "parse tuple from JSON with condition" {
  let value = @json.parse(
    "{\"object\":\"document:1\",\"relation\":\"viewer\",\"user\":\"user:anne\",\"condition\":{\"name\":\"in_ip\",\"context\":{\"ip\":\"10.0.0.1\"}}}",
  ) catch {
    _ => abort("bad fixture")
  }
  let tuple = @fga.tuple_from_json(value) catch {
    @fga.FgaError(..) as err => abort(@fga.error_message(err))
  }
  inspect(tuple.object, content="document:1")
  inspect(tuple.relation, content="viewer")
  inspect(tuple.user, content="user:anne")
  match tuple.condition_name() {
    Some(name) => inspect(name, content="in_ip")
    None => abort("missing condition name")
  }
  inspect(tuple.has_condition(), content="true")
}

///|
test "parse textual tuple without condition" {
  let tuple = @fga.tuple_from_string("document:1#viewer@user:anne") catch {
    @fga.FgaError(..) as err => abort(@fga.error_message(err))
  }
  inspect(tuple.object, content="document:1")
  inspect(tuple.user, content="user:anne")
  inspect(tuple.has_condition(), content="false")
}

///|
test "parse textual tuple with condition context" {
  let tuple = @fga.tuple_from_string(
    "document:1#viewer@user:anne[in_ip:{\"ip\":\"10.0.0.1\"}]",
  ) catch {
    @fga.FgaError(..) as err => abort(@fga.error_message(err))
  }
  match tuple.condition_name() {
    Some(name) => inspect(name, content="in_ip")
    None => abort("missing condition")
  }
  match tuple.condition {
    Some(condition) =>
      match condition.context.get("ip") {
        Some(@fga.VString(value)) => inspect(value, content="10.0.0.1")
        _ => abort("missing ip")
      }
    None => abort("missing condition")
  }
}

///|
test "tuple text lines ignore comments and blanks" {
  let tuples = @fga.tuples_from_text(
    "# comment\n\ndocument:1#viewer@user:anne\n" +
    "document:2#editor@group:eng#member\n",
  ) catch {
    @fga.FgaError(..) as err => abort(@fga.error_message(err))
  }
  inspect(tuples.length(), content="2")
  inspect(tuples[1].user, content="group:eng#member")
}

///|
test "reject malformed tuple text" {
  let rejected = try {
    let _ = @fga.tuple_from_string("document:1 viewer user:anne")
    false
  } catch {
    @fga.FgaError(..) => true
  }
  inspect(rejected, content="true")
}
