#!/usr/bin/env python3
"""Reconstruct a Klash candidate from an upstream release and the reviewed overlay."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def run(*args, cwd=ROOT, check=True):
    return subprocess.run(args, cwd=cwd, check=check, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def version(tag):
    match = re.fullmatch(r'v?(\d+)\.(\d+)\.(\d+)', tag)
    if not match:
        raise ValueError(f'Unsupported stable upstream tag: {tag}')
    parts = tuple(map(int, match.groups()))
    return parts, f'{parts[0] + 1}.{parts[1]}.{parts[2]}'


def reconstruct(tag, destination, paths):
    run('git', 'worktree', 'add', '--detach', str(destination), tag)
    result = run('git', 'apply', '--3way', '--index', str(ROOT / 'klash/runtime.patch'), cwd=destination, check=False)
    if result.returncode:
        raise RuntimeError(f'Klash overlay conflict; no candidate published:\n{result.stderr}')
    for relative in paths:
        original = ROOT / relative
        target = destination / relative
        if original.exists() and not target.exists():
            raise RuntimeError(f'Overlay lost {relative}')


def retain_release_history(destination, base):
    run('git', 'merge', '--strategy=ours', '--no-ff', base,
        '-m', 'chore(upstream): retain klash release history', cwd=destination)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--validate-overlay', action='store_true')
    args = parser.parse_args()
    manifest = json.loads((ROOT / 'klash/upstream.json').read_text())
    paths = (ROOT / 'klash/runtime-paths.txt').read_text().splitlines()
    if args.validate_overlay:
        changed = set(run('git', 'diff', '--name-only', manifest['commit'], '--', 'lib', 'macos', 'plugins/rust_api', 'test', 'arb', 'assets/images/icon.png').stdout.splitlines())
        missing = changed.difference(paths)
        if missing:
            raise RuntimeError(f'Runtime changes missing from the overlay path list: {sorted(missing)}')
        tag = manifest['commit']
        release = None
    else:
        release = json.loads(run('gh', 'api', f'repos/{manifest["repository"]}/releases/latest').stdout)
        if release['draft'] or release['prerelease']:
            return
        tag = release['tag_name']
        if version(tag)[0] <= version(manifest['tag'])[0]:
            print('No newer stable upstream release')
            return
        run('git', 'fetch', f'https://github.com/{manifest["repository"]}.git', f'refs/tags/{tag}:refs/tags/{tag}')
    temporary = Path(tempfile.mkdtemp(prefix='klash-overlay-'))
    destination = temporary / 'candidate'
    try:
        reconstruct(tag, destination, paths)
        if args.validate_overlay:
            for relative in paths:
                expected, actual = ROOT / relative, destination / relative
                if expected.exists() != actual.exists() or (expected.exists() and expected.read_bytes() != actual.read_bytes()):
                    raise RuntimeError(f'Overlay differs from current runtime file: {relative}')
            print('Klash runtime overlay reconstructs all declared files')
            return
        upstream_commit = run('git', 'rev-parse', 'HEAD', cwd=destination).stdout.strip()
        klash_version = version(tag)[1]
        repository = os.environ['GITHUB_REPOSITORY']
        branch = f'codex/upstream-{tag}'
        existing = json.loads(run('gh', 'pr', 'list', '--repo', repository, '--head', branch, '--state', 'open', '--json', 'number').stdout)
        if existing:
            print(f'Candidate PR already exists: {existing[0]["number"]}')
            return
        if run('gh', 'release', 'view', f'v{klash_version}', '--repo', repository, check=False).returncode == 0:
            raise RuntimeError('Klash release already exists; refusing to replace it')
        shutil.rmtree(destination / '.github/workflows', ignore_errors=True)
        for relative in ['.github/workflows', '.github/upstream-workflows', '.github/ISSUE_TEMPLATE', 'klash', 'tool/klash']:
            shutil.copytree(ROOT / relative, destination / relative, dirs_exist_ok=True)
        for relative in ['README.md', 'README_zh_CN.md', 'KLASH-NOTICE.md', '.gitattributes']:
            shutil.copy2(ROOT / relative, destination / relative)
        manifest.pop('release_revision', None)
        manifest.update(tag=tag, commit=upstream_commit, klash_version=klash_version)
        (destination / 'klash/upstream.json').write_text(json.dumps(manifest, indent=2) + '\n')
        spec = destination / 'pubspec.yaml'
        current_build = int(re.search(r'^version: .*\+(\d+)$', (ROOT / 'pubspec.yaml').read_text(), re.M)[1])
        upstream_build = re.search(r'^version: .*\+(\d+)$', spec.read_text(), re.M)
        build = max(current_build + 1, int(upstream_build[1]) if upstream_build else 0)
        candidate_spec = re.sub(r'^version: .*$', f'version: {klash_version}+{build}', spec.read_text(), flags=re.M)
        description = re.search(r'^description: .*$', (ROOT / 'pubspec.yaml').read_text(), re.M)[0]
        spec.write_text(re.sub(r'^description: .*$', description, candidate_spec, flags=re.M))
        patch = run('git', 'diff', '--binary', '--full-index', tag, '--', *paths, cwd=destination).stdout
        (destination / 'klash/runtime.patch').write_text(patch)
        run('git', 'add', '-A', cwd=destination)
        run('git', 'commit', '-m', f'feat(upstream): integrate {tag} as Klash {klash_version}', cwd=destination)
        retain_release_history(destination, run('git', 'rev-parse', 'HEAD').stdout.strip())
        run('git', 'push', 'origin', f'HEAD:refs/heads/{branch}', cwd=destination)
        body = temporary / 'pr.md'
        body.write_text(f'Upgrade to {manifest["repository"]} {tag} ({upstream_commit}).\n\nThe Klash overlay applied without unresolved conflicts. Publication requires analysis, tests and both macOS builds. A failed check leaves this PR open.\n')
        base = run('gh', 'repo', 'view', repository, '--json', 'defaultBranchRef', '--jq', '.defaultBranchRef.name').stdout.strip()
        run('gh', 'pr', 'create', '--repo', repository, '--base', base, '--head', branch, '--title', f'Klash {klash_version} from FlClash {tag}', '--body-file', str(body))
        number = json.loads(run('gh', 'pr', 'list', '--repo', repository, '--head', branch, '--json', 'number').stdout)[0]['number']
        run('gh', 'workflow', 'run', 'flash-macos.yml', '--repo', repository, '--ref', branch, '-f', 'publish=true', '-f', f'sync_pr={number}')
        print(f'Created PR {number} and dispatched Klash {klash_version} build')
    finally:
        run('git', 'worktree', 'remove', '--force', str(destination), check=False)
        shutil.rmtree(temporary, ignore_errors=True)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, ValueError, subprocess.CalledProcessError) as error:
        detail = getattr(error, 'stderr', '')
        raise SystemExit(f'{error}\n{detail}')
