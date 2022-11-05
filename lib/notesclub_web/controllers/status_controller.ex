defmodule NotesclubWeb.StatusController do
  use NotesclubWeb, :controller

  def ok(conn, _params), do: text(conn, "OK")

  def status(conn, _params) do
    check
  end
end
