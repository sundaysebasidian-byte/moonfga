# MoonFGA

MoonFGA is an OpenFGA-compatible relationship-based authorization (ReBAC)
engine written in MoonBit. It implements the OpenFGA schema 1.1 modeling
language, JSON authorization models, tuple storage, `Check`, `BatchCheck`,
`ListObjects`, `ListUsers`, `Expand`, explainable checks, and a self-contained
CEL subset for conditional relationships. The library builds and tests on the
native, wasm-gc and JavaScript backends.

"OpenFGA" is a trademark of the OpenFGA project. MoonFGA is an independent
implementation and is not endorsed by the OpenFGA project.

See [`docs/conformance.md`](docs/conformance.md) for the upstream test matrix
results, [`docs/design.md`](docs/design.md) for the architecture,
[`docs/proposal.md`](docs/proposal.md) for the submission summary, and
[`CHANGELOG.md`](CHANGELOG.md) for the release notes.

## 项目目标

- 在 MoonBit 上实现一个可直接嵌入的 Zanzibar / OpenFGA 风格授权引擎。
- 以 OpenFGA 官方一致性测试为验收标准，而不是只实现一个相似 API。
- 同一套模型与元组可在服务端、WASM 边缘函数和浏览器中运行。
- 保持实现可读、可测试、无外部网络/数据库依赖。

## 覆盖矩阵

| 能力 | 状态 | 说明 |
| --- | --- | --- |
| Schema 1.1 DSL | 支持 | `model`、`schema 1.1`、`type`、`relations`、`define`、`[user, group#member, user:*, user with cond]`、`or` / `and` / `but not`、括号、computed userset、tuple-to-userset、`condition`、注释 |
| AuthorizationModel JSON | 支持 | 导入、导出；`schema_version`、`type_definitions`、`relations`、`metadata.relations`、`conditions` |
| 模型校验 | 支持 | 未知类型/关系、元组限制、禁止的循环、重复定义、条件参数类型；带行列位置的错误 |
| 元组存储 | 支持 | 内存索引（按 `object#relation`、按 user）、写入/删除、上下文元组覆盖层、`TupleReader` trait |
| Check | 支持 | 深度 25、循环检测、通配符、union/intersection/difference 短路、TTU、条件求值 |
| BatchCheck | 支持 | 进程内批量执行，逐项返回结果或错误 |
| ListObjects / ListUsers | 部分支持 | 条件、上下文元组、通配符用户、userset 过滤器；随机差分有 11 处已记录差异 |
| Expand | 支持 | 返回关系重写树 |
| Explain | 支持 | 返回允许/拒绝的解析路径（`--explain`） |
| ReadChanges | 不支持 | 内存存储没有变更日志；接口未实现 |
| FGA Modules | 不支持 | `module` / `extends` 语法与模块合并未实现；单文件模型可完整使用 |
| 持久化存储 / HTTP / gRPC | 不支持 | 只提供可嵌入的内存引擎和 CLI，持久化需由调用方封装 |
| 分页、consistency preference | 不支持 | List 接口一次返回全部结果 |
| CEL 子集 | 支持 | `int` / `uint` / `double` / `bool` / `string` / `duration` / `timestamp` / `list` / `map` / `ipaddress`，运算符、三元表达式、`exists` / `exists_one` / `all` / `map` / `filter`、常用字符串/时间/网络方法 |
| CLI | 支持 | `validate`、`transform`、`check`、`list-objects`、`list-users`、`expand`、`test` |
| `.fga.yaml` 测试 | 支持 | `model` / `model_file`、全局与用例元组、Check / ListObjects / ListUsers 断言、`errorCode` |

随机官方服务差分：1002 组 / 3006 次比较，11 处差异（ListUsers 10、ListObjects 1）；
含 wildcard 组合与条件覆盖边界，见 [差分报告](docs/conformance.md#第-3a-阶段官方服务随机差分2026-10-31)。
性能实测与复现命令见 [performance.md](docs/performance.md)。

上游一致性结果（固定 commit，当前结果）：

| API | 通过 | 总数 | 失败 | 跳过 |
| --- | ---: | ---: | ---: | ---: |
| Check | 516 | 516 | 0 | 0 |
| ListObjects | 354 | 354 | 0 | 0 |
| ListUsers | 393 | 394 | 0 | 1 |

`openfga/language` 的 DSL ↔ JSON 转换夹具当前为 **29/29**。唯一跳过的断言来自上游用例
`simple_computeduserset_indirect_ref`：其 `expectation: nil` 嵌在 request 内部，没有顶层
期望值或 `errorCode`，因此按 `skip/no_expectation` 如实记录，而不是计为通过。

## 安装与构建

当前模块未发布到 Mooncakes。请从源码构建：

```bash
git clone https://github.com/sundaysebasidian-byte/moonfga
cd moonfga
export PATH="$HOME/.moon/bin:$PATH"
moon check --deny-warn
moon test
```

三个后端均可运行测试：

```bash
moon test --target native
moon test --target wasm-gc
moon test --target js
```

## 库 API 快速开始

在 `moon.pkg` 中加入依赖：

```moonbit
import {
  "sundaysebasidian-byte/moonfga/fga",
  "sundaysebasidian-byte/moonfga/dsl",
  "sundaysebasidian-byte/moonfga/store",
  "sundaysebasidian-byte/moonfga/engine",
}
```

最小可运行示例（完整版本见 `examples/library/main.mbt`）：

```moonbit
let model = @dsl.parse_model(
  "model\n  schema 1.1\n\ntype user\n\ntype group\n  relations\n    define member: [user]\n\ntype document\n  relations\n    define viewer: [user, group#member]\n",
)
let store = @store.MemoryStore::new()
let _ = store.write(
  @fga.Tuple::{ object: "group:eng", relation: "member", user: "user:anne", condition: None },
)
let _ = store.write(
  @fga.Tuple::{ object: "document:roadmap", relation: "viewer", user: "group:eng#member", condition: None },
)
let engine = @engine.Engine::new(model, store as &@fga.TupleReader)
let allowed = engine.check("document:roadmap", "viewer", "user:anne")
println(allowed.to_string()) // true
```

运行该示例：

```bash
moon run examples/library
```

常用接口：

- `@dsl.parse_model(dsl)` / `@model.json_to_model(json)` / `@model.model_from_source(source)`
- `@model.model_to_json(model)` / `@dsl.to_dsl(model)`
- `@validate.validate_model(model)` 返回带位置的 `ValidationIssue`
- `@store.MemoryStore::{ new, write, write_all, delete, read }`
- `@engine.Engine::{ check, check_with, batch_check, list_objects, list_users, expand_json, explain_check }`

## CLI

```bash
# 校验 DSL 或 JSON 模型
moon run cmd/main -- validate examples/basic/model.fga

# DSL -> JSON / JSON -> DSL
moon run cmd/main -- transform examples/basic/model.fga --to json
moon run cmd/main -- transform examples/basic/model.fga --to dsl

# Check（--explain 打印解析路径）
moon run cmd/main -- check \
  --model examples/basic/model.fga \
  --store examples/basic/tuples.fga \
  --object document:budget --relation viewer --user user:bob --explain

# ListObjects / ListUsers
moon run cmd/main -- list-objects \
  --model examples/basic/model.fga --store examples/basic/tuples.fga \
  --type document --relation viewer --user user:bob
moon run cmd/main -- list-users \
  --model examples/basic/model.fga --store examples/basic/tuples.fga \
  --object document:budget --relation viewer --filters user

# Expand 关系树
moon run cmd/main -- expand \
  --model examples/basic/model.fga --store examples/basic/tuples.fga \
  --object document:budget --relation viewer

# 条件（ABAC）示例
moon run cmd/main -- check \
  --model examples/abac/model.fga --store examples/abac/tuples.fga \
  --object document:plan --relation viewer --user user:dana \
  --context '{"office":"hq","allowed":["remote"]}'

# 运行 .fga.yaml 测试
moon run cmd/main -- test examples/basic/store.fga.yaml
moon run cmd/main -- test examples/abac/store.fga.yaml
```

元组文件支持三种格式：JSON 数组、YAML（`tuples:`）以及每行
`object#relation@user` 的文本格式；带条件时写作
`document:1#viewer@user:anne[in_ip:{"ip":"10.0.0.1"}]`。

## 一致性测试复现

上游测试数据不会被提交到仓库；`scripts/fetch-upstream.sh` 按固定 commit 下载到被
`.gitignore` 忽略的 `.upstream/`，许可证为 Apache-2.0。

```bash
scripts/fetch-upstream.sh          # 首次运行，固定 commit
./scripts/conformance.sh           # 运行两个矩阵并检查 95/90 阈值
moon run cmd/language              # DSL <-> JSON 夹具，29/29
```

`./scripts/conformance.sh` 会在 `conformance-results/` 写入 `summary.txt` 与
`summary.json`（均被忽略），并按 Check ≥ 95%、ListObjects/ListUsers ≥ 90% 的阈值返回
非零退出码。逐断言结果见 [`docs/conformance.md`](docs/conformance.md)。

## 与 jhshuai/moonpolicykit 的区别

MoonFGA 是独立的 OpenFGA 兼容实现，没有复用 `moonpolicykit` 的代码，也不以其为目标
超集。差异在于验收方式与范围：

- MoonFGA 直接回放 OpenFGA 官方 Check / ListObjects / ListUsers / ABAC 测试矩阵，
  兼容性由上游用例而非自定义语义定义。
- MoonFGA 完整覆盖 OpenFGA schema 1.1 的 DSL、AuthorizationModel JSON、条件关系与
  `.fga.yaml` 测试格式。
- MoonFGA 自带 OpenFGA 语义的 CEL 子集（含 `timestamp`、`duration`、`ipaddress`），
  而不是依赖通用策略表达式引擎。
- `moonpolicykit` 是另一个 MoonBit 策略/授权项目，其能力与 API 请以该项目文档为准；
  两者不构成替代关系。

## 限制与路线图

已明确不支持：FGA modules、ReadChanges、持久化/分布式存储、HTTP/gRPC 服务端、
分页与 consistency preference、完整 CEL 标准库（如 `bytes`、正则捕获组等）。

后续优先级：

1. 可插拔持久化存储与变更日志（ReadChanges）。
2. 服务端 API（HTTP/gRPC）与一致性偏好。
3. FGA modules 与模块级校验。
4. 扩展 CEL 标准库与更细的错误定位。

## 许可证

Apache-2.0，见 [`LICENSE`](LICENSE) 与 [`NOTICE`](NOTICE)。上游一致性测试数据仅在本地
按固定 commit 下载，不随仓库分发。
