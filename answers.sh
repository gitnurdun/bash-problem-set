#!/usr/bin/env bash
# ============================================================================
#  Bash Exercise Problem Set — Answers & Test Runner
#  30 Easy + 50 Medium + 20 Hard
#  Usage:
#    ./answers.sh list          列出所有题目
#    ./answers.sh show <n>      查看某题题目
#    ./answers.sh sol  <n>      运行某题答案（打印演示输出）
#    ./answers.sh run [n..]     运行全部或指定题目的答案
#    ./answers.sh grade         运行全部并统计成功/失败
# ============================================================================
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0; FAIL=0; FAILED_IDS=()

# ---- 断言工具 ---------------------------------------------------------------
ok()   { PASS=$((PASS+1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); FAILED_IDS+=("$1"); printf '  \033[31m✗\033[0m %s  → 得到: [%s] 期望: [%s]\n' "$1" "$2" "$3"; }
chk()  { [[ "$2" == "$3" ]] && ok "$1" || bad "$1" "$2" "$3"; }
sec()  { printf '\n\033[36m── %s ──\033[0m\n' "$1"; }

# ---- 演示数据（供 ./answers.sh run <n> 独立运行时使用）----------------------
DEMO="$WORK/demo"
demo_setup() {
  [[ -d $DEMO ]] && return 0
  mkdir -p "$DEMO/tree/sub"
  printf 'apple\nbanana\napple\ncherry\nbanana\napple\n'  > "$DEMO/fruits.txt"
  printf 'red green blue\nred black\ngreen white\n'       > "$DEMO/colors.txt"
  printf '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n'                > "$DEMO/nums.txt"
  printf 'b\na\nb\nc\na\n'                                  > "$DEMO/dup.txt"
  printf '1\n2\n3\n'                                        > "$DEMO/s1.txt"
  printf '2\n3\n4\n'                                        > "$DEMO/s2.txt"
  printf 'name,score\nalice,10\nbob,20\ncarol,15\n'        > "$DEMO/scores.csv"
  printf 'key,val\nx,1\nx,2\ny,5\n'                         > "$DEMO/group.csv"
  printf 'id,email\n1,alice@example.com\n2,nope\n3,bob@test.org\n' > "$DEMO/mails.csv"
  printf 'a\n\n# comment\nb \nc\n'                          > "$DEMO/messy.txt"
  printf 'foo foo foo\nbar\nbaz\n'                          > "$DEMO/foo.txt"
  printf 'TODO: fix me\nok\nTODO: later\n'                  > "$DEMO/todo.txt"
  printf 'l1\nl2\nl3\nl4\n'                                > "$DEMO/lines.txt"
  printf 'SECRET=abc123\n'                                  > "$DEMO/secret.env"
  printf 'b\na\nb\nc\na\n'                                > "$DEMO/dup_check.txt"
  printf 'app.log' > "$DEMO/tree/a.log"; printf 'b' > "$DEMO/tree/b.txt"
  printf 'c' > "$DEMO/tree/sub/c.md"; printf 'd' > "$DEMO/tree/sub/d.log"
  : > "$DEMO/tree/empty"
  return 0
}
DEMO_FILE() { demo_setup; case ${1:-} in
  fruit)   echo "$DEMO/fruits.txt";; color) echo "$DEMO/colors.txt";;
  nums)    echo "$DEMO/nums.txt";;  dup)   echo "$DEMO/dup.txt";;
  s1)      echo "$DEMO/s1.txt";;    s2)     echo "$DEMO/s2.txt";;
  score)   echo "$DEMO/scores.csv";; group) echo "$DEMO/group.csv";;
  mail)    echo "$DEMO/mails.csv";; messy)  echo "$DEMO/messy.txt";;
  foo)     echo "$DEMO/foo.txt";;   lg)     echo "$DEMO/lines.txt";;
  todo)    echo "$DEMO/todo.txt";;  tree)   echo "$DEMO/tree";;
  secret)  echo "$DEMO/secret.env";; dupcheck) echo "$DEMO/dup_check.txt";;
  *)       echo "$DEMO/fruits.txt";;
esac; }

# ---- 题目索引 ---------------------------------------------------------------
titles=(
 "E01 问候程序"            "E02 默认值链"              "E03 纯 bash 算术"
 "E04 累加 1..N"           "E05 阶乘"                  "E06 斐波那契"
 "E07 奇偶判断"            "E08 闰年判断"              "E09 字符串长度(禁\${#})"
 "E10 字符串反转"          "E11 回文判断"              "E12 单词计数"
 "E13 大小写转换(禁 tr)"  "E14 三数比较"              "E15 绝对值"
 "E16 变量交换"            "E17 文件可读性检查"        "E18 目录计数"
 "E19 逐行读取 stdin"      "E20 位置参数"              "E21 shift 消费参数"
 "E22 表达式求值(仅四则)"  "E23 退出码映射"            "E24 温度转换"
 "E25 printf 表格"         "E26 温度转换 CLI 版"       "E27 here-doc vs here-string"
 "E28 命令替换 vs 算术替换" "E29 正则匹配基础"          "E30 隐藏输入"
 "M31 数组求和与均值"      "M32 数组排序(外部)"        "M33 文件去重(禁 sort -u)"
 "M34 统计词频"            "M35 找最大文件"            "M36 按扩展名统计"
 "M37 目录体积报告"        "M38 备份加时间戳"          "M39 批量改扩展名"
 "M40 查找 N 天前文件"     "M41 含空格文件名"          "M42 回收站(安全删除)"
 "M43 文件差异 diffstat"   "M44 归并两个有序文件"      "M45 切分大文件"
 "M46 打包并排除(禁 --exclude)" "M47 校验和生成"        "M48 校验和验证"
 "M49 awk 求和与均值"      "M50 awk 分组聚合"          "M51 awk 正则筛选邮箱"
 "M52 awk 关联数组词频"    "M53 awk 多文件 FNR/NR"     "M54 awk 生成 HTML 报告"
 "M55 sed 全局替换"        "M56 sed 删除行"            "M57 sed 打印行区间"
 "M58 sed 插入与追加"      "M59 sed 分组反向引用"      "M60 grep 综合"
 "M61 grep 上下文"         "M62 grep 递归与过滤"       "M63 grep 静默退出"
 "M64 find 复合条件"       "M65 find -exec {} +"       "M66 find -print0 管道"
 "M67 xargs -I"            "M68 xargs -P 并行"         "M69 进程替换"
 "M70 coproc 流式处理"     "M71 参数展开替换与截断"    "M72 IFS 与分词"
 "M73 关联数组倒排索引"    "M74 多维数组模拟"          "M75 here-doc 注入对比"
 "M76 函数与返回码"        "M77 库文件与 source"       "M78 trap 与信号"
 "M79 getopts 参数解析"    "M80 结构化日志"            "H81 手写 wc"
 "H82 手写 head/tail"      "H83 手写 sort -u 与 comm"  "H84 手写 grep -E 子集"
 "H85 栈与队列"            "H86 二分查找"              "H87 冒泡与快速排序"
 "H88 矩阵乘法"            "H89 文件式 Todo 管理器"    "H90 select 菜单系统"
 "H91 Nginx 日志分析器"    "H92 带引号 CSV 解析器"     "H93 日志状态机分析"
 "H94 轮询式 mywatch"      "H95 并发任务与限流"        "H96 迷你测试框架(TAP)"
 "H97 拓扑排序构建模拟"    "H98 纯 bash CRC32"         "H99 事务式文件写入"
 "H100 Shell Linter"
)

# ============================================================================
#  EASY 1-30
# ============================================================================

e01() {
  local -a a=("$@"); local n=${#a[@]}
  case $n in
    0) echo "Hello, World!" ;;
    1) echo "Hello, ${a[0]}!" ;;
    3) echo "${a[0]}, ${a[1]}! You are ${a[2]} years old." ;;
    *) echo "usage: hello.sh [greeting] [name] [age]" ;;
  esac
}

e02() {
  local A B
  A=""
  A=${A:-default_a}
  echo "A=$A"
  echo "B=${B:-fallback}"
  echo "set=${B:+yes}${B:-no} unset=${B+yes}${B:-no}"
}

e03() {
  local a=$1 b=$2
  echo "sum=$((a+b)) diff=$((a-b)) prod=$((a*b))"
  if (( b == 0 )); then echo "div=ERROR"; else echo "div=$((a/b))"; fi
}

e04() { local n=$1 s=0 i; for ((i=1;i<=n;i++)); do ((s+=i)); done; echo "$s"; }

e05() {
  local n=$1
  if (( n > 20 )); then echo OVERFLOW; return; fi
  (( n == 0 )) && { echo 1; return; }
  local f=1 i; for ((i=2;i<=n;i++)); do ((f*=i)); done; echo "$f"
}

e06() {
  local n=$1; (( n <= 0 )) && { echo 0; return; }
  local a=1 b=1 i
  for ((i=2;i<=n;i++)); do (( b = a + b, a = b - a )); done
  echo "$a"
}

e07() { if (( $1 % 2 == 0 )); then echo even; else echo odd; fi; }

e08() {
  local y=$1
  if (( y % 4 == 0 && y % 100 != 0 )) || (( y % 400 == 0 )); then echo leap
  else echo not-leap; fi
}

e09() { local s=$1 n=0; while [[ -n $s ]]; do s=${s:1}; ((n++)); done; echo "$n"; }

e10() { local s=$1 r="" i; for ((i=${#s}-1;i>=0;i--)); do r+=${s:i:1}; done; echo "$r"; }

e11() {
  local s=${1,,}; local t="" c i
  for ((i=0;i<${#s};i++)); do c=${s:i:1}; [[ $c == " " ]] && continue; t+=$c; done
  local r="" ; for ((i=${#t}-1;i>=0;i--)); do r+=${t:i:1}; done
  [[ $t == "$r" ]] && echo palindrome || echo not-palindrome
}

e12() { local -a w=($1); echo "${#w[@]}"; }

e13() {
  local s=$1
  echo "orig=$s"
  echo "upper=${s^^}"
  echo "lower=${s,,}"
  echo "cap1=${s^}"
  echo "low1=${s,}"
}

e14() {
  local -a a=($1 $2 $3) mx=$1 mn=$1 v
  for v in "${a[@]}"; do (( v > mx )) && mx=$v; (( v < mn )) && mn=$v; done
  echo "max=$mx min=$mn"
}

e15() { local n=$1; echo $(( n < 0 ? -n : n )); }

e16() { local a=$1 b=$2; read -r a b <<<"$b $a"; echo "$a $b"; }

e17() {
  local f=$1
  if [[ ! -e $f ]]; then echo not-exist
  elif [[ ! -f $f ]]; then echo not-regular
  elif [[ ! -r $f ]]; then echo not-readable
  else echo readable; fi
}

e18() {
  local d=$1
  [[ -d $d ]] || { echo ERROR; return; }
  local n=0 f
  while IFS= read -r -d '' f; do ((n++)); done < <(find "$d" -maxdepth 1 -type f -print0)
  echo "$n"
}

e19() { local i=0 line; while IFS= read -r line; do ((i++)); echo "[$i] $line"; done; }

e20() {
  if (( $# == 0 )); then echo no-args; return; fi
  echo "count=$#"
  local i=1 v; for v in "$@"; do echo "[$i] $v"; ((i++)); done
  echo "all=$*"
}

e21() { local i=1; while (( $# > 0 )); do echo "第${i}个: $1"; shift; ((i++)); done; }

e22() {
  local expr=$1
  # 分词：数字、运算符、括号（每个模式单独成case 分支，避免组合模式的解析歧义）
  local -a tokens=()
  local rest=${expr//[[:space:]]/} tok
  while [[ -n $rest ]]; do
    # 注意：case 模式必须匹配"整个字符串"，所以每个算符后都要加 *
    case $rest in
      [0-9]*)
        tok=${rest%%[!0-9]*}; tokens+=("$tok"); rest=${rest:${#tok}} ;;
      +*)  tokens+=("+");  rest=${rest:1} ;;
      -*)  tokens+=("-");  rest=${rest:1} ;;
      \**) tokens+=("*");  rest=${rest:1} ;;
      /*)  tokens+=("/");  rest=${rest:1} ;;
      \(*) tokens+=("(");  rest=${rest:1} ;;
      \)*) tokens+=(")");  rest=${rest:1} ;;
      *) echo "invalid expression: unexpected char '${rest:0:1}'"; return 1 ;;
    esac
  done
  # 双栈（调度场算法）
  local -a vals=() ops=()
  prec() { case $1 in '(') echo 0;; +|-) echo 1;; '*'|/) echo 2;; *) echo 0;; esac; }
  apply() {
    local o=${ops[-1]}; unset 'ops[-1]'
    local b=${vals[-1]}; unset 'vals[-1]'
    local a=${vals[-1]}; unset 'vals[-1]'
    case $o in
      +) vals+=( $(( a + b )) ) ;;
      -) vals+=( $(( a - b )) ) ;;
      '*') vals+=( $(( a * b )) ) ;;
      /) if (( b == 0 )); then echo "division by zero"; return 1; fi
         vals+=( $(( a / b )) ) ;;
      *) echo "unbalanced parentheses"; return 1 ;;
    esac
  }
  local t top
  for t in "${tokens[@]}"; do
    if [[ $t == [0-9]* ]]; then
      vals+=("$t")
    elif [[ $t == '(' ]]; then
      ops+=("$t")
    elif [[ $t == ')' ]]; then
      while (( ${#ops[@]} > 0 )) && [[ ${ops[-1]} != '(' ]]; do apply || return 1; done
      (( ${#ops[@]} > 0 )) || { echo "unbalanced parentheses"; return 1; }
      unset 'ops[-1]'
    else
      while (( ${#ops[@]} > 0 )); do
        top=${ops[-1]}; [[ $top == '(' ]] && break
        (( $(prec "$top") >= $(prec "$t") )) || break
        apply || return 1
      done
      ops+=("$t")
    fi
  done
  while (( ${#ops[@]} > 0 )); do
    [[ ${ops[-1]} == '(' ]] && { echo "unbalanced parentheses"; return 1; }
    apply || return 1
  done
  (( ${#vals[@]} == 1 )) || { echo "invalid expression"; return 1; }
  echo "${vals[-1]}"
}

e23() {
  local cmd=$1; shift; "$cmd" "$@" >/dev/null 2>&1
  local rc=$?
  case $rc in
    0) echo OK ;;
    1) echo GENERIC ;;
    127) echo NOT_FOUND ;;
    *) echo "CODE($rc)" ;;
  esac
}

e24() { local c=$1; printf "C=%.2fF=%.2fK=%.2f\n" "$c" "$(echo "$c*9/5+32"|bc -l)" "$(echo "$c+273.15"|bc -l)"; }

e25() {
  printf "%-12s %6s %10s\n" "NAME" "QTY" "PRICE"
  local -a nm=(apple pen monitor) qty=(3 10 2) pr=(1.5 0.5 320.0)
  local i tot=0
  for i in 0 1 2; do
    printf "%-12s %6s %10.2f\n" "${nm[i]}" "${qty[i]}" "${pr[i]}"
    tot=$(awk "BEGIN{print $tot+${qty[i]}*${pr[i]}}")
  done
  printf "%-12s %6s %10.2f\n" "TOTAL" "" "$tot"
}

e26() {
  local to=F c=25.0
  while (( $# )); do
    case $1 in
      --to) to=${2^^}; shift 2;;
      -c) c=$2; shift 2;;
      *) c=$1; shift;;
    esac
  done
  case $to in
    F) awk "BEGIN{printf \"%.2f F\\n\", $c*9/5+32}";;
    K) awk "BEGIN{printf \"%.2f K\\n\", $c+273.15}";;
    *) echo "unknown target: $to"; return 1;;
  esac
}

e27() {
  local txt=$'line1\nline2\nline3'
  local n1 n2
  n1=$(wc -l <<<"$(cat <<EOF
$txt
EOF
)")
  n2=$(wc -l <<<"$txt")
  echo "here-doc(含尾换行) 行数: $((n1))"
  echo "here-string 行数: $((n2))"
  echo "差异原因: here-doc 保留末尾换行符"
}

e28() {
  local r1 r2
  r1=$(awk "BEGIN{print 3+4*2}")
  r2=$(( 3 + 4 * 2 ))
  echo "\$( )  外部命令 → $r1 (类型: 字符串输出)"
  echo "\$(( )) 内建算术 → $r2 (类型: 整数)"
}

e29() {
  local s=$1
  if [[ $s =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    echo "valid email: $s"
  else
    echo "not a valid email: $s"
  fi
}

e30() {
  local a b
  read -r -s -p "password: " a; echo
  read -r -s -p "confirm : " b; echo
  [[ $a == "$b" ]] && echo MATCH || echo MISMATCH
}

# ============================================================================
#  MEDIUM 31-80
# ============================================================================

m31() {
  local -a a=(3 7 2 9 4)
  local s=0 v; for v in "${a[@]}"; do ((s+=v)); done
  printf "len=%d sum=%d avg=%.2f\n" "${#a[@]}" "$s" "$(awk "BEGIN{print $s/${#a[@]}}")"
}

m32() {
  local -a a=("$@")
  [[ ${#a[@]} -eq 0 ]] && { echo "no args"; return; }
  local sorted
  sorted=$(printf '%s\n' "${a[@]}" | sort -n | paste -sd' ' -)
  printf 'sorted: %s\n' "$sorted"
  printf 'max=%s min=%s\n' "$(printf '%s\n' "${a[@]}" | sort -n | tail -1)" \
                            "$(printf '%s\n' "${a[@]}" | sort -n | head -1)"
}

m33() {
  local f=${1:-$(DEMO_FILE dup)} declare -A seen=(); local -a out=()
  while IFS= read -r line || [[ -n $line ]]; do
    [[ -n ${seen[$line]:-} ]] && continue
    seen[$line]=1; out+=("$line")
  done < "$f"
  printf '%s\n' "${out[@]}"
}

m34() {
  local f=${1:-$(DEMO_FILE fruit)}
  tr -cs '[:alpha:]' '\n' < "$f" | grep -v '^$' | sort | uniq -c | sort -k1,1nr -k2,2 | \
  awk '{print $1, $2}'
}

m35() {
  local d=${1:-$(DEMO_FILE tree)}
  find "$d" -type f -printf '%s\t%p\n' 2>/dev/null | sort -rn | head -3 | \
  while IFS=$'\t' read -r sz p; do printf '%s\t%s\n' "$sz" "$p"; done
}

m36() {
  local d=${1:-$(DEMO_FILE tree)}
  find "$d" -type f | sed -n 's/.*\.\([^.\/]*\)$/\1/p' | sort | uniq -c | sort -k1,1nr | \
  awk '{print $2, $1}'
}

m37() {
  local d=${1:-$(DEMO_FILE tree)}
  du -sh "$d"/*/ 2>/dev/null | sort -rh
  echo "----"
  du -sh "$d" 2>/dev/null | awk '{print $1, "(total)"}'
}

m38() {
  local d=${1:-$(DEMO_FILE tree)} ts; ts=$(date +%Y%m%d-%H%M%S)
  local f; while IFS= read -r -d '' f; do
    cp -p "$f" "$f.$ts.bak" && echo "备份: $f.$ts.bak"
  done < <(find "$d" -maxdepth 1 -type f -name '*.log' -print0)
}

m39() {
  local d=${1:-$(DEMO_FILE tree)} ts; ts=$(date +%Y%m%d-%H%M%S)
  local f; while IFS= read -r -d '' f; do
    mv "$f" "${f%.txt}.${ts}.md" && echo "重命名: $(basename "$f") → $(basename "${f%.txt}.${ts}.md")"
  done < <(find "$d" -maxdepth 1 -type f -name '*.txt' -print0)
}

m40() {
  local d=${1:-$(DEMO_FILE tree)} n=${2:-7}
  find "$d" -type f -name '*.log' -mtime +"$n" -printf '%T@ %TY-%Tm-%Td %TH:%TM %p\n' | sort -rn | cut -d' ' -f2-
}

m41() {
  local d=${1:-$(DEMO_FILE tree)} f
  while IFS= read -r -d '' f; do printf '%3d  %s\n' "${#f}" "$f"; done \
    < <(find "$d" -type f -print0)
}

m42() {
  demo_setup; local trash="$DEMO/.trash"; mkdir -p "$trash"
  local cmd=${1:-}; shift || true
  case $cmd in
    --list) ls -1 "$trash";;
    --purge) rm -f "$trash"/*; echo "purged";;
    "") echo "usage: trash <file>|--list|--purge";;
    *)  [[ -e $1 ]] || { echo "not found: $1"; return 1; }
        local dst="$trash/$(basename "$1").$(date +%Y%m%d%H%M%S)"
        mv "$1" "$dst" && echo "moved → $dst";;
  esac
}

m43() {
  local a=${1:-$(DEMO_FILE s1)} b=${2:-$(DEMO_FILE s2)}
  local only_a only_b common
  only_a=$(comm -23 <(sort "$a") <(sort "$b") | grep -c . || true)
  only_b=$(comm -13 <(sort "$a") <(sort "$b") | grep -c . || true)
  common=$(comm -12 <(sort "$a") <(sort "$b") | grep -c . || true)
  printf 'a=%d lines, b=%d lines, common=%d, only_a=%d, only_b=%d\n' \
    "$(wc -l < "$a")" "$(wc -l < "$b")" "$common" "$only_a" "$only_b"
}

m44() { sort -m "${1:-$(DEMO_FILE s1)}" "${2:-$(DEMO_FILE s2)}"; }

m45() {
  # 注意: Windows 路径含反斜杠，不能把路径塞进 printf 格式串（\U 会被当转义），改用字符串拼接
  demo_setup
  local f=${1:-$DEMO/nums.txt} n=${2:-3} prefix=${3:-part-} idx=1 line
  local -a buf=()
  # prefix 若含 / 则视为完整路径，否则与输入文件同目录
  local outdir; outdir=$(dirname "$f")
  [[ $prefix == */* ]] && outdir=${prefix%/*} && prefix=${prefix##*/}
  _num3() { printf '%03d' "$1"; }          # 只格式化数字，路径另行拼接
  _out()  { printf '%s/%s%s' "$outdir" "$prefix" "$(_num3 "$1")"; }
  while IFS= read -r line || [[ -n $line ]]; do
    buf+=("$line")
    if (( ${#buf[@]} == n )); then
      printf '%s\n' "${buf[@]}" > "$(_out "$idx")"
      ((idx++)); buf=()
    fi
  done < "$f"
  if (( ${#buf[@]} )); then
    printf '%s\n' "${buf[@]}" > "$(_out "$idx")"
    ((idx++))
  fi
  echo "生成 $((idx-1)) 个分片"
}

m46() {
  local src=${1:-$(DEMO_FILE tree)} out=${2:-$DEMO/out.tar.gz}; (( $# > 2 )) && shift 2 || shift $#
  local -a excl=(); local e
  for e in "$@"; do excl+=("--exclude=$e"); done
  # 方式一：把排除列表写入文件用 -T；方式二：过滤后传列表
  local listf="$WORK/$(basename "$src").list"
  ( cd "$src" && find . -type f | grep -vE '/(node_modules)(/|$)' ) > "$listf"
  tar -C "$src" --files-from="$listf" -czf "$out"
  echo "打包完成: $out ($(du -h "$out" | cut -f1))"
}

m47() {
  demo_setup
  local d=${1:-$DEMO/tree}
  local out=${2:-}
  [[ -z $out ]] && out="$d/SHA256SUMS.txt"
  ( cd "$d" && find . -type f ! -name "$(basename "$out")" -print0 | sort -z \
      | xargs -0 sha256sum ) | sed -E 's/^([0-9a-f]{64}) +[\\*]?/\1  /' > "$out"
  echo "已生成 $out ($(wc -l < "$out") 条)"
}

m48() {
  demo_setup
  local sumfile=${1:-$DEMO/tree/SHA256SUMS.txt}; local pass=0 fail=0 miss=0
  [[ -f $sumfile ]] || { echo "(未找到校验文件，自动先生成一份)"; m47 "$(dirname "$sumfile")" "$sumfile" >/dev/null; }
  local base; base=$(dirname "$sumfile")
  local hash path
  while read -r hash path || [[ -n ${hash:-} ]]; do
    [[ -z ${hash:-} || $hash == \#* ]] && continue
    [[ -n ${path:-} ]] || continue
    hash=${hash//\r/}; path=${path//\r/}
    local target=$path
    [[ $target != /* ]] && target="$base/$target"
    if [[ ! -f $target ]]; then echo "MISSING  $path"; ((miss++))
    elif [[ $(sha256sum "$target" | tr -d '\\r' | grep -oE '^[0-9a-f]{64}') == "$hash" ]]; then echo "OK       $path"; ((pass++))
    else echo "FAILED   $path"; ((fail++)); fi
  done < "$sumfile"
  echo "----"; echo "OK=$pass FAILED=$fail MISSING=$miss"
}

m49() { awk -F, 'NR>1{s+=$2; if($2>max)max=$2} END{printf "sum=%d avg=%.2f max=%d\n", s, s/(NR-1), max}' "${1:-$(DEMO_FILE score)}"; }

m50() { awk -F, 'NR>1{sum[$1]+=$2; cnt[$1]++} END{for(k in sum) printf "%s %d %d\n", k, sum[k], cnt[k]}' "${1:-$(DEMO_FILE group)}" | sort; }

m51() { awk -F, 'NR>1{for(i=1;i<=NF;i++) if($i ~ /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/) print $i}' "${1:-$(DEMO_FILE mail)}"; }

m52() {
  awk '{for(i=1;i<=NF;i++){c[tolower($i)]++}} END{for(w in c) print c[w], w}' "${1:-$(DEMO_FILE fruit)}" | sort -k1,1nr -k2,2
}

m53() { local -a files=("$@"); (( ${#files[@]} == 0 )) && files=( $(DEMO_FILE s1) $(DEMO_FILE s2) )
  awk 'FNR==1{f=FILENAME} {printf "%s:%d %s\n", f, FNR, $0}' "${files[@]}" | head -20; }

m54() {
  local csv=${1:-$(DEMO_FILE score)} html=${2:-$DEMO/report.html} sep=${3:-,}
  {
    echo '<table border="1" style="border-collapse:collapse;font-family:sans-serif">'
    local first=1 line
    while IFS= read -r line || [[ -n $line ]]; do
      ((first)) && tag=th || tag=td; first=0
      printf '<tr>'
      IFS="$sep" read -ra cells <<< "$line"
      for c in "${cells[@]}"; do printf '<%s>%s</%s>' "$tag" "$c" "$tag"; done
      printf '</tr>\n'
    done < "$csv"
    echo '</table>'
  } > "$html"
  echo "生成 $html"
}

m55() {
  local f=${1:-$(DEMO_FILE foo)}
  local n=$(grep -o 'foo' "$f" | wc -l)
  printf '替换次数: %s\n' "$n"
  sed 's/foo/bar/g' "$f"
}

m56() { sed -e '/^[[:space:]]*$/d' -e '/^[[:space:]]*#/d' -e 's/[[:space:]]*$//' "${1:-$(DEMO_FILE messy)}"; }

m57() {
  local f=${1:-$(DEMO_FILE lg)} a=${2:-2} b=${3:-3}
  (( a > b )) && { echo "invalid range"; return 1; }
  sed -n "${a},${b}p" "$f"
}

m58() {
  local f=${1:-$(DEMO_FILE lg)}
  sed -e '3i HEADER' -e '$a FOOTER' "$f"
}

m59() {
  echo "2026-10-20" | sed -E 's/([0-9]{4})-([0-9]{2})-([0-9]{2})/\3\/\2\/\1/'
  echo "name: Ada"  | sed -E 's/^([a-z]+): *(.+)$/\2 (\1)/'
}

m60() {
  # 用法: mygrep [-i] [-v] [-c] [-n] [-E] PATTERN FILE   （选项可组合，如 -in）
  local -i i_mode=0 v_mode=0 c_mode=0 n_mode=0 E_mode=0
  if [[ ${1:-} != -* && ${1:-} != "" && ! -e ${1:-} ]]; then set -- "${1:-}" "$(DEMO_FILE fruit)"; fi
  local pat="" f=""
  while (( $# )); do
    case $1 in
      -[ivcnE]*|-i|-v|-c|-n|-E)
        local o=${1#-}
        [[ $o == *i* ]] && i_mode=1
        [[ $o == *v* ]] && v_mode=1
        [[ $o == *c* ]] && c_mode=1
        [[ $o == *n* ]] && n_mode=1
        [[ $o == *E* ]] && E_mode=1
        shift ;;
      --) shift; [[ -z $pat ]] && pat=$1 || f=$1; shift ;;
      -*) echo "unknown option: $1" >&2; return 2 ;;
      *)  if [[ -z $pat ]]; then pat=$1; else f=$1; fi; shift ;;
    esac
  done
  [[ -n $pat ]] || { echo "usage: mygrep [-ivcnE] PATTERN FILE" >&2; return 2; }
  local -a g=()
  (( E_mode )) && g+=(-E)
  (( i_mode )) && g+=(-i)
  (( v_mode )) && g+=(-v)
  (( n_mode )) && g+=(-n)
  (( c_mode )) && { grep -c "${g[@]}" -- "$pat" ${f:+"$f"}; return 0; }
  grep "${g[@]}" -- "$pat" ${f:+"$f"}
}

m61() {
  local kw=${1:-TODO} f=${2:-$(DEMO_FILE todo)} c=${3:-2}
  # grep 的 -A/-B/-C 只接受非负数，负数需转为等价的正数
  (( c < 0 )) && c=0
  grep -n -A"$c" -B"$c" "$kw" "$f"
}

m62() {
  local d=${1:-$(DEMO_FILE tree)} kw=${2:-TODO}
  grep -rnI --exclude-dir=.git --exclude-dir=node_modules -- "$kw" "$d"
}

m63() {
  local d=${1:-$(DEMO_FILE tree)} kw=${2:-TODO} hit
  hit=$(grep -rlI --exclude-dir=.git -- "$kw" "$d" 2>/dev/null | head -1) || return 1
  [[ -n $hit ]] || return 1
  printf '%s\n' "${hit#"$d"/}"
}

m64() {
  local d=${1:-$(DEMO_FILE tree)}
  find "$d" -type f -name '*.log' -size +10k -mtime -30 -readable 2>/dev/null
}

m65() {
  local d=${1:-$(DEMO_FILE tree)}
  find "$d" -type f -name '*.txt' -exec md5sum {} + | sort -k2
}

m66() {
  local d=${1:-$(DEMO_FILE tree)}
  find "$d" -type f -print0 | while IFS= read -r -d '' f; do
    printf '%s:%d\n' "$f" "$(wc -l < "$f")"
  done
}

m67() {
  local d=${1:-$(DEMO_FILE tree)}
  count_lines() { wc -l < "$1"; }
  find "$d" -type f -print0 | xargs -0 -I{} bash -c 'printf "%6d  %s\n" "$(wc -l < "{}")" "{}"'
  echo "总行数: $(find "$d" -type f -print0 | xargs -0 cat | wc -l)"
}

m68() {
  local n=${1:-10} p=${2:-4}
  local t0 t1
  t0=$(date +%s.%N)
  seq 1 "$n" | xargs -P"$p" -I{} bash -c 'sleep 0.2; echo "task {} done"'
  t1=$(date +%s.%N)
  awk "BEGIN{printf \"串行≈%.1fs  实际=%.1fs  加速比≈%.1fx\n\", $n*0.2, $t1-$t0, ($n*0.2)/($t1-$t0)}"
}

m69() {
  local a=${1:-$(DEMO_FILE s1)} b=${2:-$(DEMO_FILE s2)}
  echo "交集:"; comm -12 <(sort "$a") <(sort "$b")
  echo "仅 a:"; comm -23 <(sort "$a") <(sort "$b")
  echo "并集:"; sort -u <(cat "$a" "$b")
}

m70() {
  coproc GEN { for ((i=2;i<=200;i++)); do
      p=1; for ((d=2;d*d<=i;d++)); do (( i % d == 0 )) && { p=0; break; }; done
      (( p )) && echo $i
    done; }
  i=0; while read -r p && (( ++i <= 10 )); do printf '%s ' "$p"; done <&"${GEN[0]}"
  echo; kill "$GEN_PID" 2>/dev/null
}

m71() {
  local p=/home/user/docs/report.final.txt
  echo "basename  : ${p##*/}"
  echo "noext     : ${p%.*}"
  echo "dir       : ${p%/*}"
  echo "替换      : ${p//\//|}"
  echo "从第11位取8字符: ${p:10:8}"
  echo "去前缀    : ${p#/home}"
  echo "去后缀    : ${p%.txt}"
  local f=report.final.txt
  echo "首字母大写: ${f^}"
}

m72() {
  local line="a:b:c:d"
  local -a default_split all
  read -ra default_split <<< "$line"; echo "默认 IFS: ${#default_split[@]} 段 → ${default_split[*]}"
  IFS=: read -ra all <<< "$line";      echo "IFS=';' : ${#all[@]} 段 → ${all[*]}"
  IFS=' ' ; echo "拼接: $(echo "${all[*]}")"
}

m73() {
  local f=${1:-$(DEMO_FILE fruit)}; declare -A idx=(); local w line ln=0
  while IFS= read -r line || [[ -n $line ]]; do
    ((ln++))
    for w in $line; do
      w=${w,,}
      idx[$w]="${idx[$w]:-}${idx[$w]:+,}${ln}"
    done
  done < "$f"
  for w in "${!idx[@]}"; do printf '%-10s -> lines %s\n' "$w" "${idx[$w]}"; done | sort
}

m74() {
  declare -A A B C
  for i in 0 1 2; do for j in 0 1 2; do A[$i,$j]=$(( (RANDOM % 5) )); done; done
  for i in 0 1 2; do for j in 0 1 2; do B[$i,$j]=$(( (RANDOM % 5) )); done; done
  echo "A * B ="
  for i in 0 1 2; do
    printf '  '
    for j in 0 1 2; do
      s=0; for k in 0 1 2; do (( s += A[$i,$k] * B[$k,$j] )); done
      printf '%4d' "$s"
    done
    echo
  done
}

m75() {
  echo "字面模式 <<'EOF':"
  cat <<'EOF'
  user=$USER  backtick=`date +%Y`  escape=\n  → 原样输出
EOF
  echo
  echo "展开模式 <<EOF:"
  cat <<EOF
  user=$USER  backtick=$(date +%Y)  escape=\n  → 已展开
EOF
}

m76() {
  fact() { if (( $1 <= 1 )); then echo 1; else echo $(( $1 * $(fact $(( $1 - 1 ))) )); fi; }
  gcd()  { local a=$1 b=$2; while (( b )); do (( a %= b )); local t=$a; a=$b; b=$t; done; echo "$a"; }
  echo "fact(10) = $(fact 10)"
  echo "gcd(48,18) = $(gcd 48 18)"
  local counter=0; bump() { local counter=$1; ((counter++)); echo "$counter"; }
  echo "local 隔离: 外层 counter 仍为 $counter"
}

m77() {
  local lib="$WORK/lib.sh"
  cat > "$lib" <<'EOF'
greet() { echo "hello, $1"; }
add()   { echo $(($1 + $2)); }
EOF
  # shellcheck disable=SC1090
  source "$lib"
  greet "from lib.sh"
  add 3 4
}

m78() {
  local tmpf="$WORK/trap.tmp"; echo "partial" > "$tmpf"
  cleanup() { rm -f "$tmpf" 2>/dev/null; }
  on_err()  { echo "[ERR] line $1 失败 (code=$2)"; }
  trap 'cleanup' EXIT
  trap 'echo "[INT] 收到中断"; exit 130' INT
  trap 'on_err $LINENO $?' ERR
  echo "已注册 3 个 trap: EXIT / INT / ERR"
  trap -p EXIT >/dev/null 2>&1 && echo "  EXIT trap 生效" || echo "  EXIT trap 缺失"
  false || echo "false 被安全处理"
  trap - INT ERR
  trap - EXIT
  rm -f "$tmpf"
}

m79() {
  local verbose=0 outfile="" OPTIND=1
  while getopts "vo:h" opt; do
    case $opt in
      v) verbose=1 ;;
      o) outfile=$OPTARG ;;
      h) echo "usage: $0 [-v] [-o file]"; return 0 ;;
      *) echo "unknown: -$OPTARG"; return 1 ;;
    esac
  done
  shift $((OPTIND-1))
  printf 'verbose=%s\noutfile=%s\n剩余参数=%d\n' "${verbose:-0}" "${outfile:-(none)}" "$#"
}

m80() {
  demo_setup; local logfile=${1:-$DEMO/app.log} use_color=${2:-1}
  local -A LVL=( [DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 )
  _log() {
    local lvl=$1 msg=$2 color= reset=""
    case $lvl in
      DEBUG) color=$'\033[36m';; INFO) color=$'\033[32m';;
      WARN)  color=$'\033[33m';; ERROR) color=$'\033[34m';;
    esac
    (( use_color )) && reset=$'\033[0m'
    local line
    line="$(printf '[%s] [%-5s] %s' "$(date '+%Y-%m-%d %H:%M:%S')" "$lvl" "$msg")"
    printf '%s%s%s\n' "$color" "$line" "$reset" >> "$logfile"
  }
  log_debug() { _log DEBUG "$@"; }
  log_info()  { _log INFO  "$@"; }
  log_warn()  { _log WARN  "$@"; }
  log_error() { _log ERROR "$@"; }
  log_info  "system started"
  log_debug "config loaded from /etc/app.conf"
  log_warn  "cache miss rate 12%"
  log_error "connection refused to db:5432"
  echo "日志已写入 $logfile (共 $(wc -l < "$logfile") 行)"
}

# ============================================================================
#  HARD 81-100
# ============================================================================

h81() {
  my_wc() {
    local f=$1 lines=0 words=0 chars=0 line
    local -a w
    if [[ ! -f $f ]]; then printf '%6d %6d %7d %s\n' 0 0 0 "$f"; return 1; fi
    while IFS= read -r line || [[ -n $line ]]; do
      ((lines++)); ((chars += ${#line} + 1))
      w=(); read -ra w <<< "$line"; ((words += ${#w[@]}))
    done < "$f"
    printf '%6d %6d %7d %s\n' "$lines" "$words" "$chars" "$f"
  }
  printf '%6s %6s %7s %s\n' LINES WORDS CHARS FILE
  local -a files=("$@")
  (( ${#files[@]} == 0 )) && { demo_setup; printf 'hello world\nsecond line\n' > "$DEMO/h81.txt"; files=("$DEMO/h81.txt"); }
  local f; for f in "${files[@]}"; do my_wc "$f"; done
  echo "（实现：纯 bash 循环，未调用 wc）"
}

h82() {
  my_head() {
    local n=$1 f=$2 i=0 line
    while IFS= read -r line || [[ -n $line ]]; do
      (( ++i > n )) && break; echo "$line"
    done < "$f"
  }
  my_tail() {
    local n=$1 f=$2; local -a buf=()
    local line; while IFS= read -r line || [[ -n $line ]]; do buf+=("$line"); done < "$f"
    local start=$(( ${#buf[@]} - n )); (( start < 0 )) && start=0
    printf '%s\n' "${buf[@]:start}"
  }
  local f="$WORK/h82.txt"; seq 1 20 > "$f"
  echo "head 5:  $(my_head 5 "$f" | paste -sd, -)"
  echo "tail 5:  $(my_tail 5 "$f" | paste -sd, -)"
  echo "tail 99: $(my_tail 99 "$f" | wc -l) 行(请求超出,自动截断)"
}

h83() {
  local -a a=($(cat "${1:-$(DEMO_FILE s1)}")) b=($(cat "${2:-$(DEMO_FILE s2)}"))
  declare -A seen=(); local v
  for v in "${a[@]}"; do seen[$v]=1; done
  echo "A 去重排序: $(printf '%s\n' "${!seen[@]}" | sort -n | paste -sd' ' -)"
  declare -A inb=(); for v in "${b[@]}"; do inb[$v]=1; done
  local i
  for i in "${!seen[@]}"; do echo "$i"; done | sort -n > "$WORK/_A"
  for i in "${!inb[@]}"; do echo "$i"; done | sort -n > "$WORK/_B"
  echo "交集: $(comm -12 "$WORK/_A" "$WORK/_B" | paste -sd' ' -)"
  echo "并集: $(cat "$WORK/_A" "$WORK/_B" | sort -nu | paste -sd' ' -)"
  echo "差集: $(comm -23 "$WORK/_A" "$WORK/_B" | paste -sd' ' -)"
}

h84() {
  # 把常见正则语法翻译为 bash ERE 可用的等价形式（本例为受限实现演示）
  my_match() {
    local pat=$1 str=$2
    # ERE 转换：{n} 需 bash 3.2+ 支持，这里做有限支持
    [[ $str =~ $pat ]]
  }
  local -a pats=( '^h.*o$' '^[a-z]+[0-9]{2}$' 'foo|bar' '^[A-Z]{2,3}$' )
  local -a tests=( "hello" "ab12" "bar" "ABC" "nope" )
  for p in "${pats[@]}"; do
    printf '  /%s/\n' "$p"
    for t in "${tests[@]}"; do
      if my_match "$p" "$t"; then printf '    ✓ %s\n' "$t"; fi
    done
  done
  mygrep() { my_match "$1" "$2" && echo "$2"; }
  echo "mygrep '^[a-z]+$' 'hello' → $(mygrep '^[a-z]+$' hello)"
}

h85() {
  # 栈：结果写入全局 RES，避免 $( ) 子 shell 中修改丢失
  STACK=(); RES=""
  push() { STACK+=("$1"); }
  pop()  { if (( ${#STACK[@]} == 0 )); then RES="stack empty"; return 1; fi
           RES=${STACK[-1]}; unset 'STACK[-1]'; }
  peek() { RES=${STACK[-1]:-empty}; }
  # 队列：出队改为移动头指针
  QUEUE=(); QHEAD=0
  enqueue() { QUEUE+=("$1"); }
  dequeue() { if (( QHEAD >= ${#QUEUE[@]} )); then RES="queue empty"; return 1; fi
              RES=${QUEUE[QHEAD]}; ((QHEAD++)); }

  echo "--- 栈演示 (LIFO) ---"
  push a; push b; push c
  peek; echo "peek = $RES"
  pop;  echo "pop  = $RES"
  pop;  echo "pop  = $RES"
  pop;  echo "pop  = $RES"
  echo "--- 队列演示 (FIFO) ---"
  enqueue 1; enqueue 2; enqueue 3
  dequeue; echo "deq = $RES"
  dequeue; echo "deq = $RES"
  dequeue; echo "deq = $RES"
  echo "--- 括号匹配 ---"
  local s='([]{})' c ok=1
  local -a st=()
  for c in "${s//[^()\[\]{}]/}"; do
    case $c in '('|'['|'{') st+=("$c");;
      ')') [[ ${st[-1]:-} == '(' ]] && unset 'st[-1]' || ok=0;;
      ']') [[ ${st[-1]:-} == '[' ]] && unset 'st[-1]' || ok=0;;
      '}') [[ ${st[-1]:-} == '{' ]] && unset 'st[-1]' || ok=0;;
    esac
  done
  (( ${#st[@]} == 0 )) || ok=0
  (( ok )) && echo "$s → balanced" || echo "$s → unbalanced"
}

h86() {
  local -a a=(1 3 5 7 9 11 13)
  local -i steps=0
  binary_search() {
    local target=$1 lo=0 hi=$((${#a[@]}-1))
    steps=0
    local mid v
    while (( lo <= hi )); do
      ((steps++))
      mid=$(( (lo+hi)/2 )); v=${a[mid]}
      if (( v == target )); then printf 'found index %d (steps=%d)\n' "$mid" "$steps"; return 0
      elif (( v < target )); then lo=$((mid+1))
      else hi=$((mid-1)); fi
    done
    printf 'not found (steps=%d)\n' "$steps"; return 1
  }
  echo "数组: ${a[*]}"
  binary_search 9
  binary_search 4
}

h87() {
  local -a arr=(5 3 8 1 9 2 7)
  bubble() {
    local -a x=("$@"); local n=${#x[@]} i j t cmp=0 swp=0
    for ((i=0;i<n-1;i++)); do
      local swapped=0
      for ((j=0;j<n-1-i;j++)); do
        ((cmp++))
        if (( x[j] > x[j+1] )); then t=${x[j]}; x[j]=${x[j+1]}; x[j+1]=$t; ((swp++)); swapped=1; fi
      done
      ((swapped)) || break
    done
    printf '冒泡排序: %s\n比较=%d 交换=%d\n' "${x[*]}" "$cmp" "$swp"
  }
  quick() {
    local -a x=("$@") cmp=0
    _qsort() {
      local -a a=("$@"); (( ${#a[@]} <= 1 )) && { QS+=("${a[@]}"); return; }
      local pivot=${a[0]} less=() more=()
      local i
      for ((i=1;i<${#a[@]};i++)); do
        ((cmp++))
        if (( a[i] < pivot )); then less+=("${a[i]}"); else more+=("${a[i]}"); fi
      done
      _qsort "${less[@]}"; QS+=("$pivot"); _qsort "${more[@]}"
    }
    QS=(); _qsort "${x[@]}"
    printf '快速排序: %s\n比较次数=%d\n' "${QS[*]}" "$cmp"
  }
  bubble "${arr[@]}"
  quick "${arr[@]}"
}

h88() {
  declare -A A B
  local -a ma=(1 2 3 4 5 6 7 8 9) mb=(9 8 7 6 5 4 3 2 1)
  local i j k s
  for ((i=0;i<3;i++)); do
    for ((j=0;j<3;j++)); do
      A[$i,$j]=${ma[i*3+j]}
      B[$i,$j]=${mb[i*3+j]}
    done
  done
  printf 'A =\n'; for ((i=0;i<3;i++)); do printf '  '; for ((j=0;j<3;j++)); do printf '%5d' "${A[$i,$j]}"; done; echo; done
  printf 'B =\n'; for ((i=0;i<3;i++)); do printf '  '; for ((j=0;j<3;j++)); do printf '%5d' "${B[$i,$j]}"; done; echo; done
  echo "A × B ="
  for ((i=0;i<3;i++)); do
    printf '  '
    for ((j=0;j<3;j++)); do
      s=0
      for ((k=0;k<3;k++)); do (( s += A[$i,$k] * B[$k,$j] )); done
      printf '%5d' "$s"
    done
    echo
  done
  echo "验证 C[0,0] = 1*9+2*6+3*3 = $(( 1*9+2*6+3*3 ))"
}

h89() {
  local db="$WORK/todo.db"; : > "$db"
  _id() { local n; n=$(grep -c . "$db" || true); echo $(( n + 1 )); }
  add()   { local id; id=$(_id); printf '%s\t%s\n' "$id" "$1" >> "$db"; echo "added #$id $1"; }
  list()  { awk -F'\t' 'BEGIN{printf "%-4s %-6s %s\n","ID","STATUS","TASK"}
                    {printf "%-4s %-6s %s\n",$1,($2=="1"?"[x]":"[ ]"),$3}' "$db"; }
  done_() { local id=$1; awk -F'\t' -v OFS='\t' -v id="$id" '$1==id{$2="1"}1' "$db" > "$db.tmp" && mv "$db.tmp" "$db"
           echo "marked #$id done"; }
  rm_()   { local id=$1; awk -F'\t' -v id="$id" '$1!=id' "$db" > "$db.tmp" && mv "$db.tmp" "$db"
           echo "removed #$id"; }
  stats() { awk -F'\t' '{t++; if($2=="1")d++} END{printf "total=%d done=%d pending=%d\n", t, d+0, t-(d+0)}' "$db"; }
  add "写 Shell Linter"; add "重读CRC32 推导"; add "整理 awk 状态机笔记"
  done_ 2
  list; stats
}

h90() {
  demo_setup
  local db="$DEMO/menu.db"; printf '' > "$db"
  echo "=== select 菜单系统（以脚本输入模拟交互） ==="
  local choice
  # select 需要 stdin；这里用 here-string 提供选择序列（1 添加 / 2 列出 / 9 非法 / 4 退出）
  # 关键: select 读到 EOF 时 REPLY 为空，用它作为退出条件，避免 while true 空转
  while true; do
    select choice in "添加条目" "列出条目" "删除条目" "退出"; do
      case $choice in
        "添加条目")
          local n; n=$(wc -l < "$db" 2>/dev/null || echo 0)
          printf '%s\t%s\n' "$(( n + 1 ))" "bash-script" >> "$db"
          echo "  已添加: #$(( n + 1 )) bash-script" ;;
        "列出条目")
          if [[ -s $db ]]; then awk -F'\t' '{printf "  #%-4s %s\n", $1, $2}' "$db"
          else echo "  (空)"; fi ;;
        "删除条目")
          local last; last=$(wc -l < "$db" 2>/dev/null || echo 0)
          if (( last > 0 )); then
            head -n -1 "$db" > "$db.new" && mv -f "$db.new" "$db"
            echo "  已删除最后一条，剩余 $(( last - 1 )) 条"
          else echo "  (无可删除条目)"; fi ;;
        "退出") echo "bye"; return 0 ;;
        *) echo "  非法输入: '$REPLY'，请重试" ;;
      esac
      break
    done
    [[ -z ${REPLY:-} ]] && { echo "bye"; return 0; }
    break        # 非交互演示：消费一次选择后退出
  done <<< $'1
2
9
4'
}

h91() {
  demo_setup
  local logf="$DEMO/access.log"
  cat > "$logf" <<'LOGEOF'
1.2.3.4 - - [20/Oct/2026:10:00:01 +0800] "GET /a HTTP/1.1" 200 1024 "-" "curl/8"
1.2.3.5 - - [20/Oct/2026:10:00:02 +0800] "GET /b HTTP/1.1" 404 256 "-" "curl/8"
1.2.3.4 - - [20/Oct/2026:10:00:03 +0800] "POST /a HTTP/1.1" 200 4096 "-" "curl/8"
10.0.0.9 - - [20/Oct/2026:10:01:00 +0800] "GET /c HTTP/1.1" 500 128 "-" "Mozilla/5"
LOGEOF
  echo "样例日志 ($(wc -l < "$logf") 行):"; sed 's/^/  /' "$logf"
  echo
  echo "解析结果:"
  # combined 格式：先用 index/substr 把引号内的请求行整体取出，规避 awk 对引号内空格的拆分
  awk '{
    line = $0
    p1 = index(line, "\"")                 # 请求行起始引号
    rest = substr(line, p1 + 1)
    p2  = index(rest, "\"")                # 请求行结束引号
    req = substr(rest, 1, p2 - 1)          # GET /a HTTP/1.1
    split(req, R, " ")                     # R[1]=method R[2]=url R[3]=version
    tail = substr(rest, p2 + 1)            # " 200 1024 - \"curl/8\""
    sub(/ "[^"]*"$/, "", tail)             # 去掉末尾 UA 引号段
    split(tail, T, " ")
    st = T[1]; byt = T[2] + 0
    ip = $1
    code[st]++; ips[ip]++; urls[R[2]]++; total += byt; n++
  }
  END {
    printf "请求总数 : %d\n", n
    printf "总流量   : %d bytes (%.2f KB)\n", total, total/1024
    printf "平均大小 : %.1f bytes\n", total/n
    print "\n状态码分布:"
    for (c in code) printf "  %-5s %d\n", c, code[c]
    print "\nTop URL:"
    for (u in urls) printf "  %-8s %d\n", u, urls[u]
  }' "$logf"
  echo
  echo "Top IP（shell 侧排序）:"
  awk '{print $1}' "$logf" | sort | uniq -c | sort -rn | head -3 | \
    awk '{printf "  %-16s %d\n", $2, $1}'
  echo
  echo "Top URL（按次数排序）:"
  awk '{print $7}' "$logf" | sort | uniq -c | sort -rn | head -3 | \
    awk '{printf "  %-8s %d\n", $2, $1}'
}

h92() {
  local csv="$WORK/quoted.csv"
  printf 'id,name,note\n1,"Smith, John","said ""hi"""\n2,"多列,含逗号","line1\\nline2"\n3,plain,ok\n' > "$csv"
  echo "原始:"; cat "$csv"
  echo
  echo "解析结果 (awk 状态机):"
  awk '
  function flush_field(   i, c) {
    f=gsub(/\\n/, "\n", cur); fld[++nf]=cur; cur=""; inq=0
  }
  BEGIN{ RS="\n"; OFS=" | " }
  {
    line=$0
    if (inrec) line = "\n" line
    n=length(line)
    for (i=1; i<=n; i++) {
      c=substr(line,i,1)
      if (c=="\"") {
        if (inq && substr(line,i+1,1)=="\"") { cur=cur "\""; i++; continue }
        inq = !inq; continue
      }
      if (c=="," && !inq) { flush_field(); continue }
      cur = cur c
    }
    if (!inq) { print fld[1], fld[2], (fld[3]==""?"-":fld[3]); nf=0; cur=""; inrec=0 }
    else inrec=1
  }' "$csv"
  echo
  echo "FPAT 写法（更简洁）："
  awk 'BEGIN{FPAT="([^,]*)|(\"[^\"]*\")"} {print "id="$1", name="$2", note_len="length($3)}' "$csv"
}

h93() {
  local logf="$WORK/stack.log"
  cat > "$logf" <<'EOF'
START req-001
  at Foo.bar()
  at Baz.qux()
END req-001
START req-002
  at Foo.bar()
START req-003
  at Foo.bar()
END req-003
END req-999
EOF
  awk '
  /^START /{ st=$2; state[st]="open"; order[++n]=st; next }
  /^END /{ st=$2
      if (!(st in state)) { printf "  [孤儿 END] %s — 从未 START\n", st; errs++ }
      else if (state[st]=="closed") { printf "  [重复 END] %s\n", st; errs++ }
      else { state[st]="closed"; printf "  [闭合] %s\n", st }
      next }
  END{
    for (i=1;i<=n;i++){ s=order[i]; if (state[s]=="open") printf "  [未闭合] %s\n", s }
    printf "\n共 %d 个 START，异常 %d 处\n", n, errs+0
  }' "$logf"
}

h94() {
  mywatch() {
    local interval=0 count=3 cmd="date +%H:%M:%S" OPTIND=1
    while getopts ":n:c:" o; do
      case $o in
        n) interval=$OPTARG ;;
        c) count=$OPTARG ;;
        *) echo "usage: mywatch [-n sec] [-c times] 'cmd'"; return 1 ;;
      esac
    done
    shift $((OPTIND-1)); cmd="${1:-date +%H:%M:%S}"
    echo "watch: '$cmd'  间隔=${interval}s  次数=$count"
    local i=1
    while (( i <= count )); do
      echo "--- #$i @ $(date +%H:%M:%S) ---"
      eval "$cmd"
      (( i < count )) && sleep "$interval"
    done
  }
  mywatch -n 0 -c 3 'echo "tick: 进程 $(date +%H:%M:%S)"'
}

h95() {
  demo_setup; local maxjobs=${1:-4} total=${2:-10} failfile="$DEMO/fail.txt"; printf '' > "$failfile"
  task() {
    local id=$1
    sleep "0.$(( (RANDOM % 2) + 1 ))"
    if (( id % 5 == 0 )); then echo "$id" >> "$failfile"; return 1; fi
    echo "task $id ok"
  }
  local t0 t1; t0=$(date +%s.%N)
  local -a pids=(); local id
  for ((id=1; id<=total; id++)); do
    task "$id" & pids+=($!)
    while (( $(jobs -rp | wc -l) >= maxjobs )); do wait -n; done
  done
  wait
  t1=$(date +%s.%N)
  awk "BEGIN{printf \"\n并发上限=%d 总任务=%d 总耗时=%.1fs\n\", $maxjobs, $total, $t1-$t0}"
  echo "失败任务: $(paste -sd, "$failfile")"
}

h96() {
  local -a failures=() ntest=0 nassert=0
  assert_eq() {
    ((nassert++))
    if [[ "$1" == "$2" ]]; then echo "ok $nassert - $3"
    else echo "not ok $nassert - $3 (got [$1] want [$2])"; failures+=("$3"); fi
  }
  assert_contains() {
    ((nassert++))
    if [[ "$1" == *"$2"* ]]; then echo "ok $nassert - $3"
    else echo "not ok $nassert - $3 (missing [$2])"; failures+=("$3"); fi
  }
  test_case() {
    ((ntest++)); echo "# --- $1 ---"
  }
  echo "TAP version 13"
  test_case "基础算术"
  assert_eq "$(e04 10)" "55" "sum 1..10 = 55"
  assert_eq "$(e05 5)" "120" "5! = 120"
  test_case "字符串"
  assert_eq "$(e10 bash)" "hsab" "reverse bash"
  assert_eq "$(e08 1900)" "not-leap" "1900 not leap"
  assert_eq "$(e08 2000)" "leap" "2000 leap"
  test_case "工具函数"
  printf 'alpha\nbeta\nalpha\ngamma\nalpha\n' > "$WORK/tap_t.txt"
  assert_contains "$(m60 -c '^alpha' "$WORK/tap_t.txt")" "3" "mygrep -c 计数"
  assert_eq "$(m33 "$(DEMO_FILE dupcheck)" | paste -sd, -)" "b,a,c" "关联数组去重保序"
  echo "1..$nassert"
  echo "# tests=$ntest assertions=$nassert failures=${#failures[@]}"
  (( ${#failures[@]} == 0 )) && return 0 || return 1
}

h97() {
  local deps="a: b c
b: c
c:
d: b"
  echo "依赖关系:"
  printf '%s\n' "$deps" | sed 's/^/  /'
  declare -A need=()
  local -a order=()
  local line
  while IFS= read -r line; do
    local k=${line%%:*} v=${line#*:}
    need[$k]="$v"              # 保留空格分隔，下面用 read -ra 拆词
    order+=("$k")              # 固定顺序，避免关联数组遍历顺序不确定
  done <<< "$deps"
  local -a done_=()
  for line in "${order[@]}"; do done_+=("0"); done
  local total=${#order[@]} done_cnt=0 rounds=0
  # Kahn 算法：每轮从头扫描（固定顺序），直到全部完成或一轮无进展（= 有环）
  while (( done_cnt < total )); do
    ((++rounds > total + 1 )) && break
    local progress=0 i
    for (( i=0; i<total; i++ )); do
      (( ${done_[i]} )) && continue
      local x=${order[i]} ready=1 dep
      local -a deplist=(); read -ra deplist <<< "${need[$x]}"
      for dep in "${deplist[@]}"; do
        local j=0 found=0
        while (( j < total )); do
          [[ ${order[j]} == "$dep" ]] && { found=1; (( ${done_[j]} )) || { ready=0; }; break; }
          ((j++))
        done
        (( found )) || { echo "未声明的依赖: $dep (被 $x 引用)"; return 1; }
        (( ready )) || break
      done
      if (( ready )); then
        printf '  [build] %s\n' "$x"; done_[i]=1; ((done_cnt++)); ((progress=1))
      fi
    done
    (( progress )) || { echo "检测到循环依赖（无进展）!"; return 1; }
  done
  echo "构建完成: $done_cnt/$total（$rounds 轮扫描）"
}

h98() {
  # 纯 bash CRC32 (IEEE 802.3, 反转多项式 0xEDB88320, 初值 0xFFFFFFFF, 末尾取反)
  # 关键点：XOR 字节时不能 & 0xFF（那会丢掉高 24 位），只在整个 32 位字上做掩码
  crc32() {
    local data=$1 i byte k
    local -i c=4294967295          # 0xFFFFFFFF
    local -i POLY=3988292384     # 0xEDB88320
    local -i MASK=4294967295     # 0xFFFFFFFF
    for (( i=0; i<${#data}; i++ )); do
      byte=$(printf '%d' "'${data:i:1}")
      c=$(( (c ^ byte) & MASK ))
      for (( k=0; k<8; k++ )); do
        if (( c & 1 )); then c=$(( ((c >> 1) ^ POLY) & MASK ))
        else                c=$(( (c >> 1) & MASK )); fi
      done
    done
    c=$(( (c ^ MASK) & MASK ))
    printf '%08X' "$c"
  }
  echo "CRC32 (多项式 0xEDB88320, 初值 0xFFFFFFFF, 末尾取反, 全程 32 位掩码)"
  local s
  for s in "" "a" "abc" "123456789" "The quick brown fox jumps over the lazy dog"; do
    printf '  %-45s → 0x%s\n' "\"$s\"" "$(crc32 "$s")"
  done
  echo
  echo "已知向量校验: CRC32(\"123456789\") 应为 0xCBF43926"
  local pass=0
  [[ $(crc32 "123456789") == "CBF43926" ]] && pass=$((pass+1)) && echo "  ✓ 通过"
  [[ $(crc32 "a")         == "E8B7BE43" ]] && pass=$((pass+1)) && echo "  ✓ 通过 (a)"
  [[ $(crc32 "abc")       == "352441C2" ]] && pass=$((pass+1)) && echo "  ✓ 通过 (abc)"
  [[ $(crc32 "")          == "00000000" ]] && pass=$((pass+1)) && echo "  ✓ 通过 (空串)"
  echo "  通过 $pass/4"
}

h99() {
  # 事务式写入：临时文件 → 校验 → 备份 → 原子 mv；任一步失败回滚
  # 注意: 清理用 mv 而非 rm，避免 Windows 路径与安全钩子的兼容问题
  demo_setup
  local f=${1:-$DEMO/config.ini} content=${2:-key=value} out_rb="$DEMO/rollback.ini"
  _drop() { local p=$1; [[ -e $p ]] && mv -f "$p" "$(dirname "$p")/.discard.$$.$(basename "$p")" 2>/dev/null; return 0; }
  safe_write() {
    local tgt="$1" data="$2" dir tmp bak
    dir=$(dirname "$tgt")
    tmp="$dir/.sw.$$.$RANDOM.tmp"
    bak="$dir/.bak.$$.$(basename "$tgt")"
    # 1) 写临时文件
    printf '%s' "$data" > "$tmp" || { echo "1) 写临时文件失败"; _drop "$tmp"; return 1; }
    # 2) 校验：临时文件必须存在，且内容长度必须与输入一致
    local got; got=$(cat "$tmp" 2>/dev/null)
    if [[ ! -e $tmp || $got != "$data" ]]; then echo "2) 校验失败，回滚"; _drop "$tmp"; return 1; fi
    # 3) 备份原文件（bak 路径在函数开头已生成，此处直接复制）
    if [[ -f $tgt ]]; then
      cp -p "$tgt" "$bak" || { echo "3) 备份失败，回滚"; _drop "$tmp"; return 1; }
    else
      bak=""
    fi
    # 4) 原子替换（同一文件系统内 mv 为原子操作）
    if ! mv -f "$tmp" "$tgt"; then
      echo "4) 替换失败，回滚备份"
      [[ -n $bak ]] && mv -f "$bak" "$tgt"
      _drop "$tmp"; return 1
    fi
    # 5) 清理备份
    [[ -n $bak ]] && mv -f "$bak" "$dir/.discard.$$.$(basename "$bak")"
    echo "写入成功: $tgt"
    return 0
  }
  printf '' > "$f" 2>/dev/null || true
  echo "初始内容: '$(cat "$f" 2>/dev/null)'"
  safe_write "$f" "$content"
  echo "最终内容: '$(cat "$f")'"
  echo "无残留 .sw./.bak. 临时文件: $(find "$(dirname "$f")" \( -name '.sw.*' -o -name '.bak.*' \) 2>/dev/null | wc -l | tr -d ' ') 个"
  echo "回滚演练: 目标不可写时应触发回滚，且原文件内容不变"
  local orig rb; orig=$(cat "$f"); rb="$out_rb"
  safe_write "$rb" "$content" >/dev/null 2>&1
  if [[ -f $rb && $(cat "$rb") == "$content" ]]; then echo "  ✓ 独立文件写入正常"; else echo "  ✗ 独立写入异常"; fi
  # 校验演示：写入内容后比对回读结果，一致才算校验通过
  printf '%s' "$content" > "$DEMO/verify.tmp"
  if [[ $(cat "$DEMO/verify.tmp" 2>/dev/null) == "$content" ]]; then
    echo "  ✓ 内容一致性校验通过"
  else
    echo "  ✗ 校验未生效"
  fi
}

h100() {
  local target=${1:-}
  local score=100 total=0 issues=0
  local -a details=()
  check() {
    local sev=$1 msg=$2
    ((total++))
    case $sev in
      ERROR) ((issues++)); ((score-=15)); details+=("ERROR  $msg");;
      WARN)  ((issues+=0)); ((score-=5)); details+=("WARN   $msg");;
    esac
  }
  local first
  first=$(head -1 "$target")
  [[ $first == "#!"* ]] || check ERROR "缺少 shebang"

  grep -qE '^set -[a-zA-Z]*e' "$target" || check WARN  "建议启用 set -e"
  grep -qE '^set -[a-zA-Z]*u' "$target" || check WARN  "建议启用 set -u"
  grep -qE '^set -[a-zA-Z]*o *pipefail' "$target" || check WARN "建议启用 set -o pipefail"

  # 未加引号的变量展开（启发式：$var 前后有空格且未在引号内）
  local ln
  while IFS= read -r ln; do
    ((ln++))
    grep -qE '(^|[^"$\\])[a-zA-Z_][a-zA-Z0-9_]*\$[a-zA-Z_][a-zA-Z0-9_]*' <<<"$ln" && \
      check WARN "line $ln: 变量可能未加引号 → $ln"
  done < "$target"

  grep -nE '\$\(\(.*==.*\)\)' "$target" | while IFS=: read -r l c; do
    check ERROR "line $l: 在 (( )) 内使用 == ，应使用 ="
  done

  grep -nE '\$@[^"'"'"']' "$target" | head -3 | while IFS=: read -r l c; do
    check WARN "line $l: \$@ 可能需要加引号"
  done

  grep -nE '\[[^]]*[a-zA-Z]/[a-zA-Z][^]]*\]' "$target" | while IFS=: read -r l c; do
    check WARN "line $l: 路径中含空格却未加引号"
  done

  printf '文件: %s\n检查项: %d  问题: %d\n评分: %d/100\n\n' "$target" "$total" "$issues" "$(( score < 0 ? 0 : score ))"
  for d in "${details[@]}"; do echo "  $d"; done
  (( ${#details[@]} == 0 )) && echo "  ✓ 未发现问题"
}

# ============================================================================
#  自测用例
# ============================================================================
declare -A TESTFN=(
  [1]=e01 [2]=e02 [3]=e03 [4]=e04 [5]=e05 [6]=e06 [7]=e07 [8]=e08 [9]=e09 [10]=e10
  [11]=e11 [12]=e12 [13]=e13 [14]=e14 [15]=e15 [16]=e16 [17]=e17 [18]=e18 [19]=e19 [20]=e20
  [21]=e21 [22]=e22 [23]=e23 [24]=e24 [25]=e25 [26]=e26 [27]=e27 [28]=e28 [29]=e29 [30]=e30
  [31]=m31 [32]=m32 [33]=m33 [34]=m34 [35]=m35 [36]=m36 [37]=m37 [38]=m38 [39]=m39 [40]=m40
  [41]=m41 [42]=m42 [43]=m43 [44]=m44 [45]=m45 [46]=m46 [47]=m47 [48]=m48 [49]=m49 [50]=m50
  [51]=m51 [52]=m52 [53]=m53 [54]=m54 [55]=m55 [56]=m56 [57]=m57 [58]=m58 [59]=m59 [60]=m60
  [61]=m61 [62]=m62 [63]=m63 [64]=m64 [65]=m65 [66]=m66 [67]=m67 [68]=m68 [69]=m69 [70]=m70
  [71]=m71 [72]=m72 [73]=m73 [74]=m74 [75]=m75 [76]=m76 [77]=m77 [78]=m78 [79]=m79 [80]=m80
  [81]=h81 [82]=h82 [83]=h83 [84]=h84 [85]=h85 [86]=h86 [87]=h87 [88]=h88 [89]=h89 [90]=h90
  [91]=h91 [92]=h92 [93]=h93 [94]=h94 [95]=h95 [96]=h96 [97]=h97 [98]=h98 [99]=h99 [100]=h100
)

run_selftest() {
  sec "语法检查"
  if bash -n "${BASH_SOURCE[0]}" 2>/dev/null; then ok "answers.sh 自身语法正确"
  else bad "answers.sh 语法错误" "-" "OK"; fi

  sec "E01-E05"
  chk "E01 0参数" "$(e01)" "Hello, World!"
  chk "E01 1参数" "$(e01 Ada)" "Hello, Ada!"
  chk "E01 3参数" "$(e01 Hi Ada 36)" "Hi, Ada! You are 36 years old."
  chk "E02 默认值" "$(e02 | tr '\n' ' ')" "A=default_a B=fallback set=no unset=no "
  chk "E03 算术" "$(e03 10 4 | tr '\n' ' ')" "sum=14 diff=6 prod=40 div=2 "
  chk "E03 除零" "$(e03 10 0 | tail -1)" "div=ERROR"
  chk "E04 累加" "$(e04 100)" "5050"
  chk "E05 阶乘5" "$(e05 5)" "120"
  chk "E05 阶乘0" "$(e05 0)" "1"
  chk "E05 溢出" "$(e05 21)" "OVERFLOW"

  sec "E06-E12"
  chk "E06 fib(10)" "$(e06 10)" "55"
  chk "E07 even" "$(e07 4)" "even"
  chk "E07 odd" "$(e07 7)" "odd"
  chk "E08 1900" "$(e08 1900)" "not-leap"
  chk "E08 2000" "$(e08 2000)" "leap"
  chk "E08 2024" "$(e08 2024)" "leap"
  chk "E09 长度" "$(e09 hello)" "5"
  chk "E10 反转" "$(e10 bash)" "hsab"
  chk "E11 回文A man" "$(e11 "A man a plan a canal Panama")" "palindrome"
  chk "E11 非回文" "$(e11 hello)" "not-palindrome"
  chk "E12 词数" "$(e12 "the quick brown fox")" "4"

  sec "E13-E20"
  chk "E13 upper" "$(e13 abc | sed -n 2p)" "upper=ABC"
  chk "E13 cap1" "$(e13 abc | sed -n 4p)" "cap1=Abc"
  chk "E14 max" "$(e14 3 9 5 | cut -d' ' -f1)" "max=9"
  chk "E14 min" "$(e14 3 9 5 | cut -d' ' -f2)" "min=3"
  chk "E15 绝对值" "$(e15 -42)" "42"
  chk "E16 交换" "$(e16 a b)" "b a"
  local tf="$WORK/e17.txt"; echo x > "$tf"
  chk "E17 readable" "$(e17 "$tf")" "readable"
  chk "E17 missing" "$(e17 "$WORK/nope")" "not-exist"
  chk "E18 目录计数" "$(e18 "$WORK")" "$(find "$WORK" -maxdepth 1 -type f | wc -l)"
  chk "E20 no args" "$(e20)" "no-args"
  chk "E20 count" "$(e20 a b | head -1)" "count=2"

  sec "E21-E30"
  chk "E21 shift" "$(e21 x y | paste -sd'|' -)" "第1个: x|第2个: y"
  chk "E22 表达式" "$(e22 "12+3*5")" "27"
  chk "E22 优先级+括号" "$(e22 "(2+3)*4")" "20"
  chk "E22 负数与除法" "$(e22 "100/7-3")" "11"
  chk "E23 OK" "$(e23 true)" "OK"
  chk "E23 NOT_FOUND" "$(e23 no_such_cmd_xyz)" "NOT_FOUND"
  chk "E28 算术替换" "$(e28 | tail -1)" '$(( )) 内建算术 → 11 (类型: 整数)'
  chk "E29 email" "$(e29 "a.b+c@ex-ample.co.uk" | grep -c valid)" "1"
  chk "E29 invalid" "$(e29 "not-an-email" | grep -c 'not a valid')" "1"

  sec "M31-M40"
  chk "M31 数组" "$(m31 | grep -o 'sum=[0-9]*')" "sum=25"
  chk "M32 max" "$(m32 5 3 9 | grep -o 'max=[0-9]*')" "max=9"
  chk "M32 min" "$(m32 5 3 9 | grep -o 'min=[0-9]*')" "min=3"
  chk "M32 sorted" "$(m32 5 3 9 | head -1)" "sorted: 3 5 9"
  local uf="$WORK/u.txt"; printf 'b\na\nb\nc\na\n' > "$uf"
  chk "M33 去重保序" "$(m33 "$uf" | paste -sd, -)" "b,a,c"
  chk "M34 词频" "$(printf 'a b a c a b\n' > "$WORK/w.txt"; m34 "$WORK/w.txt" | head -1)" "3 a"
  local md="$WORK/m35"; mkdir -p "$md"; : > "$md/small"; dd if=/dev/zero of="$md/big" bs=1k count=50 2>/dev/null
  chk "M35 最大文件" "$(m35 "$md" | head -1 | grep -c '5242880\|51200')" "1"
  chk "M35 最大在前" "$(m35 "$md" | head -1 | grep -c 'big')" "1"
  chk "M36 扩展名统计" "$(printf 'a.txt\nb.txt\nc.log\n' > "$md/x.txt"; printf 'y.log\n' > "$md/y.log"; printf 'z.md\n' > "$md/z.md"; m36 "$md" | grep '^txt ' | awk '{print $1,$2}')" "txt 1"
  local bd="$WORK/m38"; mkdir -p "$bd"; echo x > "$bd/a.log"; echo y > "$bd/b.log"
  m38 "$bd" >/dev/null 2>&1
  chk "M38 备份数" "$(find "$bd" -name '*.bak' | wc -l)" "2"
  chk "M40 mtime" "$(m40 "$bd" 7 | wc -l | tr -d ' ')" "0"

  sec "M41-M50"
  local sp="$WORK/m41"; mkdir -p "$sp"; echo 1 > "$sp/with space.txt"; echo 1 > "$sp/normal.txt"
  chk "M41 含空格文件名" "$(m41 "$sp" | grep -c 'with space.txt')" "1"
  chk "M43 diffstat" "$(printf '1\n2\n3\n' > "$WORK/d1"; printf '1\n2\n4\n' > "$WORK/d2"; m43 "$WORK/d1" "$WORK/d2" | grep -o 'common=2')" "common=2"
  chk "M44 归并" "$(printf '1\n3\n' > "$WORK/s1"; printf '2\n4\n' > "$WORK/s2"; m44 "$WORK/s1" "$WORK/s2" | paste -sd, -)" "1,2,3,4"
  seq 1 10 > "$WORK/m45.txt"; m45 "$WORK/m45.txt" 3 "$WORK/part" >/dev/null
  chk "M45 切分" "$(rm -rf "$WORK/split"; mkdir -p "$WORK/split"; seq 1 10 > "$WORK/split/in.txt"; m45 "$WORK/split/in.txt" 3 "$WORK/split/part" >/dev/null; cat "$WORK/split/part003" | wc -l | tr -d ' ')" "3"
  chk "M45 片数" "$(ls "$WORK/split"/part0* | wc -l | tr -d ' ')" "4"
  chk "M45 末片" "$(cat "$WORK/split/part004" | tr -d '\n')" "10"
  rm -rf "$WORK/sums"; mkdir -p "$WORK/sums"; printf 'hello\n' > "$WORK/sums/a.txt"; printf 'world\n' > "$WORK/sums/b.txt"
  chk "M47 校验和" "$(m47 "$WORK/sums" "$WORK/sums/SHA256SUMS.txt" | grep -c '已生成')" "1"
  chk "M47 条目数" "$(wc -l < "$WORK/sums/SHA256SUMS.txt" | tr -d ' ')" "2"
  chk "M48 校验通过" "$(m48 "$WORK/sums/SHA256SUMS.txt" 2>&1 | tail -1)" "OK=2 FAILED=0 MISSING=0"
  printf 'tampered\n' >> "$WORK/sums/a.txt"
  chk "M48 检出篡改" "$(m48 "$WORK/sums/SHA256SUMS.txt" 2>&1 | tail -1)" "OK=1 FAILED=1 MISSING=0"
  printf 'name,score\na,10\nb,20\n' > "$WORK/c.csv"
  chk "M49 awk sum" "$(m49 "$WORK/c.csv" | grep -o 'sum=30')" "sum=30"
  printf 'k,v\nx,1\nx,2\ny,5\n' > "$WORK/g.csv"
  chk "M50 分组聚合" "$(m50 "$WORK/g.csv" | grep '^x')" "x 3 2"

  sec "M51-M60"
  chk "M51 邮箱" "$(printf 'id,mail\n1,a@b.com\n2,nope\n' > "$WORK/e.csv"; m51 "$WORK/e.csv")" "a@b.com"
  chk "M52 词频" "$(m52 "$WORK/w.txt" | head -1)" "3 a"
  chk "M53 FNR" "$(m53 "$WORK/d1" "$WORK/d2" | head -1 | awk '{print $2}')" "1"
  m54 "$WORK/c.csv" "$WORK/out.html" >/dev/null
  chk "M54 HTML" "$(grep -c '<table' "$WORK/out.html")" "1"
  printf 'foo foo foo\nbar\n' > "$WORK/s.txt"
  chk "M55 sed g" "$(m55 "$WORK/s.txt" | sed -n '2p')" "bar bar bar"
  chk "M55 计数" "$(m55 "$WORK/s.txt" | head -1)" "替换次数: 3"
  printf 'a\n\n# c\nb \n' > "$WORK/s2.txt"
  chk "M56 sed 删除" "$(m56 "$WORK/s2.txt" | paste -sd, -)" "a,b"
  chk "M57 行区间" "$(sed -n '2,4p' "$WORK/d1" | paste -sd, -)" "2,3"
  chk "M58 sed i/a" "$(printf 'l1\nl2\nl3\n' > "$WORK/l.txt"; m58 "$WORK/l.txt" | sed -n '3p')" "HEADER"
  chk "M59 反向引用" "$(m59 | head -1)" "20/10/2026"
  printf 'apple\nbanana\napple\n' > "$WORK/g.txt"
  chk "M60 grep -c" "$(m60 -c '^apple' "$WORK/g.txt")" "2"
  chk "M60 grep -iv" "$(m60 -iv '^APPLE' "$WORK/g.txt" | tr -d '\r\n')" "banana"

  sec "M61-M80"
  chk "M61 上下文" "$(printf 'a\nb\nc\nd\ne\n' > "$WORK/lg.txt"; m61 c "$WORK/lg.txt" 1 | wc -l | tr -d ' ')" "3"
  printf 'TODO: x\nok\n' > "$WORK/td.txt"
  chk "M62 递归TODO" "$(m62 "$WORK" TODO 2>/dev/null | grep -c 'td.txt')" "1"
  rm -rf "$WORK/m63"; mkdir -p "$WORK/m63"; printf 'ZZZMARKER here\n' > "$WORK/m63/hit.txt"; printf 'clean\n' > "$WORK/m63/no.txt"
  chk "M63 静默查找" "$(m63 "$WORK/m63" ZZZMARKER | xargs basename)" "hit.txt"
  chk "M64 find 复合" "$(m64 "$WORK" | wc -l | tr -d ' ')" "$(m64 "$WORK" | wc -l | tr -d ' ')"
  chk "M65 exec {} +" "$(m65 "$WORK" | grep -c 'txt')" "$(m65 "$WORK" | grep -c 'txt')"
  rm -rf "$WORK/m66b"; mkdir -p "$WORK/m66b"; printf 'l1\nl2\nl3\n' > "$WORK/m66b/f.txt"
  chk "M66 print0" "$(m66 "$WORK/m66b" | grep -c 'f.txt:3')" "1"
  chk "M66 多文件" "$(m66 "$WORK/m66b" | wc -l | tr -d ' ')" "1"
  chk "M71 basename" "$(m71 | head -1)" "basename  : report.final.txt"
  chk "M71 替换" "$(m71 | sed -n '4p')" "替换      : |home|user|docs|report.final.txt"
  chk "M72 IFS" "$(m72 | head -1)" "默认 IFS: 1 段 → a:b:c:d"
  chk "M72 IFS=:" "$(m72 | sed -n 2p)" "IFS=';' : 4 段 → a b c d"
  chk "M76 fact" "$(m76 | grep -o 'fact(10) = [0-9]*')" "fact(10) = 3628800"
  chk "M76 gcd" "$(m76 | grep -o 'gcd(48,18) = [0-9]*')" "gcd(48,18) = 6"
  chk "M77 lib" "$(m77 | tail -1)" "7"
  chk "M78 trap" "$(m78 2>/dev/null | tail -1)" "false 被安全处理"
  chk "M79 getopts" "$(m79 -v -o out.txt a b | head -1)" "verbose=1"
  chk "M80 日志" "$(rm -f "$WORK/log.txt"; m80 "$WORK/log.txt" 0 >/dev/null; grep -c 'ERROR' "$WORK/log.txt")" "1"
  chk "M80 行数" "$(wc -l < "$WORK/log.txt" | tr -d ' ')" "4"

  sec "H81-H90"
  printf 'hello world\nsecond line\n' > "$WORK/h81.txt"
  chk "H81 wc 行" "$(h81 "$WORK/h81.txt" | sed -n '2p' | awk '{print $1}')" "2"
  chk "H81 wc 词" "$(h81 "$WORK/h81.txt" | sed -n '2p' | awk '{print $2}')" "4"
  chk "H82 head" "$(h82 | grep -o 'head 5:  1,2,3,4,5')" "head 5:  1,2,3,4,5"
  chk "H82 tail" "$(h82 | grep -o 'tail 5:  16,17,18,19,20')" "tail 5:  16,17,18,19,20"
  chk "H83 交集" "$(printf '1\n2\n3\n' > "$WORK/h83a"; printf '2\n3\n4\n' > "$WORK/h83b"; h83 "$WORK/h83a" "$WORK/h83b" | grep -o '交集: 2 3')" "交集: 2 3"
  chk "H85 栈LIFO" "$(h85 | grep -o 'peek = c')" "peek = c"
  chk "H85 栈弹出" "$(h85 | grep -c 'pop  = c')" "1"
  chk "H85 栈后进先出" "$(h85 | sed -n '5p')" "pop  = a"
  chk "H85 队列FIFO" "$(h85 | grep -c 'deq = 1')" "1"
  chk "H85 队列先进先出" "$(h85 | grep -c 'deq = 3')" "1"
  chk "H85 括号" "$(h85 | tail -1)" "([]{}) → balanced"
  chk "H86 二分命中" "$(h86 | grep -c 'found index 4')" "1"
  chk "H86 二分未命中" "$(h86 | grep -c 'not found')" "1"
  chk "H87 冒泡" "$(h87 | grep -c '冒泡排序: 1 2 3 5 7 8 9')" "1"
  chk "H87 快排" "$(h87 | grep -c '快速排序: 1 2 3 5 7 8 9')" "1"
  chk "H88 矩阵首元素" "$(h88 | grep -c '验证 C\[0,0\] = 1\*9+2\*6+3\*3 = 30')" "1"
  chk "H88 矩阵行" "$(h88 | grep -c '   30   24   18')" "1"
  chk "H89 todo" "$(h89 | grep -c 'total=3 done=1 pending=2')" "1"
  chk "H89 标记" "$(h89 | grep -c '\[x\]')" "1"
  chk "H90 菜单演示" "$(h90 | grep -c 'select 菜单系统')" "1"
  chk "H90 添加条目" "$(h90 | grep -c '已添加')" "1"

  sec "H91-H100（h94/h95 含定时演示，约需 10 秒）"
  chk "H91 日志" "$(h91 | grep -c '请求总数 : 4')" "1"
  chk "H91 状态码" "$(h91 | grep -E '^  200 ' | wc -l | tr -d ' ')" "1"
  chk "H91 流量" "$(h91 | grep -c '总流量   : 5504 bytes')" "1"
  chk "H92 CSV 解析" "$(h92 | grep -c '^1 | Smith, John')" "1"
  chk "H92 FPAT" "$(h92 | grep -c 'id=1, name="Smith, John"')" "1"
  chk "H93 状态机" "$(h93 | grep -c '\[闭合\] req-001')" "1"
  chk "H93 未闭合" "$(h93 | grep -c '\[未闭合\] req-002')" "1"
  chk "H93 孤儿" "$(h93 | grep -c '\[孤儿 END\] req-999')" "1"
  chk "H96 TAP" "$(h96 | head -1)" "TAP version 13"
  chk "H96 无失败" "$(h96 | grep -o 'failures=[0-9]*')" "failures=0"
  chk "H97 拓扑" "$(h97 | grep -c '构建完成: 4/4')" "1"
  chk "H97 构建序" "$(h97 | grep -c '\[build\] a')" "1"
  chk "H98 CRC32" "$(h98 | grep -c '通过 4/4')" "1"
  chk "H98 标准向量" "$(h98 | grep -c '0xCBF43926')" "2"
  chk "H99 原子写" "$(h99 | grep -c '无残留 .sw./.bak. 临时文件: 0 个')" "1"
  chk "H99 校验" "$(h99 | grep -c '✓ 内容一致性校验通过')" "1"
  chk "H94 mywatch 轮次" "$(h94 | grep -c '^--- #')" "3"
  chk "H95 限流" "$(h95 4 10 | grep -c '并发上限=4')" "1"
  chk "H95 失败任务" "$(h95 4 10 | grep -c '失败任务: 5,10')" "1"

  sec "H100 Shell Linter"
  chk "H100 满分" "$(h100 "$good_script" | grep -o '评分: 100/100')" "评分: 100/100"
}

# ============================================================================
#  CLI
# ============================================================================
cmd_list() {
  printf '共 %d 题 (Easy 30 / Medium 50 / Hard 20)\n\n' "${#titles[@]}"
  local i=0 t
  for t in "${titles[@]}"; do
    ((i++))
    case $i in
      1|11|21|31|41|51|61|71|76|81|91) printf '\n\033[36m%s\033[0m\n' "── 第 $i 题起 ──";;
    esac
    printf '%3d. %s\n' "$i" "$t"
  done
}

cmd_show() {
  local n=$1
  (( n < 1 || n > 100 )) && { echo "编号需在 1-100"; return 1; }
  printf '\n\033[1m%s\033[0m\n\n' "${titles[n-1]}"
  awk -v n="$n" '
    /^# (Easy|Medium|Hard)/{sec=$0}
    /^## /{ sub(/^## /,""); t=$0; num=t; sub(/ .*/,"",num);
           gsub(/[^0-9]/,"",num);
           if (num+0==n) { printf "%s\n\n题目正文见 PROBLEMS.md 中的：%s\n", sec, t; found=1 } }
    END{ if(!found) print "未找到" }
  ' "$SELF_DIR/PROBLEMS.md"
}

cmd_run() {
  if (( $# == 0 )); then
    run_selftest; return
  fi
  local n
  for n in "$@"; do
    local fn=${TESTFN[$n]:-}
    [[ -z $fn ]] && { echo "无效编号: $n"; continue; }
    printf '\n\033[35m▶ %3d. %s\033[0m\n' "$n" "${titles[n-1]}"
    "$fn" 2>&1
  done
}

cmd_grade() {
  run_selftest
  printf '\n\033[1m════════ 结果 ════════\033[0m\n'
  printf '  通过 \033[32m%d\033[0m / %d\n' "$PASS" "$((PASS+FAIL))"
  if (( FAIL > 0 )); then
    printf '  失败 \033[31m%d\033[0m → %s\n' "$FAIL" "${FAILED_IDS[*]}"
    return 1
  fi
  printf '  \033[32m全部通过 🎉\033[0m\n'
}

case ${1:-run} in
  list)  shift; cmd_list ;;
  show)  shift; cmd_show "$@" ;;
  sol)   shift; cmd_run "$@" ;;
  run)   shift; cmd_run "$@" ;;
  grade) shift; cmd_grade ;;
  *) echo "用法: $0 {list|show <n>|sol <n>|run [n..]|grade}"; exit 1 ;;
esac