defmodule CalibrationApp.FreeRotationServer do
  use GenServer

  @frame_interval_ms 600
  @pubsub_topic "free_rotation:images"

  # ── Public API ──────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    gen_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, :ok, gen_opts)
  end

  @doc "PubSub topic used for image broadcasts."
  def topic, do: @pubsub_topic

  @doc "Start the image loop. No-op if already rotating."
  def start_rotation(server \\ __MODULE__) do
    GenServer.call(server, :start_rotation)
  end

  @doc "Stop the image loop. Current frame is preserved."
  def stop_rotation(server \\ __MODULE__) do
    GenServer.call(server, :stop_rotation)
  end

  @doc "Return current state map for LiveView mount."
  def get_state(server \\ __MODULE__) do
    GenServer.call(server, :get_state)
  end

  # ── GenServer callbacks ──────────────────────────────────────────────────────

  @impl true
  def init(:ok) do
    {:ok,
     %{
       images: [],
       current_index: 0,
       current_image_data: nil,
       rotating: false,
       image_count: 0,
       timer_ref: nil
     }, {:continue, :load_images}}
  end

  @impl true
  def handle_continue(:load_images, state) do
    images = load_images()
    current_image_data = Enum.at(images, 0)

    {:noreply,
     %{
       state
       | images: images,
         current_image_data: current_image_data,
         image_count: length(images)
     }}
  end

  @impl true
  def handle_call(:start_rotation, _from, state) do
    state =
      if state.rotating do
        state
      else
        ref = Process.send_after(self(), :tick, @frame_interval_ms)
        %{state | rotating: true, timer_ref: ref}
      end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:stop_rotation, _from, state) do
    if state.timer_ref, do: Process.cancel_timer(state.timer_ref)
    {:reply, :ok, %{state | rotating: false, timer_ref: nil}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    reply = %{
      current_image_data: state.current_image_data,
      rotating: state.rotating
    }

    {:reply, reply, state}
  end

  @impl true
  def handle_info(:tick, %{rotating: false} = state) do
    # Rotation was stopped before this tick arrived; discard.
    {:noreply, state}
  end

  @impl true
  def handle_info(:tick, state) do
    next_index = rem(state.current_index + 1, max(state.image_count, 1))
    current_image_data = Enum.at(state.images, next_index)

    if current_image_data do
      Phoenix.PubSub.broadcast(
        CalibrationApp.PubSub,
        @pubsub_topic,
        {:image_update, current_image_data}
      )
    end

    ref = Process.send_after(self(), :tick, @frame_interval_ms)

    {:noreply,
     %{state | current_index: next_index, current_image_data: current_image_data, timer_ref: ref}}
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  defp images_dir do
    Path.join([
      :code.priv_dir(:calibration_app) |> List.to_string(),
      "static",
      "images",
      "free_rotation"
    ])
  end

  defp load_images do
    path = images_dir()

    case File.ls(path) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.match?(&1, ~r/\.(png|jpg|jpeg|gif)$/i))
        |> Enum.sort()
        |> Enum.map(&encode_image(Path.join(path, &1)))
        |> Enum.reject(&is_nil/1)

      {:error, _} ->
        []
    end
  end

  defp encode_image(path) do
    case File.read(path) do
      {:ok, data} ->
        ext = path |> Path.extname() |> String.downcase() |> String.trim_leading(".")
        mime = if ext in ["jpg", "jpeg"], do: "image/jpeg", else: "image/#{ext}"
        "data:#{mime};base64,#{Base.encode64(data)}"

      {:error, _} ->
        nil
    end
  end
end
