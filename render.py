#!/usr/bin/env python3
"""render.py — 渲染全部 PlantUML 图

用法:
  python render.py              # 渲染全部模块
  python render.py class        # 仅渲染 class
  python render.py class time   # 渲染 class + time
"""
import subprocess, sys, os, shutil, glob

ROOT = os.path.dirname(os.path.abspath(__file__))

MODULE_SCRIPT = {
    "class":   f"{ROOT}/class/render.py",
    "time":    f"{ROOT}/time/render.py",
    "status":  f"{ROOT}/status/render.py",
    "activity":f"{ROOT}/activity/render.py",
    "usecase": f"{ROOT}/usecase/scripts/render_plantuml.py",
}

def locate_cmd():
    for cmd in ["plantuml-native", "plantuml"]:
        if shutil.which(cmd):
            return cmd
    return None

def main():
    requested = sys.argv[1:] if len(sys.argv) > 1 else list(MODULE_SCRIPT.keys())

    ok = 0
    fail = 0

    for mod in requested:
        if mod not in MODULE_SCRIPT:
            print(f"[{mod}] Unknown module. Available: {', '.join(MODULE_SCRIPT.keys())}")
            fail += 1
            continue

        script = MODULE_SCRIPT[mod]
        if not os.path.exists(script):
            print(f"[{mod}] Script not found: {script}")
            fail += 1
            continue

        print(f"{'='*46}", flush=True)
        print(f" Module: {mod}", flush=True)
        print(f"{'='*46}", flush=True)
        ret = subprocess.run([sys.executable, script])
        if ret.returncode == 0:
            ok += 1
        else:
            fail += 1
        print()

    # fallback: if any root-level module has no render.py but has puml files,
    # render them directly
    cmd = locate_cmd()
    if cmd:
        for mod in requested:
            if mod in MODULE_SCRIPT:
                continue  # already handled above
            src_dir = f"{ROOT}/{mod}/src"
            img_dir = f"{ROOT}/{mod}/img"
            if os.path.isdir(src_dir):
                os.makedirs(img_dir, exist_ok=True)
                print(f"[{mod}] rendering via {cmd}...")
                for f in sorted(glob.glob(f"{src_dir}/*.puml")):
                    subprocess.run([cmd, "-tsvg", "-o", img_dir, f], check=True)
                    print(f"  {os.path.basename(f)}")
                ok += 1

    print(f"{'='*46}")
    print(f" Summary: {ok} module(s) OK, {fail} failed")
    print(f"{'='*46}")
    return fail

if __name__ == "__main__":
    sys.exit(main())