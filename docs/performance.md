# 查询性能实测

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

## 第 3a 阶段返工复验

对齐 v1.22.1 List 语义后，用上述相同数据和命令重新执行：
Check 4.59 µs ± 150.53 ns，ListObjects 44.27 ms ± 2.00 ms，两个 benchmark 均通过。
原始输出见 evidence/bench-rework1.txt。此为当前代码的另一次实测，
不把与首轮测量的差值单独归因于本轮语义修复。

## 后端返工第 2 轮

改为反向对象证明后，在同一 10 万元组 / 10 层 group 数据上重跑：
Check 4.36 µs ± 97.39 ns；ListObjects 39.20 ms ± 678.66 µs；benchmark 2/2。
原始输出见 evidence/bench-rework2.txt。每次 ListObjects 请求构造反向图，
此样本不代表大型多关系图的峰值内存或所有查询分布。

## 最终 N1 深度修复复验

同一命令、相同 10 万元组 / 10 层 group 数据，benchmark 两次均为 2/2：
首测 Check 22.90 µs ± 8.20 µs，ListObjects 263.99 ms ± 27.49 ms；
复测 Check 4.44 µs ± 99.97 ns，ListObjects 39.24 ms ± 633.82 µs。
两次原始输出分别见 evidence/bench-n1.txt、evidence/bench-n1-repeat.txt。
复测前机器 load averages 实测 16.75 / 21.54 / 17.18，首测也有较大样本波动；
不丢弃这组异常样本，也不将测量差异单独归因于代码变化。
本轮没有改变基准数据或计时边界，没有据此宣称性能提升。
