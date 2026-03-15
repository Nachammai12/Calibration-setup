defmodule CalibrationApp.CameraTest do
  use ExUnit.Case, async: true
  alias CalibrationApp.Camera

  @test_image_path Path.join([
                     :code.priv_dir(:calibration_app) |> List.to_string(),
                     "static",
                     "images",
                     "primary_alignment",
                     "live_mode",
                     "1-angular_more.png"
                   ])

  test "get_frame/1 returns {:ok, data_uri} for a real image" do
    assert {:ok, data} = Camera.get_frame(@test_image_path)
    assert String.starts_with?(data, "data:image/png;base64,")
  end

  test "get_frame/1 returns {:error, :not_found} for a missing path" do
    assert {:error, :not_found} = Camera.get_frame("/does/not/exist.png")
  end

  test "get_frame/1 handles jpg extension" do
    tmp = System.tmp_dir!() |> Path.join("test_cam.jpg")
    File.write!(tmp, <<0xFF, 0xD8, 0xFF>>)
    assert {:ok, data} = Camera.get_frame(tmp)
    assert String.starts_with?(data, "data:image/jpeg;base64,")
    File.rm!(tmp)
  end
end
