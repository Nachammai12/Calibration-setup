defmodule CalibrationApp.HeatmapPipeline do
  @moduledoc """
  Resolves which image to display given the current alignment stage and heatmap state,
  then returns the encoded image data-URI.

  Stage-to-label mapping:
    0 → live mode (initial, before first heatmap use)
    1 → angular_more
    2 → angular_slight
    3 → angular_aligned

  When heatmap_on=true, calls PythonBridge.run_heatmap/1 before encoding.
  Today the bridge is a pass-through, so the pre-rendered heatmap PNG is served directly.
  """

  alias CalibrationApp.{Camera, PythonBridge}

  @stage_labels %{
    1 => "angular_more",
    2 => "angular_slight",
    3 => "angular_aligned"
  }

  @doc """
  Returns the absolute filesystem path for the image corresponding to
  the given alignment stage and heatmap flag.
  """
  @spec image_path(stage :: 0..3, heatmap_on :: boolean()) :: String.t()
  def image_path(0, false) do
    base_dir() |> Path.join("live_mode/1-angular_more.png")
  end

  def image_path(stage, false) when stage in 1..3 do
    label = Map.fetch!(@stage_labels, stage)
    base_dir() |> Path.join("heatmap_off/#{stage}-#{label}.png")
  end

  def image_path(stage, true) when stage in 1..3 do
    label = Map.fetch!(@stage_labels, stage)
    base_dir() |> Path.join("heatmap_on/heatmap_#{stage}-#{label}.png")
  end

  @doc """
  Returns `{:ok, data_uri}` for the image matching the given alignment state.
  When heatmap_on=true, runs the image through PythonBridge first (pass-through today).
  When heatmap_on=false, reads the image directly via Camera.
  """
  @spec get_image(stage :: 0..3, heatmap_on :: boolean()) ::
          {:ok, String.t()} | {:error, term()}
  def get_image(stage, false) do
    path = image_path(stage, false)
    Camera.get_frame(path)
  end

  def get_image(stage, true) do
    path = image_path(stage, true)

    with {:ok, result_path} <- PythonBridge.run_heatmap(path) do
      Camera.get_frame(result_path)
    end
  end

  # ── Private ─────────────────────────────────────────────────────────────────
  defp base_dir do
    Path.join([
      :code.priv_dir(:calibration_app) |> List.to_string(),
      "static", "images", "primary_alignment"
    ])
  end
end
