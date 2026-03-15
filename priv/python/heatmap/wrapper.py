# python/heatmap/wrapper.py
"""
Entry point for the Elixir PythonBridge Port.
Protocol (one exchange per Port lifetime):
  stdin  <- {"image_path": "<absolute_path>"}
  stdout -> {"result_path": "<absolute_path>"}
Elixir sends one JSON line then closes the Port (EOF).
This script reads that one line, processes it, writes the response, and exits.
"""
import sys
import json
from algo import process_heatmap

def main() -> None:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        req = json.loads(line)
        result_path = process_heatmap(req["image_path"])
        sys.stdout.write(json.dumps({"result_path": result_path}) + "\n")
        sys.stdout.flush()
        break  # one-shot protocol: process one line then exit

if __name__ == "__main__":
    main()
