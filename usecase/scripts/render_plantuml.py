#!/usr/bin/env python3
"""Render PlantUML .puml files in docs/{module}/src/ to docs/{module}/img/.

Searches commands in order (first match wins):
  - plantuml       (apt/brew/pacman package)
  - plantuml-native (AUR / manual install)
  - java -jar plantuml.jar  (jar in scripts/ or docs/)
  - docker run plantuml/plantuml

Usage:
  python3 usecase/scripts/render_plantuml.py
  python3 usecase/scripts/render_plantuml.py --module backend
  python3 usecase/scripts/render_plantuml.py --module overview,frontend
"""
import sys
import os
import shutil
import subprocess
import glob
import argparse

SEARCH_COMMANDS = ['plantuml', 'plantuml-native']

JAR_CANDIDATES = [
    'plantuml.jar',                              # next to this script
    os.path.join('..', 'docs', 'plantuml.jar'),  # under usecase/docs/
]

DOCKER_IMAGE = 'plantuml/plantuml'


def locate_cmd() -> str | None:
    for cmd in SEARCH_COMMANDS:
        path = shutil.which(cmd)
        if path:
            print(f"Detected `{cmd}` at {path}")
            return path
    return None


def locate_jar(script_dir: str) -> str | None:
    for rel in JAR_CANDIDATES:
        jar = os.path.normpath(os.path.join(script_dir, rel))
        if os.path.isfile(jar):
            print(f"Found plantuml.jar at {jar}")
            return jar
    return None


def find_modules(src_root: str) -> list[str]:
    """Return list of module directories under src_root (e.g. ['overview', 'backend'])."""
    modules = []
    for entry in sorted(os.listdir(src_root)):
        full = os.path.join(src_root, entry)
        if os.path.isdir(full) and os.path.isdir(os.path.join(full, 'src')):
            modules.append(entry)
    return modules


def puml_files(module_src: str) -> list[str]:
    return sorted(glob.glob(os.path.join(module_src, '*.puml')))


def render_batch(cmd_template: list[str], src_files: list[str], img_dir: str) -> bool:
    ok = True
    for f in src_files:
        try:
            cmd = cmd_template + ['-tsvg', '-o', img_dir, f]
            subprocess.run(cmd, check=True)
            print(f"  Rendered: {os.path.basename(f)}")
        except subprocess.CalledProcessError as e:
            print(f"  Error rendering {f}: {e}")
            ok = False
    return ok


def render_via_cmd(command: str, modules: list[str], docs_root: str) -> bool:
    all_ok = True
    for mod in modules:
        src_dir = os.path.join(docs_root, mod, 'src')
        img_dir = os.path.join(docs_root, mod, 'img')
        files = puml_files(src_dir)
        if not files:
            continue
        os.makedirs(img_dir, exist_ok=True)
        print(f"[{mod}] rendering {len(files)} diagram(s) with `{command}`")
        if not render_batch([command], files, img_dir):
            all_ok = False
    return all_ok


def render_via_jar(jar_path: str, modules: list[str], docs_root: str) -> bool:
    all_ok = True
    for mod in modules:
        src_dir = os.path.join(docs_root, mod, 'src')
        img_dir = os.path.join(docs_root, mod, 'img')
        files = puml_files(src_dir)
        if not files:
            continue
        os.makedirs(img_dir, exist_ok=True)
        print(f"[{mod}] rendering {len(files)} diagram(s) via java -jar")
        if not render_batch(['java', '-jar', jar_path], files, img_dir):
            all_ok = False
    return all_ok


def render_via_docker(modules: list[str], docs_root: str) -> bool:
    all_ok = True
    for mod in modules:
        src_dir = os.path.join(docs_root, mod, 'src')
        img_dir = os.path.join(docs_root, mod, 'img')
        files = puml_files(src_dir)
        if not files:
            continue

        abs_src = os.path.abspath(src_dir)
        abs_img = os.path.abspath(img_dir)
        os.makedirs(abs_img, exist_ok=True)

        for f in files:
            basename = os.path.basename(f)
            try:
                cmd = [
                    'docker', 'run', '--rm',
                    '-v', f'{abs_src}:/workspace/src',
                    '-v', f'{abs_img}:/workspace/img',
                    DOCKER_IMAGE, '-tsvg', '-o', '/workspace/img', f'/workspace/src/{basename}'
                ]
                subprocess.run(cmd, check=True)
                print(f"  [{mod}] Rendered via docker: {basename}")
            except subprocess.CalledProcessError as e:
                print(f"  Docker render error for {basename}: {e}")
                all_ok = False
    return all_ok


def main():
    parser = argparse.ArgumentParser(description='Render PlantUML diagrams')
    parser.add_argument('--module', '-m', help='Comma-separated module names (e.g. overview,backend). Default: all')
    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    docs_root = os.path.normpath(os.path.join(script_dir, '..', 'docs'))

    all_modules = find_modules(docs_root)
    if not all_modules:
        print(f"No module directories with src/ found under {docs_root}")
        sys.exit(0)

    if args.module:
        requested = [m.strip() for m in args.module.split(',')]
        modules = [m for m in all_modules if m in requested]
        missing = set(requested) - set(modules)
        if missing:
            print(f"Unknown modules: {', '.join(missing)}")
            sys.exit(2)
    else:
        modules = all_modules

    # 1) Try native commands in order
    command = locate_cmd()
    if command:
        if render_via_cmd(command, modules, docs_root):
            print("All diagrams rendered successfully.")
            sys.exit(0)

    # 2) Try plantuml.jar
    jar = locate_jar(script_dir)
    if jar:
        if render_via_jar(jar, modules, docs_root):
            print("All diagrams rendered successfully.")
            sys.exit(0)

    # 3) Try Docker
    if shutil.which('docker'):
        print("Docker detected. Trying plantuml/plantuml image.")
        if render_via_docker(modules, docs_root):
            print("All diagrams rendered successfully.")
            sys.exit(0)

    print('\nNo renderer available. Install one of:')
    print('  - `plantuml`          (apt/brew/pacman)')
    print('  - `plantuml-native`   (AUR / local install)')
    print(f'  - `plantuml.jar`      (place in scripts/ or usecase/docs/)')
    print(f'  - Docker + `{DOCKER_IMAGE}` image')
    sys.exit(2)


if __name__ == '__main__':
    main()