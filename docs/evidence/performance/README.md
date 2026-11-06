# 0.2.2 性能证据

- [方法、适用范围与缓存边界](../../performance.md)
- [逐项结果表](final-20261106/results.md)
- `final-20261106/environment.json`：实测引擎 commit、源码/夹具 SHA-256、机器与工具版本。
- `native.json`、`js.json`、`wasm-gc.json`：每后端 198 个操作进程（3 规模 × 11 形状 × 6 操作），含失败项；时间单位 µs。
- 每行 `samples` 的 iteration 0–4 为预热，5–34 为正式请求；`count` 是校验过的结果数量。
- `graph_us[i]` 与 ListObjects 已完成的 `samples[i]` 按索引对齐；超时可能多出一个尚未完成请求的构图时间。单请求构图占比为两者之比；汇总 `graph_fraction` 只用正式样本。
- `latency_us` 用 nearest-rank；30 样本的 p99 是最大值。吞吐为正式请求数 / 正式耗时之和。
- `peak_rss_bytes` 是 time -l 的进程高水位；JS `process_memory_usage` 是输出边界采样峰值和最终快照。
- `status: 未完成` 保留原因、可捕获输出和部分样本，不生成完整分位数。60 秒是包括夹具生成的整组预算，不能推断单请求超过 60 秒；缓冲输出可能使部分样本不可见，终止 time 时 RSS 也不可得。
- `build-*.json` 是 release 构建记录。隔离计时代码由脚本生成，未进入发布引擎。
- [validation.json](validation.json)：要求的检查、测试与 web smoke 的命令、退出码和输出。Windows 设备性能/运行未验证。

复现：`./scripts/bench-scale.sh docs/evidence/performance/new-run --timeout 60`，
再用 `python3 scripts/bench_report.py docs/evidence/performance/new-run` 生成表。
依赖必须已缓存；生成器与构建不需要网络。此入口不在 CI 执行；部分项未完成时继续采集，是否完成须读取每行 status，不能只看入口退出码。
