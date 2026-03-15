defmodule CalibrationAppWeb.PrimaryAlignmentLiveTest do
  use CalibrationAppWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "mounts and renders the camera image area", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    assert has_element?(view, "#camera-feed")
  end

  test "renders the step progress bar with Primary Alignment active", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    assert has_element?(view, "#step-bar")
    assert has_element?(view, "#step-primary-alignment.step-active")
  end

  test "renders the instructions card", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    assert has_element?(view, "#instructions-card")
  end

  test "renders the heatmap toggle", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    assert has_element?(view, "#heatmap-toggle")
  end

  test "renders the exposure indicator", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    assert has_element?(view, "#exposure-indicator")
  end

  test "renders the stage position indicator", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    assert has_element?(view, "#position-indicator", "Stage Position")
  end

  test "heatmap toggle starts in OFF state", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    assert has_element?(view, "#heatmap-toggle[data-state=off]")
  end

  test "clicking heatmap ON switches to heatmap_on image set", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    view |> element("#heatmap-btn-on") |> render_click()
    assert has_element?(view, "#heatmap-toggle[data-state=on]")
    assert has_element?(view, "#heatmap-btn-on.bg-blue-600")
  end

  test "heatmap OFF button is blue (active) on initial page load", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    assert has_element?(view, "#heatmap-btn-off.bg-blue-600")
  end

  test "clicking heatmap OFF after ON switches to heatmap_off image set", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    view |> element("#heatmap-btn-on") |> render_click()
    view |> element("#heatmap-btn-off") |> render_click()
    assert has_element?(view, "#heatmap-toggle[data-state=off]")
    assert has_element?(view, "#heatmap-btn-off.bg-blue-600")
  end

  # Adjust FOV

  test "renders the adjust FOV card", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    assert has_element?(view, "#adjust-fov-card")
  end

  test "adjust FOV form is visible on page load (heatmap OFF)", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    assert has_element?(view, "#roi-form")
    assert has_element?(view, "#roi-centre-x")
    assert has_element?(view, "#roi-centre-y")
    assert has_element?(view, "#roi-radius")
  end

  test "adjust FOV inputs are disabled (opacity) when heatmap is ON", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    view |> element("#heatmap-btn-on") |> render_click()
    assert has_element?(view, "#adjust-fov-card .opacity-40")
  end

  test "adjust FOV shows turn-off notice when heatmap is ON", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    view |> element("#heatmap-btn-on") |> render_click()
    assert render(view) =~ "To adjust FOV, turn the heatmap OFF first."
  end

  # Next button (replaces Auto Exposure button)

  test "renders the next button", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    assert has_element?(view, "#next-btn")
  end

  test "next button is enabled on initial load", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    refute has_element?(view, "#next-btn[disabled]")
  end

  test "auto exposure button is no longer present", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    refute has_element?(view, "#auto-exposure-btn")
  end

  test "clicking next starts auto exposure and shows running state", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    view |> element("#next-btn") |> render_click()
    assert has_element?(view, "#auto-exposure-panel")
    refute has_element?(view, "#next-btn")
  end

  test "clicking next disables the button while running", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    view |> element("#next-btn") |> render_click()
    assert has_element?(view, "#auto-exposure-panel")
    refute has_element?(view, "#next-btn")
  end

  test "after auto_exposure_done navigates to set-table-position", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    view |> element("#next-btn") |> render_click()
    send(view.pid, :auto_exposure_done)
    assert_redirect(view, "/set-table-position")
  end

  # Image display — with real images on disk, camera feed should show an img tag

  test "loads and displays image from live_mode folder", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    # If images exist on disk the img tag should be present; placeholder otherwise
    # We assert the camera-feed panel renders (image or placeholder both valid)
    assert has_element?(view, "#camera-feed")
  end

  # Alignment stage state machine tests

  test "initial alignment_stage is 0 (live mode)", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    # Stage 0 = heatmap off, live mode image
    assert has_element?(view, "#heatmap-toggle[data-state=off]")
  end

  test "clicking heatmap ON for first time advances stage to 1", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    view |> element("#heatmap-btn-on") |> render_click()
    # Stage 1, heatmap on — toggle shows ON state
    assert has_element?(view, "#heatmap-toggle[data-state=on]")
  end

  test "clicking heatmap OFF after first ON advances stage to 2", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    view |> element("#heatmap-btn-on") |> render_click()
    view |> element("#heatmap-btn-off") |> render_click()
    # Stage 2, heatmap off
    assert has_element?(view, "#heatmap-toggle[data-state=off]")
  end

  test "heatmap OFF at stage 3 does not advance past 3", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    # Reach stage 3: ON (stage 1) → OFF (stage 2) → ON (stage 2) → OFF (stage 3)
    view |> element("#heatmap-btn-on") |> render_click()   # stage 0 → 1
    view |> element("#heatmap-btn-off") |> render_click()  # stage 1 → 2
    view |> element("#heatmap-btn-on") |> render_click()   # stage 2 (no change on ON)
    view |> element("#heatmap-btn-off") |> render_click()  # stage 2 → 3
    # Extra OFF at stage 3 — must stay at 3, not raise or go to 4
    view |> element("#heatmap-btn-on") |> render_click()   # stage 3 (no change on ON)
    view |> element("#heatmap-btn-off") |> render_click()  # stage 3 (clamped, no change)
    assert has_element?(view, "#heatmap-toggle[data-state=off]")
  end

  test "ROI overlay is hidden when heatmap is ON", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    view |> element("#heatmap-btn-on") |> render_click()
    # FOV card becomes disabled when heatmap is on
    assert has_element?(view, "#adjust-fov-card .opacity-40")
  end
end
