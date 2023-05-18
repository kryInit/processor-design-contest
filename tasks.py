import os
import subprocess
from invoke import task
from pathlib import Path
from typing import Optional

from colorama import Fore, Style

project_root_path = Path(__file__).parent.resolve()
workspace_path = project_root_path.joinpath("workspace")
src_path = project_root_path.joinpath("src")
default_target = src_path.joinpath("multi_cycle.v")


def override_program(program_path: str):
    pass


@task
def build(c, target: str = default_target, program: Optional[str] = None):
    override_program(program)
    subprocess.run(f"iverilog {target} && ./a.out > out.txt", shell=True, cwd=workspace_path)


@task
def test(c, target: str = default_target, program: Optional[str] = None):
    build(c, target, program)
    result = subprocess.run("""cat out.txt | tail -n 1 | awk '{split($NF, a, " "); if (a[length(a)] == "017fd000") exit 0; else exit 1}'""", shell=True, cwd=workspace_path)
    succeeded = result.returncode == 0

    if succeeded:
        line_count = sum(1 for _ in open(workspace_path.joinpath('out.txt')))
        print(f"{Fore.GREEN}{Style.BRIGHT}Passed{Style.RESET_ALL} ✅, cycles: {line_count}")
    else:
        print(f"{Fore.RED}{Style.BRIGHT}Failed{Style.RESET_ALL} 🥹")
    exit(result.returncode)
