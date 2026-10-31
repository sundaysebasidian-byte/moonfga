// OpenFGA counts full Check dispatches, but its userset / weight-two paths can
// read terminal tuples without dispatching another Check request.

///|
priv enum DepthProbe {
  FullRequest
  TerminalJoin
  RecursiveUserset
}

///|
priv struct TerminalReader {
  base : &@fga.TupleReader
}

///|
impl @fga.TupleReader for TerminalReader with fn read(self, object, relation) {
  self.base
  .read(object, relation)
  .filter(fn(t) {
    match @fga.parse_user_ref(t.user) {
      Some(u) => u.relation is None
      None => false
    }
  })
}

///|
impl @fga.TupleReader for TerminalReader with fn read_userset(
  _self,
  _object,
  _relation,
) {
  []
}

///|
impl @fga.TupleReader for TerminalReader with fn all_objects(self, type_name) {
  self.base.all_objects(type_name)
}

///|
impl @fga.TupleReader for TerminalReader with fn all_users(self) {
  self.base.all_users()
}

///|
/// Whether a relation can be evaluated using terminal tuple reads alone.
/// The optional self relation permits the single recursive userset edge;
/// that edge is cut by TerminalReader during the one-level terminal probe.
fn terminal_shape(
  model : @fga.AuthModel,
  type_name : String,
  relation : String,
  rewrite : @fga.Userset,
  recursive : (String, String)?,
  path : Array[String],
) -> Bool {
  match rewrite {
    This => {
      for r in model.direct_restrictions(type_name, relation) {
        match r.relation {
          Some(target) =>
            if recursive != Some((r.type_name, target)) {
              return false
            }
          None => ()
        }
      }
      true
    }
    Computed(target) =>
      terminal_relation(model, type_name, target, recursive, path)
    Union(children) | Intersection(children) =>
      children.all(fn(c) {
        terminal_shape(model, type_name, relation, c, recursive, path)
      })
    Difference(a, b) =>
      terminal_shape(model, type_name, relation, a, recursive, path) &&
      terminal_shape(model, type_name, relation, b, recursive, path)
    TupleToUserset(_, _) => false
  }
}

///|
fn terminal_relation(
  model : @fga.AuthModel,
  type_name : String,
  relation : String,
  recursive : (String, String)?,
  path : Array[String],
) -> Bool {
  let key = type_name + "#" + relation
  if path.contains(key) {
    return false
  }
  let rewrite = match model.find_type(type_name) {
    Some(td) =>
      match td.relation_rewrite(relation) {
        Some(r) => r
        None => return false
      }
    None => return false
  }
  path.push(key)
  defer {
    let _ = path.pop()
  }
  terminal_shape(model, type_name, relation, rewrite, recursive, path)
}

///|
fn recursive_terminal_relation(
  model : @fga.AuthModel,
  type_name : String,
  relation : String,
) -> Bool {
  model
  .direct_restrictions(type_name, relation)
  .any(fn(r) { r.type_name == type_name && r.relation == Some(relation) }) &&
  terminal_relation(model, type_name, relation, Some((type_name, relation)), [])
}

///|
fn check_relation_cycle(
  model : @fga.AuthModel,
  type_name : String,
  relation : String,
  path : Array[String],
) -> Bool {
  let key = type_name + "#" + relation
  if path.contains(key) {
    return true
  }
  let rewrite = match model.find_type(type_name) {
    Some(td) =>
      match td.relation_rewrite(relation) {
        Some(r) => r
        None => return false
      }
    None => return false
  }
  path.push(key)
  defer {
    let _ = path.pop()
  }
  check_rewrite_cycle(model, type_name, relation, rewrite, path)
}

///|
fn check_rewrite_cycle(
  model : @fga.AuthModel,
  type_name : String,
  relation : String,
  rewrite : @fga.Userset,
  path : Array[String],
) -> Bool {
  match rewrite {
    This =>
      model
      .direct_restrictions(type_name, relation)
      .any(fn(r) {
        match r.relation {
          Some(target) => check_relation_cycle(model, r.type_name, target, path)
          None => false
        }
      })
    Computed(target) => check_relation_cycle(model, type_name, target, path)
    TupleToUserset(computed, tupleset) =>
      model
      .direct_restrictions(type_name, tupleset)
      .any(fn(r) { check_relation_cycle(model, r.type_name, computed, path) })
    Union(children) | Intersection(children) =>
      children.any(fn(c) {
        check_rewrite_cycle(model, type_name, relation, c, path)
      })
    Difference(a, b) =>
      check_rewrite_cycle(model, type_name, relation, a, path) ||
      check_rewrite_cycle(model, type_name, relation, b, path)
  }
}

///|
fn Engine::userset_terminal_mode(
  self : Engine,
  object : String,
  relation : String,
  target : String,
  target_relation : String,
) -> DepthProbe {
  let source_type = @fga.object_type(object)
  let target_type = @fga.object_type(target)
  if source_type == target_type &&
    relation == target_relation &&
    recursive_terminal_relation(self.model, source_type, relation) {
    return RecursiveUserset
  }
  // The ordinary weight-two join is unavailable through a recursive model
  // component, even if this particular tuple points to a terminal relation.
  if !check_relation_cycle(self.model, source_type, relation, []) &&
    terminal_relation(self.model, target_type, target_relation, None, []) {
    TerminalJoin
  } else {
    FullRequest
  }
}

///|
fn Engine::ttu_terminal_mode(
  self : Engine,
  object : String,
  tupleset : String,
  computed : String,
) -> DepthProbe {
  let parents = self.model.direct_restrictions(
    @fga.object_type(object),
    tupleset,
  )
  if !parents.is_empty() &&
    parents.all(fn(r) {
      terminal_relation(self.model, r.type_name, computed, None, [])
    }) {
    TerminalJoin
  } else {
    FullRequest
  }
}

///|
fn Engine::dispatch_check(
  self : Engine,
  object : String,
  relation : String,
  subject : String,
  context : Map[String, Json],
  depth : Int32,
  path : Array[String],
  mode : DepthProbe,
) -> Outcome raise @fga.FgaError {
  if depth == @fga.MAX_RESOLUTION_DEPTH &&
    !(mode is FullRequest) &&
    !is_userset_user(subject) {
    let terminal = TerminalReader::{ base: self.reader, }
    let probe = Engine::{ ..self, reader: terminal as &@fga.TupleReader, }
    // depth describes the prospective child request. This read stays at
    // the caller's depth: the filtered reader cannot follow userset edges.
    let outcome = probe.resolve(
      object,
      relation,
      subject,
      context,
      depth - 1,
      path,
    )
    if mode is TerminalJoin || outcome is OTrue {
      return outcome
    }
  }
  self.resolve(object, relation, subject, context, depth, path)
}
