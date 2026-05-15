import os
import shutil
import subprocess
import glob

def render_dir(plantuml_cmd, src_dir, img_dir):
    puml_files = sorted(glob.glob(os.path.join(src_dir, '*.puml')))
    if not puml_files:
        return
    
    os.makedirs(img_dir, exist_ok=True)
    for f in puml_files:
        try:
            cmd = [plantuml_cmd, '-tsvg', '-o', os.path.abspath(img_dir), os.path.abspath(f)]
            subprocess.run(cmd, check=True)
            print(f"Rendered: {f} -> {img_dir}")
        except subprocess.CalledProcessError as e:
            print(f"Error rendering {f}: {e}")

def main():
    plantuml_cmd = shutil.which('plantuml')
    if not plantuml_cmd:
        print("plantuml command not found")
        return

    # Find all directories that contain a /src/ and end with puml files
    for root, dirs, files in os.walk('docs'):
        if root.endswith('/src') or root == 'docs/src':
            img_dir = root.replace('/src', '/img')
            render_dir(plantuml_cmd, root, img_dir)

if __name__ == '__main__':
    main()
