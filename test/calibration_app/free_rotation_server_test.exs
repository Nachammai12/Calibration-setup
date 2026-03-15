defmodule CalibrationApp.FreeRotationServerTest do
  use ExUnit.Case, async: false

  alias CalibrationApp.FreeRotationServer

  setup do
    # Start a fresh isolated server for each test (not the app-level named one)
    {:ok, pid} = start_supervised({FreeRotationServer, name: nil})
    %{pid: pid}
  end

  test "initial state: not rotating", %{pid: pid} do
    state = FreeRotationServer.get_state(pid)
    assert state.rotating == false

    # current_image_data is loaded on init via handle_continue; may be a binary or nil depending on env
    assert is_nil(state.current_image_data) or is_binary(state.current_image_data)
  end

  test "start_rotation sets rotating to true", %{pid: pid} do
    FreeRotationServer.start_rotation(pid)
    state = FreeRotationServer.get_state(pid)
    assert state.rotating == true
  end

  test "stop_rotation sets rotating to false", %{pid: pid} do
    FreeRotationServer.start_rotation(pid)
    FreeRotationServer.stop_rotation(pid)
    state = FreeRotationServer.get_state(pid)
    assert state.rotating == false
  end

  test "stop_rotation when already stopped is a no-op", %{pid: pid} do
    FreeRotationServer.stop_rotation(pid)
    state = FreeRotationServer.get_state(pid)
    assert state.rotating == false
  end
end
