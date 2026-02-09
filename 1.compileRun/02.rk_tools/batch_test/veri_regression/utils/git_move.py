#!/usr/bin/env python
#########################################################################
# File Name: git_move.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue 10 Jun 2025 11:43:57 AM CST
#########################################################################

import subprocess
from typing import Tuple, Optional

def run_command(command, use_str=False):
    """执行给定的 shell 命令并返回输出、错误和执行状态"""
    try:
        result = subprocess.run(command, shell=use_str, check=True,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except subprocess.CalledProcessError as e:
        return e.stdout.strip(), e.stderr.strip(), e.returncode

def get_current_branch() -> str:
    """获取当前分支名"""
    stdout, _, _ = run_command(["git", "branch", "--show-current"])
    return stdout

def get_remote_repo(branch: str) -> str:
    """获取指定分支对应的远程仓库"""
    stdout, _, _ = run_command(["git", "config", "--list"])
    for line in stdout.split('\n'):
        if line.startswith(f"branch.{branch}.remote="):
            return line.split('=')[1]
    return "origin"  # 默认返回 origin

def get_commit_info(commit_hash: str, location: Optional[str] = None) -> Tuple[str, str]:
    """获取提交的简短哈希和提交信息"""
    cmd = ["git", "log", "--oneline", "-n", "1", commit_hash]
    if location:
        cmd.append("--")
        cmd.append(location)
    stdout, _, _ = run_command(cmd)
    parts = stdout.split(' ', 1)
    return parts[0], parts[1] if len(parts) > 1 else ""

def gmf(cnt: int = 1, location: Optional[str] = None) -> bool:
    """
    Git Move Forward - 向前移动到更新的提交

    :param cnt: 要向前移动的提交数量
    :param location: 可选的文件或目录路径，限制查询范围
    :return: 是否成功执行
    """
    # 获取当前提交
    cmd = ["git", "rev-list", "--max-count=1", "--abbrev-commit", "HEAD"]
    if location:
        cmd.extend(["--", location])
    stdout, stderr, retcode = run_command(cmd)
    if retcode != 0:
        print(f"Error getting current commit: {stderr}")
        return False

    cur_com_id = stdout
    cur_com_hash, cur_com_msg = get_commit_info(cur_com_id, location)
    print(f"Current commit:   {cur_com_hash} {cur_com_msg}")

    # 获取远程信息
    current_branch = get_current_branch()
    remote_repo = get_remote_repo(current_branch)
    print(f"Remote repo:      {remote_repo}")
    print(f"Current branch:   {current_branch}")

    # 查找向前移动的目标提交
    range_spec = f"{cur_com_id}^..{remote_repo}/{current_branch}"
    cmd = ["git", "rev-list", "--abbrev-commit", range_spec]
    if location:
        cmd.extend(["--", location])
    stdout, stderr, retcode = run_command(cmd)
    if retcode != 0:
        print(f"Error getting commit range: {stderr}")
        return False

    commits = stdout.split('\n')
    try:
        idx = commits.index(cur_com_id)
        target_idx = idx - cnt
        if target_idx >= len(commits):
            print(f"Cannot move forward {cnt} commits - reached end of history")
            return False
        forward_com_id = commits[target_idx]
    except ValueError:
        print(f"Current commit {cur_com_id} not found in commit list")
        return False

    forward_com_hash, forward_com_msg = get_commit_info(forward_com_id, location)
    print(f"Target commit:    {forward_com_hash} {forward_com_msg}")

    # 执行重置
    _, stderr, retcode = run_command(["git", "reset", "--hard", forward_com_id])
    if retcode != 0:
        print(f"Error resetting to commit: {stderr}")
        return False

    print("Successfully moved forward")
    return True

def gmb(cnt: int = 1, location: Optional[str] = None) -> bool:
    """
    Git Move Backward - 向后移动到更旧的提交

    :param cnt: 要向后移动的提交数量
    :param location: 可选的文件或目录路径，限制查询范围
    :return: 是否成功执行
    """
    # 获取当前提交
    cmd = ["git", "rev-list", "--max-count=1", "--abbrev-commit", "HEAD"]
    if location:
        cmd.extend(["--", location])
    stdout, stderr, retcode = run_command(cmd)
    if retcode != 0:
        print(f"Error getting current commit: {stderr}")
        return False

    cur_com_id = stdout
    cur_com_hash, cur_com_msg = get_commit_info(cur_com_id, location)
    print(f"Current commit:   {cur_com_hash} {cur_com_msg}")

    # 查找向后移动的目标提交
    limit = cnt * 2  # 获取足够多的提交以确保能找到目标
    cmd = ["git", "rev-list", f"--max-count={limit}", "--abbrev-commit", "HEAD"]
    if location:
        cmd.extend(["--", location])
    stdout, stderr, retcode = run_command(cmd)
    if retcode != 0:
        print(f"Error getting commit history: {stderr}")
        return False

    commits = stdout.split('\n')
    try:
        idx = commits.index(cur_com_id)
        target_idx = idx + cnt
        if target_idx < 0:
            print(f"Cannot move backward {cnt} commits - reached start of history")
            return False
        backward_com_id = commits[target_idx]
    except ValueError:
        print(f"Current commit {cur_com_id} not found in commit list")
        return False

    backward_com_hash, backward_com_msg = get_commit_info(backward_com_id, location)
    print(f"Target commit:    {backward_com_hash} {backward_com_msg}")

    # 执行重置
    _, stderr, retcode = run_command(["git", "reset", "--hard", backward_com_id])
    if retcode != 0:
        print(f"Error resetting to commit: {stderr}")
        return False

    print("Successfully moved backward")
    return True

def main():
    import argparse

    # 主解析器
    parser = argparse.ArgumentParser(description="Git commit navigation tool")
    subparsers = parser.add_subparsers(dest='command', required=True)

    # gmf 命令
    gmf_parser = subparsers.add_parser('gmf', help='Move forward to newer commit')
    gmf_parser.add_argument('-n', '--count', type=int, default=1, help='Number of commits to move forward')
    gmf_parser.add_argument('-l', '--location', help='Limit to specific file/directory')

    # gmb 命令
    gmb_parser = subparsers.add_parser('gmb', help='Move backward to older commit')
    gmb_parser.add_argument('-n', '--count', type=int, default=1, help='Number of commits to move backward')
    gmb_parser.add_argument('-l', '--location', help='Limit to specific file/directory')

    args = parser.parse_args()

    if args.command == 'gmf':
        success = gmf(args.count, args.location)
    elif args.command == 'gmb':
        success = gmb(args.count, args.location)

    if not success:
        exit(1)

if __name__ == "__main__":
    main()
