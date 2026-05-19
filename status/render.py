#!/usr/bin/env python3
"""status/render.py — 渲染状态图"""
import subprocess
ROOT = __file__.replace('/render.py', '')
src = f"{ROOT}/src/state_charger.puml"
img = f"{ROOT}/img"
print("[status] Rendering...")
subprocess.run(["/usr/bin/plantuml-native", "-tsvg", "-o", img, src], check=True)
print("[status] Done.")