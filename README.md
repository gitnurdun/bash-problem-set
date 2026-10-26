# Bash Exercise Problem Set

**100 道 Bash 练习题** · 30 Easy / 50 Medium / 20 Hard
每题都有可运行的参考实现与内置自测。

```
PROBLEMS.md    题卷：100 道题的题目、要求、提示
answers.sh     答案：全部 100 题的实现 + 131 项自测断言
```

## 快速开始

```bash
cd Bash-Problem-Set-2026-10-20
chmod +x answers.sh      # Windows Git Bash 首次需加执行权限

./answers.sh list        # 列出全部 100 题
./answers.sh show 45     # 查看第 45 题题目
./answers.sh sol 45      # 运行第 45 题的答案（自带演示数据）
./answers.sh sol 45 91   # 一次跑多题
./answers.sh run         # 跑全部内置自测
./answers.sh grade       # 自测 + 通过/失败统计（131 项断言）
```

## 题目分布

| 区间 | 主题 | 题数 |
| --- | --- | --- |
| E01–E10 | 变量、算术、字符串、参数展开 | 10 |
| E11–E20 | 流程控制、条件判断、文件测试 | 10 |
| E21–E30 | I/O 重定向、here-doc、格式化、正则、交互输入 | 10 |
| M31–M45 | 数组、查找排序、文件批处理与切分 | 15 |
| M46–M60 | 归档校验、awk / sed / grep 进阶 | 15 |
| M61–M75 | find / xargs、进程替换、IFS、关联数组 | 15 |
| M76–M80 | 函数、source、trap、getopts、日志 | 5 |
| H81–H90 | 纯 bash 重写 coreutils、栈队列、排序算法、矩阵 | 10 |
| H91–H100 | 日志/CSV 解析、状态机、并发、测试框架、CRC32、Linter | 10 |

## 难度定位

- **Easy** — 语法熟练度：`$(( ))`、参数展开、条件与循环、位置参数。
- **Medium** — 工具链组合：`awk`/`sed`/`grep`/`find`/`xargs` 何时用哪个、如何串联。
- **Hard** — 「不用现成工具时你还能剩下什么」：手写 `wc`/`head`/`sort -u`/`grep -E`、
  手写 CRC32、拓扑排序、并发限流、TAP 测试框架、Shell Linter。

## 亮点题（Hard 组）

| 题号 | 内容 | 技术点 |
| --- | --- | --- |
| H81 | 手写 `wc` | 纯 bash 循环统计行/词/字符 |
| H82 | 手写 `head` / `tail` | 环形缓冲；n 超出总行数的边界处理 |
| H84 | 手写 `grep -E` 子集 | `=~` 与 ERE 的边界 |
| H87 | 冒泡 vs 快排 | 纯 bash 排序 + 比较次数统计 |
| H91 | Nginx 日志分析器 | `index`/`substr`/`split` 规避引号内空格拆分 |
| H92 | 带引号 CSV 解析器 | awk 状态机 + FPAT 双解法 |
| H93 | 多行日志状态机 | START/END 配对、孤儿与未闭合检测 |
| H95 | 并发限流调度器 | `wait -n` + `jobs -rp` 控制并发数 |
| H96 | TAP 测试框架 | 断言、汇总、退出码语义 |
| H97 | 拓扑排序构建模拟 | Kahn 算法 + 循环依赖检测 |
| H98 | 纯 bash CRC32 | 位运算、32 位掩码；4 个标准向量全部通过 |
| H99 | 事务式文件写入 | 临时文件 → 校验 → 备份 → 原子 `mv` → 回滚 |
| H100 | Shell Linter | 检测缺 shebang、未加引号、`(( ))` 内误用 `==` 等 |

## 环境要求

- Bash 4.4+（Git Bash / WSL / Linux / macOS 均可）
- 依赖常见 coreutils：`awk` `sed` `grep` `sort` `find` `xargs` `sha256sum` `bc`
- `./answers.sh grade` 全量自测约需 **2 分钟**（H94/H95 含 `sleep` 定时演示）

## 已验证

```
$ ./answers.sh grade
...
  通过 131 / 131
  全部通过 🎉
```

CRC32 实现已与 Python `zlib.crc32` 交叉验证一致：
`""`→`00000000`、`"a"`→`E8B7BE43`、`"abc"`→`352441C2`、`"123456789"`→`CBF43926`、
`"The quick brown fox..."`→`414FA339`。

## Windows / Git Bash 注意事项

调试过程中踩到的几个真实坑，答案代码里已全部规避并加注释：

1. **`printf` 格式串不能塞路径** — `printf "$prefix%03d" "$path"` 中路径里的 `\U`
   会被当成 Unicode 转义（`missing unicode digit for \U`）。改为只格式化数字、路径另行拼接。
2. **`case` 模式必须匹配整串** — 写 `case $c in +)` 判断单个字符永远不匹配，
   必须写 `+*)`。
3. **`sha256sum` 在 Windows 下输出带 `\` 前缀** — `hash \path` 而非 `hash *path`，
   用 `cut -d' ' -f1` 会把反斜杠留在 hash 里，需用 `grep -oE '^[0-9a-f]{64}'` 提取。
4. **命令替换 `$( )` 是子 shell** — 在其中修改数组（`unset 'STACK[-1]'`）不会影响父 shell。
   栈/队列类实现要把结果写入全局变量。
5. **`select` / `read` 读到 EOF 会永久等待** — 用 `[[ -z $REPLY ]]` 判断 EOF 并退出，
   否则 `while true` 空转（实测单题从 40 秒降到 0 秒）。
6. **关联数组遍历顺序不确定** — 拓扑排序、词频输出等需要稳定顺序的场景，用
   `order=()` 索引数组显式保序。