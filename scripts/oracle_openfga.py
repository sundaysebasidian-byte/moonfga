"""Seeded black-box differential oracle; Python standard library only."""
from oracle_cases import boundary_case
import argparse
import hashlib
import json
from pathlib import Path
import platform
import random
import socket
import subprocess
import tarfile
import tempfile
import time
import urllib.error
import urllib.request

VERSION = "1.22.1"
COMMIT = "44054f542f64e9b9589dd26a595081b3d2cfd942"
HASHES = {
    ("Darwin", "arm64"): ("darwin_arm64", "4d64ccd3ead676e3b13154bb32372421f3cd4735eda0211f5d0b7d244c689b90"),
    ("Linux", "x86_64"): ("linux_amd64", "80d2d4b582762c02dc86b1246f7f6f54d6854259727b36e5b5c43ba90792814a"),
}


def binary():
    host = (platform.system(), platform.machine())
    if host not in HASHES:
        raise RuntimeError(f"Unsupported oracle host: {host}; use macOS arm64 or Linux amd64")
    target, expected = HASHES[host]
    cache = Path(".upstream/oracle")
    cache.mkdir(parents=True, exist_ok=True)
    archive = cache / f"openfga_{VERSION}_{target}.tar.gz"
    if not archive.exists():
        urllib.request.urlretrieve(
            f"https://github.com/openfga/openfga/releases/download/v{VERSION}/{archive.name}", archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != expected:
        raise RuntimeError("OpenFGA archive checksum mismatch")
    executable = cache / f"openfga-{VERSION}-{target}"
    with tarfile.open(archive) as tar:
        member = tar.extractfile("openfga")
        data = member.read()
    if not executable.exists() or executable.read_bytes() != data:
        # Never truncate an executable another oracle process may be running.
        with tempfile.NamedTemporaryFile(dir=cache, delete=False) as staging:
            staging.write(data)
            staged = Path(staging.name)
        try:
            staged.chmod(0o755)
            staged.replace(executable)
        finally:
            staged.unlink(missing_ok=True)
    executable.chmod(0o755)
    return str(executable.resolve())


def port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


HTTP_ERRORS = []


def request(base, path, data=None):
    payload = None if data is None else json.dumps(data).encode()
    req = urllib.request.Request(base + path, payload, {"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            return json.load(response)
    except urllib.error.HTTPError as e:
        body = json.load(e)
        HTTP_ERRORS.append({"path": path, "status": e.code, "body": body})
        # Error categories used by this generator (conditions / invalid input).
        if body.get("code") == "validation_error":
            return "E2000"
        if body.get("code") == "authorization_model_resolution_too_complex":
            return "E2002"
        raise RuntimeError((path, e.code, body)) from e


def generate(rng, i):
    direct = {"this": {}}
    computed = lambda r: {"computedUserset": {"relation": r}}
    facets = [{"type": "user"}, {"type": "user", "wildcard": {}}, {"type": "group", "relation": "member"}]
    alternatives = [
        computed("reader"),
        {"union": {"child": [computed("reader"), computed("writer")]}},
        {"intersection": {"child": [computed("reader"), computed("writer")]}},
        {"difference": {"base": computed("reader"), "subtract": computed("blocked")}},
        {"tupleToUserset": {"tupleset": {"relation": "parent"}, "computedUserset": {"relation": "viewer"}}},
    ]
    rewrite = rng.choice(alternatives[:4])
    if i % 5 == 4:
        rewrite = {"union": {"child": [rewrite, alternatives[4]]}}
    model = {"schema_version": "1.1", "type_definitions": [
        {"type": "user"},
        {"type": "group", "relations": {"member": direct}, "metadata": {"relations": {"member": {"directly_related_user_types": [{"type": "user"}, {"type": "group", "relation": "member"}]}}}},
        {"type": "document", "relations": {"reader": direct, "writer": direct, "blocked": direct, "parent": direct, "viewer": rewrite},
         "metadata": {"relations": {**{r: {"directly_related_user_types": facets} for r in ["reader", "writer", "blocked"]}, "parent": {"directly_related_user_types": [{"type": "document"}]}}}}
    ]}
    tuples = []
    def add(o, r, u):
        t = {"object": o, "relation": r, "user": u}
        if t not in tuples:
            tuples.append(t)
    for g in range(3):
        for u in range(4):
            if rng.random() < .35:
                add(f"group:{g}", "member", f"user:{u}")
        if g > 0 and rng.random() < .5:
            add(f"group:{g}", "member", f"group:{g-1}#member")
    for d in range(4):
        for r in ["reader", "writer", "blocked"]:
            for u in ["user:0", "user:1", "user:2", "user:3", "user:*", "group:2#member"]:
                if rng.random() < .18:
                    add(f"document:{d}", r, u)
        if d and rng.random() < .5:
            add(f"document:{d}", "parent", f"document:{d-1}")
    return {"model": model, "tuples": tuples, "object": f"document:{rng.randrange(4)}",
            "relation": "viewer", "user": f"user:{rng.randrange(5)}"}


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--cases", type=int, default=1000)
    p.add_argument("--seed", type=int, default=314159)
    p.add_argument("--output", type=Path, default=Path("conformance-results/oracle"))
    p.add_argument("--corpus", type=Path, help="Replay explicit authorization cases instead of generated cases")
    args = p.parse_args()
    if args.cases < 1:
        p.error("--cases must be positive")
    out = args.output
    out.mkdir(parents=True, exist_ok=True)
    rng = random.Random(args.seed)
    fixed = []
    if args.corpus:
        cases = json.loads(args.corpus.read_text())
        if not cases:
            p.error("corpus must not be empty")
    else:
        cases = [generate(rng, i) if i % 5 == 0 else boundary_case(rng, i) for i in range(args.cases)]
        for i in range(2):
            c = generate(random.Random(args.seed + i), 0)
            c["model"]["conditions"] = {"enabled": {"name": "enabled", "expression": "ok", "parameters": {"ok": {"type_name": "TYPE_NAME_BOOL"}}}}
            doc = c["model"]["type_definitions"][2]
            doc["relations"]["viewer"] = {"this": {}}
            doc["metadata"]["relations"]["viewer"] = {"directly_related_user_types": [{"type": "user", "condition": "enabled"}]}
            c.update(object="document:0", relation="viewer", user="user:0")
            c["tuples"] = [{"object": c["object"], "relation": "viewer", "user": c["user"], "condition": {"name": "enabled", "context": {"ok": True}}}]
            c["contextual"] = [{"object": c["object"], "relation": "viewer", "user": c["user"], "condition": {"name": "enabled", "context": {"ok": False} if i == 0 else {}}}]
            cases.append(c)
        fixed = json.loads(Path("examples/regressions/oracle.json").read_text())
        fixed += json.loads(Path("examples/regressions/check-depth.json").read_text())
        cases.extend(fixed)
    (out / "cases.json").write_text(json.dumps(cases))
    local = subprocess.run(["moon", "run", "--target", "native", "cmd/oracle", "--", str(out / "cases.json")], check=False, text=True, capture_output=True)
    if local.returncode:
        raise RuntimeError(f"MoonFGA oracle failed: {local.stderr}")
    actual = json.loads(local.stdout)
    if len(actual) != len(cases):
        raise RuntimeError("local oracle returned wrong result count")
    ports = [port() for _ in range(3)]
    base = f"http://127.0.0.1:{ports[0]}"
    with (out / "server.log").open("w") as log:
        proc = subprocess.Popen([binary(), "run", "--datastore-engine", "memory", "--http-addr", f"127.0.0.1:{ports[0]}", "--grpc-addr", f"127.0.0.1:{ports[1]}", "--metrics-addr", f"127.0.0.1:{ports[2]}", "--playground-enabled=false", "--profiler-enabled=false", "--log-level", "error"], stdout=log, stderr=log)
        mismatches = []
        expected = []
        try:
            for _ in range(100):
                if proc.poll() is not None:
                    raise RuntimeError("OpenFGA exited; see server.log")
                try:
                    request(base, "/healthz")
                    break
                except urllib.error.URLError:
                    time.sleep(.1)
            else:
                raise RuntimeError("OpenFGA readiness timeout")
            for i, c in enumerate(cases):
                store = request(base, "/stores", {"name": f"oracle-{i}"})["id"]
                path = f"/stores/{store}"
                mid = request(base, path + "/authorization-models", c["model"])["authorization_model_id"]
                if c["tuples"]:
                    written = request(base, path + "/write", {"authorization_model_id": mid, "writes": {"tuple_keys": c["tuples"]}})
                    if not isinstance(written, dict):
                        raise RuntimeError(f"case {i}: oracle setup write rejected: {HTTP_ERRORS[-1]}")
                common = {"authorization_model_id": mid, "context": c.get("context", {}), "contextual_tuples": {"tuple_keys": c.get("contextual", [])}}
                check = request(base, path + "/check", {**common, "tuple_key": {k: c[k] for k in ["object", "relation", "user"]}})
                objects = request(base, path + "/list-objects", {**common, "type": c["object"].split(":", 1)[0], "relation": c["relation"], "user": c["user"]})
                users = request(base, path + "/list-users", {**common, "contextual_tuples": c.get("contextual", []), "object": {"type": c["object"].split(":", 1)[0], "id": c["object"].split(":", 1)[1]}, "relation": c["relation"], "user_filters": [{"type": "user"}]})
                result = {"check": check if isinstance(check, str) else check.get("allowed", False),
                          "list_objects": objects if isinstance(objects, str) else sorted(objects.get("objects", [])),
                          "list_users": users if isinstance(users, str) else sorted(
                              u["object"]["type"] + ":" + u["object"]["id"] if "object" in u else u["wildcard"]["type"] + ":*" for u in users.get("users", []))}
                expected.append(result)
                for kind in result:
                    value = actual[i][kind]
                    if isinstance(value, list):
                        value = sorted(value)
                    if value != result[kind]:
                        mismatches.append({"case": i, "kind": kind, "local": value, "openfga": result[kind]})
                # Each case has its own store: no state or model-cache leakage.
                if (i + 1) % 100 == 0:
                    print(f"oracle: {i+1}/{len(cases)}", flush=True)
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
    summary = {"version": VERSION, "commit": COMMIT, "seed": args.seed, "cases": len(cases), "random_cases": args.cases, "regression_cases": 2 + len(fixed), "comparisons": len(cases)*3, "mismatches": len(mismatches),
               "families": {k: sum(c.get("family", "graph") == k for c in cases[:args.cases]) for k in ["graph", "logical_errors", "unicode", "timestamp", "deep_graph"]},
               "by_api": {k: {"compared": len(cases), "mismatches": sum(m["kind"] == k for m in mismatches)} for k in ["check", "list_objects", "list_users"]}}
    if args.corpus:
        summary.update(corpus=str(args.corpus), random_cases=0, regression_cases=len(cases), families={"cel": len(cases)})
    for name, value in [("summary", summary), ("mismatches", mismatches), ("expected", expected), ("actual", actual), ("http-errors", HTTP_ERRORS)]:
        (out / f"{name}.json").write_text(json.dumps(value, indent=2) + "\n")
    print(json.dumps(summary, indent=2))
    return bool(mismatches)


if __name__ == "__main__":
    raise SystemExit(main())
