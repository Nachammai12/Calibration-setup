# python/auto_exposure/algo.py
"""
Dummy auto-exposure algorithm.
Input:  image_path (str), avg_intensity (float), current_exposure (int)
Output: (new_exposure: int, good_exposure: bool)

Target exposure: 200. Steps up by +10 each call until 200 is reached.
Replace this function body with the real algorithm when available.
The wrapper.py and PythonBridge calling convention remain the same.
"""


def process_auto_exposure(image_path: str, avg_intensity: float, current_exposure: int):
    """Return (new_exposure, good_exposure) for one iteration."""
    if current_exposure >= 200:
        return current_exposure, True
    new_exposure = current_exposure + 10
    return new_exposure, new_exposure >= 200
