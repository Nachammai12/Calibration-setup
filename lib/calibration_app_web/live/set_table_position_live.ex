defmodule CalibrationAppWeb.SetTablePositionLive do
  use CalibrationAppWeb, :live_view

  alias CalibrationApp.FreeRotationServer

  @pubsub_topic FreeRotationServer.topic()

  # Dummy durations (ms) for Coarse and Fine rotation
  @coarse_duration_ms 3_000
  @fine_duration_ms 2_000

  @impl true
  def mount(_params, _session, socket) do
    socket =
      if connected?(socket) do
        Phoenix.PubSub.subscribe(CalibrationApp.PubSub, @pubsub_topic)
        server_state = FreeRotationServer.get_state()

        socket
        |> assign(:current_image_data, server_state.current_image_data)
        |> assign(:active, if(server_state.rotating, do: :free, else: :none))
      else
        socket
        |> assign(:current_image_data, nil)
        |> assign(:active, :none)
      end

    roi = load_roi_defaults()

    socket =
      socket
      |> assign(:page_title, "Set Table Position")
      |> assign(:exposure, roi["exposure"] || 72)
      |> assign(:position, roi["stage_position"] || "0.00 mm")
      |> assign(:scan_angle, "10")
      |> assign(:encoder_value, nil)
      |> assign(:cube_gauge_width, nil)
      |> assign(:rotation_token, 0)

    {:ok, socket}
  end

  # ── Free Rotation ──────────────────────────────────────────────────────────

  @impl true
  def handle_event("toggle_free", _params, socket) do
    active = socket.assigns.active

    active =
      if active == :free do
        FreeRotationServer.stop_rotation()
        :none
      else
        FreeRotationServer.start_rotation()
        :free
      end

    {:noreply, assign(socket, :active, active)}
  end

  # ── Coarse / Fine Rotation ─────────────────────────────────────────────────

  @impl true
  def handle_event("toggle_coarse_fine", _params, socket) do
    active = socket.assigns.active

    socket =
      if active == :coarse or active == :fine do
        # Bump token to invalidate any in-flight timer messages
        socket
        |> assign(:active, :none)
        |> assign(:rotation_token, socket.assigns.rotation_token + 1)
      else
        new_token = socket.assigns.rotation_token + 1
        Process.send_after(self(), {:coarse_done, new_token}, @coarse_duration_ms)

        socket
        |> assign(:active, :coarse)
        |> assign(:rotation_token, new_token)
      end

    {:noreply, socket}
  end

  # ── Scan Angle input ───────────────────────────────────────────────────────

  @impl true
  def handle_event("update_scan_angle", %{"value" => val}, socket) do
    {:noreply, assign(socket, :scan_angle, val)}
  end

  # ── Navigation ────────────────────────────────────────────────────────────

  @impl true
  def handle_event("go_previous", _params, socket) do
    if socket.assigns.active != :none do
      {:noreply, socket}
    else
      {:noreply, push_navigate(socket, to: ~p"/primary-alignment")}
    end
  end

  @impl true
  def handle_event("go_next", _params, socket) do
    if socket.assigns.active != :none do
      {:noreply, socket}
    else
      encoder = socket.assigns.encoder_value
      path = if encoder, do: ~p"/result?encoder=#{encoder}", else: ~p"/result"
      {:noreply, push_navigate(socket, to: path)}
    end
  end

  # ── Coarse / Fine timer callbacks ─────────────────────────────────────────

  @impl true
  def handle_info({:coarse_done, token}, socket) do
    if token != socket.assigns.rotation_token do
      # Stale message from a cancelled run — ignore
      {:noreply, socket}
    else
      Process.send_after(self(), {:fine_done, token}, @fine_duration_ms)
      {:noreply, assign(socket, :active, :fine)}
    end
  end

  @impl true
  def handle_info({:fine_done, token}, socket) do
    if token != socket.assigns.rotation_token do
      # Stale message from a cancelled run — ignore
      {:noreply, socket}
    else
      encoder = Float.round(:rand.uniform() * 360, 2)

      socket =
        socket
        |> assign(:active, :none)
        |> assign(:encoder_value, encoder)
        |> assign(:position, encoder)
        |> assign(:cube_gauge_width, Float.round(:rand.uniform() * 10 + 5, 2))

      {:noreply, socket}
    end
  end

  # ── Free Rotation image updates (PubSub) ───────────────────────────────────

  @impl true
  def handle_info({:image_update, image_data}, socket) do
    {:noreply, assign(socket, :current_image_data, image_data)}
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp load_roi_defaults do
    path = Path.join(:code.priv_dir(:calibration_app), "static/roi_defaults.json")

    case File.read(path) do
      {:ok, data} ->
        case Jason.decode(data) do
          {:ok, parsed} -> parsed
          {:error, _} -> %{"exposure" => 72, "stage_position" => "0.00 mm"}
        end

      {:error, _} ->
        %{"exposure" => 72, "stage_position" => "0.00 mm"}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="fixed inset-0 bg-[#0f0f0f] text-[#d1d1d1] flex flex-col overflow-hidden">
        <%!-- Top bar --%>
        <div class="flex items-center justify-between px-6 py-2 bg-[#1a1a1a] border-b border-[#2a2a2a]">
          <span class="text-white font-semibold tracking-wide text-sm">Calibration Setup</span>

          <div id="step-bar" class="flex items-center gap-3 text-xs font-medium">
            <span class="text-[#555]">Primary Alignment</span>
            <span class="text-[#333]">──────</span>
            <span id="step-set-table-position" class="text-white font-bold">Set Table Position</span>
            <span class="text-[#333]">──────</span>
            <span class="text-[#555]">Result</span>
          </div>

          <div class="w-40" />
        </div>

        <%!-- Main content --%>
        <div class="flex flex-1 overflow-hidden">
          <%!-- Left: Camera feed --%>
          <div class="flex-[3] flex flex-col overflow-hidden min-w-0">
            <div class="flex-1 flex items-center justify-center bg-[#0f0f0f] p-4 overflow-hidden">
              <div
                id="camera-feed"
                class="relative w-full h-full flex items-center justify-center rounded-lg overflow-hidden border border-[#2a2a2a]"
              >
                <%= if @current_image_data do %>
                  <img
                    id="rotation-image"
                    src={@current_image_data}
                    alt="Camera feed"
                    class="max-w-full max-h-full object-contain"
                  />
                <% else %>
                  <div class="flex flex-col items-center justify-center gap-3 text-[#444]">
                    <.icon name="hero-camera" class="w-16 h-16" />
                    <span class="text-sm">No images loaded</span>
                  </div>
                <% end %>
              </div>
            </div>

            <%!-- Status bar --%>
            <div class="flex items-center gap-8 px-6 py-2 bg-[#1a1a1a] border-t border-[#2a2a2a]">
              <div id="exposure-indicator" class="flex items-center gap-2">
                <span class="text-xs font-semibold text-[#888] uppercase tracking-widest">
                  Exposure
                </span>
                <span class="text-sm font-mono text-[#d1d1d1]">{@exposure}</span>
              </div>
              <div class="w-px h-4 bg-[#333]" />
              <div id="position-indicator" class="flex items-center gap-2">
                <span class="text-xs font-semibold text-[#888] uppercase tracking-widest">
                  Stage Position
                </span>
                <span class="text-sm font-mono text-[#d1d1d1]">{@position}</span>
              </div>
            </div>
          </div>

          <%!-- Right: Control panel --%>
          <div class="w-96 flex flex-col bg-[#1a1a1a] border-l border-[#2a2a2a] px-4 py-4 gap-4 overflow-y-auto">
            <%!-- Section 1: Free Rotation --%>
            <div
              id="free-rotation-section"
              class="bg-[#242424] border border-[#333] rounded-lg px-4 py-3 flex flex-col gap-3"
            >
              <p class="text-xs font-semibold text-[#888] uppercase tracking-widest">Free Rotation</p>
              <p id="free-rotation-description" class="text-sm text-[#999]">
                Use Free Rotation to manually align the table axis parallel to the optical lens and illumination source before Coarse/Fine.
              </p>
              <button
                id="free-rotation-btn"
                phx-click="toggle_free"
                disabled={@active in [:coarse, :fine]}
                class={[
                  "w-full py-2.5 rounded text-sm font-medium transition-colors duration-150",
                  if(@active == :free,
                    do: "bg-red-600 hover:bg-red-700 text-white",
                    else: "bg-blue-600 hover:bg-blue-700 text-white"
                  ),
                  @active in [:coarse, :fine] && "opacity-40 cursor-not-allowed"
                ]}
              >
                {if @active == :free, do: "Stop", else: "Start"}
              </button>
            </div>

            <%!-- Section 2: Coarse / Fine Rotation --%>
            <div
              id="coarse-fine-section"
              class="bg-[#242424] border border-[#333] rounded-lg px-4 py-3 flex flex-col gap-3"
            >
              <p class="text-xs font-semibold text-[#888] uppercase tracking-widest">
                Coarse / Fine Rotation
              </p>

              <div class="flex flex-col gap-1">
                <label for="scan-angle-input" class="text-xs text-[#888]">Scan Angle (+/-)</label>
                <form id="scan-angle-form" phx-change="update_scan_angle" phx-submit="update_scan_angle">
                  <input
                    id="scan-angle-input"
                    type="text"
                    inputmode="decimal"
                    value={@scan_angle}
                    name="value"
                    disabled={@active != :none}
                    placeholder="Enter angle, e.g. 45"
                    class={[
                      "w-full bg-[#1a1a1a] border border-[#333] rounded px-3 py-2 text-sm text-[#d1d1d1]",
                      "focus:outline-none focus:border-[#555] placeholder-[#555]",
                      @active != :none && "opacity-40 cursor-not-allowed"
                    ]}
                  />
                </form>
              </div>

              <%= cond do %>
                <% @active == :coarse -> %>
                  <p class="text-xs text-[#888] italic">Running Coarse Rotation...</p>
                <% @active == :fine -> %>
                  <p class="text-xs text-[#888] italic">Running Fine Rotation...</p>
                <% true -> %>
                  <span />
              <% end %>

              <button
                id="coarse-fine-btn"
                phx-click="toggle_coarse_fine"
                disabled={@active == :free or (@scan_angle == "" and @active not in [:coarse, :fine])}
                title={
                  if @scan_angle == "" and @active not in [:coarse, :fine],
                    do: "Enter a scan angle to start",
                    else: ""
                }
                class={[
                  "w-full py-2.5 rounded text-sm font-medium transition-colors duration-150",
                  if(@active in [:coarse, :fine],
                    do: "bg-red-600 hover:bg-red-700 text-white",
                    else: "bg-blue-600 hover:bg-blue-700 text-white"
                  ),
                  (@active == :free or (@scan_angle == "" and @active not in [:coarse, :fine])) &&
                    "opacity-40 cursor-not-allowed"
                ]}
              >
                {if @active in [:coarse, :fine], do: "Stop", else: "Start"}
              </button>
            </div>

            <%!-- Section 3: Outputs --%>
            <div
              id="outputs-section"
              class="bg-[#242424] border border-[#333] rounded-lg px-4 py-3 flex flex-col gap-2"
            >
              <p class="text-xs font-semibold text-[#888] uppercase tracking-widest">Outputs</p>

              <div class="flex items-center justify-between">
                <span class="text-xs text-[#888]">Encoder Value</span>
                <span id="encoder-value" class="text-sm font-mono text-[#d1d1d1]">
                  {if @encoder_value, do: @encoder_value, else: "—"}
                </span>
              </div>

              <div class="flex items-center justify-between">
                <span class="text-xs text-[#888]">Cube Gauge Width</span>
                <span id="cube-gauge-width" class="text-sm font-mono text-[#d1d1d1]">
                  {if @cube_gauge_width, do: @cube_gauge_width, else: "—"}
                </span>
              </div>
            </div>

            <%!-- Navigation --%>
            <div class="mt-auto pt-2 flex gap-3">
              <button
                id="prev-btn"
                phx-click="go_previous"
                disabled={@active != :none}
                title={if @active != :none, do: "Stop the rotation before navigating", else: ""}
                class={[
                  "flex-1 py-2.5 rounded text-sm font-medium bg-[#242424] hover:bg-[#2e2e2e] text-[#d1d1d1] border border-[#333] transition-colors duration-150",
                  @active != :none && "opacity-40 cursor-not-allowed hover:bg-[#242424]"
                ]}
              >
                Previous
              </button>
              <button
                id="next-btn"
                phx-click="go_next"
                disabled={@active != :none}
                title={if @active != :none, do: "Stop the rotation before navigating", else: ""}
                class={[
                  "flex-1 py-2.5 rounded text-sm font-medium bg-blue-600 hover:bg-blue-700 text-white transition-colors duration-150",
                  @active != :none && "opacity-40 cursor-not-allowed hover:bg-blue-600"
                ]}
              >
                Next
              </button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
