defmodule CalibrationApp.PythonBridge do
  @moduledoc """
  Calls Python scripts via Elixir Port (stdin/stdout JSON protocol).
  The Port is opened per-call (one-shot). Elixir writes one JSON line to stdin,
  reads one JSON response line from stdout, then closes the Port (EOF to Python).

  Protocol:
    send:    {"image_path": "<absolute_path>"}\\n
    receive: {"result_path": "<absolute_path>"}\\n

  To replace the dummy algo with a real one, only edit python/heatmap/algo.py.
  This module and the protocol remain unchanged.
  """

  @doc """
  Runs the heatmap Python script on the given image path.
  Returns `{:ok, result_path}` where `result_path` is the processed image path,
  or `{:error, reason}` on failure.
  """
  @spec run_heatmap(image_path :: String.t()) :: {:ok, String.t()} | {:error, term()}
  def run_heatmap(image_path) do
    run_heatmap_with_script(wrapper_script(), image_path)
  end

  @doc false
  # Public only for testing the error branch with a custom script path.
  @spec run_heatmap_with_script(script_path :: String.t(), image_path :: String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def run_heatmap_with_script(script_path, image_path) do
    payload = Jason.encode!(%{image_path: image_path}) <> "\n"

    port =
      Port.open({:spawn_executable, System.find_executable("python3")}, [
        :binary,
        :use_stdio,
        :exit_status,
        {:args, [script_path]}
      ])

    Port.command(port, payload)
    collect_port_output(port, "")
  rescue
    e -> {:error, {:exception, Exception.message(e)}}
  end

  # ── Private ─────────────────────────────────────────────────────────────────

  defp collect_port_output(port, acc) do
    receive do
      {^port, {:data, data}} ->
        collect_port_output(port, acc <> data)

      {^port, {:exit_status, 0}} ->
        parse_response(acc)

      {^port, {:exit_status, code}} ->
        {:error, {:python_exit, code}}
    after
      5000 ->
        Port.close(port)
        {:error, :timeout}
    end
  end

  defp parse_response(output) do
    output
    |> String.trim()
    |> Jason.decode()
    |> case do
      {:ok, %{"result_path" => path}} when is_binary(path) ->
        {:ok, path}

      {:ok, other} ->
        {:error, {:unexpected_response, other}}

      {:error, reason} ->
        {:error, {:json_decode, reason}}
    end
  end

  # Resolves the wrapper script path using the app's priv directory.
  defp wrapper_script do
    :code.priv_dir(:calibration_app)
    |> List.to_string()
    |> Path.join("python/heatmap/wrapper.py")
  end
end
