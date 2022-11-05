defmodule Notesclub.Searches.StatusCheck do
  import Ecto.Query
  alias Notesclub.Repo

  def query_last_inserted_notebooks do
    query =
      from n in "notebooks",
        where: n.inserted_at > fragment("current_date - interval '49 hours'"),
        select: [:inserted_at]

    check(Repo.all(query))
  end

  def check([]) do
    # fazer a query para buscar o ultimo
    {:error}
  end

  def check(_repos) do
    # retornar o retorno esperado
  end
end
