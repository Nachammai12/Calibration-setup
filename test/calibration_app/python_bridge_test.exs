defmodule CalibrationApp.PythonBridgeTest do
  use ExUnit.Case, async: true
  @moduletag :python
  alias CalibrationApp.PythonBridge

  @test_image_path Path.join([
    :code.priv_dir(:calibration_app) |> List.to_string(),
    "static", "images", "primary_alignment", "heatmap_on", "heatmap_1-angular_more.png"
  ])

  test "run_heatmap/1 returns {:ok, path} for a valid image path" do
    assert {:ok, result_path} = PythonBridge.run_heatmap(@test_image_path)
    assert is_binary(result_path)
    assert String.ends_with?(result_path, ".png")
  end

  test "run_heatmap/1 pass-through: result path equals input path (dummy algo)" do
    assert {:ok, result_path} = PythonBridge.run_heatmap(@test_image_path)
    assert result_path == @test_image_path
  end

  test "run_heatmap/1 returns {:error, _} when Python is not available" do
    result = PythonBridge.run_heatmap_with_script("/nonexistent/script.py", @test_image_path)
    assert {:error, _reason} = result
  end
end
