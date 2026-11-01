# 查询性能实测

## 0.1.1 规模实验

完整 p50 / p95 / max、峰值 RSS、图构建占比见 [测量表](evidence/scale-results.md)。
原始逐请求 CSV、`time -l` 输出和工具版本分别保存在 `evidence/scale-baseline/` 与
`evidence/scale-optimized/`。下文旧实验保留作为历史记录。

固定种子 20261101，元组总数严格为 10,000 / 100,000 / 1,000,000；
每个规模有低（10 个 document）、中（总数 1%）、高（总数 50%）扇出。
每个 document 都连接 group:19#member，20 层 group 到 user:alice；
其余元组是不同 group 对 997 个种子生成的无关用户的成员关系。
这些是合成数据，不代表生产流量、复杂模型或跨平台性能。

每组独立 release 进程，Check 和 ListObjects 各预热 3 次，再逐请求采集 30 次。
Check 为 document:0 的深链命中；ListObjects 返回精确的全部 document，
每次都校验结果数量（校验在计时外）；完整集合语义由矩阵与差分验证。p50/p95 用 nearest-rank，max 不剔除异常。
单请求分位数不是原有 core/bench 的自适应批次均值，不可直接混比。

测量脚本仅在 `.upstream/perf-<label>` 的隔离源码里加入 core/bench 单调时钟：
图构建从创建 edges 开始，直到 incoming/outgoing 索引完成；占比为 30 次
图构建耗时之和 / ListObjects 总耗时之和。ListObjects 计时含一个阶段输出的开销。
RSS 是 macOS `/usr/bin/time -l` 的整个子进程高水位，包含建模、元组生成、
索引及查询，并非图的增量内存；JS 包含 V8 和 GC。没有测导入延迟或单独图分配量。
同机顺序执行两版本；机器还有其他任务，JS 长尾不删除，30 样本的 p95 仍较粗糙。
Check 代码未修改，也不据这些测量宣称 Check 加速；小规模样本及 JS 高扇出的
Check 分布有波动，说明单次前后实验仍受主机状态影响。

复现（macOS arm64，Moon 与 Node 版本见环境 JSON）。仓库已提交 `baseline` 与 `optimized` 两组证据，本地复跑请换用新 label，例如：

```sh
export PATH="$HOME/.moon/bin:$PATH"
python3 scripts/performance.py rerun-baseline --engine-ref a769ecf
python3 scripts/performance.py rerun-optimized
python3 scripts/performance_report.py
```

首次运行若同名目录已有证据会拒绝覆盖；中断后用 `--resume`，继续原隔离源码的未完成数据组。
label 若改名，相应修改报告脚本读取的目录名。脚本生成数据，无需下载数据集。
`scale-before*` 保留早期测量器编译失败输出，不是性能样本；后续修正为直接读取
命令行末尾两个参数，以适配 native 与 Node 不同的 argv 前缀。

### 实现选择

低、中扇出基线的图构建占绝大多数 ListObjects 时间。0.1.1 改为从请求类型
的根关系出发，只构建其传递依赖中的关系节点；仍以 reader 的对象清单为准，
每个相关类型的对象清单只读取一次并建立存在性索引，避免深链上的重复线性扫描。
结果排序、条件求值、非单调关系的残余 Check 和深度语义保留。

native 的低、中扇出 ListObjects p50 降低 52.2–71.2%；百万元组低扇出
358.56 → 163.02 ms，中扇出 377.82 → 180.59 ms，因此保留这项局部优化。
高扇出并无一致收益：1 万元组快约 2.1%，10 万、100 万元组分别慢约 5.2%、8.1%。
百万低扇出的进程峰值 RSS 从 534.6 增至 607.8 MiB（约 +13.7%），
这是建立请求范围存在性索引的代价，不能宣称内存优化。
JS 百万低、中扇出的 RSS 由约 1011 / 954 MiB 增至约 2279 / 2581 MiB，
涉及 V8 分配与回收策略，内存受限宿主须实际验证预算。JS 高扇出基线
还存在明显长尾，不能将前后差异全部归因于这次构图改动。

没有增加跨请求缓存：现有 TupleReader 无版本/错误通道，模型还可被宿主修改，
缓存会要求扩展公共契约并管理 contextual tuples 等请求状态。当前优化每次读取当前
快照；写、删、clear、contextual tuples 隔离及循环均有回归测试。
最坏情况仍需枚举相关类型对象与可达关系，密集全相关图不保证加速。

验收与已知宿主限制见 [0.1.1 验证记录](evidence/0.1.1-validation/README.md)。

## 历史测量

2026-10-31，macOS arm64，Moon 0.1.20261028 (e1e1f15)，native release benchmark。
使用 core/bench 自适应批次，每项 10 个样本；同机顺序执行前后测量，未并发运行 oracle。
建模、写入和正确性断言在计时之外；不是端到端导入性能或内存峰值测量。

数据：100,000 条元组，其中 10,000 个 document 各指向 group:9#member，
group:9 到 group:0 共 10 个 group，再到 user:alice；其余 89,990 条为无关 group。
Check 查询 document:0；ListObjects 返回全部 10,000 个 document。

| 查询 | 优化前 mean ± sigma | 优化后 mean ± sigma | mean 降幅 |
| --- | ---: | ---: | ---: |
| Check | 7.88 µs ± 127.63 ns | 4.92 µs ± 95.90 ns | 37.6% |
| ListObjects | 79.63 ms ± 1.60 ms | 49.52 ms ± 1.61 ms | 37.8% |

原始输出：evidence/bench-before.txt、evidence/bench-after.txt。
前测使用 9f29dc4 的引擎/存储及相同 benchmark 源码；优化提交 6f5672a。
主要热点是每条 userset 边重复解析用户字符串，改为一次解析后用于类型限制和遍历。
同时给候选对象枚举加类型索引。仅添加类型索引的中间试验未出现超过噪声的显著收益；
表中数字是两项优化一起的结果，不单独归因给索引。

复现当前版本：

```bash
export PATH="$HOME/.moon/bin:$PATH"
moon bench --target native -p benchmarks
```

复现基线可在本仓库内的独立缓存目录重建已提交源码（保留原工作区）：

```bash
mkdir -p .upstream/benchmark-baseline
git archive 9f29dc4 | tar -x -C .upstream/benchmark-baseline
cp -R benchmarks .upstream/benchmark-baseline/
(cd .upstream/benchmark-baseline && moon bench --target native -p benchmarks)
```

机器负载、编译器及运行时版本会影响数字；没有测 Windows/Linux 性能。
未增加全局结果缓存：结果依赖条件、请求上下文、深度和循环路径，盲目共享缓存会改变语义。

## List 语义对齐后复测

对齐 v1.22.1 List 语义后，用上述相同数据和命令重新执行：
Check 4.59 µs ± 150.53 ns，ListObjects 44.27 ms ± 2.00 ms，两个 benchmark 均通过。
原始输出见 evidence/bench-list-graph.txt。此为当前代码的另一次实测，
不把与首轮测量的差值单独归因于这次语义修复。

## 反向对象证明后复测

改为反向对象证明后，在同一 10 万元组 / 10 层 group 数据上重跑：
Check 4.36 µs ± 97.39 ns；ListObjects 39.20 ms ± 678.66 µs；benchmark 2/2。
原始输出见 evidence/bench-depth-budget.txt。每次 ListObjects 请求构造反向图，
此样本不代表大型多关系图的峰值内存或所有查询分布。

## 深度预算修复后复测

同一命令、相同 10 万元组 / 10 层 group 数据，benchmark 两次均为 2/2：
首测 Check 22.90 µs ± 8.20 µs，ListObjects 263.99 ms ± 27.49 ms；
复测 Check 4.44 µs ± 99.97 ns，ListObjects 39.24 ms ± 633.82 µs。
两次原始输出分别见 evidence/bench-depth-final.txt、evidence/bench-depth-final-repeat.txt。
复测前机器 load averages 实测 16.75 / 21.54 / 17.18，首测也有较大样本波动；
不丢弃这组异常样本，也不将测量差异单独归因于代码变化。
本轮没有改变基准数据或计时边界，没有据此宣称性能提升。
