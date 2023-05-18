import os
import subprocess
from invoke import task
from pathlib import Path

from colorama import Fore, Style

project_root_path = Path(__file__).parent.resolve()
workspace_path = project_root_path.joinpath("workspace")
src_path = project_root_path.joinpath("src")
default_target = src_path.joinpath("multi_cycle.v")
inputs_path = project_root_path.joinpath("inputs")
default_program = inputs_path.joinpath("program.txt")


def override_program(target_path: Path, program_path: Path) -> None:
    rel_path = os.path.relpath(program_path, target_path.parent)

    with open(target_path, 'r') as f:
        lines = map(lambda line: f"""`include "{rel_path}" // [include]""" if "[include]" in line else line, f.read().splitlines())

    # ファイルを書き込みモードで開き、新しい内容を書き込む
    with open(target_path, 'w') as f:
        f.write("\n".join(lines))
        f.write("\n")


@task
def build(c, target: str = default_target, program: str = default_program) -> int:
    target = Path(target).absolute()
    program = Path(program).absolute()

    if program is not None:
        override_program(target, program)
    return subprocess.run(f"iverilog {target}", shell=True, cwd=workspace_path).returncode


@task
def run(c) -> int:
    return subprocess.run(f"./a.out > out.txt", shell=True, cwd=workspace_path).returncode


@task
def brc(c, target: str = default_target, program: str = default_program) -> None:
    ret = build(c, target, program)
    if ret != 0:
        exit(ret)
    ret = run(c)
    if ret != 0:
        exit(ret)
    subprocess.run(f"cat out.txt | head -n 30", shell=True, cwd=workspace_path)
    line_count = sum(1 for _ in open(workspace_path.joinpath('out.txt')))
    print(f"    -> line count: {line_count}")


@task
def test(c, target: str = default_target, program: str = default_program):
    target = Path(target).absolute()
    program = Path(program).absolute()

    build_return_code = build(c, target, program)
    if build_return_code != 0:
        exit(build_return_code)
    run_return_code = run(c)
    if run_return_code != 0:
        exit(run_return_code)

    result = subprocess.run("""cat out.txt | tail -n 1 | awk '{split($NF, a, " "); if (a[length(a)] == "017fd000") exit 0; else exit 1}'""", shell=True, cwd=workspace_path)
    succeeded = result.returncode == 0

    if succeeded:
        line_count = sum(1 for _ in open(workspace_path.joinpath('out.txt')))
        print(f"{Fore.GREEN}{Style.BRIGHT}Passed{Style.RESET_ALL} ✅, cycles: {line_count}")
    else:
        print(f"{Fore.RED}{Style.BRIGHT}Failed{Style.RESET_ALL} 🥹")
    exit(result.returncode)
