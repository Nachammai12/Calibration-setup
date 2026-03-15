defmodule CalibrationAppWeb.ResultLiveTest do
  use CalibrationAppWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "result page content" do
    test "shows 'Calibration Setup Completed' as primary heading", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/result")

      assert has_element?(view, "#result-line-1", "Calibration Setup Completed")
    end

    test "shows 'The machine is ready for calibration now' as subtitle", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/result")

      assert has_element?(view, "#result-line-2", "The machine is ready for calibration now")
    end

    test "result card is present", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/result")

      assert has_element?(view, "#result-card")
    end

    test "no right-side control panel — layout is single centered card", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/result")

      # The old layout had a separate right panel with a summary card inside it.
      # Now there is only one card — #result-card — and no separate panel wrapper.
      refute has_element?(view, "#result-card + div")
    end

    test "does not show inline 'Finalized home position is' text above summary", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/result")

      refute html =~ "result-line-3"
    end
  end

  describe "calibration summary" do
    test "shows calibration summary section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/result")

      assert has_element?(view, "#result-summary")
    end

    test "summary shows Primary Alignment as Done", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/result")

      assert has_element?(view, "#summary-primary-alignment")
      assert view |> element("#summary-primary-alignment") |> render() =~ "Done"
    end

    test "summary shows Set Table Position as Done", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/result")

      assert has_element?(view, "#summary-set-table-position")
      assert view |> element("#summary-set-table-position") |> render() =~ "Done"
    end

    test "summary shows Home Position Set as Done", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/result")

      assert has_element?(view, "#summary-home-position-set")
      assert view |> element("#summary-home-position-set") |> render() =~ "Done"
    end

    test "summary shows Finalized Home Position row with dash when no encoder", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/result")

      assert has_element?(view, "#summary-finalized-position")
      assert view |> element("#summary-finalized-position") |> render() =~ "—"
    end

    test "summary shows encoder value in Finalized Home Position when provided", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/result?encoder=142.37")

      assert has_element?(view, "#summary-finalized-position")
      assert view |> element("#summary-finalized-position") |> render() =~ "142.37"
    end

    test "summary does not show a separate Encoder Value row", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/result")

      refute html =~ "result-encoder-value"
    end
  end

  describe "navigation" do
    test "finish button is present and labelled 'New Calibration Setup'", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/result")

      assert has_element?(view, "#finish-btn", "New Calibration Setup")
    end

    test "finish button navigates to primary alignment", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/result")

      {:ok, _view, _html} =
        view |> element("#finish-btn") |> render_click() |> follow_redirect(conn)
    end
  end
end
