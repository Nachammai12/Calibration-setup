defmodule CalibrationAppWeb.ResultLive do
  use CalibrationAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Result")
      |> assign(:encoder_value, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"encoder" => raw}, _uri, socket) do
    encoder =
      case Float.parse(raw) do
        {val, _} -> val
        :error -> nil
      end

    {:noreply, assign(socket, :encoder_value, encoder)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("finish", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/primary-alignment")}
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
            <span class="text-[#555]">Set Table Position</span>
            <span class="text-[#333]">──────</span>
            <span id="step-result" class="text-white font-bold">Result</span>
          </div>

          <div class="w-40" />
        </div>

        <%!-- Main content: single centered card --%>
        <div class="flex-1 flex items-center justify-center bg-[#0f0f0f] p-6 overflow-hidden">
          <div
            id="result-card"
            class="w-full max-w-md flex flex-col items-center gap-6 p-10 rounded-xl border border-[#2a2a2a] bg-[#141414]"
          >
            <%!-- Success icon ring --%>
            <div class="w-20 h-20 rounded-full border-2 border-green-700 bg-green-950 flex items-center justify-center">
              <.icon name="hero-check" class="w-9 h-9 text-green-400" />
            </div>

            <%!-- Title + subtitle --%>
            <div class="flex flex-col items-center gap-2 text-center">
              <p id="result-line-1" class="text-2xl font-semibold text-white tracking-tight">
                Calibration Setup Completed
              </p>
              <p id="result-line-2" class="text-sm text-[#888] leading-relaxed">
                The machine is ready for calibration now
              </p>
            </div>

            <%!-- Divider --%>
            <div class="w-full h-px bg-[#2a2a2a]" />

            <%!-- Calibration Summary --%>
            <div id="result-summary" class="w-full flex flex-col gap-3">
              <p class="text-xs font-semibold text-[#888] uppercase tracking-widest">
                Calibration Summary
              </p>
              <div class="flex flex-col gap-2">
                <div id="summary-primary-alignment" class="flex items-center justify-between">
                  <span class="text-xs text-[#888]">Primary Alignment</span>
                  <span class="flex items-center gap-1 text-xs text-green-400 font-medium">
                    <.icon name="hero-check-circle" class="w-3.5 h-3.5" /> Done
                  </span>
                </div>
                <div class="w-full h-px bg-[#2a2a2a]" />
                <div id="summary-set-table-position" class="flex items-center justify-between">
                  <span class="text-xs text-[#888]">Set Table Position</span>
                  <span class="flex items-center gap-1 text-xs text-green-400 font-medium">
                    <.icon name="hero-check-circle" class="w-3.5 h-3.5" /> Done
                  </span>
                </div>
                <div class="w-full h-px bg-[#2a2a2a]" />
                <div id="summary-home-position-set" class="flex items-center justify-between">
                  <span class="text-xs text-[#888]">Home Position Set</span>
                  <span class="flex items-center gap-1 text-xs text-green-400 font-medium">
                    <.icon name="hero-check-circle" class="w-3.5 h-3.5" /> Done
                  </span>
                </div>
                <div class="w-full h-px bg-[#2a2a2a]" />
                <div id="summary-finalized-position" class="flex items-center justify-between">
                  <span class="text-xs text-[#888]">Finalized Home Position</span>
                  <span class="text-xs font-mono text-[#d1d1d1]">
                    {if @encoder_value, do: @encoder_value, else: "—"}
                  </span>
                </div>
              </div>
            </div>

            <%!-- Action button --%>
            <button
              id="finish-btn"
              phx-click="finish"
              class="w-full py-2.5 rounded text-sm font-medium bg-[#242424] hover:bg-[#2e2e2e] text-[#d1d1d1] border border-[#333] transition-colors duration-150"
            >
              New Calibration Setup
            </button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
