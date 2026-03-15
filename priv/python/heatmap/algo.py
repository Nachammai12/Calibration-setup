# python/heatmap/algo.py
"""
Dummy heatmap algorithm.
Input:  absolute path to a greyscale PNG
Output: absolute path to a processed (coloured) PNG
Today this is an identity function — returns the input path unchanged.
Replace this function body with the real algorithm when available.
The wrapper.py and PythonBridge calling convention remain the same.
"""
def process_heatmap(image_path: str) -> str:
    """Return the input image path unchanged (pass-through dummy)."""
    return image_path
