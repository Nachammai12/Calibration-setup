defmodule CalibrationAppWeb.SetTablePositionLiveTest do
  use CalibrationAppWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    # Ensure FreeRotationServer is stopped before each test to prevent state leakage
    CalibrationApp.FreeRotationServer.stop_rotation()
    :ok
  end

  describe "mount" do
    test "renders the page with all three sections", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      assert has_element?(view, "#free-rotation-section")
      assert has_element?(view, "#coarse-fine-section")
      assert has_element?(view, "#outputs-section")
    end

    test "free rotation button starts as Start", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      assert has_element?(view, "#free-rotation-btn", "Start")
    end

    test "coarse/fine button starts as Start", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      assert has_element?(view, "#coarse-fine-btn", "Start")
    end

    test "outputs show dash when no rotation has run", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      assert has_element?(view, "#encoder-value", "—")
      assert has_element?(view, "#cube-gauge-width", "—")
    end
  end

  describe "free rotation toggle" do
    test "clicking Start changes button to Stop", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      view |> element("#free-rotation-btn") |> render_click()

      assert has_element?(view, "#free-rotation-btn", "Stop")
    end

    test "clicking Start disables coarse/fine button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      view |> element("#free-rotation-btn") |> render_click()

      assert has_element?(view, "#coarse-fine-btn[disabled]")
    end

    test "clicking Stop re-enables coarse/fine button (default scan angle is set)", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      view |> element("#free-rotation-btn") |> render_click()
      view |> element("#free-rotation-btn") |> render_click()

      # scan_angle defaults to "10", so button is re-enabled after stopping free rotation
      refute has_element?(view, "#coarse-fine-btn[disabled]")
    end

    test "clicking Stop re-enables coarse/fine button when scan angle is set", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      view
      |> element("#scan-angle-form")
      |> render_change(%{"value" => "45"})

      view |> element("#free-rotation-btn") |> render_click()
      view |> element("#free-rotation-btn") |> render_click()

      refute has_element?(view, "#coarse-fine-btn[disabled]")
    end
  end

  describe "coarse/fine rotation toggle" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      # Enter a scan angle so the coarse/fine button is enabled
      view |> element("#scan-angle-form") |> render_change(%{"value" => "45"})

      {:ok, view: view}
    end

    test "clicking Start changes button to Stop", %{view: view} do
      view |> element("#coarse-fine-btn") |> render_click()

      assert has_element?(view, "#coarse-fine-btn", "Stop")
    end

    test "clicking Start disables free rotation button", %{view: view} do
      view |> element("#coarse-fine-btn") |> render_click()

      assert has_element?(view, "#free-rotation-btn[disabled]")
    end

    test "outputs update after coarse+fine complete", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")
      view |> element("#scan-angle-form") |> render_change(%{"value" => "45"})
      view |> element("#coarse-fine-btn") |> render_click()

      # Wait for coarse (3s) + fine (2s) + buffer
      Process.sleep(6_000)
      render(view)

      refute has_element?(view, "#encoder-value", "—")
      refute has_element?(view, "#cube-gauge-width", "—")
    end

    test "stage position indicator updates to encoder value after coarse+fine complete", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")
      view |> element("#scan-angle-form") |> render_change(%{"value" => "45"})
      view |> element("#coarse-fine-btn") |> render_click()

      # Wait for coarse (3s) + fine (2s) + buffer
      Process.sleep(6_000)
      render(view)

      # Stage position in the status bar must no longer show the default "0.00 mm"
      refute has_element?(view, "#position-indicator", "0.00 mm")
      # And the position-indicator must match the encoder value shown in outputs
      encoder_html = view |> element("#encoder-value") |> render()
      position_html = view |> element("#position-indicator") |> render()
      assert String.contains?(position_html, Regex.run(~r/[\d.]+/, encoder_html) |> List.first())
    end
  end

  describe "mutual exclusion" do
    test "free rotation button is disabled while coarse/fine is active", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")
      view |> element("#scan-angle-form") |> render_change(%{"value" => "45"})
      view |> element("#coarse-fine-btn") |> render_click()

      assert has_element?(view, "#free-rotation-btn[disabled]")
    end

    test "coarse/fine button is disabled while free rotation is active", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      view |> element("#free-rotation-btn") |> render_click()

      assert has_element?(view, "#coarse-fine-btn[disabled]")
    end
  end

  describe "free rotation description" do
    test "shows updated technical description", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      assert has_element?(
               view,
               "#free-rotation-description",
               "Use Free Rotation to manually align the table axis parallel to the optical lens and illumination source before Coarse/Fine."
             )
    end
  end

  describe "coarse/fine scan angle validation" do
    test "coarse/fine start button is enabled by default (default scan angle is 10)", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      # scan_angle defaults to "10", so button is enabled on mount
      refute has_element?(view, "#coarse-fine-btn[disabled]")
    end

    test "coarse/fine start button is enabled after entering a scan angle", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      view
      |> element("#scan-angle-form")
      |> render_change(%{"value" => "45"})

      refute has_element?(view, "#coarse-fine-btn[disabled]")
    end

    test "coarse/fine start button shows tooltip when disabled due to empty scan angle", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      # Clear the scan angle to trigger the disabled+tooltip state
      view |> element("#scan-angle-form") |> render_change(%{"value" => ""})

      html = render(view)
      assert html =~ "Enter a scan angle to start"
    end
  end

  describe "navigation locking during rotation" do
    test "previous and next buttons are disabled while free rotation is active", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      view |> element("#free-rotation-btn") |> render_click()

      assert has_element?(view, "#prev-btn[disabled]")
      assert has_element?(view, "#next-btn[disabled]")
    end

    test "previous and next buttons are disabled while coarse/fine is active", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      view
      |> element("#scan-angle-form")
      |> render_change(%{"value" => "45"})

      view |> element("#coarse-fine-btn") |> render_click()

      assert has_element?(view, "#prev-btn[disabled]")
      assert has_element?(view, "#next-btn[disabled]")
    end

    test "previous and next buttons show tooltip during active rotation", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      view |> element("#free-rotation-btn") |> render_click()

      html = render(view)
      assert html =~ "Stop the rotation before navigating"
    end

    test "previous and next buttons are enabled when no rotation is active", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      refute has_element?(view, "#prev-btn[disabled]")
      refute has_element?(view, "#next-btn[disabled]")
    end

    test "go_previous is blocked while rotation is active", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      view |> element("#free-rotation-btn") |> render_click()

      # Button is disabled so server never receives the event — render stays on same page
      html = render(view)
      assert html =~ "Set Table Position"
      assert has_element?(view, "#prev-btn[disabled]")
    end

    test "go_next is blocked while rotation is active", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      view |> element("#free-rotation-btn") |> render_click()

      html = render(view)
      assert html =~ "Set Table Position"
      assert has_element?(view, "#next-btn[disabled]")
    end
  end
end
