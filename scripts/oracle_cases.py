"""Original randomized boundary scenarios for the v1.22.1 oracle."""
from datetime import datetime, timedelta, timezone


def condition_case(expression, parameters, context):
    return {
        "model": {"schema_version": "1.1", "type_definitions": [
            {"type": "user"},
            {"type": "document", "relations": {"viewer": {"this": {}}},
             "metadata": {"relations": {"viewer": {"directly_related_user_types": [{"type": "user", "condition": "enabled"}]}}}},
        ], "conditions": {"enabled": {"name": "enabled", "expression": expression, "parameters": parameters}}},
        "tuples": [{"object": "document:0", "relation": "viewer", "user": "user:0",
                    "condition": {"name": "enabled", "context": context}}],
        "object": "document:0", "relation": "viewer", "user": "user:0",
    }


def logical_case(rng):
    values = ["true", "false", "(1 / x > 0)"]
    expression = f"{rng.choice(values)} {rng.choice(['&&', '||'])} {rng.choice(values)}"
    c = condition_case(expression, {"x": {"type_name": "TYPE_NAME_INT"}}, {"x": rng.choice([0, 0, 1])})
    if rng.choice([False, True]):
        doc = c["model"]["type_definitions"][1]
        doc["relations"]["conditional"] = doc["relations"]["viewer"]
        doc["metadata"]["relations"]["conditional"] = doc["metadata"]["relations"].pop("viewer")
        doc["relations"]["owner"] = {"this": {}}
        doc["metadata"]["relations"]["owner"] = {"directly_related_user_types": [{"type": "user"}]}
        children = [{"computedUserset": {"relation": "conditional"}}, {"computedUserset": {"relation": "owner"}}]
        rng.shuffle(children)
        doc["relations"]["viewer"] = {rng.choice(["union", "intersection"]): {"child": children}}
        c["tuples"][0]["relation"] = "conditional"
        if rng.choice([False, True]):
            c["tuples"].append({"object": "document:0", "relation": "owner", "user": "user:0"})
        if rng.choice([False, True]):
            c["contextual"] = c["tuples"]
            c["tuples"] = []
    c["family"] = "logical_errors"
    return c


def unicode_case(rng):
    s = "".join(rng.choice(["a", "中", "😀", "é", "𐐀"]) for _ in range(rng.randrange(6)))
    expression = rng.choice(["size(s)", "s.size()"]) + f" == {len(s) + rng.choice([0, 0, 1])}"
    c = condition_case(expression, {"s": {"type_name": "TYPE_NAME_STRING"}}, {"s": s})
    c["family"] = "unicode"
    return c


def timestamp_case(rng):
    dt = datetime(rng.randrange(1960, 2100), rng.randrange(1, 13), rng.randrange(1, 28),
                  rng.randrange(24), rng.randrange(60), rng.randrange(60),
                  rng.randrange(1000)*1000, timezone.utc)
    offset = timezone(timedelta(minutes=rng.choice([-330, 0, 60, 480])))
    wall = dt.astimezone(offset)
    fraction = f"{rng.randrange(1_000_000_000):09d}".rstrip("0")
    source_suffix = wall.isoformat()[-6:]
    source = wall.strftime("%Y-%m-%dT%H:%M:%S") + ("." + fraction if fraction else "") + source_suffix
    suffix = "Z" if offset.utcoffset(None) == timedelta(0) else source_suffix
    target = wall.strftime("%Y-%m-%dT%H:%M:%S") + ("." + fraction if fraction else "") + suffix
    c = condition_case(f"string(t) == '{target}'", {"t": {"type_name": "TYPE_NAME_TIMESTAMP"}}, {"t": source})
    c["family"] = "timestamp"
    return c


def deep_case(rng):
    length = rng.choice([0, 1, 23, 24, 25, 26, 27, 32])
    c = {
        "model": {"schema_version": "1.1", "type_definitions": [
            {"type": "user"},
            {"type": "group", "relations": {"member": {"this": {}}},
             "metadata": {"relations": {"member": {"directly_related_user_types": [{"type": "user"}, {"type": "group", "relation": "member"}]}}}},
        ]},
        "tuples": [{"object": "group:0", "relation": "member", "user": "user:0"}] + [
            {"object": f"group:{i}", "relation": "member", "user": f"group:{i-1}#member"}
            for i in range(1, length+1)],
        "object": f"group:{rng.choice([0, length])}", "relation": "member", "user": "user:0", "family": "deep_graph",
    }
    if length > 0 and rng.randrange(4) == 0:
        c["tuples"].append({"object": "group:0", "relation": "member", "user": f"group:{length}#member"})
    if rng.randrange(4) == 0:
        t = {"object": f"group:{length}", "relation": "member", "user": "user:0"}
        if t not in c["tuples"]:
            c["tuples"].append(t)
    return c


def boundary_case(rng, i):
    return {1: logical_case, 2: unicode_case, 3: timestamp_case, 4: deep_case}[i % 5](rng)
