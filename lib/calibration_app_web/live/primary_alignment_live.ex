defmodule CalibrationAppWeb.PrimaryAlignmentLive do
  use CalibrationAppWeb, :live_view

  @frame_interval_ms 600
  @auto_exposure_frame_interval_ms 5000

  defp images_path(set) do
    Path.join([:code.priv_dir(:calibration_app) |> List.to_string(), "static", "images", "primary_alignment", Atom.to_string(set)])
  end

  defp load_images(set) do
    path = images_path(set)

    case File.ls(path) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.match?(&1, ~r/\.(png|jpg|jpeg|gif)$/i))
        |> Enum.sort()
        |> Enum.map(&Path.join(path, &1))

      {:error, _} ->
        []
    end
  end

  defp read_image_data(images, index) do
    case Enum.at(images, index) do
      nil ->
        nil

      path ->
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

  defp load_roi_defaults do
    path = Path.join(:code.priv_dir(:calibration_app), "static/roi_defaults.json")

    case File.read(path) do
      {:ok, data} -> Jason.decode!(data)
      {:error, _} -> %{"centre_x" => 0, "centre_y" => 0, "radius" => 50}
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
    if socket.assigns.image_set == :heatmap_on or Map.get(socket.assigns, :auto_exposure_running, false) do
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

  # Switch to a new image set, cancel any in-flight frame loops by bumping the frame_token
  defp switch_image_set(socket, set) do
    images = load_images(set)
    current_image_data = read_image_data(images, 0)
    new_token = socket.assigns.frame_token + 1
    interval = if set == :auto_exposure_running, do: @auto_exposure_frame_interval_ms, else: @frame_interval_ms

    if length(images) > 1 do
      Process.send_after(self(), {:next_frame, new_token}, interval)
    end

    socket
    |> assign(:image_set, set)
    |> assign(:images, images)
    |> assign(:current_index, 0)
    |> assign(:current_image_data, current_image_data)
    |> assign(:frame_token, new_token)
    |> push_roi_event()
  end

  @auto_exposure_duration_ms 2000

  @impl true
  def mount(_params, _session, socket) do
    images = load_images(:live_mode)
    current_index = 0
    current_image_data = read_image_data(images, current_index)
    initial_token = 0
    roi = load_roi_defaults()

    socket =
      socket
      |> assign(:page_title, "Primary Alignment")
      |> assign(:image_set, :live_mode)
      |> assign(:images, images)
      |> assign(:current_index, current_index)
      |> assign(:current_image_data, current_image_data)
      |> assign(:exposure, roi["exposure"] || 72)
      |> assign(:position, roi["stage_position"] || "0.00 mm")
      |> assign(:auto_exposure_running, false)
      |> assign(:frame_token, initial_token)
      |> assign(:roi_centre_x, to_string(roi["centre_x"]))
      |> assign(:roi_centre_y, to_string(roi["centre_y"]))
      |> assign(:roi_radius, to_string(roi["radius"]))

    socket =
      if connected?(socket) do
        if length(images) > 1 do
          Process.send_after(self(), {:next_frame, initial_token}, @frame_interval_ms)
        end

        push_roi_event(socket)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_info({:next_frame, token}, socket) do
    # Ignore stale frame messages from a previous image set
    if token != socket.assigns.frame_token do
      {:noreply, socket}
    else
      images = socket.assigns.images
      next_index = rem(socket.assigns.current_index + 1, max(length(images), 1))
      current_image_data = read_image_data(images, next_index)
      interval = if socket.assigns.image_set == :auto_exposure_running, do: @auto_exposure_frame_interval_ms, else: @frame_interval_ms

      if length(images) > 1 do
        Process.send_after(self(), {:next_frame, token}, interval)
      end

      {:noreply,
       socket
       |> assign(:current_index, next_index)
       |> assign(:current_image_data, current_image_data)}
    end
  end

  @impl true
  def handle_info(:auto_exposure_done, socket) do
    socket =
      socket
      |> assign(:image_set, :auto_exposure_done)
      |> assign(:auto_exposure_running, false)

    {:noreply, push_navigate(socket, to: ~p"/set-table-position")}
  end

  @impl true
  def handle_event("heatmap_on", _params, socket) do
    {:noreply, switch_image_set(socket, :heatmap_on)}
  end

  @impl true
  def handle_event("heatmap_off", _params, socket) do
    {:noreply, switch_image_set(socket, :heatmap_off)}
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
    socket =
      socket
      |> assign(:auto_exposure_running, true)
      |> switch_image_set(:auto_exposure_running)

    Process.send_after(self(), :auto_exposure_done, @auto_exposure_duration_ms)
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
                      Drop images into images/primary_alignment/{Atom.to_string(@image_set)}/
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
                  <span>Observe the live camera feed.</span>
                </li>
                <li class="flex gap-2">
                  <span class="text-[#555] font-mono shrink-0">2.</span>
                  <span>Toggle the <span class="text-white font-semibold">Heatmap</span> to inspect intensity distribution.</span>
                </li>
                <li class="flex gap-2">
                  <span class="text-[#555] font-mono shrink-0">3.</span>
                  <span>Use <span class="text-white font-semibold">Adjust FOV</span> to set the field of view — enter the centre coordinates and radius.</span>
                </li>
                <li class="flex gap-2">
                  <span class="text-[#555] font-mono shrink-0">4.</span>
                  <span>When alignment looks correct, press <span class="text-white font-semibold">Next</span> to run auto exposure.</span>
                </li>
              </ol>
            </div>

            <%!-- Heatmap toggle --%>
            <div class="bg-[#242424] border border-[#333] rounded-lg px-4 py-3 mb-3">
              <p class="text-xs font-semibold text-[#888] uppercase tracking-widest mb-2">Heatmap</p>
              <div
                id="heatmap-toggle"
                class="flex rounded overflow-hidden border border-[#444]"
                data-state={if @image_set == :heatmap_on, do: "on", else: "off"}
              >
                <button
                  id="heatmap-btn-off"
                  phx-click="heatmap_off"
                  class={[
                    "flex-1 py-2 text-sm font-medium transition-colors duration-150",
                    if(@image_set != :heatmap_on,
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
                    if(@image_set == :heatmap_on,
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
                @image_set == :heatmap_on && "opacity-40 pointer-events-none"
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
              <%= if @image_set == :heatmap_on do %>
                <p class="text-xs text-[#555] mt-1">To adjust FOV, turn the heatmap OFF first.</p>
              <% end %>
            </div>

            <%!-- Spacer to push Next button to the bottom --%>
            <div class="flex-1" />

            <%!-- Next button — pinned to bottom --%>
            <button
              id="next-btn"
              phx-click="next"
              disabled={@auto_exposure_running}
              class={[
                "w-full py-2.5 rounded text-sm font-medium transition-colors duration-150",
                if(@auto_exposure_running,
                  do: "bg-[#333] text-[#555] cursor-not-allowed",
                  else: "bg-blue-600 hover:bg-blue-700 text-white"
                )
              ]}
            >
              <%= if @auto_exposure_running do %>
                Running...
              <% else %>
                Next
              <% end %>
            </button>
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
