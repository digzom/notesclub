defmodule NotesclubWeb.StatusController do
  use NotesclubWeb, :controller

  alias Notesclub.Searches.StatusCheck
  def ok(conn, _params), do: text(conn, "OK")

  def status(conn, _params) do
    StatusCheck.check()
  end
end
