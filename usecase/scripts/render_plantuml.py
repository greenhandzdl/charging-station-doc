#!/usr/bin/env python3
"""Render PlantUML .puml files in ../docs/src to ../docs/img.

Checks (in order):
- `plantuml` command on PATH (often installed via package manager)
- `plantuml.jar` located next to this script or in ../docs
- Docker image `plantuml/plantuml`

Usage:
  python3 usecase/scripts/render_plantuml.py
  # or from usecase/docs: python3 ../scripts/render_plantuml.py
"""
import sys
import os
import shutil
import subprocess
import glob


def render_with_cmd(plantuml_cmd, src_files, img_dir, extra_args=None):
    ok = True
    for f in src_files:
        try:
            cmd = [plantuml_cmd, '-tsvg', '-o', img_dir, f]
            subprocess.run(cmd, check=True)
            print(f"Rendered: {os.path.basename(f)} -> {img_dir}")
        except subprocess.CalledProcessError as e:
            print(f"Error rendering {f} with {plantuml_cmd}: {e}")
            ok = False
    return ok


def render_with_jar(jar_path, src_files, img_dir):
    ok = True
    for f in src_files:
        try:
            cmd = ['java', '-jar', jar_path, '-tsvg', '-o', img_dir, f]
            subprocess.run(cmd, check=True)
            print(f"Rendered via jar: {os.path.basename(f)} -> {img_dir}")
        except subprocess.CalledProcessError as e:
            print(f"Error rendering {f} with jar {jar_path}: {e}")
            ok = False
    return ok


def render_with_docker(src_files, src_dir, img_dir):
    ok = True
    for f in src_files:
        basename = os.path.basename(f)
        try:
            cmd = [
                'docker', 'run', '--rm',
                '-v', f'{src_dir}:/workspace',
                '-v', f'{img_dir}:/output',
                'plantuml/plantuml', '-tsvg', '-o', '/output', f'/workspace/{basename}'
            ]
            subprocess.run(cmd, check=True)
            print(f"Rendered via docker: {basename} -> {img_dir}")
        except subprocess.CalledProcessError as e:
            print(f"Docker render error for {basename}: {e}")
            ok = False
    return ok


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    src_dir = os.path.normpath(os.path.join(script_dir, '..', 'docs', 'src'))
    img_dir = os.path.normpath(os.path.join(script_dir, '..', 'docs', 'img'))
    os.makedirs(img_dir, exist_ok=True)

    puml_files = sorted(glob.glob(os.path.join(src_dir, '*.puml')))
    if not puml_files:
        print(f"No .puml files found in {src_dir}")
        sys.exit(0)

    # 1) plantuml CLI
    plantuml_cmd = shutil.which('plantuml')
    if plantuml_cmd:
        print('Detected `plantuml` command (likely installed via package manager). Using it.')
        success = render_with_cmd(plantuml_cmd, puml_files, img_dir)
        if success:
            print('All diagrams rendered with plantuml.')
            sys.exit(0)

    # 2) plantuml.jar in script or docs
    candidate_jars = [
        os.path.join(script_dir, 'plantuml.jar'),
        os.path.join(script_dir, '..', 'docs', 'plantuml.jar'),
    ]
    for jar in candidate_jars:
        if os.path.isfile(jar):
            print(f'Found plantuml.jar at {jar}; rendering via java -jar.')
            if render_with_jar(jar, puml_files, img_dir):
                print('All diagrams rendered with plantuml.jar.')
                sys.exit(0)

    # 3) docker
    if shutil.which('docker'):
        print('Docker detected. Trying to render diagrams with plantuml Docker image.')
        if render_with_docker(puml_files, src_dir, img_dir):
            print('All diagrams rendered with Docker image plantuml/plantuml.')
            sys.exit(0)

    print('\n未能找到可用的渲染器：请确保至少安装下列之一：')
    print('- `plantuml` 命令（可通过系统包管理器安装，例如 apt/brew/pacman）')
    print('- `plantuml.jar`（放到 usecase/scripts 或 usecase/docs 下）')
    print('- Docker（用于运行 plantuml 镜像）')
    sys.exit(2)


if __name__ == '__main__':
    main()
