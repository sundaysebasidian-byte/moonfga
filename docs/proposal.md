# MoonFGA 提案

- 在线体验：https://sundaysebasidian-byte.github.io/moonfga/
- GitHub：https://github.com/sundaysebasidian-byte/moonfga

## 解决什么问题，给谁用
应用要回答"这个用户能不能操作这个资源"，而组织、团队、文件夹层层嵌套时，权限规则很快散落在业务代码里。
OpenFGA（Zanzibar 风格的授权系统）用一份模型加一批关系元组把规则集中起来，但它以独立服务运行。
MoonFGA 是兼容它的内存引擎，可以直接嵌入 MoonBit 应用：不起服务、不连数据库，
native、wasm-gc、JavaScript 三个后端都能构建和测试，也能在浏览器里运行。

## 和 OpenFGA 结果一致的证据
- 官方 v1.22.1 测试矩阵：Check 516/516，ListObjects 354/354，ListUsers 393/394。
  唯一的跳过是上游用例把期望值嵌在 request 里，没有顶层断言，如实记为 skip。
- DSL ↔ JSON 夹具（`openfga/language`）29/29；和官方 v1.22.1 二进制随机差分：两个 seed 共 6570 次比较，0 不一致；
  CEL 错误、Unicode、timestamp、List 深度及 Explain 反例已固化为三后端回归测试。
  复现：`scripts/fetch-upstream.sh` 下载固定 commit 的数据，`./scripts/conformance.sh` 跑全部矩阵。

## 覆盖矩阵
支持：Schema 1.1 DSL 与 JSON 模型互转、带行列的模型校验、内存元组存储、
Check / BatchCheck / ListObjects / ListUsers / Expand / 解析路径 Explain、
自实现 CEL 子集（条件关系，含 timestamp / duration / ipaddress）、CLI、`.fga.yaml` 测试运行器，
以及同一个引擎编译成 JS 的浏览器 Playground（Check 的解析路径画成树）。

## 明确不支持
FGA modules（`module` / `extends`）、ReadChanges、持久化/分布式存储、HTTP/gRPC 服务端、
分页与 consistency preference、完整 CEL 标准库（如 `bytes`）。

## 与 moonpolicykit 的区别
独立实现，不含 `jhshuai/moonpolicykit` 的代码；MoonFGA 以 OpenFGA 官方测试定义兼容性。
