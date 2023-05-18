#!/bin/zsh
iverilog multi_cycle.v && ./a.out | tail -n 1 | awk '{split($NF, a, " "); if (a[length(a)] == "017fd000") exit 0; else exit 1}'
result=$?
[ $result -eq 0 ] && echo "\e[1;32mPassed\e[0m " ✅  || echo "\e[1;31mFailed\e[0m " 🥹
exit result

