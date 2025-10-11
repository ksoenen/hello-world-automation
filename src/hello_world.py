import os
import json
import sys
from datetime import datetime

# BASE_DIR = os.path.dirname(os.path.abspath(__file__))
# For exe, use sys._MEIPASS or something, but simple for now

CONFIG_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'hello_world.py_config.json')

def load_config():
    with open(CONFIG_PATH, 'r') as f:
        return json.load(f)

def main(input_file=None):
    print("Hello World! This is a sample program - first round now written in pyton.. i get this works..")
    if input_file:
        print(f"Processing: {input_file}")
    # Add more based on purpose
    config = load_config()
    print(f"Config loaded: {config.get('docs', {}).get('general', {}).get('how_to_use', '')}")

if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else None)