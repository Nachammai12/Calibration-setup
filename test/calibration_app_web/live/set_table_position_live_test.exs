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

    test "clicking Stop re-enables coarse/fine button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      view |> element("#free-rotation-btn") |> render_click()
      view |> element("#free-rotation-btn") |> render_click()

      refute has_element?(view, "#coarse-fine-btn[disabled]")
    end
  end

  describe "coarse/fine rotation toggle" do
    test "clicking Start changes button to Stop", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      view |> element("#coarse-fine-btn") |> render_click()

      assert has_element?(view, "#coarse-fine-btn", "Stop")
    end

    test "clicking Start disables free rotation button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      view |> element("#coarse-fine-btn") |> render_click()

      assert has_element?(view, "#free-rotation-btn[disabled]")
    end

    test "outputs update after coarse+fine complete", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      view |> element("#coarse-fine-btn") |> render_click()

      # Wait for coarse (3s) + fine (2s) + buffer
      Process.sleep(6_000)
      render(view)

      refute has_element?(view, "#encoder-value", "—")
      refute has_element?(view, "#cube-gauge-width", "—")
    end
  end

  describe "mutual exclusion" do
    test "free rotation button is disabled while coarse/fine is active", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      view |> element("#coarse-fine-btn") |> render_click()

      assert has_element?(view, "#free-rotation-btn[disabled]")
    end

    test "coarse/fine button is disabled while free rotation is active", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/set-table-position")

      view |> element("#free-rotation-btn") |> render_click()

      assert has_element?(view, "#coarse-fine-btn[disabled]")
    end
  end
end
