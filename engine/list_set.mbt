// ListUsers expands the relation graph into sets, rather than checking each
// possible user. Negative entries and exclusions preserve wildcard differences.

///|
priv struct UserSet {
  found : Map[String, Bool]
  excluded : Map[String, Unit]
  mut cycle : Bool
  mut error : @fga.FgaError?
}

///|
fn user_set() -> UserSet {
  { found: Map([]), excluded: Map([]), cycle: false, error: None, }
}

///|
fn UserSet::merge(self : UserSet, other : UserSet) -> Unit {
  other.found.each(fn(k, v) { self.found[k] = v })
  other.excluded.each(fn(k, _) { self.excluded[k] = () })
  self.cycle = self.cycle || other.cycle
  if self.error is None {
    self.error = other.error
  }
}

///|
fn Engine::expand_users(
  self : Engine,
  object : String,
  relation : String,
  filter : @fga.UserRef,
  context : Map[String, Json],
  depth : Int32,
  path : Array[String],
) -> UserSet {
  let out = user_set()
  if depth >= @fga.MAX_RESOLUTION_DEPTH {
    out.error = Some(
      @fga.fail(
        @fga.ERR_RESOLUTION_TOO_COMPLEX,
        "ListUsers resolution depth exceeded",
      ),
    )
    return out
  }
  let key = path_key(object, relation)
  if path.contains(key) {
    out.cycle = true
    return out
  }
  if @fga.object_type(object) == filter.type_name &&
    filter.relation == Some(relation) {
    out.found[key] = true
  }
  let rewrite = match self.model.find_type(@fga.object_type(object)) {
    Some(td) =>
      match td.relation_rewrite(relation) {
        Some(r) => r
        None => return out
      }
    None => return out
  }
  path.push(key)
  defer {
    let _ = path.pop()
  }
  out.merge(
    self.expand_user_rewrite(
      object, relation, rewrite, filter, context, depth, path,
    ),
  )
  out
}

///|
fn Engine::expand_user_rewrite(
  self : Engine,
  object : String,
  relation : String,
  rewrite : @fga.Userset,
  filter : @fga.UserRef,
  context : Map[String, Json],
  depth : Int32,
  path : Array[String],
) -> UserSet {
  let out = user_set()
  match rewrite {
    Computed(target) =>
      return self.expand_users(object, target, filter, context, depth + 1, path)
    This | TupleToUserset(_, _) => {
      let read_relation = match rewrite {
        TupleToUserset(_, r) => r
        _ => relation
      }
      for tuple in self.reader.read(object, read_relation) {
        let binding = tuple_binding_spec(
          self.model,
          @fga.object_type(object),
          read_relation,
          tuple,
        )
        if binding is TupleBindingSpec::Invalid {
          continue
        }
        let holds = self.condition_holds(tuple, binding, context) catch {
          err => {
            if out.error is None {
              out.error = Some(err)
            }
            false
          }
        }
        if !holds {
          continue
        }
        let user = match @fga.parse_user_ref(tuple.user) {
          Some(u) => u
          None => continue
        }
        match rewrite {
          TupleToUserset(computed, _) =>
            if user.relation is None && user.id != "*" {
              out.merge(
                self.expand_users(
                  tuple.user,
                  computed,
                  filter,
                  context,
                  depth + 1,
                  path,
                ),
              )
            }
          _ =>
            match user.relation {
              Some(r) =>
                out.merge(
                  self.expand_users(
                    user.type_name + ":" + user.id,
                    r,
                    filter,
                    context,
                    depth + 1,
                    path,
                  ),
                )
              None =>
                if user.type_name == filter.type_name {
                  out.found[tuple.user] = true
                }
            }
        }
      }
      // TTU and composite rewrites consume cycle metadata; direct usersets
      // propagate it so an exclusion can reject a cyclic subtract branch.
      if rewrite is TupleToUserset(_, _) {
        out.cycle = false
      }
    }
    Union(children) | Intersection(children) => {
      let parts = children.map(fn(r) {
        self.expand_user_rewrite(
          object, relation, r, filter, context, depth, path,
        )
      })
      let candidates : Map[String, Unit] = Map([])
      let exclusion_counts : Map[String, Int32] = Map([])
      for part in parts {
        if out.error is None {
          out.error = part.error
        }
        part.found.each(fn(k, v) { if v { candidates[k] = () } })
        part.excluded.each(fn(k, _) {
          exclusion_counts[k] = exclusion_counts.get(k).unwrap_or(0) + 1
        })
      }
      let wildcard = filter.type_name + ":*"
      let intersect = rewrite is Intersection(_)
      exclusion_counts.each(fn(k, n) {
        if intersect || n == parts.length() {
          out.excluded[k] = ()
        }
      })
      candidates.each(fn(k, _) {
        let mut present = !intersect
        if intersect {
          present = !out.excluded.contains(k)
          for part in parts {
            if part.found.get(k) != Some(true) &&
              part.found.get(wildcard) != Some(true) {
              present = false
            }
          }
        }
        if present {
          out.found[k] = true
        }
      })
    }
    Difference(base, subtract) => {
      let a = self.expand_user_rewrite(
        object, relation, base, filter, context, depth, path,
      )
      let b = self.expand_user_rewrite(
        object, relation, subtract, filter, context, depth, path,
      )
      if b.cycle {
        return out
      }
      out.error = match a.error {
        Some(e) => Some(e)
        None => b.error
      }
      let wildcard = filter.type_name + ":*"
      if a.found.contains(wildcard) {
        a.found.each(fn(k, v) {
          if !b.found.contains(k) && !b.found.contains(wildcard) {
            out.found[k] = v
          }
        })
        a.excluded.each(fn(k, _) { out.excluded[k] = () })
        b.found.each(fn(k, v) {
          if k != wildcard {
            out.found[k] = !v
            if v {
              out.excluded[k] = ()
            }
          } else {
            a.found.each(fn(key, _) {
              if !b.found.contains(key) {
                out.found[key] = false
              }
            })
          }
        })
      } else {
        a.found.each(fn(k, v) {
          if b.found.contains(k) || b.found.contains(wildcard) {
            out.found[k] = !b.found.get(k).unwrap_or(true)
          } else {
            out.found[k] = v
          }
        })
      }
    }
  }
  out
}
