# MoonFGA

**[在浏览器里试用 →](https://sundaysebasidian-byte.github.io/moonfga/)**

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/assets/playground-dark.png">
  <img alt="MoonFGA Playground" src="docs/assets/playground-light.png">
</picture>

MoonFGA 是用 MoonBit 写的 OpenFGA 兼容授权（ReBAC）引擎：把"谁对什么对象有什么关系"存成元组，
按模型规则推导"这个人能不能访问那个资源"。支持 OpenFGA schema 1.1 建模语言、JSON 授权模型、
元组存储、`Check`、`BatchCheck`、`ListObjects`、`ListUsers`、`Expand`、可解释的 Check，以及用于
条件关系的自实现 CEL 子集。库在 native、wasm-gc 和 JavaScript 三个后端都能构建和测试，
Playground 就是同一个引擎编译成 JS 在浏览器里跑。

"OpenFGA" 是 OpenFGA 项目的商标。MoonFGA 是独立实现，未获 OpenFGA 项目背书。

文档：[一致性测试结果](docs/conformance.md) · [设计说明](docs/design.md) ·
[性能](docs/performance.md) · [提案](docs/proposal.md) · [更新日志](CHANGELOG.md)

## 为什么做这个

- 在 MoonBit 上提供一个能直接嵌入的 Zanzibar / OpenFGA 风格授权引擎。
- 兼容性以 OpenFGA 官方测试为准，而不是实现一个"看起来像"的 API。
- 引擎是内存实现，不依赖网络和数据库，同一套模型与元组可以在服务端和浏览器里运行。

## 与 OpenFGA 的一致性

直接回放 OpenFGA v1.22.1 的 Check / ListObjects / ListUsers / ABAC 测试矩阵（固定 commit）：

| API | 通过 | 总数 | 失败 | 跳过 |
| --- | ---: | ---: | ---: | ---: |
| Check | 516 | 516 | 0 | 0 |
| ListObjects | 354 | 354 | 0 | 0 |
| ListUsers | 393 | 394 | 0 | 1 |

`openfga/language` 的 DSL ↔ JSON 转换夹具是 29/29。

唯一跳过的断言来自上游用例 `simple_computeduserset_indirect_ref`：它的 `expectation: nil` 嵌在
request 里面，没有顶层期望值或 `errorCode`，所以按 `skip/no_expectation` 如实记录，不算通过。

除了固定用例，还和官方 v1.22.1 二进制做了随机差分：两个 seed 各 1095 组（1000 随机＋95 定向），共 6570 次比较，
0 不一致。另有独立定向差分脚本 `scripts/oracle_directed.py`，204 组 / 612 次比较，0 不一致。随机生成覆盖 CEL 逻辑错误、Unicode、timestamp 与深链；审查反例已固化为三后端测试，见
[差分报告](docs/conformance.md)。性能实测与复现命令见
[performance.md](docs/performance.md)。

## 覆盖矩阵

| 能力 | 状态 | 说明 |
| --- | --- | --- |
| Schema 1.1 DSL | 支持 | `model`、`schema 1.1`、`type`、`relations`、`define`、`[user, group#member, user:*, user with cond]`、`or` / `and` / `but not`、括号、computed userset、tuple-to-userset、`condition`、注释 |
| AuthorizationModel JSON | 支持 | 导入、导出；`schema_version`、`type_definitions`、`relations`、`metadata.relations`、`conditions` |
| 模型校验 | 支持 | 未知类型/关系、元组限制、禁止的循环、重复定义、条件参数类型；错误带行列位置 |
| 元组存储 | 支持 | 内存索引（按 `object#relation`、按 user）、写入/删除、上下文元组覆盖层、`TupleReader` trait |
| Check | 支持 | 完整 Check 请求深度预算 25、终端 join 不额外 dispatch、computed alias 迭代折叠、循环检测、通配符、union/intersection/difference 短路、TTU、条件求值 |
| BatchCheck | 支持 | 进程内批量执行，逐项返回结果或错误 |
| ListObjects / ListUsers | 支持 | 反向对象证明 / 用户集合展开、独立深度与条件错误传播、wildcard、userset 过滤器、contextual 合并语义 |
| Expand | 支持 | 返回关系重写树 |
| Explain | 支持 | 返回允许/拒绝的解析路径（`--explain`，Playground 里画成树） |
| CEL 子集 | 支持 | `int` / `uint` / `double` / `bool` / `string` / `duration` / `timestamp` / `list` / `map` / `ipaddress`，运算符、三元表达式、`exists` / `exists_one` / `all` / `map` / `filter`、常用字符串/时间/网络方法 |
| CLI | 支持 | `validate`、`transform`、`check`、`list-objects`、`list-users`、`expand`、`test` |
| `.fga.yaml` 测试 | 支持 | `model` / `model_file`、全局与用例元组、Check / ListObjects / ListUsers 断言、`errorCode` |
| ReadChanges | 不支持 | 内存存储没有变更日志 |
| FGA Modules | 不支持 | `module` / `extends` 语法与模块合并未实现；单文件模型可完整使用 |
| 持久化存储 / HTTP / gRPC | 不支持 | 只提供可嵌入的内存引擎和 CLI，持久化需要调用方自己封装 |
| 分页、consistency preference | 不支持 | List 接口一次返回全部结果 |

## Playground

页面是纯静态的（HTML + CSS + 原生 JS，无框架、无 CDN），引擎由 `playground/` 包编译到 JS。
左边编辑模型（DSL 或 JSON）和元组，错误会标到具体行；右边查询 Check / ListObjects / ListUsers，
Check 的解析路径画成树（解释不完整时结果旁标出 Incomplete），Tests 标签页直接运行 `.fga.yaml`。内置 GitHub、Drive、ABAC 三个示例。

本地构建并打开：

```bash
scripts/build-web.sh
node web/smoke.mjs                  # 对内置示例做冒烟断言
python3 -m http.server -d web/dist  # 然后访问 http://localhost:8000
```

`playground` 包导出 7 个函数，输入输出都是 JSON 字符串，错误以 `{"ok":false,"error":{...}}`
返回，不抛异常：`validate_model`、`dsl_to_json`、`json_to_dsl`、`check`、`list_objects`、
`list_users`、`run_tests`。请求字段见 [`playground/api.mbt`](playground/api.mbt) 的注释。
`.fga.yaml` 在浏览器里必须用内联的 `model:`；`storetest` 只负责解析和运行，`model_file` 由调用方提供读取函数（CLI 会提供）。

推送到 `main` 后，[`pages.yml`](.github/workflows/pages.yml) 会构建、跑冒烟测试并发布到 GitHub Pages。

## 安装与构建

在已有 MoonBit 模块中安装：

```bash
moon add sundaysebasidian-byte/moonfga@0.1.0
```

从源码构建：

```bash
git clone https://github.com/sundaysebasidian-byte/moonfga
cd moonfga
export PATH="$HOME/.moon/bin:$PATH"
moon check --deny-warn
moon test
```

三个后端都能跑测试：

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

最小示例（完整版本见 `examples/library/main.mbt`）：

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

运行：

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

元组文件支持三种格式：JSON 数组、YAML（`tuples:`），以及每行一条 `object#relation@user` 的文本；
带条件时写作 `document:1#viewer@user:anne[in_ip:{"ip":"10.0.0.1"}]`。

## 一致性测试复现

上游测试数据不提交到仓库。`scripts/fetch-upstream.sh` 按固定 commit 把它下载到被
`.gitignore` 忽略的 `.upstream/`，数据的许可证是 Apache-2.0。

```bash
scripts/fetch-upstream.sh          # 首次运行，固定 commit
./scripts/conformance.sh           # 运行两个矩阵并检查 95/90 阈值
moon run cmd/language              # DSL <-> JSON 夹具，29/29
```

`./scripts/conformance.sh` 会在 `conformance-results/` 写入 `summary.txt` 和 `summary.json`
（均被忽略）；Check 低于 95% 或 ListObjects/ListUsers 低于 90% 时返回非零退出码。
逐断言结果见 [`docs/conformance.md`](docs/conformance.md)。

## 与 jhshuai/moonpolicykit 的区别

MoonFGA 是独立的 OpenFGA 兼容实现，没有复用 `moonpolicykit` 的代码，也不以它的超集为目标。
区别在验收方式和范围：

- MoonFGA 直接回放 OpenFGA 官方 Check / ListObjects / ListUsers / ABAC 测试矩阵，
  兼容性由上游用例定义，而不是自定义语义。
- 覆盖 OpenFGA schema 1.1 的 DSL、AuthorizationModel JSON、条件关系和 `.fga.yaml` 测试格式。
- 自带 OpenFGA 语义的 CEL 子集（含 `timestamp`、`duration`、`ipaddress`），不依赖通用策略表达式引擎。
- `moonpolicykit` 是另一个 MoonBit 策略/授权项目，它的能力与 API 以该项目文档为准；
  两者不是替代关系。

## 限制与路线图

明确不支持：FGA modules、ReadChanges、持久化/分布式存储、HTTP/gRPC 服务端、分页与
consistency preference、完整 CEL 标准库（如 `bytes`、正则捕获组等）。

后续优先级：

1. 可插拔持久化存储与变更日志（ReadChanges）。
2. 服务端 API（HTTP/gRPC）与一致性偏好。
3. FGA modules 与模块级校验。
4. 扩展 CEL 标准库，错误定位更细。

## 许可证

Apache-2.0，见 [`LICENSE`](LICENSE) 和 [`NOTICE`](NOTICE)。上游一致性测试数据只在本地按固定 commit
下载，不随仓库分发。
