# 自定义 TupleReader 宿主契约

`snapshot.mbt` 是独立于 MemoryStore 的最小实现，线性扫描适合示例，小数据可直接使用。
生产宿主可换成索引快照，但须保持以下契约：

- `read(object, relation)` 返回精确匹配的全部元组，包括 wildcard、userset、条件名称及参数；不能预先按请求用户或条件过滤。
- `read_userset` 只返回同一键下带 `#relation` 的用户引用。
- `all_objects(type)` 返回有存储元组的不同 object，`all_users()` 返回不同的原始 user 引用（包括 wildcard/userset）。不把仅作为 user 出现的对象加入 object 集合。
- 无匹配项返回 `[]`。返回数组归调用者所有，修改数组不能损坏索引；本次求值期间各方法必须看到一致的数据。
- 现有 trait 不支持 `raise`、异步或错误通道。宿主必须先完整读取一致快照，再 `load_snapshot(Ok(rows))` 并交给 `Engine::new(model, snapshot as &@fga.TupleReader)`。数据库失败传 `Err(message)`，调用者处理异常，不进入 Engine。示例的 E2000 是宿主错误映射示范，不是 OpenFGA 数据库错误码兼容承诺。禁止捕获读取异常后返回空数组。
- contextual tuples 由 Engine 的请求覆盖层处理，宿主不持久化它们。每次成功加载的新快照用于新的 Engine。

`contract_wbtest.mbt` 的 `contract` 接收 trait 对象，可替换成自己的实现；固定 fixture 为 document:a#viewer 的 user:alice、user:*、group:g#member 三条无条件元组；另一项测试检查带条件元组的名称和参数原样返回，并由 Engine 按请求上下文求值。`all_users()` 的顺序不属于契约。

```sh
moon test --target all -p examples/tuple-reader
```
