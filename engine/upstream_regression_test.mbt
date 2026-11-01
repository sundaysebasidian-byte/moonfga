// Independent review counterexamples, with expected responses captured from
// the official v1.22.1 release. Fixtures are embedded for all three backends.

///|
fn assert_review_case(input : String, expected : String) -> Unit raise {
  let c = @json.parse(input)
  let model = @model.model_from_json(@fga.json_object_get(c, "model").unwrap())
  let store = @store.MemoryStore::new()
  let _ = store.write_all(
    @fga.tuples_from_json(@fga.json_object_get(c, "tuples")),
  )
  let engine = @engine.Engine::new(model, store as &@fga.TupleReader)
  let object = @fga.json_get_string(c, "object").unwrap()
  let relation = @fga.json_get_string(c, "relation").unwrap()
  let user = @fga.json_get_string(c, "user").unwrap()
  let context = match @fga.json_object_get(c, "context") {
    Some(Object(m)) => m
    _ => Map([])
  }
  let contextual = @fga.tuples_from_json(@fga.json_object_get(c, "contextual"))
  let result : Map[String, Json] = Map([])
  result["check"] = Json::boolean(
    engine.check_with(object, relation, user, context, contextual),
  ) catch {
    e => Json::string("E" + @fga.error_code(e).to_string())
  }
  result["list_objects"] = Json::array(
    engine
    .list_objects(@fga.object_type(object), relation, user, context, contextual)
    .map(Json::string),
  ) catch {
    e => Json::string("E" + @fga.error_code(e).to_string())
  }
  result["list_users"] = Json::array(
    engine
    .list_users(object, relation, ["user"], context, contextual)
    .map(Json::string),
  ) catch {
    e => Json::string("E" + @fga.error_code(e).to_string())
  }
  assert_true(@model.json_eq(Json::object(result), @json.parse(expected)))
}

///|
test "official review cel_string_size_unicode" {
  assert_review_case(
    "{\"name\": \"cel_string_size_unicode\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"test_condition\"}]}}}}], \"conditions\": {\"test_condition\": {\"name\": \"test_condition\", \"expression\": \"size(s) == 1\", \"parameters\": {\"s\": {\"type_name\": \"TYPE_NAME_STRING\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"test_condition\", \"context\": {\"s\": \"😀\"}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review cel_timestamp_get_seconds" {
  assert_review_case(
    "{\"name\": \"cel_timestamp_get_seconds\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"test_condition\"}]}}}}], \"conditions\": {\"test_condition\": {\"name\": \"test_condition\", \"expression\": \"t.getSeconds() == 1767225600\", \"parameters\": {\"t\": {\"type_name\": \"TYPE_NAME_TIMESTAMP\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"test_condition\", \"context\": {\"t\": \"2026-01-01T00:00:00Z\"}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": false, \"list_objects\": [], \"list_users\": []}",
  )
}

///|
test "official review cel_timestamp_string" {
  assert_review_case(
    "{\"name\": \"cel_timestamp_string\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"test_condition\"}]}}}}], \"conditions\": {\"test_condition\": {\"name\": \"test_condition\", \"expression\": \"string(t) == '2026-01-01T00:00:00Z'\", \"parameters\": {\"t\": {\"type_name\": \"TYPE_NAME_TIMESTAMP\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"test_condition\", \"context\": {\"t\": \"2026-01-01T00:00:00Z\"}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review cel_duration_get_milliseconds" {
  assert_review_case(
    "{\"name\": \"cel_duration_get_milliseconds\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"test_condition\"}]}}}}], \"conditions\": {\"test_condition\": {\"name\": \"test_condition\", \"expression\": \"d.getMilliseconds() == 234\", \"parameters\": {\"d\": {\"type_name\": \"TYPE_NAME_DURATION\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"test_condition\", \"context\": {\"d\": \"1.234s\"}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": false, \"list_objects\": [], \"list_users\": []}",
  )
}

///|
test "official review cel_error_left_and_false" {
  assert_review_case(
    "{\"name\": \"cel_error_left_and_false\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"test_condition\"}]}}}}], \"conditions\": {\"test_condition\": {\"name\": \"test_condition\", \"expression\": \"1 / x > 0 && false\", \"parameters\": {\"x\": {\"type_name\": \"TYPE_NAME_INT\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"test_condition\", \"context\": {\"x\": 0}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": false, \"list_objects\": [], \"list_users\": []}",
  )
}

///|
test "official review cel_false_and_error" {
  assert_review_case(
    "{\"name\": \"cel_false_and_error\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"test_condition\"}]}}}}], \"conditions\": {\"test_condition\": {\"name\": \"test_condition\", \"expression\": \"false && 1 / x > 0\", \"parameters\": {\"x\": {\"type_name\": \"TYPE_NAME_INT\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"test_condition\", \"context\": {\"x\": 0}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": false, \"list_objects\": [], \"list_users\": []}",
  )
}

///|
test "official review cel_error_left_or_true" {
  assert_review_case(
    "{\"name\": \"cel_error_left_or_true\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"test_condition\"}]}}}}], \"conditions\": {\"test_condition\": {\"name\": \"test_condition\", \"expression\": \"1 / x > 0 || true\", \"parameters\": {\"x\": {\"type_name\": \"TYPE_NAME_INT\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"test_condition\", \"context\": {\"x\": 0}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review cel_true_or_error" {
  assert_review_case(
    "{\"name\": \"cel_true_or_error\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"test_condition\"}]}}}}], \"conditions\": {\"test_condition\": {\"name\": \"test_condition\", \"expression\": \"true || 1 / x > 0\", \"parameters\": {\"x\": {\"type_name\": \"TYPE_NAME_INT\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"test_condition\", \"context\": {\"x\": 0}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review union_condition_error_plus_unconditional_true" {
  assert_review_case(
    "{\"name\": \"union_condition_error_plus_unconditional_true\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"conditional\": {\"this\": {}}, \"owner\": {\"this\": {}}, \"viewer\": {\"union\": {\"child\": [{\"computedUserset\": {\"relation\": \"conditional\"}}, {\"computedUserset\": {\"relation\": \"owner\"}}]}}}, \"metadata\": {\"relations\": {\"conditional\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}, \"owner\": {\"directly_related_user_types\": [{\"type\": \"user\"}]}, \"viewer\": {\"directly_related_user_types\": []}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"ok\", \"parameters\": {\"ok\": {\"type_name\": \"TYPE_NAME_BOOL\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"conditional\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {}}}, {\"object\": \"document:0\", \"relation\": \"owner\", \"user\": \"user:0\"}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": true, \"list_objects\": \"E2000\", \"list_users\": \"E2000\"}",
  )
}

///|
test "official review intersection_condition_error_plus_unconditional_false" {
  assert_review_case(
    "{\"name\": \"intersection_condition_error_plus_unconditional_false\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"conditional\": {\"this\": {}}, \"owner\": {\"this\": {}}, \"viewer\": {\"intersection\": {\"child\": [{\"computedUserset\": {\"relation\": \"owner\"}}, {\"computedUserset\": {\"relation\": \"conditional\"}}]}}}, \"metadata\": {\"relations\": {\"conditional\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}, \"owner\": {\"directly_related_user_types\": [{\"type\": \"user\"}]}, \"viewer\": {\"directly_related_user_types\": []}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"ok\", \"parameters\": {\"ok\": {\"type_name\": \"TYPE_NAME_BOOL\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"conditional\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": false, \"list_objects\": \"E2000\", \"list_users\": \"E2000\"}",
  )
}

///|
test "official review difference_condition_error_in_subtract" {
  assert_review_case(
    "{\"name\": \"difference_condition_error_in_subtract\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"conditional\": {\"this\": {}}, \"owner\": {\"this\": {}}, \"viewer\": {\"difference\": {\"base\": {\"computedUserset\": {\"relation\": \"owner\"}}, \"subtract\": {\"computedUserset\": {\"relation\": \"conditional\"}}}}}, \"metadata\": {\"relations\": {\"conditional\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}, \"owner\": {\"directly_related_user_types\": [{\"type\": \"user\"}]}, \"viewer\": {\"directly_related_user_types\": []}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"ok\", \"parameters\": {\"ok\": {\"type_name\": \"TYPE_NAME_BOOL\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"conditional\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {}}}, {\"object\": \"document:0\", \"relation\": \"owner\", \"user\": \"user:0\"}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": \"E2000\", \"list_objects\": \"E2000\", \"list_users\": \"E2000\"}",
  )
}

///|
test "official review recursive_depth_0" {
  assert_review_case(
    "{\"name\": \"recursive_depth_0\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"group\", \"relations\": {\"member\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"member\": {\"directly_related_user_types\": [{\"type\": \"user\"}, {\"type\": \"group\", \"relation\": \"member\"}]}}}}]}, \"tuples\": [{\"object\": \"group:0\", \"relation\": \"member\", \"user\": \"user:0\"}, {\"object\": \"group:1\", \"relation\": \"member\", \"user\": \"group:0#member\"}, {\"object\": \"group:2\", \"relation\": \"member\", \"user\": \"group:1#member\"}, {\"object\": \"group:3\", \"relation\": \"member\", \"user\": \"group:2#member\"}, {\"object\": \"group:4\", \"relation\": \"member\", \"user\": \"group:3#member\"}, {\"object\": \"group:5\", \"relation\": \"member\", \"user\": \"group:4#member\"}, {\"object\": \"group:6\", \"relation\": \"member\", \"user\": \"group:5#member\"}, {\"object\": \"group:7\", \"relation\": \"member\", \"user\": \"group:6#member\"}, {\"object\": \"group:8\", \"relation\": \"member\", \"user\": \"group:7#member\"}, {\"object\": \"group:9\", \"relation\": \"member\", \"user\": \"group:8#member\"}, {\"object\": \"group:10\", \"relation\": \"member\", \"user\": \"group:9#member\"}, {\"object\": \"group:11\", \"relation\": \"member\", \"user\": \"group:10#member\"}, {\"object\": \"group:12\", \"relation\": \"member\", \"user\": \"group:11#member\"}, {\"object\": \"group:13\", \"relation\": \"member\", \"user\": \"group:12#member\"}, {\"object\": \"group:14\", \"relation\": \"member\", \"user\": \"group:13#member\"}, {\"object\": \"group:15\", \"relation\": \"member\", \"user\": \"group:14#member\"}, {\"object\": \"group:16\", \"relation\": \"member\", \"user\": \"group:15#member\"}, {\"object\": \"group:17\", \"relation\": \"member\", \"user\": \"group:16#member\"}, {\"object\": \"group:18\", \"relation\": \"member\", \"user\": \"group:17#member\"}, {\"object\": \"group:19\", \"relation\": \"member\", \"user\": \"group:18#member\"}, {\"object\": \"group:20\", \"relation\": \"member\", \"user\": \"group:19#member\"}, {\"object\": \"group:21\", \"relation\": \"member\", \"user\": \"group:20#member\"}, {\"object\": \"group:22\", \"relation\": \"member\", \"user\": \"group:21#member\"}, {\"object\": \"group:23\", \"relation\": \"member\", \"user\": \"group:22#member\"}, {\"object\": \"group:24\", \"relation\": \"member\", \"user\": \"group:23#member\"}, {\"object\": \"group:25\", \"relation\": \"member\", \"user\": \"group:24#member\"}, {\"object\": \"group:26\", \"relation\": \"member\", \"user\": \"group:25#member\"}], \"object\": \"group:0\", \"relation\": \"member\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": true, \"list_objects\": [\"group:0\", \"group:1\", \"group:10\", \"group:11\", \"group:12\", \"group:13\", \"group:14\", \"group:15\", \"group:16\", \"group:17\", \"group:18\", \"group:19\", \"group:2\", \"group:20\", \"group:21\", \"group:22\", \"group:23\", \"group:24\", \"group:25\", \"group:26\", \"group:3\", \"group:4\", \"group:5\", \"group:6\", \"group:7\", \"group:8\", \"group:9\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review recursive_depth_25" {
  assert_review_case(
    "{\"name\": \"recursive_depth_25\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"group\", \"relations\": {\"member\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"member\": {\"directly_related_user_types\": [{\"type\": \"user\"}, {\"type\": \"group\", \"relation\": \"member\"}]}}}}]}, \"tuples\": [{\"object\": \"group:0\", \"relation\": \"member\", \"user\": \"user:0\"}, {\"object\": \"group:1\", \"relation\": \"member\", \"user\": \"group:0#member\"}, {\"object\": \"group:2\", \"relation\": \"member\", \"user\": \"group:1#member\"}, {\"object\": \"group:3\", \"relation\": \"member\", \"user\": \"group:2#member\"}, {\"object\": \"group:4\", \"relation\": \"member\", \"user\": \"group:3#member\"}, {\"object\": \"group:5\", \"relation\": \"member\", \"user\": \"group:4#member\"}, {\"object\": \"group:6\", \"relation\": \"member\", \"user\": \"group:5#member\"}, {\"object\": \"group:7\", \"relation\": \"member\", \"user\": \"group:6#member\"}, {\"object\": \"group:8\", \"relation\": \"member\", \"user\": \"group:7#member\"}, {\"object\": \"group:9\", \"relation\": \"member\", \"user\": \"group:8#member\"}, {\"object\": \"group:10\", \"relation\": \"member\", \"user\": \"group:9#member\"}, {\"object\": \"group:11\", \"relation\": \"member\", \"user\": \"group:10#member\"}, {\"object\": \"group:12\", \"relation\": \"member\", \"user\": \"group:11#member\"}, {\"object\": \"group:13\", \"relation\": \"member\", \"user\": \"group:12#member\"}, {\"object\": \"group:14\", \"relation\": \"member\", \"user\": \"group:13#member\"}, {\"object\": \"group:15\", \"relation\": \"member\", \"user\": \"group:14#member\"}, {\"object\": \"group:16\", \"relation\": \"member\", \"user\": \"group:15#member\"}, {\"object\": \"group:17\", \"relation\": \"member\", \"user\": \"group:16#member\"}, {\"object\": \"group:18\", \"relation\": \"member\", \"user\": \"group:17#member\"}, {\"object\": \"group:19\", \"relation\": \"member\", \"user\": \"group:18#member\"}, {\"object\": \"group:20\", \"relation\": \"member\", \"user\": \"group:19#member\"}, {\"object\": \"group:21\", \"relation\": \"member\", \"user\": \"group:20#member\"}, {\"object\": \"group:22\", \"relation\": \"member\", \"user\": \"group:21#member\"}, {\"object\": \"group:23\", \"relation\": \"member\", \"user\": \"group:22#member\"}, {\"object\": \"group:24\", \"relation\": \"member\", \"user\": \"group:23#member\"}, {\"object\": \"group:25\", \"relation\": \"member\", \"user\": \"group:24#member\"}, {\"object\": \"group:26\", \"relation\": \"member\", \"user\": \"group:25#member\"}], \"object\": \"group:25\", \"relation\": \"member\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": true, \"list_objects\": [\"group:0\", \"group:1\", \"group:10\", \"group:11\", \"group:12\", \"group:13\", \"group:14\", \"group:15\", \"group:16\", \"group:17\", \"group:18\", \"group:19\", \"group:2\", \"group:20\", \"group:21\", \"group:22\", \"group:23\", \"group:24\", \"group:25\", \"group:26\", \"group:3\", \"group:4\", \"group:5\", \"group:6\", \"group:7\", \"group:8\", \"group:9\"], \"list_users\": \"E2002\"}",
  )
}

///|
test "official review recursive_depth_26" {
  assert_review_case(
    "{\"name\": \"recursive_depth_26\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"group\", \"relations\": {\"member\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"member\": {\"directly_related_user_types\": [{\"type\": \"user\"}, {\"type\": \"group\", \"relation\": \"member\"}]}}}}]}, \"tuples\": [{\"object\": \"group:0\", \"relation\": \"member\", \"user\": \"user:0\"}, {\"object\": \"group:1\", \"relation\": \"member\", \"user\": \"group:0#member\"}, {\"object\": \"group:2\", \"relation\": \"member\", \"user\": \"group:1#member\"}, {\"object\": \"group:3\", \"relation\": \"member\", \"user\": \"group:2#member\"}, {\"object\": \"group:4\", \"relation\": \"member\", \"user\": \"group:3#member\"}, {\"object\": \"group:5\", \"relation\": \"member\", \"user\": \"group:4#member\"}, {\"object\": \"group:6\", \"relation\": \"member\", \"user\": \"group:5#member\"}, {\"object\": \"group:7\", \"relation\": \"member\", \"user\": \"group:6#member\"}, {\"object\": \"group:8\", \"relation\": \"member\", \"user\": \"group:7#member\"}, {\"object\": \"group:9\", \"relation\": \"member\", \"user\": \"group:8#member\"}, {\"object\": \"group:10\", \"relation\": \"member\", \"user\": \"group:9#member\"}, {\"object\": \"group:11\", \"relation\": \"member\", \"user\": \"group:10#member\"}, {\"object\": \"group:12\", \"relation\": \"member\", \"user\": \"group:11#member\"}, {\"object\": \"group:13\", \"relation\": \"member\", \"user\": \"group:12#member\"}, {\"object\": \"group:14\", \"relation\": \"member\", \"user\": \"group:13#member\"}, {\"object\": \"group:15\", \"relation\": \"member\", \"user\": \"group:14#member\"}, {\"object\": \"group:16\", \"relation\": \"member\", \"user\": \"group:15#member\"}, {\"object\": \"group:17\", \"relation\": \"member\", \"user\": \"group:16#member\"}, {\"object\": \"group:18\", \"relation\": \"member\", \"user\": \"group:17#member\"}, {\"object\": \"group:19\", \"relation\": \"member\", \"user\": \"group:18#member\"}, {\"object\": \"group:20\", \"relation\": \"member\", \"user\": \"group:19#member\"}, {\"object\": \"group:21\", \"relation\": \"member\", \"user\": \"group:20#member\"}, {\"object\": \"group:22\", \"relation\": \"member\", \"user\": \"group:21#member\"}, {\"object\": \"group:23\", \"relation\": \"member\", \"user\": \"group:22#member\"}, {\"object\": \"group:24\", \"relation\": \"member\", \"user\": \"group:23#member\"}, {\"object\": \"group:25\", \"relation\": \"member\", \"user\": \"group:24#member\"}, {\"object\": \"group:26\", \"relation\": \"member\", \"user\": \"group:25#member\"}], \"object\": \"group:26\", \"relation\": \"member\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": \"E2002\", \"list_objects\": [\"group:0\", \"group:1\", \"group:10\", \"group:11\", \"group:12\", \"group:13\", \"group:14\", \"group:15\", \"group:16\", \"group:17\", \"group:18\", \"group:19\", \"group:2\", \"group:20\", \"group:21\", \"group:22\", \"group:23\", \"group:24\", \"group:25\", \"group:26\", \"group:3\", \"group:4\", \"group:5\", \"group:6\", \"group:7\", \"group:8\", \"group:9\"], \"list_users\": \"E2002\"}",
  )
}

///|
test "official review recursive_cycle_terminates" {
  assert_review_case(
    "{\"name\": \"recursive_cycle_terminates\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"group\", \"relations\": {\"member\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"member\": {\"directly_related_user_types\": [{\"type\": \"user\"}, {\"type\": \"group\", \"relation\": \"member\"}]}}}}]}, \"tuples\": [{\"object\": \"group:0\", \"relation\": \"member\", \"user\": \"group:1#member\"}, {\"object\": \"group:1\", \"relation\": \"member\", \"user\": \"group:0#member\"}], \"object\": \"group:0\", \"relation\": \"member\", \"user\": \"user:0\", \"context\": {}, \"contextual\": [], \"note\": \"Use a valid two-object cycle: OpenFGA rejects a self-defining tuple at write time.\"}",
    "{\"check\": false, \"list_objects\": [], \"list_users\": []}",
  )
}

///|
test "official review wildcard_intersection_and_exclusion" {
  assert_review_case(
    "{\"name\": \"wildcard_intersection_and_exclusion\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"reader\": {\"this\": {}}, \"writer\": {\"this\": {}}, \"blocked\": {\"this\": {}}, \"viewer\": {\"difference\": {\"base\": {\"intersection\": {\"child\": [{\"computedUserset\": {\"relation\": \"reader\"}}, {\"computedUserset\": {\"relation\": \"writer\"}}]}}, \"subtract\": {\"computedUserset\": {\"relation\": \"blocked\"}}}}}, \"metadata\": {\"relations\": {\"reader\": {\"directly_related_user_types\": [{\"type\": \"user\"}, {\"type\": \"user\", \"wildcard\": {}}]}, \"writer\": {\"directly_related_user_types\": [{\"type\": \"user\"}, {\"type\": \"user\", \"wildcard\": {}}]}, \"blocked\": {\"directly_related_user_types\": [{\"type\": \"user\"}, {\"type\": \"user\", \"wildcard\": {}}]}, \"viewer\": {\"directly_related_user_types\": []}}}}]}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"reader\", \"user\": \"user:*\"}, {\"object\": \"document:0\", \"relation\": \"writer\", \"user\": \"user:0\"}, {\"object\": \"document:0\", \"relation\": \"writer\", \"user\": \"user:1\"}, {\"object\": \"document:0\", \"relation\": \"blocked\", \"user\": \"user:1\"}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review logical_&&_true_true" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"true && true\", \"parameters\": {\"x\": {\"type_name\": \"TYPE_NAME_INT\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"x\": 0}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"logical_&&_true_true\"}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review logical_&&_true_false" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"true && false\", \"parameters\": {\"x\": {\"type_name\": \"TYPE_NAME_INT\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"x\": 0}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"logical_&&_true_false\"}",
    "{\"check\": false, \"list_objects\": [], \"list_users\": []}",
  )
}

///|
test "official review logical_&&_true_(1 / x > 0)" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"true && (1 / x > 0)\", \"parameters\": {\"x\": {\"type_name\": \"TYPE_NAME_INT\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"x\": 0}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"logical_&&_true_(1 / x > 0)\"}",
    "{\"check\": \"E2000\", \"list_objects\": \"E2000\", \"list_users\": \"E2000\"}",
  )
}

///|
test "official review logical_&&_false_true" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"false && true\", \"parameters\": {\"x\": {\"type_name\": \"TYPE_NAME_INT\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"x\": 0}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"logical_&&_false_true\"}",
    "{\"check\": false, \"list_objects\": [], \"list_users\": []}",
  )
}

///|
test "official review logical_&&_false_false" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"false && false\", \"parameters\": {\"x\": {\"type_name\": \"TYPE_NAME_INT\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"x\": 0}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"logical_&&_false_false\"}",
    "{\"check\": false, \"list_objects\": [], \"list_users\": []}",
  )
}

///|
test "official review logical_&&_false_(1 / x > 0)" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"false && (1 / x > 0)\", \"parameters\": {\"x\": {\"type_name\": \"TYPE_NAME_INT\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"x\": 0}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"logical_&&_false_(1 / x > 0)\"}",
    "{\"check\": false, \"list_objects\": [], \"list_users\": []}",
  )
}

///|
test "official review logical_&&_(1 / x > 0)_true" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"(1 / x > 0) && true\", \"parameters\": {\"x\": {\"type_name\": \"TYPE_NAME_INT\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"x\": 0}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"logical_&&_(1 / x > 0)_true\"}",
    "{\"check\": \"E2000\", \"list_objects\": \"E2000\", \"list_users\": \"E2000\"}",
  )
}

///|
test "official review logical_&&_(1 / x > 0)_false" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"(1 / x > 0) && false\", \"parameters\": {\"x\": {\"type_name\": \"TYPE_NAME_INT\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"x\": 0}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"logical_&&_(1 / x > 0)_false\"}",
    "{\"check\": false, \"list_objects\": [], \"list_users\": []}",
  )
}

///|
test "official review logical_&&_(1 / x > 0)_(1 / x > 0)" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"(1 / x > 0) && (1 / x > 0)\", \"parameters\": {\"x\": {\"type_name\": \"TYPE_NAME_INT\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"x\": 0}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"logical_&&_(1 / x > 0)_(1 / x > 0)\"}",
    "{\"check\": \"E2000\", \"list_objects\": \"E2000\", \"list_users\": \"E2000\"}",
  )
}

///|
test "official review logical_||_true_true" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"true || true\", \"parameters\": {\"x\": {\"type_name\": \"TYPE_NAME_INT\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"x\": 0}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"logical_||_true_true\"}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review logical_||_true_false" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"true || false\", \"parameters\": {\"x\": {\"type_name\": \"TYPE_NAME_INT\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"x\": 0}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"logical_||_true_false\"}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review logical_||_true_(1 / x > 0)" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"true || (1 / x > 0)\", \"parameters\": {\"x\": {\"type_name\": \"TYPE_NAME_INT\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"x\": 0}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"logical_||_true_(1 / x > 0)\"}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review logical_||_false_true" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"false || true\", \"parameters\": {\"x\": {\"type_name\": \"TYPE_NAME_INT\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"x\": 0}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"logical_||_false_true\"}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review logical_||_false_false" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"false || false\", \"parameters\": {\"x\": {\"type_name\": \"TYPE_NAME_INT\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"x\": 0}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"logical_||_false_false\"}",
    "{\"check\": false, \"list_objects\": [], \"list_users\": []}",
  )
}

///|
test "official review logical_||_false_(1 / x > 0)" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"false || (1 / x > 0)\", \"parameters\": {\"x\": {\"type_name\": \"TYPE_NAME_INT\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"x\": 0}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"logical_||_false_(1 / x > 0)\"}",
    "{\"check\": \"E2000\", \"list_objects\": \"E2000\", \"list_users\": \"E2000\"}",
  )
}

///|
test "official review logical_||_(1 / x > 0)_true" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"(1 / x > 0) || true\", \"parameters\": {\"x\": {\"type_name\": \"TYPE_NAME_INT\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"x\": 0}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"logical_||_(1 / x > 0)_true\"}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review logical_||_(1 / x > 0)_false" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"(1 / x > 0) || false\", \"parameters\": {\"x\": {\"type_name\": \"TYPE_NAME_INT\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"x\": 0}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"logical_||_(1 / x > 0)_false\"}",
    "{\"check\": \"E2000\", \"list_objects\": \"E2000\", \"list_users\": \"E2000\"}",
  )
}

///|
test "official review logical_||_(1 / x > 0)_(1 / x > 0)" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"(1 / x > 0) || (1 / x > 0)\", \"parameters\": {\"x\": {\"type_name\": \"TYPE_NAME_INT\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"x\": 0}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"logical_||_(1 / x > 0)_(1 / x > 0)\"}",
    "{\"check\": \"E2000\", \"list_objects\": \"E2000\", \"list_users\": \"E2000\"}",
  )
}

///|
test "official review unicode_False_" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"size(s) == 0\", \"parameters\": {\"s\": {\"type_name\": \"TYPE_NAME_STRING\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"s\": \"\"}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"unicode_False_\"}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review unicode_True_" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"s.size() == 0\", \"parameters\": {\"s\": {\"type_name\": \"TYPE_NAME_STRING\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"s\": \"\"}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"unicode_True_\"}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review unicode_False_中" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"size(s) == 1\", \"parameters\": {\"s\": {\"type_name\": \"TYPE_NAME_STRING\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"s\": \"中\"}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"unicode_False_中\"}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review unicode_True_中" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"s.size() == 1\", \"parameters\": {\"s\": {\"type_name\": \"TYPE_NAME_STRING\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"s\": \"中\"}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"unicode_True_中\"}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review unicode_False_😀" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"size(s) == 1\", \"parameters\": {\"s\": {\"type_name\": \"TYPE_NAME_STRING\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"s\": \"😀\"}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"unicode_False_😀\"}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review unicode_True_😀" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"s.size() == 1\", \"parameters\": {\"s\": {\"type_name\": \"TYPE_NAME_STRING\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"s\": \"😀\"}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"unicode_True_😀\"}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review unicode_False_é" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"size(s) == 2\", \"parameters\": {\"s\": {\"type_name\": \"TYPE_NAME_STRING\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"s\": \"é\"}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"unicode_False_é\"}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review unicode_True_é" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"s.size() == 2\", \"parameters\": {\"s\": {\"type_name\": \"TYPE_NAME_STRING\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"s\": \"é\"}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"unicode_True_é\"}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review unicode_False_a😀中" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"size(s) == 3\", \"parameters\": {\"s\": {\"type_name\": \"TYPE_NAME_STRING\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"s\": \"a😀中\"}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"unicode_False_a😀中\"}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review unicode_True_a😀中" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"s.size() == 3\", \"parameters\": {\"s\": {\"type_name\": \"TYPE_NAME_STRING\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"s\": \"a😀中\"}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"unicode_True_a😀中\"}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review timestamp_2026-01-01T00:00:00Z_2026-01-01T00:00:00Z" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"string(t) == '2026-01-01T00:00:00Z'\", \"parameters\": {\"t\": {\"type_name\": \"TYPE_NAME_TIMESTAMP\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"t\": \"2026-01-01T00:00:00Z\"}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"timestamp_2026-01-01T00:00:00Z_2026-01-01T00:00:00Z\"}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review timestamp_2026-01-01T08:00:00+08:00_2026-01-01T08:00:00+08:00" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"string(t) == '2026-01-01T08:00:00+08:00'\", \"parameters\": {\"t\": {\"type_name\": \"TYPE_NAME_TIMESTAMP\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"t\": \"2026-01-01T08:00:00+08:00\"}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"timestamp_2026-01-01T08:00:00+08:00_2026-01-01T08:00:00+08:00\"}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review timestamp_2026-01-01T00:00:00.120Z_2026-01-01T00:00:00.12Z" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"string(t) == '2026-01-01T00:00:00.12Z'\", \"parameters\": {\"t\": {\"type_name\": \"TYPE_NAME_TIMESTAMP\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"t\": \"2026-01-01T00:00:00.120Z\"}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"timestamp_2026-01-01T00:00:00.120Z_2026-01-01T00:00:00.12Z\"}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review timestamp_1969-12-31T23:59:59.999999999Z_1969-12-31T23:59:59.999999999Z" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"string(t) == '1969-12-31T23:59:59.999999999Z'\", \"parameters\": {\"t\": {\"type_name\": \"TYPE_NAME_TIMESTAMP\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"t\": \"1969-12-31T23:59:59.999999999Z\"}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"timestamp_1969-12-31T23:59:59.999999999Z_1969-12-31T23:59:59.999999999Z\"}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review timestamp_2026-01-01T08:00:00.123456789+08:00_2026-01-01T08:00:00.123456789+08:00" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"string(t) == '2026-01-01T08:00:00.123456789+08:00'\", \"parameters\": {\"t\": {\"type_name\": \"TYPE_NAME_TIMESTAMP\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"t\": \"2026-01-01T08:00:00.123456789+08:00\"}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"timestamp_2026-01-01T08:00:00.123456789+08:00_2026-01-01T08:00:00.123456789+08:00\"}",
    "{\"check\": true, \"list_objects\": [\"document:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review timestamp_2026-01-01T08:00:00+08:00_2026-01-01T00:00:00Z" {
  assert_review_case(
    "{\"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"viewer\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"viewer\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"string(t) == '2026-01-01T00:00:00Z'\", \"parameters\": {\"t\": {\"type_name\": \"TYPE_NAME_TIMESTAMP\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {\"t\": \"2026-01-01T08:00:00+08:00\"}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"name\": \"timestamp_2026-01-01T08:00:00+08:00_2026-01-01T00:00:00Z\"}",
    "{\"check\": false, \"list_objects\": [], \"list_users\": []}",
  )
}

///|
test "official review list_error_union_False_False" {
  assert_review_case(
    "{\"name\": \"list_error_union_False_False\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"conditional\": {\"this\": {}}, \"owner\": {\"this\": {}}, \"viewer\": {\"union\": {\"child\": [{\"computedUserset\": {\"relation\": \"conditional\"}}, {\"computedUserset\": {\"relation\": \"owner\"}}]}}}, \"metadata\": {\"relations\": {\"conditional\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}, \"owner\": {\"directly_related_user_types\": [{\"type\": \"user\"}]}, \"viewer\": {\"directly_related_user_types\": []}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"ok\", \"parameters\": {\"ok\": {\"type_name\": \"TYPE_NAME_BOOL\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"conditional\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {}}}, {\"object\": \"document:0\", \"relation\": \"owner\", \"user\": \"user:0\"}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": true, \"list_objects\": \"E2000\", \"list_users\": \"E2000\"}",
  )
}

///|
test "official review list_error_union_False_True" {
  assert_review_case(
    "{\"name\": \"list_error_union_False_True\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"conditional\": {\"this\": {}}, \"owner\": {\"this\": {}}, \"viewer\": {\"union\": {\"child\": [{\"computedUserset\": {\"relation\": \"conditional\"}}, {\"computedUserset\": {\"relation\": \"owner\"}}]}}}, \"metadata\": {\"relations\": {\"conditional\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}, \"owner\": {\"directly_related_user_types\": [{\"type\": \"user\"}]}, \"viewer\": {\"directly_related_user_types\": []}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"ok\", \"parameters\": {\"ok\": {\"type_name\": \"TYPE_NAME_BOOL\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"owner\", \"user\": \"user:0\"}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"context\": {}, \"contextual\": [{\"object\": \"document:0\", \"relation\": \"conditional\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {}}}]}",
    "{\"check\": true, \"list_objects\": \"E2000\", \"list_users\": \"E2000\"}",
  )
}

///|
test "official review list_error_union_True_False" {
  assert_review_case(
    "{\"name\": \"list_error_union_True_False\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"conditional\": {\"this\": {}}, \"owner\": {\"this\": {}}, \"viewer\": {\"union\": {\"child\": [{\"computedUserset\": {\"relation\": \"owner\"}}, {\"computedUserset\": {\"relation\": \"conditional\"}}]}}}, \"metadata\": {\"relations\": {\"conditional\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}, \"owner\": {\"directly_related_user_types\": [{\"type\": \"user\"}]}, \"viewer\": {\"directly_related_user_types\": []}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"ok\", \"parameters\": {\"ok\": {\"type_name\": \"TYPE_NAME_BOOL\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"conditional\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {}}}, {\"object\": \"document:0\", \"relation\": \"owner\", \"user\": \"user:0\"}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": true, \"list_objects\": \"E2000\", \"list_users\": \"E2000\"}",
  )
}

///|
test "official review list_error_union_True_True" {
  assert_review_case(
    "{\"name\": \"list_error_union_True_True\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"conditional\": {\"this\": {}}, \"owner\": {\"this\": {}}, \"viewer\": {\"union\": {\"child\": [{\"computedUserset\": {\"relation\": \"owner\"}}, {\"computedUserset\": {\"relation\": \"conditional\"}}]}}}, \"metadata\": {\"relations\": {\"conditional\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}, \"owner\": {\"directly_related_user_types\": [{\"type\": \"user\"}]}, \"viewer\": {\"directly_related_user_types\": []}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"ok\", \"parameters\": {\"ok\": {\"type_name\": \"TYPE_NAME_BOOL\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"owner\", \"user\": \"user:0\"}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"context\": {}, \"contextual\": [{\"object\": \"document:0\", \"relation\": \"conditional\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {}}}]}",
    "{\"check\": true, \"list_objects\": \"E2000\", \"list_users\": \"E2000\"}",
  )
}

///|
test "official review list_error_intersection_False_False" {
  assert_review_case(
    "{\"name\": \"list_error_intersection_False_False\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"conditional\": {\"this\": {}}, \"owner\": {\"this\": {}}, \"viewer\": {\"intersection\": {\"child\": [{\"computedUserset\": {\"relation\": \"conditional\"}}, {\"computedUserset\": {\"relation\": \"owner\"}}]}}}, \"metadata\": {\"relations\": {\"conditional\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}, \"owner\": {\"directly_related_user_types\": [{\"type\": \"user\"}]}, \"viewer\": {\"directly_related_user_types\": []}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"ok\", \"parameters\": {\"ok\": {\"type_name\": \"TYPE_NAME_BOOL\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"conditional\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": false, \"list_objects\": \"E2000\", \"list_users\": \"E2000\"}",
  )
}

///|
test "official review list_error_intersection_False_True" {
  assert_review_case(
    "{\"name\": \"list_error_intersection_False_True\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"conditional\": {\"this\": {}}, \"owner\": {\"this\": {}}, \"viewer\": {\"intersection\": {\"child\": [{\"computedUserset\": {\"relation\": \"conditional\"}}, {\"computedUserset\": {\"relation\": \"owner\"}}]}}}, \"metadata\": {\"relations\": {\"conditional\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}, \"owner\": {\"directly_related_user_types\": [{\"type\": \"user\"}]}, \"viewer\": {\"directly_related_user_types\": []}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"ok\", \"parameters\": {\"ok\": {\"type_name\": \"TYPE_NAME_BOOL\"}}}}}, \"tuples\": [], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"context\": {}, \"contextual\": [{\"object\": \"document:0\", \"relation\": \"conditional\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {}}}]}",
    "{\"check\": false, \"list_objects\": \"E2000\", \"list_users\": \"E2000\"}",
  )
}

///|
test "official review list_error_intersection_True_False" {
  assert_review_case(
    "{\"name\": \"list_error_intersection_True_False\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"conditional\": {\"this\": {}}, \"owner\": {\"this\": {}}, \"viewer\": {\"intersection\": {\"child\": [{\"computedUserset\": {\"relation\": \"owner\"}}, {\"computedUserset\": {\"relation\": \"conditional\"}}]}}}, \"metadata\": {\"relations\": {\"conditional\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}, \"owner\": {\"directly_related_user_types\": [{\"type\": \"user\"}]}, \"viewer\": {\"directly_related_user_types\": []}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"ok\", \"parameters\": {\"ok\": {\"type_name\": \"TYPE_NAME_BOOL\"}}}}}, \"tuples\": [{\"object\": \"document:0\", \"relation\": \"conditional\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {}}}], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": false, \"list_objects\": \"E2000\", \"list_users\": \"E2000\"}",
  )
}

///|
test "official review list_error_intersection_True_True" {
  assert_review_case(
    "{\"name\": \"list_error_intersection_True_True\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"document\", \"relations\": {\"conditional\": {\"this\": {}}, \"owner\": {\"this\": {}}, \"viewer\": {\"intersection\": {\"child\": [{\"computedUserset\": {\"relation\": \"owner\"}}, {\"computedUserset\": {\"relation\": \"conditional\"}}]}}}, \"metadata\": {\"relations\": {\"conditional\": {\"directly_related_user_types\": [{\"type\": \"user\", \"condition\": \"enabled\"}]}, \"owner\": {\"directly_related_user_types\": [{\"type\": \"user\"}]}, \"viewer\": {\"directly_related_user_types\": []}}}}], \"conditions\": {\"enabled\": {\"name\": \"enabled\", \"expression\": \"ok\", \"parameters\": {\"ok\": {\"type_name\": \"TYPE_NAME_BOOL\"}}}}}, \"tuples\": [], \"object\": \"document:0\", \"relation\": \"viewer\", \"user\": \"user:0\", \"context\": {}, \"contextual\": [{\"object\": \"document:0\", \"relation\": \"conditional\", \"user\": \"user:0\", \"condition\": {\"name\": \"enabled\", \"context\": {}}}]}",
    "{\"check\": false, \"list_objects\": \"E2000\", \"list_users\": \"E2000\"}",
  )
}

///|
test "official review deep_shallow_cycle_0" {
  assert_review_case(
    "{\"name\": \"deep_shallow_cycle_0\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"group\", \"relations\": {\"member\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"member\": {\"directly_related_user_types\": [{\"type\": \"user\"}, {\"type\": \"group\", \"relation\": \"member\"}]}}}}]}, \"tuples\": [{\"object\": \"group:0\", \"relation\": \"member\", \"user\": \"user:0\"}, {\"object\": \"group:1\", \"relation\": \"member\", \"user\": \"group:0#member\"}, {\"object\": \"group:2\", \"relation\": \"member\", \"user\": \"group:1#member\"}, {\"object\": \"group:3\", \"relation\": \"member\", \"user\": \"group:2#member\"}, {\"object\": \"group:4\", \"relation\": \"member\", \"user\": \"group:3#member\"}, {\"object\": \"group:5\", \"relation\": \"member\", \"user\": \"group:4#member\"}, {\"object\": \"group:6\", \"relation\": \"member\", \"user\": \"group:5#member\"}, {\"object\": \"group:7\", \"relation\": \"member\", \"user\": \"group:6#member\"}, {\"object\": \"group:8\", \"relation\": \"member\", \"user\": \"group:7#member\"}, {\"object\": \"group:9\", \"relation\": \"member\", \"user\": \"group:8#member\"}, {\"object\": \"group:10\", \"relation\": \"member\", \"user\": \"group:9#member\"}, {\"object\": \"group:11\", \"relation\": \"member\", \"user\": \"group:10#member\"}, {\"object\": \"group:12\", \"relation\": \"member\", \"user\": \"group:11#member\"}, {\"object\": \"group:13\", \"relation\": \"member\", \"user\": \"group:12#member\"}, {\"object\": \"group:14\", \"relation\": \"member\", \"user\": \"group:13#member\"}, {\"object\": \"group:15\", \"relation\": \"member\", \"user\": \"group:14#member\"}, {\"object\": \"group:16\", \"relation\": \"member\", \"user\": \"group:15#member\"}, {\"object\": \"group:17\", \"relation\": \"member\", \"user\": \"group:16#member\"}, {\"object\": \"group:18\", \"relation\": \"member\", \"user\": \"group:17#member\"}, {\"object\": \"group:19\", \"relation\": \"member\", \"user\": \"group:18#member\"}, {\"object\": \"group:20\", \"relation\": \"member\", \"user\": \"group:19#member\"}, {\"object\": \"group:21\", \"relation\": \"member\", \"user\": \"group:20#member\"}, {\"object\": \"group:22\", \"relation\": \"member\", \"user\": \"group:21#member\"}, {\"object\": \"group:23\", \"relation\": \"member\", \"user\": \"group:22#member\"}, {\"object\": \"group:24\", \"relation\": \"member\", \"user\": \"group:23#member\"}, {\"object\": \"group:25\", \"relation\": \"member\", \"user\": \"group:24#member\"}, {\"object\": \"group:26\", \"relation\": \"member\", \"user\": \"group:25#member\"}, {\"object\": \"group:26\", \"relation\": \"member\", \"user\": \"user:0\"}, {\"object\": \"group:0\", \"relation\": \"member\", \"user\": \"group:26#member\"}], \"object\": \"group:0\", \"relation\": \"member\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": true, \"list_objects\": [\"group:0\", \"group:1\", \"group:10\", \"group:11\", \"group:12\", \"group:13\", \"group:14\", \"group:15\", \"group:16\", \"group:17\", \"group:18\", \"group:19\", \"group:2\", \"group:20\", \"group:21\", \"group:22\", \"group:23\", \"group:24\", \"group:25\", \"group:26\", \"group:3\", \"group:4\", \"group:5\", \"group:6\", \"group:7\", \"group:8\", \"group:9\"], \"list_users\": \"E2002\"}",
  )
}

///|
test "official review deep_shallow_cycle_25" {
  assert_review_case(
    "{\"name\": \"deep_shallow_cycle_25\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"group\", \"relations\": {\"member\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"member\": {\"directly_related_user_types\": [{\"type\": \"user\"}, {\"type\": \"group\", \"relation\": \"member\"}]}}}}]}, \"tuples\": [{\"object\": \"group:0\", \"relation\": \"member\", \"user\": \"user:0\"}, {\"object\": \"group:1\", \"relation\": \"member\", \"user\": \"group:0#member\"}, {\"object\": \"group:2\", \"relation\": \"member\", \"user\": \"group:1#member\"}, {\"object\": \"group:3\", \"relation\": \"member\", \"user\": \"group:2#member\"}, {\"object\": \"group:4\", \"relation\": \"member\", \"user\": \"group:3#member\"}, {\"object\": \"group:5\", \"relation\": \"member\", \"user\": \"group:4#member\"}, {\"object\": \"group:6\", \"relation\": \"member\", \"user\": \"group:5#member\"}, {\"object\": \"group:7\", \"relation\": \"member\", \"user\": \"group:6#member\"}, {\"object\": \"group:8\", \"relation\": \"member\", \"user\": \"group:7#member\"}, {\"object\": \"group:9\", \"relation\": \"member\", \"user\": \"group:8#member\"}, {\"object\": \"group:10\", \"relation\": \"member\", \"user\": \"group:9#member\"}, {\"object\": \"group:11\", \"relation\": \"member\", \"user\": \"group:10#member\"}, {\"object\": \"group:12\", \"relation\": \"member\", \"user\": \"group:11#member\"}, {\"object\": \"group:13\", \"relation\": \"member\", \"user\": \"group:12#member\"}, {\"object\": \"group:14\", \"relation\": \"member\", \"user\": \"group:13#member\"}, {\"object\": \"group:15\", \"relation\": \"member\", \"user\": \"group:14#member\"}, {\"object\": \"group:16\", \"relation\": \"member\", \"user\": \"group:15#member\"}, {\"object\": \"group:17\", \"relation\": \"member\", \"user\": \"group:16#member\"}, {\"object\": \"group:18\", \"relation\": \"member\", \"user\": \"group:17#member\"}, {\"object\": \"group:19\", \"relation\": \"member\", \"user\": \"group:18#member\"}, {\"object\": \"group:20\", \"relation\": \"member\", \"user\": \"group:19#member\"}, {\"object\": \"group:21\", \"relation\": \"member\", \"user\": \"group:20#member\"}, {\"object\": \"group:22\", \"relation\": \"member\", \"user\": \"group:21#member\"}, {\"object\": \"group:23\", \"relation\": \"member\", \"user\": \"group:22#member\"}, {\"object\": \"group:24\", \"relation\": \"member\", \"user\": \"group:23#member\"}, {\"object\": \"group:25\", \"relation\": \"member\", \"user\": \"group:24#member\"}, {\"object\": \"group:26\", \"relation\": \"member\", \"user\": \"group:25#member\"}, {\"object\": \"group:26\", \"relation\": \"member\", \"user\": \"user:0\"}, {\"object\": \"group:0\", \"relation\": \"member\", \"user\": \"group:26#member\"}], \"object\": \"group:25\", \"relation\": \"member\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": true, \"list_objects\": [\"group:0\", \"group:1\", \"group:10\", \"group:11\", \"group:12\", \"group:13\", \"group:14\", \"group:15\", \"group:16\", \"group:17\", \"group:18\", \"group:19\", \"group:2\", \"group:20\", \"group:21\", \"group:22\", \"group:23\", \"group:24\", \"group:25\", \"group:26\", \"group:3\", \"group:4\", \"group:5\", \"group:6\", \"group:7\", \"group:8\", \"group:9\"], \"list_users\": \"E2002\"}",
  )
}

///|
test "official review deep_shallow_cycle_26" {
  assert_review_case(
    "{\"name\": \"deep_shallow_cycle_26\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"group\", \"relations\": {\"member\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"member\": {\"directly_related_user_types\": [{\"type\": \"user\"}, {\"type\": \"group\", \"relation\": \"member\"}]}}}}]}, \"tuples\": [{\"object\": \"group:0\", \"relation\": \"member\", \"user\": \"user:0\"}, {\"object\": \"group:1\", \"relation\": \"member\", \"user\": \"group:0#member\"}, {\"object\": \"group:2\", \"relation\": \"member\", \"user\": \"group:1#member\"}, {\"object\": \"group:3\", \"relation\": \"member\", \"user\": \"group:2#member\"}, {\"object\": \"group:4\", \"relation\": \"member\", \"user\": \"group:3#member\"}, {\"object\": \"group:5\", \"relation\": \"member\", \"user\": \"group:4#member\"}, {\"object\": \"group:6\", \"relation\": \"member\", \"user\": \"group:5#member\"}, {\"object\": \"group:7\", \"relation\": \"member\", \"user\": \"group:6#member\"}, {\"object\": \"group:8\", \"relation\": \"member\", \"user\": \"group:7#member\"}, {\"object\": \"group:9\", \"relation\": \"member\", \"user\": \"group:8#member\"}, {\"object\": \"group:10\", \"relation\": \"member\", \"user\": \"group:9#member\"}, {\"object\": \"group:11\", \"relation\": \"member\", \"user\": \"group:10#member\"}, {\"object\": \"group:12\", \"relation\": \"member\", \"user\": \"group:11#member\"}, {\"object\": \"group:13\", \"relation\": \"member\", \"user\": \"group:12#member\"}, {\"object\": \"group:14\", \"relation\": \"member\", \"user\": \"group:13#member\"}, {\"object\": \"group:15\", \"relation\": \"member\", \"user\": \"group:14#member\"}, {\"object\": \"group:16\", \"relation\": \"member\", \"user\": \"group:15#member\"}, {\"object\": \"group:17\", \"relation\": \"member\", \"user\": \"group:16#member\"}, {\"object\": \"group:18\", \"relation\": \"member\", \"user\": \"group:17#member\"}, {\"object\": \"group:19\", \"relation\": \"member\", \"user\": \"group:18#member\"}, {\"object\": \"group:20\", \"relation\": \"member\", \"user\": \"group:19#member\"}, {\"object\": \"group:21\", \"relation\": \"member\", \"user\": \"group:20#member\"}, {\"object\": \"group:22\", \"relation\": \"member\", \"user\": \"group:21#member\"}, {\"object\": \"group:23\", \"relation\": \"member\", \"user\": \"group:22#member\"}, {\"object\": \"group:24\", \"relation\": \"member\", \"user\": \"group:23#member\"}, {\"object\": \"group:25\", \"relation\": \"member\", \"user\": \"group:24#member\"}, {\"object\": \"group:26\", \"relation\": \"member\", \"user\": \"group:25#member\"}, {\"object\": \"group:26\", \"relation\": \"member\", \"user\": \"user:0\"}, {\"object\": \"group:0\", \"relation\": \"member\", \"user\": \"group:26#member\"}], \"object\": \"group:26\", \"relation\": \"member\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": true, \"list_objects\": [\"group:0\", \"group:1\", \"group:10\", \"group:11\", \"group:12\", \"group:13\", \"group:14\", \"group:15\", \"group:16\", \"group:17\", \"group:18\", \"group:19\", \"group:2\", \"group:20\", \"group:21\", \"group:22\", \"group:23\", \"group:24\", \"group:25\", \"group:26\", \"group:3\", \"group:4\", \"group:5\", \"group:6\", \"group:7\", \"group:8\", \"group:9\"], \"list_users\": \"E2002\"}",
  )
}

///|
test "official review computed_depth_0" {
  assert_review_case(
    "{\"name\": \"computed_depth_0\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"group\", \"relations\": {\"member\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"member\": {\"directly_related_user_types\": [{\"type\": \"user\"}, {\"type\": \"group\", \"relation\": \"member\"}]}}}}]}, \"tuples\": [{\"object\": \"group:0\", \"relation\": \"member\", \"user\": \"user:0\"}], \"object\": \"group:0\", \"relation\": \"member\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": true, \"list_objects\": [\"group:0\"], \"list_users\": [\"user:0\"]}",
  )
}

///|
test "official review computed_depth_25" {
  assert_review_case(
    "{\"name\": \"computed_depth_25\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"group\", \"relations\": {\"member\": {\"this\": {}}, \"r0\": {\"computedUserset\": {\"relation\": \"member\"}}, \"r1\": {\"computedUserset\": {\"relation\": \"r0\"}}, \"r2\": {\"computedUserset\": {\"relation\": \"r1\"}}, \"r3\": {\"computedUserset\": {\"relation\": \"r2\"}}, \"r4\": {\"computedUserset\": {\"relation\": \"r3\"}}, \"r5\": {\"computedUserset\": {\"relation\": \"r4\"}}, \"r6\": {\"computedUserset\": {\"relation\": \"r5\"}}, \"r7\": {\"computedUserset\": {\"relation\": \"r6\"}}, \"r8\": {\"computedUserset\": {\"relation\": \"r7\"}}, \"r9\": {\"computedUserset\": {\"relation\": \"r8\"}}, \"r10\": {\"computedUserset\": {\"relation\": \"r9\"}}, \"r11\": {\"computedUserset\": {\"relation\": \"r10\"}}, \"r12\": {\"computedUserset\": {\"relation\": \"r11\"}}, \"r13\": {\"computedUserset\": {\"relation\": \"r12\"}}, \"r14\": {\"computedUserset\": {\"relation\": \"r13\"}}, \"r15\": {\"computedUserset\": {\"relation\": \"r14\"}}, \"r16\": {\"computedUserset\": {\"relation\": \"r15\"}}, \"r17\": {\"computedUserset\": {\"relation\": \"r16\"}}, \"r18\": {\"computedUserset\": {\"relation\": \"r17\"}}, \"r19\": {\"computedUserset\": {\"relation\": \"r18\"}}, \"r20\": {\"computedUserset\": {\"relation\": \"r19\"}}, \"r21\": {\"computedUserset\": {\"relation\": \"r20\"}}, \"r22\": {\"computedUserset\": {\"relation\": \"r21\"}}, \"r23\": {\"computedUserset\": {\"relation\": \"r22\"}}, \"r24\": {\"computedUserset\": {\"relation\": \"r23\"}}}, \"metadata\": {\"relations\": {\"member\": {\"directly_related_user_types\": [{\"type\": \"user\"}, {\"type\": \"group\", \"relation\": \"member\"}]}}}}]}, \"tuples\": [{\"object\": \"group:0\", \"relation\": \"member\", \"user\": \"user:0\"}], \"object\": \"group:0\", \"relation\": \"r24\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": true, \"list_objects\": [\"group:0\"], \"list_users\": \"E2002\"}",
  )
}

///|
test "official review computed_depth_26" {
  assert_review_case(
    "{\"name\": \"computed_depth_26\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"group\", \"relations\": {\"member\": {\"this\": {}}, \"r0\": {\"computedUserset\": {\"relation\": \"member\"}}, \"r1\": {\"computedUserset\": {\"relation\": \"r0\"}}, \"r2\": {\"computedUserset\": {\"relation\": \"r1\"}}, \"r3\": {\"computedUserset\": {\"relation\": \"r2\"}}, \"r4\": {\"computedUserset\": {\"relation\": \"r3\"}}, \"r5\": {\"computedUserset\": {\"relation\": \"r4\"}}, \"r6\": {\"computedUserset\": {\"relation\": \"r5\"}}, \"r7\": {\"computedUserset\": {\"relation\": \"r6\"}}, \"r8\": {\"computedUserset\": {\"relation\": \"r7\"}}, \"r9\": {\"computedUserset\": {\"relation\": \"r8\"}}, \"r10\": {\"computedUserset\": {\"relation\": \"r9\"}}, \"r11\": {\"computedUserset\": {\"relation\": \"r10\"}}, \"r12\": {\"computedUserset\": {\"relation\": \"r11\"}}, \"r13\": {\"computedUserset\": {\"relation\": \"r12\"}}, \"r14\": {\"computedUserset\": {\"relation\": \"r13\"}}, \"r15\": {\"computedUserset\": {\"relation\": \"r14\"}}, \"r16\": {\"computedUserset\": {\"relation\": \"r15\"}}, \"r17\": {\"computedUserset\": {\"relation\": \"r16\"}}, \"r18\": {\"computedUserset\": {\"relation\": \"r17\"}}, \"r19\": {\"computedUserset\": {\"relation\": \"r18\"}}, \"r20\": {\"computedUserset\": {\"relation\": \"r19\"}}, \"r21\": {\"computedUserset\": {\"relation\": \"r20\"}}, \"r22\": {\"computedUserset\": {\"relation\": \"r21\"}}, \"r23\": {\"computedUserset\": {\"relation\": \"r22\"}}, \"r24\": {\"computedUserset\": {\"relation\": \"r23\"}}, \"r25\": {\"computedUserset\": {\"relation\": \"r24\"}}}, \"metadata\": {\"relations\": {\"member\": {\"directly_related_user_types\": [{\"type\": \"user\"}, {\"type\": \"group\", \"relation\": \"member\"}]}}}}]}, \"tuples\": [{\"object\": \"group:0\", \"relation\": \"member\", \"user\": \"user:0\"}], \"object\": \"group:0\", \"relation\": \"r25\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": true, \"list_objects\": [\"group:0\"], \"list_users\": \"E2002\"}",
  )
}

///|
test "original review self-cycle terminates locally" {
  assert_review_case(
    "{\"name\": \"recursive_cycle_terminates\", \"model\": {\"schema_version\": \"1.1\", \"type_definitions\": [{\"type\": \"user\"}, {\"type\": \"group\", \"relations\": {\"member\": {\"this\": {}}}, \"metadata\": {\"relations\": {\"member\": {\"directly_related_user_types\": [{\"type\": \"user\"}, {\"type\": \"group\", \"relation\": \"member\"}]}}}}]}, \"tuples\": [{\"object\": \"group:0\", \"relation\": \"member\", \"user\": \"group:0#member\"}], \"object\": \"group:0\", \"relation\": \"member\", \"user\": \"user:0\", \"context\": {}, \"contextual\": []}",
    "{\"check\": false, \"list_objects\": [], \"list_users\": []}",
  )
}

///|
test "Explain records the successful owner path without re-evaluating errors" {
  for rewrite in ["conditional or owner", "owner or conditional"] {
    let engine = engine_of(
      "model\n  schema 1.1\ntype user\ntype document\n  relations\n    define conditional: [user with enabled]\n    define owner: [user]\n    define viewer: " +
      rewrite +
      "\ncondition enabled(ok: bool) { ok }",
      [
        @fga.Tuple::{
          object: "document:0",
          relation: "conditional",
          user: "user:0",
          condition: Some(@fga.TupleCondition::{
            name: "enabled",
            context: Map([]),
          }),
        },
        tup("document:0", "owner", "user:0"),
      ],
    )
    assert_true(engine.check("document:0", "viewer", "user:0"))
    let result = engine.explain_check(
      "document:0",
      "viewer",
      "user:0",
      Map([]),
      [],
    )
    assert_true(result.allowed && result.complete)
    assert_true(result.explain_error is None)
    assert_true(result.paths.any(fn(p) { p.contains("owner@user:0") }))
    assert_false(result.paths.any(fn(p) { p.contains("conditional") }))
    let denied = engine.explain_check(
      "document:0",
      "viewer",
      "user:nobody",
      Map([]),
      [],
    )
    assert_false(denied.allowed)
    assert_true(denied.complete)
    assert_true(denied.paths.is_empty())
  }
}

///|
test "incomplete explanation serializes a non-fatal decision" {
  let result = @engine.ExplainResult::{
    allowed: true,
    paths: [],
    complete: false,
    explain_error: Some("witness unavailable"),
  }
  let json = result.to_json()
  assert_eq(@fga.json_get_bool(json, "allowed"), Some(true))
  assert_eq(@fga.json_get_bool(json, "complete"), Some(false))
  assert_eq(
    @fga.json_get_string(json, "explain_error"),
    Some("witness unavailable"),
  )
}
