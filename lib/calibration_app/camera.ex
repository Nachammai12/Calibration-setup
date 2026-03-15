defmodule CalibrationApp.Camera do
  @moduledoc """
  Reads a camera frame from disk and returns it as a base64 data-URI.
  This is the single point of contact with the image source. Later, replace
  `get_frame/1` internals to call a real camera SDK — the return type stays the same.
  """

  @doc """
  Reads the image at `image_path` and encodes it as a base64 data-URI string.
  Returns `{:ok, "data:image/png;base64,..."}` or `{:error, :not_found}`.
  """
  @spec get_frame(image_path :: String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def get_frame(image_path) do
    case File.read(image_path) do
      {:ok, data} ->
        ext = image_path |> Path.extname() |> String.downcase() |> String.trim_leading(".")
        mime = if ext in ["jpg", "jpeg"], do: "image/jpeg", else: "image/#{ext}"
        {:ok, "data:#{mime};base64,#{Base.encode64(data)}"}

      {:error, _} ->
        {:error, :not_found}
    end
  end
end
