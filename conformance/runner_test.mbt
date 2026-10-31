///|
test "conformance runner replays cumulative stages" {
  let source =
    #|tests:
    #|  - name: basics
    #|    stages:
    #|      - model: |
    #|          model
    #|            schema 1.1
    #|          type user
    #|          type document
    #|            relations
    #|              define viewer: [user, user:*]
    #|        tuples:
    #|          - {object: document:1, relation: viewer, user: user:anne}
    #|          - {object: document:2, relation: viewer, user: "user:*"}
    #|        checkAssertions:
    #|          - tuple: {object: document:1, relation: viewer, user: user:anne}
    #|            expectation: true
    #|          - tuple: {object: document:1, relation: viewer, user: user:bob}
    #|            expectation: false
    #|          - tuple: {object: unknown:9, relation: viewer, user: user:anne}
    #|            errorCode: 2000
    #|        listObjectsAssertions:
    #|          - request: {user: user:anne, type: document, relation: viewer}
    #|            expectation: [document:1, document:2]
    #|          - request: {user: user:bob, type: document, relation: viewer}
    #|            expectation: [document:2]
    #|        listUsersAssertions:
    #|          - request: {object: document:1, relation: viewer, filters: [user]}
    #|            expectation: [user:anne]
    #|          - request: {object: document:2, relation: viewer, filters: [user]}
    #|            expectation: ["user:*"]
    #|      - model: |
    #|          model
    #|            schema 1.1
    #|          type user
    #|          type document
    #|            relations
    #|              define viewer: [user, user:*]
    #|        checkAssertions:
    #|          - tuple: {object: document:2, relation: viewer, user: user:bob}
    #|            expectation: true
  let report = @conformance.run_conformance_source(source, "inline")
  inspect(report.test_count, content="1")
  inspect(report.check.total, content="4")
  inspect(report.check.passed, content="4")
  inspect(report.list_objects.total, content="2")
  inspect(report.list_objects.failed, content="0")
  inspect(report.list_users.total, content="2")
  inspect(report.list_users.passed, content="2")
  inspect(report.list_users.failed, content="0")
}

///|
test "conformance runner treats null list expectations as empty" {
  let source =
    #|tests:
    #|  - name: empty
    #|    stages:
    #|      - model: |
    #|          model
    #|            schema 1.1
    #|          type user
    #|          type document
    #|            relations
    #|              define viewer: [user]
    #|        listObjectsAssertions:
    #|          - request: {user: user:anne, type: document, relation: viewer}
    #|            expectation:
    #|        listUsersAssertions:
    #|          - request: {object: document:1, relation: viewer, filters: [user]}
    #|            expectation:
  let report = @conformance.run_conformance_source(source, "empty")
  inspect(report.list_objects.failed, content="0")
  inspect(report.list_objects.passed, content="1")
  inspect(report.list_users.failed, content="0")
  inspect(report.list_users.passed, content="1")
}
