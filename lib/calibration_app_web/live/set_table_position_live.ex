defmodule CalibrationAppWeb.SetTablePositionLive do
  use CalibrationAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Set Table Position")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="fixed inset-0 bg-[#0f0f0f] text-[#d1d1d1] flex flex-col overflow-hidden">
        <%!-- Top bar --%>
        <div class="flex items-center justify-between px-6 py-3 bg-[#1a1a1a] border-b border-[#2a2a2a]">
          <span class="text-white font-semibold tracking-wide text-sm">Calibration App</span>

          <%!-- Step progress bar --%>
          <div id="step-bar" class="flex items-center gap-3 text-xs font-medium">
            <span class="text-[#555]">Primary Alignment</span>
            <span class="text-[#333]">──────</span>
            <span
              id="step-set-table-position"
              class="step-active text-white font-bold"
            >
              Set Table Position
            </span>
            <span class="text-[#333]">──────</span>
            <span class="text-[#555]">Result</span>
          </div>

          <div class="w-40" />
        </div>

        <%!-- Placeholder content --%>
        <div class="flex flex-1 items-center justify-center">
          <p class="text-[#555] text-sm">Set Table Position — coming soon</p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
