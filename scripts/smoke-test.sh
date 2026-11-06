#!/usr/bin/env bash
# Runs a cribelo binary on a throwaway repository and checks what it reports:
# one change per supported language, so that a parser lost in an update of
# AST Metrics fails here rather than in a user's pull request.
#
#   scripts/smoke-test.sh ./cribelo
set -euo pipefail

bin="$(cd "$(dirname "${1:?usage: smoke-test.sh path/to/cribelo}")" && pwd)/$(basename "$1")"
# python3 first; on Windows runners it can be a store stub that does not run.
py=python3
"$py" -c '' 2> /dev/null || py=python
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
out="$work/out"
mkdir -p "$out" "$work/repo" "$work/history"
cd "$work/repo"

fail() { echo "smoke-test: $*" >&2; exit 1; }

# run STATUS NAME ARGS...: runs cribelo, keeps its output in $out/NAME and
# fails unless it exits with STATUS.
run() {
	local want="$1" name="$2" status=0
	shift 2
	"$bin" "$@" > "$out/$name" 2>&1 || status=$?
	[ "$status" -eq "$want" ] || { cat "$out/$name" >&2; fail "cribelo $* exited with $status, want $want"; }
}

# want NAME EXPR VALUE: EXPR is Python over the JSON in $out/NAME, bound to p.
want() {
	local got
	got="$("$py" -c 'import json, sys; p = json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$out/$1" "$2")"
	[ "$got" = "$3" ] || fail "$1: $2 is $got, want $3"
}

git init -q -b main
git config user.email ci@cribelo.dev
git config user.name ci
git config core.autocrlf false

# Base: one trivial function per language.
mkdir -p go php py rs ts java cs
printf 'package lib\n\nfunc F(a int) int {\n\treturn a\n}\n' > go/lib.go
printf 'package lib\n\nfunc Neg(a int) int { return -a }\n' > go/util.go
printf '<?php\nfunction f($a) {\n    return $a;\n}\n' > php/lib.php
printf 'def f(a):\n    return a\n' > py/lib.py
printf 'pub fn f(a: i32) -> i32 {\n    a\n}\n' > rs/lib.rs
printf 'export function f(a: number): number {\n    return a;\n}\n' > ts/lib.ts
printf 'class Lib {\n    int f(int a) {\n        return a;\n    }\n}\n' > java/Lib.java
printf 'class Lib {\n    int F(int a) {\n        return a;\n    }\n}\n' > cs/Lib.cs
echo '# fixture' > README.md
git add -A
git commit -qm base
git checkout -qb change

# Change: one more branch in every function, so complexity goes from 1 to 2.
printf 'package lib\n\nfunc F(a int) int {\n\tif a > 0 {\n\t\treturn a\n\t}\n\treturn 0\n}\n' > go/lib.go
printf '<?php\nfunction f($a) {\n    if ($a > 0) {\n        return $a;\n    }\n    return 0;\n}\n' > php/lib.php
printf 'def f(a):\n    if a > 0:\n        return a\n    return 0\n' > py/lib.py
printf 'pub fn f(a: i32) -> i32 {\n    if a > 0 {\n        return a;\n    }\n    0\n}\n' > rs/lib.rs
printf 'export function f(a: number): number {\n    if (a > 0) {\n        return a;\n    }\n    return 0;\n}\n' > ts/lib.ts
printf 'class Lib {\n    int f(int a) {\n        if (a > 0) {\n            return a;\n        }\n        return 0;\n    }\n}\n' > java/Lib.java
printf 'class Lib {\n    int F(int a) {\n        if (a > 0) {\n            return a;\n        }\n        return 0;\n    }\n}\n' > cs/Lib.cs
# A function of ten branches, untested: the file to read first.
{
	printf 'package lib\n\nfunc Classify(a, b, c int) string {\n'
	for i in 1 2 3 4 5 6 7 8 9 10; do
		printf '\tif a == %d && b > c {\n\t\treturn "%d"\n\t}\n' "$i" "$i"
	done
	printf '\treturn ""\n}\n'
} > go/classify.go
printf 'package lib\n\nfunc Neg(a int) int { return 0 - a }\n' > go/util.go
printf 'package lib\n\nimport "testing"\n\nfunc TestF(t *testing.T) {\n\tif F(1) != 1 {\n\t\tt.Fatal()\n\t}\n}\n' > go/lib_test.go
echo 'more' >> README.md
git add -A
git commit -qm change

run 0 version --version
grep -q '(engine ' "$out/version" || fail "--version does not name the engine revision"

# The plan, with every ranked file listed.
run 0 plan.json --base main --top 20 --format json
"$py" - "$out/plan.json" <<'EOF' || fail "the plan is not the expected one"
import json, sys

plan = json.load(open(sys.argv[1]))
files = {f["path"].replace("\\", "/"): f for f in plan["files"]}

def check(cond, msg):
    if not cond:
        sys.exit("  " + msg)

for path in ["go/lib.go", "php/lib.php", "py/lib.py", "rs/lib.rs", "ts/lib.ts", "java/Lib.java", "cs/Lib.cs"]:
    check(path in files, f"{path} missing from the plan, its parser may be gone")
    feat = files[path]["features"]
    check(feat.get("max_complexity") == 2, f"{path}: max_complexity {feat.get('max_complexity')}, want 2")
    check(feat.get("complexity_added") == 1, f"{path}: complexity_added {feat.get('complexity_added')}, want 1")

top = plan["files"][0]["path"].replace("\\", "/")
check(top == "go/classify.go", f"first file is {top}, want go/classify.go")
check(files[top]["features"].get("max_complexity") == 21, f"classify: max_complexity {files[top]['features'].get('max_complexity')}, want 21")
check(plan["files"][0]["level"] in ("medium", "high"), f"classify is {plan['files'][0]['level']}, want medium or high")
for path in ["go/lib_test.go", "README.md"]:
    check(path not in files, f"{path} should be skipped, not ranked")
check(plan["changed"] == 11, f"{plan['changed']} files changed, want 11")
check(plan["clone_indexed"] > 0, "no function indexed for clone detection")
EOF

# Default base, size of the reading list, other directory.
run 0 default.json --format json
want default.json 'p["base"]' main
run 0 top.json --base main --top 2 --format json
want top.json 'p["read"]' 2
run 0 budget-short.json --base main --budget 1m --format json
want budget-short.json 'p["read"]' 1
want budget-short.json 'p["files"][0]["read"]' True
run 0 budget-long.json --base main --budget 2h --format json
# every file with a measurable change fits in two hours
want budget-long.json 'all(f["read"] for f in p["files"] if f["path"] != "go/util.go")' True
run 0 elsewhere.json -C "$work/repo/go" --base main --format json
want elsewhere.json 'p["files"][0]["path"]' go/classify.go
run 0 no-clones.json --base main --no-clones --format json
want no-clones.json 'p["clone_indexed"]' 0

# The other renderings and commands.
run 0 plan.txt --base main --no-color
grep -q 'Start with go/classify.go' "$out/plan.txt" || fail "the text plan does not start with go/classify.go"
if grep -q "$(printf '\033')" "$out/plan.txt"; then fail "--no-color output has escape codes"; fi
run 0 plan.md --base main --format markdown
grep -q 'classify.go' "$out/plan.md" || fail "the markdown plan does not mention classify.go"
run 0 skip.txt --base main skip
grep -q 'go/lib_test.go.*tests only' "$out/skip.txt" || fail "skip does not list the test file as tests only"
grep -q 'README.md.*not analyzed' "$out/skip.txt" || fail "skip does not list README.md as not analyzed"
grep -q 'go/util.go.*no measurable change' "$out/skip.txt" || fail "skip does not list go/util.go as no measurable change"
run 0 explain.txt --base main explain go/classify.go
grep -q 'Classify .*new, complexity 21' "$out/explain.txt" || fail "explain does not show Classify with complexity 21"

# The gate, and the errors.
run 1 gate-medium --base main --fail-on medium
run 0 gate-never --base main --fail-on never
run 2 bad-base --base no-such-ref
run 2 bad-budget --base main --budget soon

# .cribelo.yaml, read from the working tree.
printf 'base: main\ntop: 1\nfail_on: medium\nignore:\n  - "php/**"\n' > .cribelo.yaml
run 1 config.json --format json
want config.json 'p["read"]' 1
want config.json 'p["fail_on"]' medium
want config.json '"php/lib.php" in [f["path"].replace("\\", "/") for f in p["files"]]' False
rm .cribelo.yaml

# backtest and calibrate on a generated history: 40 changes of four Go files
# each, a fix after every third one, one day apart from a fixed date.
cd "$work/history"
git init -q -b main
git config user.email ci@cribelo.dev
git config user.name ci
git config core.autocrlf false
day=1735732800 # 2025-01-01
commit() {
	git add -A
	GIT_AUTHOR_DATE="@$day +0000" GIT_COMMITTER_DATE="@$day +0000" git commit -qm "$1"
	day=$((day + 86400))
}
mkdir src
for f in 0 1 2 3 4 5 6 7; do printf 'package src\n' > "src/f$f.go"; done
commit init
for c in $(seq 1 40); do
	for k in 0 1 2 3; do
		f=$(((c + k * 2) % 8))
		{
			printf '\nfunc C%d_%d(a int) int {\n' "$c" "$k"
			for i in $(seq 1 $(((c * 7 + k) % 6 + 1))); do printf '\tif a == %d {\n\t\treturn %d\n\t}\n' "$i" "$i"; done
			printf '\treturn 0\n}\n'
		} >> "src/f$f.go"
	done
	commit "feat: change $c"
	if [ $((c % 3)) -eq 0 ]; then
		printf '\n// fix %d\n' "$c" >> "src/f$((c % 8)).go"
		commit "fix: bug $c"
	fi
done

run 0 backtest.json backtest --format json
want backtest.json 'len(p["changes"])' 40
run 0 calibrate-dry calibrate --dry-run
[ ! -e .cribelo/weights.json ] || fail "calibrate --dry-run wrote the weights"
run 0 calibrate calibrate
[ -s .cribelo/weights.json ] || { cat "$out/calibrate" >&2; fail "calibrate did not write .cribelo/weights.json"; }

git checkout -qb change
printf '\nfunc Z(a int) int {\n\tif a > 1 {\n\t\treturn 1\n\t}\n\treturn 0\n}\n' >> src/f1.go
commit "feat: z"
run 0 calibrated.json --base main --format json
want calibrated.json 'p["calibrated"]' True
mv .cribelo/weights.json "$work/weights.json"
run 0 generic.json --base main --format json
want generic.json 'p["calibrated"]' False
run 0 weights.json --base main --weights "$work/weights.json" --format json
want weights.json 'p["calibrated"]' True
echo '{' > "$work/broken.json"
run 2 broken-weights --base main --weights "$work/broken.json"

echo "smoke-test: ok ($(cat "$out/version"))"
