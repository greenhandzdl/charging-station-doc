#!/usr/bin/env python3
"""activity/render.py — 渲染活动图（支持多个 .puml 文件）"""
import subprocess, glob
ROOT = __file__.replace('/render.py', '')
src_dir = f"{ROOT}/src"
img = f"{ROOT}/img"
print("[activity] Rendering...")
for f in sorted(glob.glob(f"{src_dir}/*.puml")):
    subprocess.run(["/usr/bin/plantuml-native", "-tsvg", "-o", img, f], check=True)
    print(f"  {f.split('/')[-1]}")
print("[activity] Done.")