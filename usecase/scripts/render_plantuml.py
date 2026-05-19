#!/usr/bin/env python3
"""Render PlantUML .puml files to SVG.

Scopes (in order):
  1. usecase/docs/{module}/ — legacy modules (overview, backend, frontend, containerd, database)
  2. {module}/ — root-level modules (class, time, status, activity)

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


ROOT_LEVEL_MODULES = ['class', 'time', 'status', 'activity']


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


def render_all(cmd: str, modules: dict[str, str]) -> bool:
    """Render modules dict (name -> root_path) via native command."""
    all_ok = True
    for mod, root in modules.items():
        src_dir = os.path.join(root, mod, 'src')
        img_dir = os.path.join(root, mod, 'img')
        files = puml_files(src_dir)
        if not files:
            continue
        os.makedirs(img_dir, exist_ok=True)
        print(f"[{mod}] rendering {len(files)} diagram(s) with `{cmd}`")
        if not render_batch([cmd], files, img_dir):
            all_ok = False
    return all_ok


def render_via_jar_all(jar_path: str, modules: dict[str, str]) -> bool:
    all_ok = True
    for mod, root in modules.items():
        src_dir = os.path.join(root, mod, 'src')
        img_dir = os.path.join(root, mod, 'img')
        files = puml_files(src_dir)
        if not files:
            continue
        os.makedirs(img_dir, exist_ok=True)
        print(f"[{mod}] rendering {len(files)} diagram(s) via java -jar")
        if not render_batch(['java', '-jar', jar_path], files, img_dir):
            all_ok = False
    return all_ok


def render_via_docker_all(modules: dict[str, str]) -> bool:
    all_ok = True
    for mod, root in modules.items():
        src_dir = os.path.join(root, mod, 'src')
        img_dir = os.path.join(root, mod, 'img')
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
    project_root = os.path.normpath(os.path.join(script_dir, '..', '..'))
    docs_root = os.path.normpath(os.path.join(script_dir, '..', 'docs'))

    # Scan both usecase/docs/ and root-level modules
    all_modules: dict[str, str] = {}   # module_name -> root_path
    for mod in find_modules(docs_root):
        all_modules[mod] = docs_root
    for mod in ROOT_LEVEL_MODULES:
        mod_path = os.path.join(project_root, mod)
        if os.path.isdir(mod_path) and os.path.isdir(os.path.join(mod_path, 'src')):
            all_modules[mod] = project_root

    if not all_modules:
        print(f"No module directories with src/ found")
        sys.exit(0)

    if args.module:
        requested = [m.strip() for m in args.module.split(',')]
        modules = {k: v for k, v in all_modules.items() if k in requested}
        missing = set(requested) - set(modules.keys())
        if missing:
            print(f"Unknown modules: {', '.join(missing)}")
            sys.exit(2)
    else:
        modules = all_modules

    # 1) Try native commands in order
    command = locate_cmd()
    if command:
        if render_all(command, modules):
            print("All diagrams rendered successfully.")
            sys.exit(0)

    # 2) Try plantuml.jar
    jar = locate_jar(script_dir)
    if jar:
        if render_via_jar_all(jar, modules):
            print("All diagrams rendered successfully.")
            sys.exit(0)

    # 3) Try Docker
    if shutil.which('docker'):
        print("Docker detected. Trying plantuml/plantuml image.")
        if render_via_docker_all(modules):
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