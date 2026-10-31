# MoonFGA 设计说明

## 总览

MoonFGA 把模型、元组、求值和工具拆成独立包，核心库不依赖文件系统或网络：

```text
                 +-----------------------+
   .fga / .json  |  dsl  |  model  | cel |  conditions
                 +----+------+------+---+
                      |      |
                 +----v------v----+
                 |      fga       |  AST, tuples, CEL values, errors
                 +----+-----------+
                      |
        +-------------+-------------+
        |                           |
   +----v----+   +----v----+   +----v-----+
   |  store  |   |  engine |   | validate |
   +---------+   +----+----+   +----------+
                      |
        +-------------+-------------+
        |             |             |
   +----v----+   +----v-----+  +----v-----+
   |  cli /  |   | storetest|  | language |
   | examples|   | (.fga.yaml) | | fixtures |
   +---------+   +----------+  +----------+
                      |
                 +----v----------+
                 | conformance   |
                 | OpenFGA YAML  |
                 +---------------+
```

## 包职责

| 包 | 职责 |
| --- | --- |
| `fga` | 核心数据结构：`AuthModel`、`TypeDefinition`、`Userset`、`Tuple`、`CelValue`、错误码；元组 JSON/文本解析 |
| `dsl` | Schema 1.1 词法、递归下降解析、规范化打印 |
| `model` | AuthorizationModel JSON 导入/导出、DSL↔JSON 转换、结构相等、来源嗅探 |
| `cel` | CEL 子集：词法、Pratt 解析、求值、条件参数类型强制、时间/IP/正则辅助 |
| `store` | 内存元组存储与上下文元组覆盖层，实现 `TupleReader` trait |
| `engine` | Check、BatchCheck、ListObjects、ListUsers、Expand、Explain |
| `validate` | 带行列位置的模型语义校验 |
| `storetest` | `.fga.yaml` 测试套件解析与执行 |
| `conformance` | OpenFGA 上游 YAML 矩阵回放、分类与报告 |
| `language` | `openfga/language` DSL↔JSON 夹具回放 |
| `cmd/*` | 可执行 CLI 与测试矩阵入口 |

## 模型表示

`Userset` 直接对应 OpenFGA 的关系重写树：

```moonbit
enum Userset {
  This
  Computed(String)
  TupleToUserset(String, String)
  Union(Array[Userset])
  Intersection(Array[Userset])
  Difference(Userset, Userset)
}
```

每个 `TypeDefinition` 同时保存 `relations`（重写树）、`relation_order`（保持 DSL 顺序）
和 `direct`（直接关系限制）。`AuthModel.conditions` 保存条件；`condition_order` 保证
导出的 JSON 顺序稳定。模型 span 用于把校验错误指向源码位置。

直接限制 `TypeRestriction` 包含 `type_name`、可选的 `relation`（userset）、`wildcard`
和 `condition`，足以表达 `[user, group#member, user:*, user with cond]`。

## DSL 解析

`dsl/lexer.mbt` 生成带行列的 token，识别关键字、`[`/`]`、`(`/`)`、`{`/`}`、`:`、`,`、
`#`、`*`、`<`/`>` 以及条件体。`parser.mbt` 是递归下降解析器：

- `or` 优先级最低，其次 `and`，然后是 `but not`；比较/计算关系构建正确嵌套的
  `Union` / `Intersection` / `Difference`。
- `X from Y` 解析为 `TupleToUserset`。
- 括号改变结合方式；解析结果保留源码 span。
- `condition name(p: type, ...) { expression }` 把表达式原样交给 CEL 包。

`printer.mbt` 输出规范化 DSL；往返测试确保 `parse(print(model))` 与
`parse(source)` 结构相等。

## JSON 转换

`model/json.mbt` 兼容 OpenFGA AuthorizationModel：

- `schema_version`、`type_definitions`、`relations`、`metadata.relations`、
  `conditions`、`parameters`、`generic_types`。
- 空模型不输出 `type_definitions`；每个关系都输出 `metadata.relations`（没有直接限制
  时为空数组），与 `openfga/language` 一致。
- 未知字段（例如部分 `source_info`）被忽略，不影响语义。
- `json_to_model` 对形状错误返回 `E2000`。

`model/equal.mbt` 提供忽略对象键顺序的结构比较，供转换夹具和回归测试使用。

## 校验

`validate/validate_model` 返回 `Array[ValidationIssue]`，不会在第一个错误处停止。检查项包括：

- 未知类型、未知关系；
- 直接限制中的未知类型/关系/条件；
- 条件重复、参数类型与泛型参数合法性；
- 关系重写中的未知引用、非法 TTU tupleset、条件缺失；
- 关系循环（按 OpenFGA 的 forbidden cycle 规则）；
- 重复类型/关系定义。

每个问题带 `code`、`message`、`line`、`column` 与 `symbol`。DSL 解析阶段也会产生带位置
的语法错误，CLI 的 `validate` 统一打印。

## 存储

`MemoryStore` 维护三个索引：

- `by_object[object#relation]`：Check/Expand 的直接读取；
- `by_user[user]`：ListObjects 的候选枚举；
- `keys`：去重。

`ContextualStore` 包装一个基础 `TupleReader` 并叠加请求级元组。`TupleReader` trait 让
调用方可以替换为数据库或其他存储。元组文本解析支持
`object#relation@user[condition:{"k":v}]`。

## Check 求值

`engine/eval.mbt` 的核心是 `resolve(object, relation, user, depth)`：

- 深度上限 25，超限返回 `E2002`；
- 每个 `(object, relation, user)` 维护访问集合以检测循环；
- `This` 读取直接元组；`Computed` 递归到同对象的其他关系；
- `TupleToUserset` 先读取 tupleset 关系，再对每个目标对象递归；
- `Union` 任一为真即短路；`Intersection` 任一为假即短路；`Difference` 先求 base，
  再求 subtract 并取反；
- 缺失类型/关系分支返回 `false`，而不是让整个请求失败（与 OpenFGA 一致）；
- 通配符 `user:*` 只在 `match_wildcard_users` 为真时匹配具体用户。

条件元组只有在“可能贡献结果”时才求值：具体用户元组要求 `tuple.user == subject`；
通配符元组要求通配符匹配 subject；userset 边上的条件在递归前求值。这样避免无关 ABAC
元组缺少参数时产生伪错误。

`BatchCheck` 复用同一引擎逐项执行，保持每项独立的错误。

## ListObjects / ListUsers

`ListObjects`：

- 从 `by_user` 与对象索引收集候选对象；
- 对每个候选调用与 Check 相同的求值逻辑，但允许在条件不满足时跳过；
- 结果排序后返回。

`ListUsers` 需要同时处理“显式用户”和通配符：

1. 先用完整通配符语义判断 `type:*` 是否满足关系；满足时在结果中加入 `type:*` 标记。
2. 如果通配符成立，则枚举显式连接的用户，并以“禁用通配符匹配”的引擎求值，避免把所有
   用户都列入。
3. 如果通配符不成立，则用完整语义求值显式候选。
4. userset 过滤器收集同类型对象、已有 userset 用户与显式用户，并转换为 `type#relation`
   形式求值。

这个混合算法覆盖了上游 `exclusion_under_wildcard_*`、`relation_with_wildcard_involving_intersection`
等用例；上下文元组在 List 接口中走同一覆盖层。

## Expand 与 Explain

`Expand` 返回关系重写树和直接叶子用户（JSON），便于调试模型。`ExplainResult` 同时返回
允许/拒绝结果与解析路径；CLI 的 `--explain` 打印路径，便于定位是直接元组、userset 边
还是 TTU 贡献了结果。

## CEL 子集

未使用现成 CEL 库，因为目标类型覆盖（`timestamp`、`duration`、`ipaddress`）和 OpenFGA
条件上下文需要可控的语义与错误码。实现分为：

- `lexer.mbt` / `parser.mbt`：字面量、标识符、成员访问、索引、方法调用、宏调用、
  一元/二元运算符、三元表达式；
- `eval.mbt`：算术、比较、逻辑、`in`、索引、`exists`/`exists_one`/`all`/`map`/`filter`、
  字符串方法（`size`、`startsWith`、`endsWith`、`contains`、`matches`）、列表/映射方法、
  类型转换（`int`、`uint`、`double`、`string`、`bool`）；
- `time.mbt` / `ip.mbt` / `regex.mbt`：RFC 3339 时间、Go 风格 duration、IPv4/IPv6
  与 CIDR 包含、简单正则匹配；
- `coerce.mbt`：按条件声明把上下文 JSON 值强制为声明类型（如字符串转 timestamp）。

边界：不实现 `bytes`、完整的正则捕获组、所有标准库函数。未知函数/方法/参数会返回
`E2000`，不会被静默当作 false。

## 错误映射

| 场景 | 错误码 |
| --- | --- |
| 请求/模型形状非法、条件参数缺失 | `E2000` |
| 模型不存在 | `E2001` |
| 解析深度超限 | `E2002` |
| 写入非法 | `E2003` |
| 类型不存在 | `E2021` |
| 关系不存在 | `E2022` |
| 非法元组/上下文元组 | `E2027` |

CLI 打印 `error <code>: <message>` 并以 1 退出；参数/文件错误以 2 退出；断言失败以 1
退出。

## 一致性测试框架

`conformance/runner.mbt` 直接把上游 YAML 解析为 JSON 后回放：

- 每个 test 使用新的 `MemoryStore`；
- stage 的 tuples 追加，stage 的 model 替换；
- 每个断言捕获 `FgaError`，按 `wrong_result`、`unexpected_error`、`missing_error`、
  `wrong_error_code`、`no_expectation` 等类别归类；
- `expectation: null` 视为空列表；
- 结果包含每条断言的 pass/fail/skip，供 `docs/conformance.md` 生成逐条表格。

`language/transform_runner.mbt` 对每个夹具目录同时比较 DSL→JSON 与 JSON→内部模型。

## 取舍与限制

- 只做进程内内存存储：换来无依赖、易测试的核心；持久化和多节点一致性留给上层。
- 不做 HTTP/gRPC 与分页：当前目标是嵌入式库与 CLI。
- CEL 是受控子集：覆盖 OpenFGA ABAC 测试所需类型与方法，但不宣称完整 CEL 标准。
- 跳过模块语法：单文件 schema 1.1 已覆盖全部上游模型用例。
- ListUsers 的通配符语义是复现上游行为中最复杂的部分，采用“标记 + 显式枚举”算法；
  相关边界继续由上游用例回归。

## 第 3a 阶段：查询路径与公开 API

解析路径使用作用域清理，条件求值抛错时也会弹出当前节点，避免兄弟分支误判为循环。
直接关系解析复用一次解析得到的 UserRef；不引入可能跨请求泄漏条件或循环状态的全局 memo。
内存存储维护按类型的候选对象索引和每个对象的元组计数，最后一条元组删除、clear、
重新插入均同步更新索引；对外返回副本。新增索引以额外内存和写入维护成本换取候选枚举效率。
解析深度从 0 起算，25 层可解析，26 层报 E2002；1000 节点链不会无限递归。

Engine、MemoryStore、ContextualStore 的字段不再公开，避免调用方绕过索引或修改内部解析模式。
构造函数和查询方法保留；CheckRequest / CheckResult 的数据字段仍公开。
引擎内部的校验函数、TupleBindingSpec 和 inline-expression 常量不再导出。
这是发布前 0.1.0 API 收窄；依赖原公开字段的调用方必须改用方法。
错误仍可模式匹配 FgaError(code~, message~, line~, column~)，也可用 error_code / error_message。
native、wasm-gc、js 使用同一核心 API；这些后端的库测试通过不等同于浏览器 JS 模块导出验收。

contextual tuple 按 object/relation/user 遮蔽持久化绑定，仅作用于当前请求。
固定官方服务的 List API 在条件覆盖用例上的行为差异见 conformance.md；
不能由 Check 的兼容性推断 List API 完全兼容。
