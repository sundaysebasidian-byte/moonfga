# 0.1.1 本地验证

2026-11-01，macOS arm64，工具版本见 ../scale-optimized/environment.json。
所有命令实际执行；未 push / publish / 打 tag。`commands.sh` 提供复现命令，
`commands.txt` 为必跑检查、Web、CLI 与随机差分的完整输出，补测另存文件。

| 检查 | 结果 |
| --- | --- |
| moon check --deny-warn --target all | 通过，四后端 |
| moon test --target all | wasm / wasm-gc / js / native 各 183/183 |
| moon fmt --check | 通过 |
| moon info；git diff --exit-code -- '*.mbti' | 通过；既有接口无差异 |
| ./scripts/conformance.sh | Check 516/516；ListObjects 354/354；ListUsers 393/394，1 个既有 no_expectation skip |
| native / wasm 补测矩阵 | 同上，见 matrix-*.txt |
| JS 引擎矩阵（argv 适配启动器） | 同上，见 matrix-js-normalized.txt |
| scripts/build-web.sh；node web/smoke.mjs | 构建成功，36/36 checks |
| node scripts/test-explain.mjs | CLI / JS decision、witness、complete 一致 |
| README CLI 与 library example | validate、双向 transform、check、list-objects、list-users、expand、ABAC、库嵌入均成功 |
| basic / abac YAML suites | 分别 7/7、3/3 assertions |
| moon run cmd/language | 29/29 |
| 固定 OpenFGA v1.22.1 oracle，seed 314159 / 271828 | 各 1095 cases、3285 comparisons、0 mismatches |
| 定向官方二进制差分 | 204 cases、612 comparisons、0 mismatches |
| TupleReader 宿主契约 | 四后端各 3/3，包含空读取与失败拒绝创建快照 |

公共引擎、存储及 TupleReader API 没有变化；新增示例包公开 Snapshot / load_snapshot，
用于展示宿主可复用的快照适配器，因此新增示例自己的 pkg.generated.mbti。
图优化没有跨请求缓存；新增回归覆盖写、删、clear、contextual tuples 请求隔离、循环和 userset identity。

已知限制：直接 `moon run --target js cmd/conformance` 的旧 CLI 参数处理把 Node 的脚本路径
当成 YAML 输入，产生 0/0；这次补测不将其记为通过。保留 matrix-js.txt 原始失败输出，
独立 matrix-js-launcher.cjs 将 Node argv 规范为现有 CLI 约定后，实际 JS 引擎完整矩阵通过。
未扩大本次改动去调整现有 CLI 参数接口。必跑默认命令与 README CLI 检查没有该问题。

性能是合成图的单机采样，Check 未改动。保留内存增幅和高扇出退化，详见 ../scale-results.md
及 ../../performance.md。当前 0.1.1 尚未发布，线上包仍为 0.1.0。
