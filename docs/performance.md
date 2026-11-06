# 查询性能实测

## 0.2.2：查询形状与缓存边界

本轮仅增加测量，没有添加缓存或优化引擎。基准源提交为 `695ce55`；
本次 0.2.2 工作版本的引擎源码相同。数据、环境和完整逐场景表见
[`performance/final-20261106`](evidence/performance/final-20261106/)。
历史 0.1.1 数字使用不同编译器和夹具，不能作为本轮加速对照。

### 方法与复现

```sh
export MOON_HOME=/tmp/moon-new PATH=/tmp/moon-new/bin:$PATH
./scripts/bench-scale.sh docs/evidence/performance/my-run --timeout 60
python3 scripts/bench_report.py docs/evidence/performance/my-run
```

此入口不被 CI 调用。需要本地已安装 Moon 0.1.20261104、Node、Python 3、
已缓存项目依赖（构建使用 `--frozen`），以及 macOS 的 `sysctl` / `/usr/bin/time -l`；不下载数据或调用网络。
入口拒绝覆盖已有输出。可以用 `--targets native js wasm-gc` 和 `--sizes` 缩小复跑范围。
可用 `--shapes group20 --operations objects_many --sizes 1000000 --timeout 180`
单独延长昂贵场景的整组预算；本轮未把 60 秒未完成解释成无法在更长预算内完成。
生成的隔离构建在 `.upstream/scale-<输出目录名>/`；不要让不同运行共用同名目录。
Windows 的性能未测；本轮不修改 `host/paths.c`。所有报告均为 release，未测 debug。

存储仅用 `MemoryStore` 的内存索引，不包含外部 TupleReader 的数据库或网络 I/O。
每个规模严格为 10,000 / 100,000 / 1,000,000 条元组，种子为 20261106 的
32 位 LCG 生成无关用户。约一半元组属于活跃查询，其余为不同 noise group 的成员关系；
不是全部相关的最坏情况。11 个形状包括直接关系（每对象 4 / 16 / 128 用户）、
2 / 20 层嵌套 group、2 / 20 层 parent/TTU、`user:*`、CEL 时间条件、
`but not`、交集。用户扇出随活跃 document 数增长；group/TTU 共享同一条链，
因此不能据此推断大量互不共享深链的成本。深度指生成的 group/parent 节点数。

每个形状分别运行 Check 命中/不命中、ListObjects 多结果/稀少结果、
ListUsers 多结果/单结果，共 6 个独立进程。ListUsers 多结果为 4、16、128 个用户，
不是十万用户枚举；ListObjects 多结果随规模增长。通配符的 ListUsers 返回一个
符号 `user:*`，不枚举无限用户；其 Check 不命中探针仍命中，稀少对象探针也会命中
全部 wildcard document，这是通配符语义，不能当作低命中测量。其他形状稀少对象探针返回 1。
每次请求都校验结果数量（不替代集合级语义矩阵）。CEL 在固定 `hour=10` 下命中，
未覆盖复杂表达式、错误条件或多上下文分布。差集的 blocked 用户与查询用户不同；
交集两分支为同一成员集合，测量残余 Check 成本，不代表大比例过滤场景。

每操作 5 次预热 + 30 次正式请求，原始 JSON 包含全部预热和样本；
nearest-rank p50/p95/p99，不剔除长尾，30 样本的 p99 就是最大值，
不能作为生产 p99 的稳定估计。吞吐为 30 / 查询耗时总和，是单进程顺序吞吐，
不含建模、导入、进程启动或输出序列化。每进程 60 秒预算包括建模与生成；
超时会终止该进程组，time 同时被终止时 RSS 高水位不可得，不能据此判定内存是否足够。保留已捕获样本并标为“未完成”（native 管道输出可能缓冲，0 样本不证明第一次请求未完成），不以部分样本冒充完整分位数。

构图计时仅在隔离源码加入单调时钟：从创建 edges 前到 incoming/outgoing 建索引后，
不含反向可达性裁剪、证明传播、残余 Check、结果排序。每次 ListObjects 均重新构图；
原始 `graph_us[i]` 对应已完成的 `samples[i]`（超时可能多出未完成请求的构图计时），可计算每次请求的构图比例，汇总比例为
正式构图耗时之和 / 正式请求耗时之和。ListObjects 总耗时包含构图计时和一行输出开销；
Check/ListUsers 没有构图输出。计时/分配采样有扰动，不据此宣称引擎加速。

native/JS/wasm-gc 均记录 macOS time 的整个进程 RSS 高水位，包括数据生成、索引和运行时，
并非图增量内存。JS 另在每次 console 输出时用 `process.memoryUsage()` 采样并保存
rss/heapUsed/external 最大值与最终值；这是采样峰值，可能漏掉请求内部瞬时峰值，
实际进程高水位以 time 的 RSS 为准。机器型号、核数、内存、OS、工具版本、源码 hash
在 environment.json。后端顺序运行，同机其他任务仍会干扰；校验命令与本轮前段采集有短暂重叠。
这是单机合成实验，不代表 Windows/Linux、并发服务或持久存储吞吐。

### 数值结论

以下以 **单请求 p95 ≤ 100 ms** 作为讨论用预算，不是产品承诺。
逐项 p50/p95/p99、吞吐、结果数、RSS 与构图占比见完整表；未完成项不纳入范围统计。

native 的 1 万元组 66/66 操作进程完成，22 个 ListObjects 探针的 p95 均在
0.736–13.706 ms；10 万元组仍为 66/66，但 ListObjects p95 达到
8.802–197.995 ms，只有 12/22 个探针符合上述预算。
百万规模完成 56/66；group2/group20/ttu2/ttu20/wildcard 的两种 ListObjects
均未在整组 60 秒预算内完成。其余 12 个 ListObjects 探针 p95 为
81.074–938.403 ms，仅 fan128 的两个探针低于 100 ms。
这些未完成不表示单次请求超过 60 秒，也不表示百万规模不可运行。
native 所有已完成的 Check p95 ≤ 0.027 ms，ListUsers p95 ≤ 0.062 ms，
这里的 ListUsers 结果最多 128 用户；不能外推到十万用户展开。
已完成进程的最大 RSS 为 653.0 MiB；超时进程缺少高水位，不算进这个最大值。

百万直接关系的 ListObjects 多结果 p95 563.387 ms，单结果 371.945 ms，
构图分别占正式总耗时 54.0% / 75.5%。fan128 多/少结果 p95 为
83.196 / 81.074 ms；相同元组总数下，活跃对象数与每对象扇出改变了扫描/输出成本。
百万 ABAC 多结果 p95 787.233 ms，差集多结果 938.403 ms，不能用直接关系数字代替。

在 100 ms 查询预算下，native 的 10 万 group/TTU 形状已需要重新评估索引/查询范围，
百万直接关系的低命中查询也不能靠返回结果少来避免重建成本。
重复请求的图缓存值得评估，但并非充分条件：百万直接关系多结果的平均请求耗时
533.734 ms，扣去本轮测得构图后仍有 245.380 ms；单结果平均 360.873 ms，
扣去构图后为 88.390 ms。这只是阶段计时相减，不是实现缓存后的性能保证；
多结果仍需评估候选索引、遍历和输出成本。Check 与小结果 ListUsers 的本轮数据
没有给出因延迟而添加结果缓存的依据。

JS 的 1 万 / 10 万 / 百万元组分别完成 66/66、66/66、55/66 项；
ListObjects 已完成探针的 p95 范围分别为 1.512–29.751、8.602–375.411、
80.627–1914.824 ms，符合 100 ms 预算的探针分别为 22/22、12/22、2/22。
百万 group/TTU/wildcard 的两种 ListObjects，以及 intersection 多结果项均未完成。
JS 已完成 Check p95 ≤ 0.093 ms，ListUsers p95 ≤ 0.235 ms。
已完成进程的最大 RSS 随规模为 274.9 / 762.7 / 2677.1 MiB；
这要求宿主验证自身内存预算，不能用 native 的 RSS 推断 V8 用量。

wasm-gc 也已实际运行，三个规模完成数为 66/66、66/66、56/66；
ListObjects 已完成探针的 p95 为 2.507–62.132、23.764–876.761、
78.971–1580.436 ms，100 ms 预算内分别为 22/22、9/22、2/22。
百万 group/TTU/wildcard 的两种 ListObjects 均未完成。
已完成 Check p95 ≤ 0.203 ms，ListUsers p95 ≤ 0.850 ms；
各规模已完成进程最大 RSS 为 94.0 / 320.2 / 1147.0 MiB；百万规模另有一条未完成（exit -5）的 wasm-gc 进程达到 1552.6 MiB。
这些运行时差异包含 GC/JIT、分配和共享主机负载，不能当作纯编译后端速度比。

### 缓存边界

现有 TupleReader 没有快照版本或失效通知，模型也可被宿主修改。
即使 user/object/relation 相同，结果还依赖模型版本、元组快照、contextual tuples、
CEL 请求上下文、用户过滤器及深度/错误语义。跨请求图缓存至少需要明确模型与存储快照身份，
写/删/clear 的失效契约及 contextual tuples 隔离；结果缓存还需包含完整请求上下文。
时间条件不能只按三元查询键长期复用。未定义这些契约前保持每次读取当前快照。

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
