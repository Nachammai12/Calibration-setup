defmodule CalibrationAppWeb.PageController do
  use CalibrationAppWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
