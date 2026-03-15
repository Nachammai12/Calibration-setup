defmodule CalibrationApp.AutoExposureServer do
  @moduledoc """
  Per-session GenServer that runs the auto-exposure feedback loop.

  Started by PrimaryAlignmentLive on the "next" event. Linked to the
  LiveView process — terminates automatically when the LiveView disconnects.

  Each iteration:
    1. Resolves the image for the current exposure value.
    2. Computes the average pixel intensity from the image bytes.
    3. Calls PythonBridge.run_auto_exposure/3 to get the next exposure.
    4. Encodes the new image and broadcasts via PubSub.
    5. If good_exposure=true: broadcasts :ae_done and stops.
       If false: schedules the next iteration after @iteration_delay_ms.
  """

  use GenServer

  @iteration_delay_ms 800

  @spec start_link(map()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec pubsub_topic(pid()) :: String.t()
  def pubsub_topic(lv_pid), do: "auto_exposure:#{inspect(lv_pid)}"

  # ── Callbacks ────────────────────────────────────────────────────────────────

  @impl true
  def init(%{lv_pid: lv_pid, initial_exposure: exposure}) do
    send(self(), :run_iteration)

    {:ok,
     %{
       lv_pid: lv_pid,
       topic: pubsub_topic(lv_pid),
       current_exposure: exposure,
       iteration: 0
     }}
  end

  @impl true
  def handle_info(:run_iteration, state) do
    %{topic: topic, current_exposure: exposure, iteration: iter} = state
    image_path = image_path_for(exposure)
    avg_intensity = compute_avg_intensity(image_path)

    case CalibrationApp.PythonBridge.run_auto_exposure(image_path, avg_intensity, exposure) do
      {:ok, %{new_exposure: new_exp, good_exposure: good?}} ->
        new_image_path = image_path_for(new_exp)

        image_data =
          case CalibrationApp.Camera.get_frame(new_image_path) do
            {:ok, data} -> data
            {:error, _} -> nil
          end

        Phoenix.PubSub.broadcast(
          CalibrationApp.PubSub,
          topic,
          {:ae_iteration, image_data, new_exp, good?}
        )

        if good? do
          Phoenix.PubSub.broadcast(CalibrationApp.PubSub, topic, :ae_done)
          {:stop, :normal, state}
        else
          Process.send_after(self(), :run_iteration, @iteration_delay_ms)
          {:noreply, %{state | current_exposure: new_exp, iteration: iter + 1}}
        end

      {:error, reason} ->
        Phoenix.PubSub.broadcast(CalibrationApp.PubSub, topic, {:ae_error, reason})
        {:stop, {:error, reason}, state}
    end
  end

  # ── Private ──────────────────────────────────────────────────────────────────

  defp base_dir do
    Path.join([
      :code.priv_dir(:calibration_app) |> List.to_string(),
      "static",
      "images",
      "primary_alignment",
      "auto_exposure"
    ])
  end

  defp image_path_for(exposure) do
    Path.join(base_dir(), "aligned_uniform_avg_#{exposure}.png")
  end

  defp compute_avg_intensity(image_path) do
    case File.read(image_path) do
      {:ok, data} ->
        bytes = :binary.bin_to_list(data)
        Enum.sum(bytes) / max(length(bytes), 1)

      {:error, _} ->
        0.0
    end
  end
end
