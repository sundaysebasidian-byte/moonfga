# MoonFGA 申报书

- 项目名称：MoonFGA；仓库：https://github.com/sundaysebasidian-byte/moonfga
- 在线体验：https://sundaysebasidian-byte.github.io/moonfga/

## 解决什么问题，给谁用

应用要回答“这个用户能不能操作这个资源”，而组织、团队、文件夹层层嵌套时，权限规则很快散落在业务代码里。OpenFGA（Zanzibar 风格的授权系统）用一份模型加一批关系元组把规则集中起来，但它以独立服务运行。MoonFGA 是兼容它的内存引擎，可以直接嵌入 MoonBit 应用：不起服务、不连数据库，native、wasm-gc、JavaScript 三个后端都能构建和测试，也能在浏览器里运行。

## 规范覆盖矩阵

兼容目标：OpenFGA Schema 1.1 的建模语言（DSL）、JSON 模型，以及 Check / BatchCheck / ListObjects / ListUsers / Expand 的语义，以官方 v1.22.1 测试矩阵和同版本官方二进制为准；不跟踪 v1.22.1 之后新增的服务端特性。状态只有两种：已支持、明确不支持。

| 范围 | 状态 | 说明 |
| --- | --- | --- |
| Schema 1.1 DSL 与 JSON 互转、模型校验（带行列） | 已支持 | openfga/language 夹具 29/29 |
| 内存元组存储、上下文元组、`TupleReader` 扩展接口 | 已支持 | 宿主可实现自己的存储 |
| Check（深度 25、循环检测、通配符、并交差、TTU）、BatchCheck、ListObjects、ListUsers、Expand、解析路径 Explain | 已支持 | Check 516/516，ListObjects 354/354，ListUsers 393/394 |
| 条件（ABAC）：自研 CEL 子集 | 已支持，范围见下 | 类型 int / uint / double / bool / string / duration / timestamp / list / map / ipaddress；运算符、三元表达式、`exists` / `all` / `map` / `filter`、常用字符串 / 时间 / 网络方法 |
| CLI（validate / transform / check / list-objects / list-users / expand / test）、`.fga.yaml` 测试运行器 | 已支持 | 浏览器 Playground 使用同一引擎 |
| CEL 未覆盖的部分（`bytes`、正则捕获组、其余标准库函数） | 明确不支持 | 使用它们的条件在求值时返回错误码 E2000，不会当作 false；不使用它们的条件不受影响 |
| FGA Modules（`module` / `extend type` / `fga.mod`） | 明确不支持 | 影响：按模块拆成多个文件的模型需要调用方先合并成单文件，单文件模型完整可用。本期不实现，需要多文件加载接口，与嵌入式库的宿主回调设计一并规划 |
| ReadChanges | 明确不支持 | 内存存储没有变更日志；只服务于同步服务端数据的场景 |
| 持久化、HTTP / gRPC 服务端 | 明确不支持 | 属于产品定位：只做可嵌入的引擎，存储由宿主通过 `TupleReader` 提供 |
| 分页、consistency preference | 明确不支持 | 内存快照单一一致，List 接口一次返回全部结果 |

## 和 OpenFGA 结果一致的证据

- 官方 v1.22.1 测试矩阵：Check 516/516，ListObjects 354/354，ListUsers 393/394。唯一的跳过是上游用例把期望值嵌在 request 里，没有顶层断言，如实记为 skip。
- 和官方 v1.22.1 二进制随机差分：两个 seed 共 6570 次比较，0 不一致；另有 204 组定向用例。
- 复现：`scripts/fetch-upstream.sh` 下载固定 commit 的数据，`./scripts/conformance.sh` 跑全部矩阵。

## 与 moonpolicykit 的区别

mooncakes 上的 `jhshuai/moonpolicykit` 只提供通用 ReBAC 原语，不兼容 OpenFGA 的建模语言、API 语义和官方测试。MoonFGA 独立实现，不含其代码，以 OpenFGA 官方测试定义兼容性。

## 基础、本期工作与参考来源

2026-10-31 新建仓库，此前没有代码基础；仓库全部提交均为本期工作。技术路线：DSL 递归下降解析 → 模型校验 → 索引元组存储 → 带深度与循环检测的重写求值；CEL 子集自研，因为现有 `moon_cel` 不支持 timestamp / duration / ipaddress。

原创实现，本项目 Apache-2.0。参考 OpenFGA（https://github.com/openfga/openfga ，Apache-2.0）的语义与测试矩阵、openfga/language（https://github.com/openfga/language ，Apache-2.0）的语法与转换夹具，均按固定 commit 运行时下载、不入库；依赖 moonbit-community/yaml（MIT）。详见 NOTICE。
