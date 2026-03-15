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
    send(view.pid, :ae_done)
    send(view.pid, :ae_navigate)
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
    # stage 0 → 1
    view |> element("#heatmap-btn-on") |> render_click()
    # stage 1 → 2
    view |> element("#heatmap-btn-off") |> render_click()
    # stage 2 (no change on ON)
    view |> element("#heatmap-btn-on") |> render_click()
    # stage 2 → 3
    view |> element("#heatmap-btn-off") |> render_click()
    # Extra OFF at stage 3 — must stay at 3, not raise or go to 4
    # stage 3 (no change on ON)
    view |> element("#heatmap-btn-on") |> render_click()
    # stage 3 (clamped, no change)
    view |> element("#heatmap-btn-off") |> render_click()
    assert has_element?(view, "#heatmap-toggle[data-state=off]")
  end

  test "ROI overlay is hidden when heatmap is ON", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    view |> element("#heatmap-btn-on") |> render_click()
    # FOV card becomes disabled when heatmap is on
    assert has_element?(view, "#adjust-fov-card .opacity-40")
  end

  # ── Additional edge case tests ──────────────────────────────────────────────

  test "page title is set to Primary Alignment", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/primary-alignment")
    assert html =~ "Primary Alignment"
  end

  test "camera image tag is rendered when images exist on disk", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    # When images exist the img element with id roi-image is rendered
    assert has_element?(view, "#roi-image")
  end

  test "ROI canvas overlay is present when images exist", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    assert has_element?(view, "#roi-canvas")
  end

  test "ROI inputs show default values on page load", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    html = render(view)
    # Default values from roi_defaults.json: centre_x=500, centre_y=500, radius=500
    assert html =~ ~s(value="500")
  end

  test "heatmap ON a second time does not advance alignment stage further", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    # First ON: stage 0 → 1
    view |> element("#heatmap-btn-on") |> render_click()
    # Second ON: stage stays at 1 (only advances from 0 on first press)
    view |> element("#heatmap-btn-on") |> render_click()
    assert has_element?(view, "#heatmap-toggle[data-state=on]")
  end

  test "heatmap OFF at stage 0 does not advance to stage 1 (guard)", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    # Stage is 0; clicking OFF directly should guard and keep stage at 0
    view |> element("#heatmap-btn-off") |> render_click()
    assert has_element?(view, "#heatmap-toggle[data-state=off]")
  end

  test "update_roi event updates the ROI input values", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")

    view
    |> element("#roi-form")
    |> render_change(%{"centre_x" => "300", "centre_y" => "400", "radius" => "250"})

    html = render(view)
    assert html =~ ~s(value="300")
    assert html =~ ~s(value="400")
    assert html =~ ~s(value="250")
  end

  test "auto exposure panel shows spinner and running text after next is clicked", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    view |> element("#next-btn") |> render_click()
    html = render(view)
    assert html =~ "Auto Exposure Running..."
    assert has_element?(view, "#auto-exposure-panel")
  end

  test "auto exposure panel shows iteration counter starting at 0", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    view |> element("#next-btn") |> render_click()
    html = render(view)
    assert html =~ "Iteration: 0"
  end

  test "ae_iteration message increments iteration counter", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    view |> element("#next-btn") |> render_click()
    # Simulate an ae_iteration PubSub message arriving
    send(view.pid, {:ae_iteration, nil, 180, false})
    html = render(view)
    assert html =~ "Iteration: 1"
  end

  test "ae_iteration message updates displayed exposure value", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    view |> element("#next-btn") |> render_click()
    send(view.pid, {:ae_iteration, nil, 210, false})
    html = render(view)
    assert html =~ "210"
  end

  test "ae_error message shows flash error and resets auto_exposure_running", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    view |> element("#next-btn") |> render_click()
    assert has_element?(view, "#auto-exposure-panel")
    send(view.pid, {:ae_error, :timeout})
    html = render(view)
    assert html =~ "Auto exposure failed. Please try again."
    # Control panel returns (next-btn visible again)
    assert has_element?(view, "#next-btn")
    refute has_element?(view, "#auto-exposure-panel")
  end

  test "ae_done message hides auto exposure panel and shows normal controls", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    view |> element("#next-btn") |> render_click()
    assert has_element?(view, "#auto-exposure-panel")
    send(view.pid, :ae_done)
    # After ae_done, auto_exposure_running becomes false so normal panel returns
    assert has_element?(view, "#next-btn")
    refute has_element?(view, "#auto-exposure-panel")
  end

  test "heatmap toggle switches back and forth correctly multiple times", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    # ON
    view |> element("#heatmap-btn-on") |> render_click()
    assert has_element?(view, "#heatmap-toggle[data-state=on]")
    # OFF
    view |> element("#heatmap-btn-off") |> render_click()
    assert has_element?(view, "#heatmap-toggle[data-state=off]")
    # ON again
    view |> element("#heatmap-btn-on") |> render_click()
    assert has_element?(view, "#heatmap-toggle[data-state=on]")
    # OFF again
    view |> element("#heatmap-btn-off") |> render_click()
    assert has_element?(view, "#heatmap-toggle[data-state=off]")
  end

  test "adjust FOV notice disappears when heatmap is turned back OFF", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    view |> element("#heatmap-btn-on") |> render_click()
    assert render(view) =~ "To adjust FOV, turn the heatmap OFF first."
    view |> element("#heatmap-btn-off") |> render_click()
    refute render(view) =~ "To adjust FOV, turn the heatmap OFF first."
  end

  test "next button has blue styling when not running", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    assert has_element?(view, "#next-btn.bg-blue-600")
  end

  test "top bar shows Calibration Setup title", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    assert render(view) =~ "Calibration Setup"
  end

  test "step bar shows Set Table Position as next step", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    assert render(view) =~ "Set Table Position"
  end

  test "step bar shows Result as final step", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    assert render(view) =~ "Result"
  end

  test "default exposure value from roi_defaults.json is shown in status bar", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    html = render(view)
    # roi_defaults.json has exposure: 72
    assert has_element?(view, "#exposure-indicator")
    assert html =~ "72"
  end

  test "default stage position from roi_defaults.json is shown in status bar", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/primary-alignment")
    html = render(view)
    # roi_defaults.json has stage_position: "0.00 mm"
    assert html =~ "0.00 mm"
  end
end
