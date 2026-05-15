import os
import subprocess

def convert_to_markdown(doc_dir):
    """
    Convert all documents in the specified directory to Markdown using pandoc.

    :param doc_dir: Path to the directory containing documents to convert.
    """
    for root, _, files in os.walk(doc_dir):
        for file in files:
            # Skip files that are already Markdown
            if file.endswith('.md'):
                continue

            # Construct full file paths
            input_path = os.path.join(root, file)
            output_path = os.path.splitext(input_path)[0] + '.md'

            try:
                # Run pandoc to convert the file
                subprocess.run([
                    'pandoc', input_path, '-o', output_path
                ], check=True)
                print(f"Converted {input_path} to {output_path}")
            except subprocess.CalledProcessError as e:
                print(f"Failed to convert {input_path}: {e}")

if __name__ == "__main__":
    # Define the directory containing the documents
    doc_directory = os.path.dirname(os.path.abspath(__file__))

    # Call the conversion function
    convert_to_markdown(doc_directory)