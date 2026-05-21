#!/usr/bin/env python3
"""status/render.py — 渲染状态图（支持多个 .puml 文件）"""
import subprocess, glob
ROOT = __file__.replace('/render.py', '')
src_dir = f"{ROOT}/src"
img = f"{ROOT}/img"
print("[status] Rendering...")
for f in sorted(glob.glob(f"{src_dir}/*.puml")):
    subprocess.run(["/usr/bin/plantuml-native", "-tsvg", "-o", img, f], check=True)
    print(f"  {f.split('/')[-1]}")
print("[status] Done.")