# MoonFGA 提案
- GitHub：https://github.com/sundaysebasidian-byte/moonfga
- Gitlink：TODO(用户填写)
## 目标
在 MoonBit 上实现与 OpenFGA 兼容的关系型授权（ReBAC）引擎，以官方一致性测试验收，
并可在 native / wasm-gc / JavaScript 后端运行。
## 交付范围
Schema 1.1 DSL 与 AuthorizationModel JSON 双向转换；带位置的模型校验；内存元组存储；
Check / BatchCheck / ListObjects / ListUsers / Expand / Explain；自研 CEL 子集
（int/uint/double/bool/string/duration/timestamp/list/map/ipaddress）；CLI 与
`.fga.yaml` 测试运行器。
## 覆盖矩阵摘要
- Check：516/516（consolidated 364，ABAC 152）。
- ListObjects：354/354（consolidated 272，ABAC 82）。
- ListUsers：393/394（consolidated 296/297，ABAC 97；1 个上游断言缺顶层期望值，记为 skip）。
- DSL ↔ JSON：openfga/language 夹具 29/29。
## 明确不支持
FGA modules（`module` / `extends`）、ReadChanges、持久化/分布式存储、HTTP/gRPC 服务端、
分页与 consistency preference、完整 CEL 标准库（如 `bytes`）。
## 差异化
独立实现、按上游矩阵验收，覆盖完整 schema 1.1 条件关系与 `.fga.yaml` 测试；不基于
`jhshuai/moonpolicykit` 代码，两者定位与验收标准不同。
## 复现
`scripts/fetch-upstream.sh` 下载固定 commit 的 Apache-2.0 测试数据；`./scripts/conformance.sh`
运行全部矩阵并执行 95/90 阈值；`moon run cmd/language` 运行转换夹具。
