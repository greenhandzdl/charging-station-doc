#!/usr/bin/env python3
"""class/render.py — 渲染类图"""
import subprocess, sys
ROOT = __file__.replace('/render.py', '')
src = f"{ROOT}/src/class_diagram.puml"
img = f"{ROOT}/img"
print("[class] Rendering...")
subprocess.run(["/usr/bin/plantuml-native", "-tsvg", "-o", img, src], check=True)
print("[class] Done.")