defmodule CalibrationAppWeb.FreeRotationLiveTest do
  use CalibrationAppWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias CalibrationApp.FreeRotationServer

  setup do
    FreeRotationServer.stop_rotation()
    :ok
  end

  test "mounts and renders the camera feed area", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/free-rotation")
    assert has_element?(view, "#camera-feed")
  end

  test "renders the step progress bar with Free Rotation active", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/free-rotation")
    assert has_element?(view, "#step-bar")
    assert has_element?(view, "#step-free-rotation.step-active")
  end

  test "renders the instructions card", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/free-rotation")
    assert has_element?(view, "#instructions-card")
  end

  test "renders the toggle button with label Start initially", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/free-rotation")
    assert has_element?(view, "#rotation-toggle-btn")
    assert render(view) =~ "Start"
  end

  test "toggle button shows Start (green) when not rotating", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/free-rotation")
    assert has_element?(view, "#rotation-toggle-btn.bg-green-600")
  end

  test "clicking toggle starts rotation and button changes to Stop", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/free-rotation")
    view |> element("#rotation-toggle-btn") |> render_click()
    assert has_element?(view, "#rotation-toggle-btn.bg-red-600")
    assert render(view) =~ "Stop"
  end

  test "clicking toggle again stops rotation and button changes back to Start", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/free-rotation")
    view |> element("#rotation-toggle-btn") |> render_click()
    view |> element("#rotation-toggle-btn") |> render_click()
    assert has_element?(view, "#rotation-toggle-btn.bg-green-600")
    assert render(view) =~ "Start"
  end

  test "renders the exposure indicator", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/free-rotation")
    assert has_element?(view, "#exposure-indicator")
  end

  test "renders the stage position indicator", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/free-rotation")
    assert has_element?(view, "#position-indicator")
  end

  test "receives image_update PubSub message and updates image", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/free-rotation")
    dummy = "data:image/png;base64,abc123"
    send(view.pid, {:image_update, dummy})
    html = render(view)
    assert html =~ dummy
  end
end
