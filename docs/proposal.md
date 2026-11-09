# MoonFGA 申报书

- 项目名称：MoonFGA；仓库：https://github.com/sundaysebasidian-byte/moonfga
- 在线体验：https://sundaysebasidian-byte.github.io/moonfga/

## 解决什么问题，给谁用

应用要回答“这个用户能不能操作这个资源”，而组织、团队、文件夹层层嵌套时，权限规则很快散落在业务代码里。OpenFGA（Zanzibar 风格的授权系统）用一份模型加一批关系元组把规则集中起来，但它以独立服务运行。MoonFGA 是兼容它的内存引擎，可以直接嵌入 MoonBit 应用：不起服务、不连数据库，native、wasm-gc、JavaScript 三个后端都能构建和测试，也能在浏览器里运行。

## 规范覆盖矩阵

兼容目标：OpenFGA Schema 1.1 的建模语言（DSL）、JSON 模型，以及 Check / BatchCheck / ListObjects / ListUsers / Expand 的语义，以官方 v1.22.1 测试矩阵和同版本官方二进制为准；不跟踪 v1.22.1 之后新增的服务端特性。各项状态与验证边界见[逐项对比](openfga-comparison.md)。

| 范围 | 状态 | 说明 |
| --- | --- | --- |
| Schema 1.1 DSL 与 JSON 互转、模型校验（带行列） | 已支持 | openfga/language 单文件夹具 29/29；模块成功转换 2/2、完整诊断 4/4，fga.mod 9/9 |
| 内存元组存储、上下文元组、`TupleReader` 扩展接口 | 已支持 | 宿主可实现自己的存储 |
| Check（深度 25、循环检测、通配符、并交差、TTU）、BatchCheck、ListObjects、ListUsers、Expand、解析路径 Explain | 已支持 | Check 516/516，ListObjects 354/354，ListUsers 393/394 |
| 条件（ABAC）：自研 CEL 实现 | 已实现主要表面，保留已知差异 | 模型期类型检查、bytes、转换、类型反射、异构容器/宏、默认 protobuf well-known 对象、时间/时区、无回溯正则、默认 cost 与宿主中断；逐函数证据见对比文档 |
| CLI（validate / transform / check / list-objects / list-users / expand / test）、`.fga.yaml` 测试运行器 | 已支持 | 浏览器 Playground 使用同一引擎 |
| CEL 完整兼容 | 未验收通过 | Local 依赖宿主时区；Local 已可显式配置；服务请求期限需宿主接入，资源成本尚无全部输入等价证明，不声明完整兼容 |
| FGA Modules（`module` / `extend type` / `fga.mod`） | 已支持 | schema 1.2；宿主传入文件内容并合并，保留 module / source_info；CLI 安全文件读取限 native（POSIX）/ JS；0.2.1 完整比较官方 24 条诊断（含 0-based 行列、文件和错误类型）；官方成功转换 2/2、完整诊断 4/4、fga.mod 9/9；06 因上游缺少模块源文件仅 JSON 往返 |
| ReadChanges | 明确不支持 | 内存存储没有变更日志；只服务于同步服务端数据的场景 |
| 持久化、HTTP / gRPC 服务端 | 明确不支持 | 属于产品定位：只做可嵌入的引擎，存储由宿主通过 `TupleReader` 提供 |
| 分页 | 明确不支持 | List 接口一次返回全部结果 |
| consistency preference | 宿主接口等价 | TupleReader 提供所需快照，无副本路由 |

## 兼容终点

条件的终点是 OpenFGA v1.22.1 实际 cel-go 环境的完整行为：标准类型与函数、宏、模型编译拒绝、上下文转换、错误与 partial evaluation，以及 ipaddress 扩展。bytes 是表达式能力，官方不提供 bytes 参数枚举；默认 protobuf well-known 对象及 Any 解码在范围内，任意应用消息描述符和扩展函数库未在该环境注册。

0.2.3 已补齐模型类型检查、转换与类型反射、异构 map/list 和宏、默认 protobuf well-known 对象、时间 getter/时区，以及无回溯正则。新差分同时比较模型拒绝、求值错误类别和结果，并在两个种子运行；不能以固定语料通过代替全部输入的兼容性证明。第二轮已补入独立审查反例与词法、正则、map 键、默认预算和解析深度边界回归。

官方实测：缺少已声明参数时，即使条件为 true 也返回 E2000；动态整数与 double 比较存在 cel-go 的舍入行为。实现按这些结果对齐。Local 宿主配置、正则资源策略和服务期限的具体边界仍见 [逐函数对比](openfga-comparison.md#host-boundaries-and-remaining-verification-limits)。未配置 Local 时仍报错；服务期限与中断由宿主接入。服务端、认证、ReadChanges 和分页明确不做，consistency 由宿主 reader 快照实现；不声明完整兼容。

## 和 OpenFGA 结果一致的证据

- 官方 v1.22.1 测试矩阵：Check 516/516，ListObjects 354/354，ListUsers 393/394。唯一的跳过是上游用例把期望值嵌在 request 里，没有顶层断言，如实记为 skip。
- 和官方 v1.22.1 二进制随机差分：两个 seed 共 6570 次比较，0 不一致；另有 204 组定向用例。条件语料两个种子各 6662 个模型，结果及错误类别均 0 不一致。
- 复现：`scripts/fetch-upstream.sh` 下载固定 commit 的数据，`./scripts/conformance.sh` 跑全部矩阵。

## 与 moonpolicykit 的区别

mooncakes 上的 `jhshuai/moonpolicykit` 只提供通用 ReBAC 原语，不兼容 OpenFGA 的建模语言、API 语义和官方测试。MoonFGA 独立实现，不含其代码，以 OpenFGA 官方测试定义兼容性。

## 基础、本期工作与参考来源

2026-10-31 新建仓库，此前没有代码基础；仓库全部提交均为本期工作。技术路线：DSL 递归下降解析 → 模型校验 → 索引元组存储 → 带深度与循环检测的重写求值；CEL 求值器自研，因为现有 `moon_cel` 不支持 timestamp / duration / ipaddress。

原创实现，本项目 Apache-2.0。参考 OpenFGA（https://github.com/openfga/openfga ，Apache-2.0）的语义与测试矩阵、openfga/language（https://github.com/openfga/language ，Apache-2.0）的语法与转换夹具，均按固定 commit 运行时下载、不入库；依赖 moonbit-community/yaml（MIT）。详见 NOTICE。
