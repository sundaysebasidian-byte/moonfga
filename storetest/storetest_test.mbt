///|
fn demo_suite() -> String {
  (
    #|name: demo
    #|model: |
    #|  model
    #|    schema 1.1
    #|
    #|  type user
    #|
    #|  type group
    #|    relations
    #|      define member: [user]
    #|
    #|  type document
    #|    relations
    #|      define viewer: [user, user:*, group#member]
    #|      define editor: [user]
    #|      define can_view: viewer or editor
    #|      define guarded: [user with in_ip]
    #|
    #|  condition in_ip(ip: string) {
    #|    ip == "10.0.0.1"
    #|  }
    #|tuples:
    #|  - object: document:1
    #|    relation: viewer
    #|    user: user:anne
    #|  - object: document:2
    #|    relation: viewer
    #|    user: group:eng#member
    #|  - object: group:eng
    #|    relation: member
    #|    user: user:bob
    #|  - object: document:4
    #|    relation: viewer
    #|    user: "user:*"
    #|  - object: document:5
    #|    relation: guarded
    #|    user: user:dan
    #|    condition:
    #|      name: in_ip
    #|      context: {ip: "10.0.0.1"}
    #|tests:
    #|  - name: basics
    #|    tuples:
    #|      - object: document:3
    #|        relation: editor
    #|        user: user:carl
    #|    check:
    #|      - user: user:bob
    #|        object: document:2
    #|        assertions:
    #|          viewer: true
    #|      - user: user:carl
    #|        object: document:3
    #|        assertions:
    #|          can_view: true
    #|      - user: user:nobody
    #|        object: document:1
    #|        assertions:
    #|          viewer: false
    #|      - user: user:anyone
    #|        object: document:4
    #|        assertions:
    #|          viewer: true
    #|      - user: user:anne
    #|        object: unknown:1
    #|        assertions:
    #|          viewer:
    #|            errorCode: 2000
    #|      - user: user:dan
    #|        object: document:5
    #|        context: {ip: "10.0.0.1"}
    #|        assertions:
    #|          guarded: true
    #|      - user: user:dan
    #|        object: document:5
    #|        context: {ip: "192.168.0.1"}
    #|        assertions:
    #|          guarded: false
    #|    listObjects:
    #|      - user: user:bob
    #|        type: document
    #|        assertions:
    #|          viewer: [document:2, document:4]
    #|      - user: user:anyone
    #|        type: document
    #|        assertions:
    #|          viewer: [document:4]
    #|      - user: user:carl
    #|        type: document
    #|        assertions:
    #|          can_view: [document:3, document:4]
    #|    listUsers:
    #|      - object: document:2
    #|        filters: [user]
    #|        assertions:
    #|          viewer: [user:bob]
    #|      - object: document:4
    #|        filters: [user]
    #|        assertions:
    #|          viewer: ["user:*"]
  )
}

///|
test "run a store test suite" {
  let suite = @storetest.load_store_test(demo_suite(), "") catch {
    @fga.FgaError(..) as err => abort(@fga.error_message(err))
  }
  inspect(suite.tests.length(), content="1")
  let report = @storetest.run_store_test(suite)
  inspect(report.tests_total, content="1")
  inspect(report.tests_passed, content="1")
  inspect(report.assertions_failed, content="0")
  inspect(report.assertions_total, content="12")
  inspect(
    @storetest.format_store_test_report(report).contains("1/1 passed"),
    content="true",
  )
}

///|
test "store test reports failing assertions" {
  let source =
    #|model: |
    #|  model
    #|    schema 1.1
    #|  type user
    #|  type document
    #|    relations
    #|      define viewer: [user]
    #|tuples:
    #|  - object: document:1
    #|    relation: viewer
    #|    user: user:anne
    #|tests:
    #|  - name: broken
    #|    check:
    #|      - user: user:anne
    #|        object: document:1
    #|        assertions:
    #|          viewer: false
  let suite = @storetest.load_store_test(source, "") catch {
    @fga.FgaError(..) as err => abort(@fga.error_message(err))
  }
  let report = @storetest.run_store_test(suite)
  inspect(report.tests_failed, content="1")
  inspect(report.assertions_failed, content="1")
  inspect(report.failures[0].section, content="check")
  inspect(report.failures[0].expected, content="false")
  inspect(report.failures[0].actual, content="true")
}

///|
test "store test needs a model" {
  let rejected = try {
    let _ = @storetest.load_store_test("tests: []\n", "") catch {
      @fga.FgaError(..) as err => raise err
    }
    false
  } catch {
    @fga.FgaError(..) => true
  }
  inspect(rejected, content="true")
}
