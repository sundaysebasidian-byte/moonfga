import copy
import json
import random
import subprocess
import sys
import time
import urllib.error
from pathlib import Path

ROOT = Path(sys.argv[1]).resolve()
OUT = Path(sys.argv[2]).resolve()
OUT.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(ROOT / "scripts"))
import oracle_openfga as oracle


def direct():
    return {"this": {}}


def computed(relation):
    return {"computedUserset": {"relation": relation}}


def union(*children):
    return {"union": {"child": list(children)}}


def intersection(*children):
    return {"intersection": {"child": list(children)}}


def difference(base, subtract):
    return {"difference": {"base": base, "subtract": subtract}}


def ttu(parent="parent", relation="viewer"):
    return {"tupleToUserset": {"tupleset": {"relation": parent}, "computedUserset": {"relation": relation}}}


USER_FACETS = [
    {"type": "user"},
    {"type": "user", "wildcard": {}},
    {"type": "group", "relation": "member"},
]


def graph_model(viewer):
    return {
        "schema_version": "1.1",
        "type_definitions": [
            {"type": "user"},
            {
                "type": "group",
                "relations": {"member": direct()},
                "metadata": {"relations": {"member": {"directly_related_user_types": [
                    {"type": "user"}, {"type": "group", "relation": "member"},
                ]}}},
            },
            {
                "type": "document",
                "relations": {
                    "reader": direct(), "writer": direct(), "blocked": direct(),
                    "parent": direct(), "viewer": viewer,
                },
                "metadata": {"relations": {
                    **{r: {"directly_related_user_types": copy.deepcopy(USER_FACETS)} for r in ["reader", "writer", "blocked"]},
                    "parent": {"directly_related_user_types": [{"type": "document"}]},
                }},
            },
        ],
    }


REWRITES = [
    computed("reader"),
    union(computed("reader"), ttu()),
    union(computed("reader"), ttu()),
    intersection(computed("reader"), union(computed("writer"), ttu())),
    difference(union(computed("reader"), ttu()), computed("blocked")),
    difference(computed("reader"), computed("blocked")),
    intersection(computed("reader"), computed("writer")),
    union(intersection(computed("reader"), computed("writer")), ttu()),
    difference(union(computed("reader"), ttu()), computed("blocked")),
    intersection(union(computed("reader"), computed("writer")), union(computed("reader"), ttu())),
    difference(difference(computed("reader"), computed("blocked")), computed("writer")),
    union(difference(computed("reader"), computed("blocked")), intersection(computed("writer"), ttu())),
]


def tup(obj, rel, user, condition=None):
    value = {"object": obj, "relation": rel, "user": user}
    if condition is not None:
        value["condition"] = {"name": "enabled", "context": condition}
    return value


def generated_case(rng, i):
    rewrite = copy.deepcopy(REWRITES[i % len(REWRITES)])
    tuples = []
    for g in range(3):
        for u in range(4):
            if rng.random() < 0.32:
                tuples.append(tup(f"group:{g}", "member", f"user:{u}"))
        if g and rng.random() < 0.55:
            tuples.append(tup(f"group:{g}", "member", f"group:{g-1}#member"))
    for n in range(6):
        for rel in ["reader", "writer", "blocked"]:
            for user in ["user:0", "user:1", "user:2", "user:3", "user:*", "group:0#member", "group:2#member"]:
                if rng.random() < 0.14:
                    tuples.append(tup(f"document:{n}", rel, user))
        if n and rng.random() < 0.55:
            tuples.append(tup(f"document:{n}", "parent", f"document:{rng.randrange(n)}"))
    if i % 11 == 0:
        cycle = tup("document:0", "parent", "document:5")
        if cycle not in tuples:
            tuples.append(cycle)
    contextual = []
    if i % 3 == 0:
        kept = []
        for index, value in enumerate(tuples):
            if index % 4 == 0:
                contextual.append(value)
            else:
                kept.append(value)
        tuples = kept
    return {
        "name": f"r2_graph_{i}_{['direct','ttu','union_ttu','intersection_ttu','ttu_butnot','butnot','intersection','nested_union','nested_butnot','nested_intersection','double_butnot','mixed'][i % 12]}",
        "family": "r2_graph",
        "model": graph_model(rewrite),
        "tuples": tuples,
        "contextual": contextual,
        "object": f"document:{rng.randrange(6)}",
        "relation": "viewer",
        "user": f"user:{rng.randrange(4)}",
        "context": rng.choice([{}, {"ok": True}, {"ok": False}]),
    }


def deep_ttu_case(length, cycle=False):
    tuples = [tup("document:0", "reader", "user:0")]
    for n in range(1, length + 1):
        tuples.append(tup(f"document:{n}", "parent", f"document:{n-1}"))
    if cycle:
        tuples.append(tup("document:0", "parent", f"document:{length}"))
    return {
        "name": f"r2_deep_ttu_{length}_{'cycle' if cycle else 'dag'}",
        "family": "r2_deep_ttu", "model": graph_model(union(computed("reader"), ttu())),
        "tuples": tuples, "object": f"document:{length}", "relation": "viewer", "user": "user:0",
    }


def wildcard_case(name, viewer, tuples, contextual=None):
    return {
        "name": name, "family": "r2_wildcard_conditions", "model": graph_model(viewer),
        "tuples": tuples, "contextual": contextual or [], "object": "document:0", "relation": "viewer", "user": "user:0",
    }


def intersection_condition_case(name, tuples, contextual=None, context=None):
    model = graph_model(intersection(computed("reader"), computed("writer")))
    model["type_definitions"][2]["metadata"]["relations"]["writer"]["directly_related_user_types"] = [
        {"type": "user"}, {"type": "user", "condition": "enabled"},
    ]
    model["conditions"] = {
        "enabled": {
            "name": "enabled", "expression": "ok",
            "parameters": {"ok": {"type_name": "TYPE_NAME_BOOL"}},
        },
    }
    return {
        "name": name, "family": "r2_intersection_conditions", "model": model,
        "tuples": tuples, "contextual": contextual or [], "context": context or {},
        "object": "document:0", "relation": "viewer", "user": "user:0",
    }


fixed = json.loads((ROOT / "examples/regressions/oracle.json").read_text())
rng = random.Random(991732)
custom = [generated_case(rng, i) for i in range(120)]
custom += [deep_ttu_case(n, cycle) for n in [0, 1, 24, 25, 26, 31] for cycle in [False, True]]
custom += [
    wildcard_case("r2_wildcard_base_explicit_exception", difference(computed("reader"), computed("blocked")), [
        tup("document:0", "reader", "user:*"), tup("document:0", "reader", "user:0"), tup("document:0", "blocked", "user:0")]),
    wildcard_case("r2_wildcard_base_wildcard_exception", difference(computed("reader"), computed("blocked")), [
        tup("document:0", "reader", "user:*"), tup("document:0", "blocked", "user:*")]),
    wildcard_case("r2_explicit_base_wildcard_exception", difference(computed("reader"), computed("blocked")), [
        tup("document:0", "reader", "user:0"), tup("document:0", "reader", "user:1"), tup("document:0", "blocked", "user:*")]),
    wildcard_case("r2_contextual_butnot_exception", difference(computed("reader"), computed("blocked")), [
        tup("document:0", "reader", "user:*")], [tup("document:0", "blocked", "user:0")]),
]
custom += [
    intersection_condition_case("r2_intersection_persistent_condition_error", [
        tup("document:0", "reader", "user:0"), tup("document:0", "writer", "user:0", {})]),
    intersection_condition_case("r2_intersection_false_branch_condition_error", [
        tup("document:0", "writer", "user:0", {})]),
    intersection_condition_case("r2_intersection_contextual_condition_true", [
        tup("document:0", "reader", "user:0")], [tup("document:0", "writer", "user:0", {})], {"ok": True}),
    intersection_condition_case("r2_intersection_contextual_condition_false", [
        tup("document:0", "reader", "user:0")], [tup("document:0", "writer", "user:0", {})], {"ok": False}),
]
cases = fixed + custom
(OUT / "cases.json").write_text(json.dumps(cases, ensure_ascii=False))
local = subprocess.run(["moon", "run", "--target", "native", "cmd/oracle", "--", str(OUT / "cases.json")], cwd=ROOT, text=True, capture_output=True)
if local.returncode:
    print(local.stdout)
    print(local.stderr, file=sys.stderr)
    raise SystemExit(local.returncode)
actual = json.loads(local.stdout)
ports = [oracle.port() for _ in range(3)]
base = f"http://127.0.0.1:{ports[0]}"
with (OUT / "server.log").open("w") as log:
    proc = subprocess.Popen([oracle.binary(), "run", "--datastore-engine", "memory", "--http-addr", f"127.0.0.1:{ports[0]}", "--grpc-addr", f"127.0.0.1:{ports[1]}", "--metrics-addr", f"127.0.0.1:{ports[2]}", "--playground-enabled=false", "--profiler-enabled=false", "--log-level", "error"], stdout=log, stderr=log)
    expected, mismatches = [], []
    try:
        for _ in range(100):
            if proc.poll() is not None:
                raise RuntimeError("OpenFGA exited")
            try:
                oracle.request(base, "/healthz")
                break
            except urllib.error.URLError:
                time.sleep(.1)
        else:
            raise RuntimeError("readiness timeout")
        for i, case in enumerate(cases):
            store = oracle.request(base, "/stores", {"name": f"r2-directed-{i}"})["id"]
            path = f"/stores/{store}"
            try:
                mid = oracle.request(base, path + "/authorization-models", case["model"])["authorization_model_id"]
            except Exception as error:
                raise RuntimeError(f"model rejected for case {i} {case.get('name')}: {error}") from error
            if case.get("tuples"):
                written = oracle.request(base, path + "/write", {"authorization_model_id": mid, "writes": {"tuple_keys": case["tuples"]}})
                if not isinstance(written, dict):
                    raise RuntimeError(f"setup write rejected for {case.get('name')}: {oracle.HTTP_ERRORS[-1]}")
            common = {"authorization_model_id": mid, "context": case.get("context", {}), "contextual_tuples": {"tuple_keys": case.get("contextual", [])}}
            check = oracle.request(base, path + "/check", {**common, "tuple_key": {k: case[k] for k in ["object", "relation", "user"]}})
            objects = oracle.request(base, path + "/list-objects", {**common, "type": case["object"].split(":", 1)[0], "relation": case["relation"], "user": case["user"]})
            users = oracle.request(base, path + "/list-users", {**common, "contextual_tuples": case.get("contextual", []), "object": {"type": case["object"].split(":", 1)[0], "id": case["object"].split(":", 1)[1]}, "relation": case["relation"], "user_filters": [{"type": "user"}]})
            result = {
                "check": check if isinstance(check, str) else check.get("allowed", False),
                "list_objects": objects if isinstance(objects, str) else sorted(objects.get("objects", [])),
                "list_users": users if isinstance(users, str) else sorted(
                    u["object"]["type"] + ":" + u["object"]["id"] if "object" in u else u["wildcard"]["type"] + ":*" for u in users.get("users", [])),
            }
            expected.append(result)
            for kind in result:
                left = actual[i][kind]
                if isinstance(left, list):
                    left = sorted(left)
                if left != result[kind]:
                    mismatches.append({"case": i, "name": case.get("name"), "family": case.get("family"), "kind": kind, "local": left, "openfga": result[kind]})
            if (i + 1) % 50 == 0:
                print(f"directed: {i+1}/{len(cases)}", flush=True)
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
summary = {"fixed_r1_cases": len(fixed), "new_cases": len(custom), "cases": len(cases), "comparisons": len(cases) * 3, "mismatches": len(mismatches)}
for name, value in [("summary", summary), ("mismatches", mismatches), ("expected", expected), ("actual", actual)]:
    (OUT / f"{name}.json").write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(summary, indent=2))
if mismatches:
    print(json.dumps(mismatches, ensure_ascii=False, indent=2))
raise SystemExit(bool(mismatches))
