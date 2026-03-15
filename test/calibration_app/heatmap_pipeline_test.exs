defmodule CalibrationApp.HeatmapPipelineTest do
  use ExUnit.Case, async: true
  alias CalibrationApp.HeatmapPipeline

  # ── image_path/2 ────────────────────────────────────────────────────────────
  test "image_path/2 stage=0, heatmap=false → live_mode file" do
    path = HeatmapPipeline.image_path(0, false)
    assert String.contains?(path, "live_mode")
    assert String.ends_with?(path, ".png")
  end

  test "image_path/2 stage=1, heatmap=false → heatmap_off/1-angular_more" do
    path = HeatmapPipeline.image_path(1, false)
    assert String.contains?(path, "heatmap_off")
    assert String.contains?(path, "1-angular_more")
  end

  test "image_path/2 stage=2, heatmap=false → heatmap_off/2-angular_slight" do
    path = HeatmapPipeline.image_path(2, false)
    assert String.contains?(path, "heatmap_off")
    assert String.contains?(path, "2-angular_slight")
  end

  test "image_path/2 stage=3, heatmap=false → heatmap_off/3-angular_aligned" do
    path = HeatmapPipeline.image_path(3, false)
    assert String.contains?(path, "heatmap_off")
    assert String.contains?(path, "3-angular_aligned")
  end

  test "image_path/2 stage=1, heatmap=true → heatmap_on/heatmap_1-angular_more" do
    path = HeatmapPipeline.image_path(1, true)
    assert String.contains?(path, "heatmap_on")
    assert String.contains?(path, "heatmap_1-angular_more")
  end

  test "image_path/2 stage=2, heatmap=true → heatmap_on/heatmap_2-angular_slight" do
    path = HeatmapPipeline.image_path(2, true)
    assert String.contains?(path, "heatmap_on")
    assert String.contains?(path, "heatmap_2-angular_slight")
  end

  test "image_path/2 stage=3, heatmap=true → heatmap_on/heatmap_3-angular_aligned" do
    path = HeatmapPipeline.image_path(3, true)
    assert String.contains?(path, "heatmap_on")
    assert String.contains?(path, "heatmap_3-angular_aligned")
  end

  # ── get_image/2 — heatmap OFF (no PythonBridge dependency) ─────────────────
  test "get_image/2 stage=0, heatmap=false returns {:ok, data_uri}" do
    assert {:ok, data} = HeatmapPipeline.get_image(0, false)
    assert String.starts_with?(data, "data:image/")
  end

  test "get_image/2 stage=1, heatmap=false returns {:ok, data_uri}" do
    assert {:ok, data} = HeatmapPipeline.get_image(1, false)
    assert String.starts_with?(data, "data:image/")
  end

  # ── get_image/2 — heatmap ON (requires PythonBridge from Chunk 2) ──────────
  @moduletag :heatmap_bridge
  test "get_image/2 stage=1, heatmap=true returns {:ok, data_uri}" do
    assert {:ok, data} = HeatmapPipeline.get_image(1, true)
    assert String.starts_with?(data, "data:image/")
  end

  @moduletag :heatmap_bridge
  test "get_image/2 stage=3, heatmap=true returns {:ok, data_uri}" do
    assert {:ok, data} = HeatmapPipeline.get_image(3, true)
    assert String.starts_with?(data, "data:image/")
  end
end
