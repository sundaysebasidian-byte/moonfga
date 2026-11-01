// Reverse proof propagation for ListObjects. Direct/union proofs are emitted
// without Check's per-object recursion limit; only intersection/exclusion
// candidates require residual membership evaluation.

///|
priv struct ReverseEdge {
  source : String
  target : String
  tuple : @fga.Tuple?
  residual : Bool
}

///|
fn reverse_edge(
  edges : Array[ReverseEdge],
  source : String,
  target : String,
  tuple : @fga.Tuple?,
  residual : Bool,
) -> Unit {
  edges.push({ source, target, tuple, residual, })
}

///|
fn Engine::reverse_rules(
  self : Engine,
  object : String,
  relation : String,
  rewrite : @fga.Userset,
  user : String,
  residual : Bool,
  edges : Array[ReverseEdge],
) -> Unit {
  let target = path_key(object, relation)
  match rewrite {
    This =>
      for tuple in self.reader.read(object, relation) {
        if tuple_binding_spec(
            self.model,
            @fga.object_type(object),
            relation,
            tuple,
          )
          is TupleBindingSpec::Invalid {
          continue
        }
        if tuple.user == user {
          reverse_edge(edges, "$subject", target, Some(tuple), residual)
        } else {
          match @fga.parse_user_ref(tuple.user) {
            Some(u) =>
              match u.relation {
                Some(r) =>
                  reverse_edge(
                    edges,
                    u.type_name + ":" + u.id + "#" + r,
                    target,
                    Some(tuple),
                    residual,
                  )
                None =>
                  if u.id == "*" && subject_matches_wildcard(user, u) {
                    reverse_edge(
                      edges,
                      "$subject",
                      target,
                      Some(tuple),
                      residual,
                    )
                  }
              }
            None => ()
          }
        }
      }
    Computed(r) =>
      reverse_edge(edges, path_key(object, r), target, None, residual)
    TupleToUserset(computed, tupleset) =>
      for tuple in self.reader.read(object, tupleset) {
        if is_concrete_user(tuple.user) &&
          !(tuple_binding_spec(
            self.model,
            @fga.object_type(object),
            tupleset,
            tuple,
          )
          is TupleBindingSpec::Invalid) {
          reverse_edge(
            edges,
            path_key(tuple.user, computed),
            target,
            Some(tuple),
            residual,
          )
        }
      }
    Union(children) =>
      for child in children {
        self.reverse_rules(object, relation, child, user, residual, edges)
      }
    Intersection(children) =>
      for child in children {
        self.reverse_rules(object, relation, child, user, true, edges)
      }
    Difference(base, subtract) => {
      self.reverse_rules(object, relation, base, user, true, edges)
      self.reverse_rules(object, relation, subtract, user, true, edges)
    }
  }
}

///|
fn Engine::reverse_objects(
  self : Engine,
  type_name : String,
  relation : String,
  user : String,
  context : Map[String, Json],
) -> Array[String] raise @fga.FgaError {
  let graph_clock = @bench.monotonic_clock_start()
  let edges : Array[ReverseEdge] = []
  let roots : Map[String, String] = Map([])
  for td in self.model.types {
    for object in self.reader.all_objects(td.name) {
      if td.name == type_name {
        roots[path_key(object, relation)] = object
      }
      for r in td.relation_order {
        self.reverse_rules(
          object,
          r,
          td.relation_rewrite(r).unwrap(),
          user,
          false,
          edges,
        )
      }
    }
  }
  // A userset includes itself even when it has no stored members.
  if is_userset_user(user) {
    let u = @fga.parse_user_ref(user).unwrap()
    if u.type_name == type_name && u.relation == Some(relation) {
      roots[user] = u.type_name + ":" + u.id
    }
  }
  let incoming : Map[String, Array[String]] = Map([])
  let outgoing : Map[String, Array[ReverseEdge]] = Map([])
  for edge in edges {
    match incoming.get(edge.target) {
      Some(xs) => xs.push(edge.source)
      None => incoming[edge.target] = [edge.source]
    }
    match outgoing.get(edge.source) {
      Some(xs) => xs.push(edge)
      None => outgoing[edge.source] = [edge]
    }
  }
  println("graph," + @bench.monotonic_clock_end(graph_clock).to_string())
  // Restrict work and condition errors to paths capable of reaching this query.
  let needed : Map[String, Unit] = Map([])
  let pending : Array[String] = []
  roots.each(fn(k, _) {
    needed[k] = ()
    pending.push(k)
  })
  let mut pos = 0
  while pos < pending.length() {
    let k = pending[pos]
    pos += 1
    for source in incoming.get(k).unwrap_or([]) {
      if !needed.contains(source) {
        needed[source] = ()
        pending.push(source)
      }
    }
  }
  let facts : Map[String, Bool] = Map([])
  let agenda = ["$subject"]
  facts["$subject"] = false
  if is_userset_user(user) {
    facts[user] = false
    agenda.push(user)
  }
  pos = 0
  let mut error : @fga.FgaError? = None
  while pos < agenda.length() {
    let source = agenda[pos]
    pos += 1
    for edge in outgoing.get(source).unwrap_or([]) {
      if !needed.contains(edge.target) {
        continue
      }
      let holds = match edge.tuple {
        None => true
        Some(t) =>
          self.condition_holds(
            t,
            tuple_binding_spec(
              self.model,
              @fga.object_type(t.object),
              t.relation,
              t,
            ),
            context,
          ) catch {
            err => {
              if error is None {
                error = Some(err)
              }
              false
            }
          }
      }
      if !holds {
        continue
      }
      let residual = edge.residual || facts.get(source).unwrap_or(false)
      match facts.get(edge.target) {
        None => {
          facts[edge.target] = residual
          agenda.push(edge.target)
        }
        Some(true) =>
          if !residual {
            facts[edge.target] = false
            agenda.push(edge.target)
          }
        _ => ()
      }
    }
  }
  match error {
    Some(err) => raise err
    None => ()
  }
  let results : Array[String] = []
  roots.each(fn(key, object) {
    match facts.get(key) {
      Some(false) => results.push(object)
      _ => ()
    }
  })
  // Residual checks are only for graph-discovered non-monotone candidates,
  // matching OpenFGA's RequiresFurtherEval path.
  for key, object in roots {
    if facts.get(key) == Some(true) {
      if self.check_resolved(object, relation, user, context) {
        results.push(object)
      }
    }
  }
  sorted(results)
}
