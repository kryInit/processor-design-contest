#!/bin/zsh
root_path=$(realpath `dirname $0`)
workspace_path=${root_path}/workspace
default_target=${root_path}/src/multi_cycle.v
target=${1:-$default_target}
target=$(realpath $target)

cd $workspace_path

iverilog $target && ./a.out > out.txt 
cat out.txt | tail -n 1 | awk '{split($NF, a, " "); if (a[length(a)] == "017fd000") exit 0; else exit 1}'
succeeded=$?
[ $succeeded -eq 0 ] && echo "\e[1;32mPassed\e[0m " ✅ " cycles: " $(wc -l < out.txt | sed 's/ //g') || echo "\e[1;31mFailed\e[0m " 🥹
exit $succeeded

