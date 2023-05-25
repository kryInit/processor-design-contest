import os
import re
import shutil
import subprocess
from invoke import task
from pathlib import Path
from typing import Optional, Callable

from colorama import Fore, Style

project_root_path = Path(__file__).parent.resolve()
workspace_path = project_root_path.joinpath("workspace")
src_path = project_root_path.joinpath("src")
default_target = src_path.joinpath("multi_cycle.v")
inputs_path = project_root_path.joinpath("inputs")
default_program = inputs_path.joinpath("program.txt")
tmp_source_path = workspace_path.joinpath("source.v")


def override_program(target_path: Path, program_path: Path, on_test: bool, on_vivado: bool) -> None:
    rel_path = os.path.relpath(program_path, target_path.parent)

    with open(target_path, 'r') as f:
        lines = f.read().splitlines()

    result = []

    on_range_delete = False
    for line in lines:
        matches = re.findall('\[\[.*\]\]', line)
        if len(matches) == 0:
            if not on_range_delete:
                result.append(line)
            continue

        cmd_args = matches[0][2:-2].split()
        ignore = (not on_vivado and "--on-vivado" in cmd_args) or (not on_test and "--on-test" in cmd_args)

        if ignore:
            if not on_range_delete:
                result.append(line)
            continue

        if cmd_args[0] == "delete-line":
            continue
        elif cmd_args[0] == "delete-begin":
            on_range_delete = True
        elif cmd_args[0] == "delete-end":
            on_range_delete = False
        elif cmd_args[0] == "include-program":
            if on_vivado:
                result.append(f"""`include "{program_path.name}" // [include-program]""")
            else:
                result.append(f"""`include "{rel_path}" // [include-program]""")
        else:
            result.append(line)

    with open(target_path, 'w') as f:
        f.write("\n".join(result))
        f.write("\n")


def dump_message_when_error_occurred(func: Callable[[], int], message: Optional[str] = None, chain: int = 0) -> int:
    if chain != 0:
        return chain

    ret = func()
    if ret != 0:
        print(message)

    return ret

@task
def build(c, target: str = default_target, program: str = default_program, is_test: bool = False, on_vivado: bool = False) -> int:
    target = Path(target).absolute()
    program = Path(program).absolute()

    shutil.copyfile(target, tmp_source_path)
    override_program(tmp_source_path, program, is_test, on_vivado)

    return subprocess.run(f"iverilog {tmp_source_path}", shell=True, cwd=workspace_path).returncode


@task
def run(c) -> int:
    return subprocess.run(f"./a.out > out.txt", shell=True, cwd=workspace_path).returncode


@task
def show(c, target: str = default_target, program: str = default_program, n: int = 30) -> None:
    ret = dump_message_when_error_occurred(
        lambda: build(c, target, program),
        f"{Fore.RED}{Style.BRIGHT}Build Failed{Style.RESET_ALL} 🥺"
    )
    ret = dump_message_when_error_occurred(
        lambda: run(c),
        f"{Fore.RED}{Style.BRIGHT}Run Failed{Style.RESET_ALL} 🥺",
        ret
    )

    if ret == 0:
        subprocess.run(f"cat out.txt | head -n {n}", shell=True, cwd=workspace_path)
        line_count = sum(1 for _ in open(workspace_path.joinpath('out.txt')))
        print(f"    -> line count: {line_count}")


@task
def test(c, target: str = default_target, program: Optional[str] = None):
    target = Path(target).absolute()

    valid_last_output_dict = {
        "program.txt": "017fd000",
        "program1.txt": "00000007",
        "program2.txt": "00000040",
        "program3.txt": "00000006",
        "program4.txt": "00000002",
        "program5.txt": "00000005",
        "program6.txt": "00000005",
    }
    programs = [inputs_path.joinpath(f'program{"" if i == 0 else f"{i}"}.txt') for i in range(7)] if program is None else [Path(program).absolute()]
    programs = programs[1:] + [programs[0]]

    for program in programs:
        valid_last_output = valid_last_output_dict.get(program.name)
        print(f"[{program.name: >12}] ", end="")

        ret = dump_message_when_error_occurred(
            lambda: build(c, target, program, True),
            f"{Fore.RED}{Style.BRIGHT}Build Failed{Style.RESET_ALL} 🥺"
        )
        ret = dump_message_when_error_occurred(
            lambda: run(c),
            f"{Fore.RED}{Style.BRIGHT}Run Failed{Style.RESET_ALL} 🥺",
            ret
        )
        ret = dump_message_when_error_occurred(
            lambda: 1 if valid_last_output is None else 0,
            f"{Fore.RED}{Style.BRIGHT}Test Failed{Style.RESET_ALL}: valid last output is not found",
            ret
        )
        ret = dump_message_when_error_occurred(
            lambda: subprocess.run(f"""cat out.txt | tail -n 1 | awk '{{split($NF, a, " "); if (a[length(a)] == "{valid_last_output}") exit 0; else exit 1}}'""", shell=True, cwd=workspace_path).returncode,
            f"{Fore.RED}{Style.BRIGHT}Failed{Style.RESET_ALL} 🥺",
            ret
        )

        if ret == 0:
            line_count = sum(1 for _ in open(workspace_path.joinpath('out.txt')))
            print(f"{Fore.GREEN}{Style.BRIGHT}Passed{Style.RESET_ALL} ✅, cycles: {line_count}")
