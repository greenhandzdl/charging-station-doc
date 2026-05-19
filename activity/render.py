#!/usr/bin/env python3
"""activity/render.py — 渲染活动图"""
import subprocess
ROOT = __file__.replace('/render.py', '')
src = f"{ROOT}/src/activity_repair.puml"
img = f"{ROOT}/img"
print("[activity] Rendering...")
subprocess.run(["/usr/bin/plantuml-native", "-tsvg", "-o", img, src], check=True)
print("[activity] Done.")