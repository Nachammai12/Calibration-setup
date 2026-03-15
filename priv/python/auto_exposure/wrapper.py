# python/auto_exposure/wrapper.py
"""
Entry point for the Elixir PythonBridge Port.
Protocol (one exchange per Port lifetime):
  stdin  <- {"image_path": "<path>", "avg_intensity": <float>, "current_exposure": <int>}
  stdout -> {"new_exposure": <int>, "good_exposure": <bool>}
Elixir sends one JSON line then closes the Port (EOF).
"""
import sys
import json
from algo import process_auto_exposure


def main() -> None:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        req = json.loads(line)
        new_exp, good = process_auto_exposure(
            req["image_path"],
            float(req["avg_intensity"]),
            int(req["current_exposure"]),
        )
        sys.stdout.write(json.dumps({"new_exposure": new_exp, "good_exposure": good}) + "\n")
        sys.stdout.flush()
        break  # one-shot protocol


if __name__ == "__main__":
    main()
