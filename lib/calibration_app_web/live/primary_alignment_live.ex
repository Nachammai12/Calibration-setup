defmodule CalibrationAppWeb.PrimaryAlignmentLive do
  use CalibrationAppWeb, :live_view

  defp load_roi_defaults do
    path = Path.join(:code.priv_dir(:calibration_app), "static/roi_defaults.json")

    case File.read(path) do
      {:ok, data} -> Jason.decode!(data)
      {:error, _} -> %{"centre_x" => 500, "centre_y" => 500, "radius" => 500}
    end
  end

  defp parse_number(str) do
    case Integer.parse(to_string(str)) do
      {n, _} -> n
      :error -> 0
    end
  end

  # Push ROI overlay event to the canvas hook.
  # Sends clear: true when heatmap is ON or auto exposure is running, otherwise sends current ROI values.
  defp push_roi_event(socket) do
    if socket.assigns.heatmap_on or
         Map.get(socket.assigns, :auto_exposure_running, false) do
      push_event(socket, "roi_updated", %{clear: true})
    else
      push_event(socket, "roi_updated", %{
        cx: parse_number(socket.assigns.roi_centre_x),
        cy: parse_number(socket.assigns.roi_centre_y),
        radius: parse_number(socket.assigns.roi_radius),
        clear: false
      })
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    roi = load_roi_defaults()

    # Get initial image (stage=0, heatmap off = live mode)
    initial_image_data =
      case CalibrationApp.HeatmapPipeline.get_image(0, false) do
        {:ok, data} -> data
        {:error, _} -> nil
      end

    socket =
      socket
      |> assign(:page_title, "Primary Alignment")
      |> assign(:alignment_stage, 0)
      |> assign(:heatmap_on, false)
      |> assign(:current_image_data, initial_image_data)
      |> assign(:exposure, roi["exposure"] || 72)
      |> assign(:position, roi["stage_position"] || "0.00 mm")
      |> assign(:auto_exposure_running, false)
      |> assign(:ae_iteration, 0)
      |> assign(:roi_centre_x, to_string(roi["centre_x"]))
      |> assign(:roi_centre_y, to_string(roi["centre_y"]))
      |> assign(:roi_radius, to_string(roi["radius"]))

    socket =
      if connected?(socket) do
        push_roi_event(socket)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_info({:ae_iteration, image_data, exposure, _good?}, socket) do
    socket =
      socket
      |> assign(:current_image_data, image_data || socket.assigns.current_image_data)
      |> assign(:exposure, exposure)
      |> assign(:ae_iteration, socket.assigns.ae_iteration + 1)

    {:noreply, socket}
  end

  @impl true
  def handle_info(:ae_done, socket) do
    {:noreply, push_navigate(socket, to: ~p"/set-table-position")}
  end

  @impl true
  def handle_info({:ae_error, _reason}, socket) do
    socket =
      socket
      |> assign(:auto_exposure_running, false)
      |> put_flash(:error, "Auto exposure failed. Please try again.")

    {:noreply, socket}
  end

  @impl true
  def handle_event("heatmap_on", _params, socket) do
    # First use: advance stage from 0 → 1. Subsequent: keep current stage.
    new_stage =
      if socket.assigns.alignment_stage == 0,
        do: 1,
        else: socket.assigns.alignment_stage

    image_data =
      case CalibrationApp.HeatmapPipeline.get_image(new_stage, true) do
        {:ok, data} -> data
        {:error, _} -> socket.assigns.current_image_data
      end

    socket =
      socket
      |> assign(:alignment_stage, new_stage)
      |> assign(:heatmap_on, true)
      |> assign(:current_image_data, image_data)
      |> push_roi_event()

    {:noreply, socket}
  end

  @impl true
  def handle_event("heatmap_off", _params, socket) do
    # Advance stage on heatmap OFF (simulates physical hardware adjustment), clamped at 3.
    # Guard: if stage is 0 (heatmap_off fired before any heatmap_on — should not
    # happen in normal UI flow), keep at 0 rather than silently advancing to 1.
    new_stage =
      if socket.assigns.alignment_stage == 0,
        do: 0,
        else: min(socket.assigns.alignment_stage + 1, 3)

    image_data =
      case CalibrationApp.HeatmapPipeline.get_image(new_stage, false) do
        {:ok, data} -> data
        {:error, _} -> socket.assigns.current_image_data
      end

    socket =
      socket
      |> assign(:alignment_stage, new_stage)
      |> assign(:heatmap_on, false)
      |> assign(:current_image_data, image_data)
      |> push_roi_event()

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_roi", params, socket) do
    socket =
      socket
      |> assign(:roi_centre_x, Map.get(params, "centre_x", socket.assigns.roi_centre_x))
      |> assign(:roi_centre_y, Map.get(params, "centre_y", socket.assigns.roi_centre_y))
      |> assign(:roi_radius, Map.get(params, "radius", socket.assigns.roi_radius))
      |> push_roi_event()

    {:noreply, socket}
  end

  @impl true
  def handle_event("next", _params, socket) do
    topic = CalibrationApp.AutoExposureServer.pubsub_topic(self())
    Phoenix.PubSub.subscribe(CalibrationApp.PubSub, topic)

    {:ok, _pid} =
      CalibrationApp.AutoExposureServer.start_link(%{
        lv_pid: self(),
        initial_exposure: 170
      })

    socket =
      socket
      |> assign(:auto_exposure_running, true)
      |> assign(:ae_iteration, 0)
      |> push_roi_event()

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <%!-- Full-screen dark wrapper --%>
      <div class="fixed inset-0 bg-[#0f0f0f] text-[#d1d1d1] flex flex-col overflow-hidden">
        <%!-- Top bar --%>
        <div class="flex items-center justify-between px-6 py-2 bg-[#1a1a1a] border-b border-[#2a2a2a]">
          <span class="text-white font-semibold tracking-wide text-sm">Calibration Setup</span>

          <%!-- Step progress bar --%>
          <div id="step-bar" class="flex items-center gap-3 text-xs font-medium">
            <span id="step-primary-alignment" class="step-active text-white font-bold">
              Primary Alignment
            </span>
            <span class="text-[#333]">──────</span>
            <span class="text-[#555]">Set Table Position</span>
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
                    id="roi-image"
                    src={@current_image_data}
                    alt="Camera feed"
                    class="max-w-full max-h-full object-contain"
                  />
                  <canvas
                    id="roi-canvas"
                    phx-hook=".RoiOverlay"
                    phx-update="ignore"
                    class="absolute inset-0 w-full h-full pointer-events-none"
                  >
                  </canvas>
                <% else %>
                  <div class="flex flex-col items-center justify-center gap-3 text-[#444]">
                    <.icon name="hero-camera" class="w-16 h-16" />
                    <span class="text-sm">No images loaded</span>
                    <span class="text-xs text-[#333]">
                      Drop images into images/primary_alignment/
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
            <%= if @auto_exposure_running do %>
              <%!-- Auto Exposure in-progress panel --%>
              <div
                id="auto-exposure-panel"
                class="flex flex-col items-center justify-center flex-1 gap-6 py-8"
              >
                <%!-- Outer spinner --%>
                <div class="w-14 h-14 rounded-full border-4 border-[#333] border-t-blue-500 animate-spin" />

                <%!-- Live status --%>
                <div class="flex flex-col items-center gap-2 text-center">
                  <span class="text-sm font-medium text-[#d1d1d1]">Auto Exposure Running...</span>
                  <span class="text-xs text-[#888]">
                    Iteration: {@ae_iteration}
                  </span>
                  <span class="text-xs text-[#888]">
                    Exposure: {@exposure}
                  </span>
                </div>
              </div>
            <% else %>
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
                    <span>Observe the live camera feed.</span>
                  </li>
                  <li class="flex gap-2">
                    <span class="text-[#555] font-mono shrink-0">2.</span>
                    <span>
                      Toggle the <span class="text-white font-semibold">Heatmap</span>
                      to inspect intensity distribution.
                    </span>
                  </li>
                  <li class="flex gap-2">
                    <span class="text-[#555] font-mono shrink-0">3.</span>
                    <span>
                      Use <span class="text-white font-semibold">Adjust FOV</span>
                      to set the field of view — enter the centre coordinates and radius.
                    </span>
                  </li>
                  <li class="flex gap-2">
                    <span class="text-[#555] font-mono shrink-0">4.</span>
                    <span>
                      When alignment looks correct, press
                      <span class="text-white font-semibold">Next</span>
                      to run auto exposure.
                    </span>
                  </li>
                </ol>
              </div>

              <%!-- Heatmap toggle --%>
              <div class="bg-[#242424] border border-[#333] rounded-lg px-4 py-3 mb-3">
                <p class="text-xs font-semibold text-[#888] uppercase tracking-widest mb-2">
                  Heatmap
                </p>
                <div
                  id="heatmap-toggle"
                  class="flex rounded overflow-hidden border border-[#444]"
                  data-state={if @heatmap_on, do: "on", else: "off"}
                >
                  <button
                    id="heatmap-btn-off"
                    phx-click="heatmap_off"
                    class={[
                      "flex-1 py-2 text-sm font-medium transition-colors duration-150",
                      if(not @heatmap_on,
                        do: "bg-blue-600 text-white",
                        else: "bg-transparent text-[#555] hover:text-[#888]"
                      )
                    ]}
                  >
                    OFF
                  </button>
                  <button
                    id="heatmap-btn-on"
                    phx-click="heatmap_on"
                    class={[
                      "flex-1 py-2 text-sm font-medium transition-colors duration-150",
                      if(@heatmap_on,
                        do: "bg-blue-600 text-white",
                        else: "bg-transparent text-[#555] hover:text-[#888]"
                      )
                    ]}
                  >
                    ON
                  </button>
                </div>
              </div>

              <%!-- Adjust FOV --%>
              <div
                id="adjust-fov-card"
                class="bg-[#242424] border border-[#333] rounded-lg px-4 py-3 mb-3"
              >
                <p class="text-xs font-semibold text-[#888] uppercase tracking-widest mb-2">
                  Adjust FOV
                </p>
                <div class={[
                  @heatmap_on && "opacity-40 pointer-events-none"
                ]}>
                  <form phx-change="update_roi" id="roi-form">
                    <%!-- Centre X + Y side by side --%>
                    <div class="flex gap-2 mb-2">
                      <div class="flex-1">
                        <label class="block text-xs text-[#888] mb-1">Centre X</label>
                        <input
                          id="roi-centre-x"
                          type="number"
                          name="centre_x"
                          value={@roi_centre_x}
                          class="w-full bg-[#1a1a1a] border border-[#444] rounded px-2 py-1.5 text-sm text-[#d1d1d1] focus:outline-none focus:border-blue-600"
                        />
                      </div>
                      <div class="flex-1">
                        <label class="block text-xs text-[#888] mb-1">Centre Y</label>
                        <input
                          id="roi-centre-y"
                          type="number"
                          name="centre_y"
                          value={@roi_centre_y}
                          class="w-full bg-[#1a1a1a] border border-[#444] rounded px-2 py-1.5 text-sm text-[#d1d1d1] focus:outline-none focus:border-blue-600"
                        />
                      </div>
                    </div>
                    <div>
                      <label class="block text-xs text-[#888] mb-1">Radius</label>
                      <input
                        id="roi-radius"
                        type="number"
                        name="radius"
                        value={@roi_radius}
                        class="w-full bg-[#1a1a1a] border border-[#444] rounded px-2 py-1.5 text-sm text-[#d1d1d1] focus:outline-none focus:border-blue-600"
                      />
                    </div>
                  </form>
                </div>
                <%= if @heatmap_on do %>
                  <p class="text-xs text-[#555] mt-1">To adjust FOV, turn the heatmap OFF first.</p>
                <% end %>
              </div>

              <%!-- Next button — pinned to bottom --%>
              <div class="mt-auto pt-2 flex gap-3">
                <button
                  id="next-btn"
                  phx-click="next"
                  disabled={@auto_exposure_running}
                  class={[
                    "w-1/2 ml-auto py-2.5 rounded text-sm font-medium transition-colors duration-150",
                    if(@auto_exposure_running,
                      do: "bg-[#333] text-[#555] cursor-not-allowed",
                      else: "bg-blue-600 hover:bg-blue-700 text-white"
                    )
                  ]}
                >
                  Next
                </button>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".RoiOverlay">
      export default {
        mounted() {
          this._lastData = null
          this.handleEvent("roi_updated", (data) => {
            this._lastData = data
            this._draw(data)
          })
        },
        _draw(data) {
          const canvas = this.el
          const img = document.getElementById("roi-image")
          if (!img) return
          // If the image hasn't finished loading, defer until it has
          if (!img.complete || img.naturalWidth === 0) {
            img.addEventListener("load", () => this._draw(data), { once: true })
            return
          }
          const ctx = canvas.getContext("2d")
          // Set canvas pixel buffer to match its actual CSS display size so arc() is a true circle
          canvas.width = canvas.clientWidth
          canvas.height = canvas.clientHeight
          ctx.clearRect(0, 0, canvas.width, canvas.height)
          if (data.clear) return
          const natW = img.naturalWidth
          const natH = img.naturalHeight
          // Compute how object-contain renders the image inside the canvas area
          const scaleX = canvas.width / natW
          const scaleY = canvas.height / natH
          const scale = Math.min(scaleX, scaleY)
          // Letterbox / pillarbox offsets so the overlay aligns with image pixels
          const renderedW = natW * scale
          const renderedH = natH * scale
          const offsetX = (canvas.width - renderedW) / 2
          const offsetY = (canvas.height - renderedH) / 2
          const cx = offsetX + data.cx * scale
          const cy = offsetY + data.cy * scale
          const r  = data.radius * scale
          ctx.strokeStyle = "#39ff14"
          ctx.lineWidth = 2
          // True circle
          ctx.beginPath()
          ctx.arc(cx, cy, r, 0, 2 * Math.PI)
          ctx.stroke()
          // Crosshair plus — arm scales with radius
          const arm = Math.max(8, r * 0.04)
          ctx.beginPath()
          ctx.moveTo(cx - arm, cy)
          ctx.lineTo(cx + arm, cy)
          ctx.moveTo(cx, cy - arm)
          ctx.lineTo(cx, cy + arm)
          ctx.stroke()
        }
      }
    </script>
    """
  end
end
