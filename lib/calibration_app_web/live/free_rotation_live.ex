defmodule CalibrationAppWeb.FreeRotationLive do
  use CalibrationAppWeb, :live_view

  alias CalibrationApp.FreeRotationServer

  @pubsub_topic FreeRotationServer.topic()

  @impl true
  def mount(_params, _session, socket) do
    socket =
      if connected?(socket) do
        Phoenix.PubSub.subscribe(CalibrationApp.PubSub, @pubsub_topic)
        server_state = FreeRotationServer.get_state()

        socket
        |> assign(:current_image_data, server_state.current_image_data)
        |> assign(:rotating, server_state.rotating)
      else
        socket
        |> assign(:current_image_data, nil)
        |> assign(:rotating, false)
      end

    roi = load_roi_defaults()

    socket =
      socket
      |> assign(:page_title, "Free Rotation")
      |> assign(:exposure, roi["exposure"] || 72)
      |> assign(:position, roi["stage_position"] || "0.00 mm")

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle", _params, socket) do
    rotating =
      if socket.assigns.rotating do
        FreeRotationServer.stop_rotation()
        false
      else
        FreeRotationServer.start_rotation()
        true
      end

    {:noreply, assign(socket, :rotating, rotating)}
  end

  @impl true
  def handle_info({:image_update, image_data}, socket) do
    {:noreply, assign(socket, :current_image_data, image_data)}
  end

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

          <%!-- Step progress bar --%>
          <div id="step-bar" class="flex items-center gap-3 text-xs font-medium">
            <span class="text-[#555]">Primary Alignment</span>
            <span class="text-[#333]">──────</span>
            <div id="step-set-table-position" class="step-active flex flex-col items-center">
              <span class="text-white font-bold">Set Table Position</span>
              <span class="text-[#888] text-[10px]">Free Rotation</span>
            </div>
            <span class="text-[#333]">──────</span>
            <span class="text-[#555]">Result</span>
          </div>

          <div class="w-40" />
        </div>

        <%!-- Main content: left camera + right panel --%>
        <div class="flex flex-1 overflow-hidden">
          <%!-- Left: Camera image panel + status bar below --%>
          <div class="flex-[3] flex flex-col overflow-hidden min-w-0">
            <%!-- Camera image area --%>
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
                    <span class="text-xs text-[#333]">
                      Drop images into priv/static/images/free_rotation/
                    </span>
                  </div>
                <% end %>
              </div>
            </div>

            <%!-- Status bar: Exposure + Stage Position below camera image --%>
            <div class="flex items-center justify-start gap-8 px-6 py-2 bg-[#1a1a1a] border-t border-[#2a2a2a]">
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
          <div class="w-96 flex flex-col bg-[#1a1a1a] border-l border-[#2a2a2a] px-4 py-3 overflow-hidden">
            <%!-- Instructions card --%>
            <div
              id="instructions-card"
              class="bg-[#242424] border border-[#333] rounded-lg px-4 py-3 mb-3"
            >
              <p class="text-xs font-semibold text-[#888] uppercase tracking-widest mb-2">
                Instructions
              </p>
              <ol class="text-sm text-[#d1d1d1] leading-relaxed list-none space-y-2">
                <li class="flex gap-2">
                  <span class="text-[#555] font-mono shrink-0">1.</span>
                  <span>
                    Press <span class="text-white font-semibold">Start</span> to begin free rotation.
                  </span>
                </li>
                <li class="flex gap-2">
                  <span class="text-[#555] font-mono shrink-0">2.</span>
                  <span>Observe the live camera feed as the table rotates.</span>
                </li>
                <li class="flex gap-2">
                  <span class="text-[#555] font-mono shrink-0">3.</span>
                  <span>
                    Press <span class="text-white font-semibold">Stop</span>
                    to freeze the current frame.
                  </span>
                </li>
              </ol>
            </div>

            <%!-- Spacer --%>
            <div class="flex-1" />

            <%!-- Toggle button — pinned to bottom --%>
            <button
              id="rotation-toggle-btn"
              phx-click="toggle"
              class={[
                "w-full py-2.5 rounded text-sm font-medium transition-colors duration-150",
                if(@rotating,
                  do: "bg-red-600 hover:bg-red-700 text-white",
                  else: "bg-green-600 hover:bg-green-700 text-white"
                )
              ]}
            >
              {if @rotating, do: "Stop", else: "Start"}
            </button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
