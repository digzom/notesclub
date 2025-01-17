defmodule Notesclub.Notebooks do
  @moduledoc """
  The Notebooks context.
  """

  import Ecto.Query, warn: false
  alias Notesclub.Repo

  alias Notesclub.Notebooks.Notebook
  alias Notesclub.Repos
  alias Notesclub.Accounts
  alias Notesclub.Accounts.User
  alias Notesclub.Repos.Repo, as: RepoSchema
  alias Notesclub.Notebooks
  alias Notesclub.Notebooks.Urls

  alias Notesclub.Workers.UrlContentSyncWorker

  require Logger

  @doc """
  Returns the list of notebooks.

  ## Examples

      iex> list_notebooks()
      [%Notebook{}, ...]

  """
  @spec list_notebooks(any) :: [%Notebook{}]
  def list_notebooks(opts \\ []) do
    Enum.reduce(opts, from(n in Notebook), fn
      {:order, :desc}, query ->
        order_by(query, [notebook], -notebook.id)

      {:github_filename, github_filename}, query ->
        search = "%#{github_filename}%"
        where(query, [notebook], ilike(notebook.github_filename, ^search))

      {:content, content}, query ->
        search = "%#{content}%"
        where(query, [notebook], ilike(notebook.content, ^search))

      {:exclude_ids, exclude_ids}, query ->
        where(query, [notebook], notebook.id not in ^exclude_ids)

      {:repo_id, repo_id}, query ->
        where(query, [notebook], notebook.repo_id == ^repo_id)

      _, query ->
        query
    end)
    |> Repo.all()
  end

  @spec list_notebooks_since(integer()) :: [%Notebook{}]
  def list_notebooks_since(num_days_ago) when is_integer(num_days_ago) do
    from(n in Notebook,
      where: n.inserted_at >= from_now(-(^num_days_ago), "day"),
      order_by: -n.id
    )
    |> Repo.all()
  end

  @doc """
  Resets the repo's notebooks url depending on notebook.github_html_url and repo.default_branch

  ## Examples

      iex> enqueue_url_and_content_sync(%Repo{id: 1})
      {:ok, %{"notebook_1" =>  %Notesclub.Notebooks.Notebook{...}, ...}}

  """
  @spec enqueue_url_and_content_sync(%RepoSchema{}) ::
          {:ok, %{binary => %Notebook{}}} | {:error, %{binary => %Ecto.Changeset{}}}
  def enqueue_url_and_content_sync(%RepoSchema{id: repo_id}) do
    %{repo_id: repo_id}
    |> list_notebooks()
    |> Enum.reduce(Ecto.Multi.new(), fn
      %Notebook{} = notebook, query ->
        Oban.insert(
          query,
          "content_sync_worker_#{notebook.id}",
          UrlContentSyncWorker.new(%{notebook_id: notebook.id})
        )

      _, query ->
        query
    end)
    |> Repo.transaction()
  end

  @doc """
  Returns the notebooks from an author in desc order

  ## Examples

      iex> list_author_notebooks_desc("someone")
      [%Notebook{}, ...]

  """
  @spec list_author_notebooks_desc(binary) :: [%Notebook{}] | nil
  def list_author_notebooks_desc(author) when is_binary(author) do
    from(n in Notebook,
      where: n.github_owner_login == ^author,
      order_by: -n.id
    )
    |> Repo.all()
  end

  @doc """
  Returns the notebooks within a repo in desc order

  ## Examples

      iex> list_repo_author_notebooks_desc("my_repo", "my_login")
      [%Notebook{}, ...]

  """
  @spec list_repo_author_notebooks_desc(binary, binary) :: [%Notebook{}]
  def list_repo_author_notebooks_desc(repo_name, author_login)
      when is_binary(repo_name) and is_binary(author_login) do
    from(n in Notebook,
      where: n.github_repo_name == ^repo_name,
      where: n.github_owner_login == ^author_login,
      order_by: -n.id
    )
    |> Repo.all()
  end

  @doc """
  Returns a list of random notebooks

  ## Examples

      iex> list_random_notebooks(%{limit: 2}
      [%Notebook{}, %Notebook{}]

  """
  def list_random_notebooks(%{limit: limit}) do
    from(n in Notebook,
      order_by: fragment("RANDOM()"),
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Gets a single notebook.

  Returns nil if the Notebook does not exist.

  ## Examples

      iex> get_notebook(123)
      %Notebook{}

      iex> get_notebook(456)
      nil

  """
  @spec get_notebook(any) :: %Notebook{}
  def get_notebook(id), do: Repo.get(Notebook, id)

  def get_notebook(id, preload: tables) do
    from(n in Notebook,
      where: n.id == ^id,
      preload: ^tables
    )
    |> Repo.one()
  end

  @doc """
  Gets a single notebook.

  Raises `Ecto.NoResultsError` if the Notebook does not exist.

  ## Examples

      iex> get_notebook!(123)
      %Notebook{}

      iex> get_notebook!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_notebook!(number) :: %Notebook{}
  def get_notebook!(id), do: Repo.get!(Notebook, id)

  def get_notebook!(id, preload: tables) do
    from(n in Notebook,
      where: n.id == ^id,
      preload: ^tables
    )
    |> Repo.one!()
  end

  @doc """
  Gets a notebook by its url or filename, owner and repo
  This allows us to override a file if the url has changed

  ## Examples
    iex> get_by(url: "https://github.com/.../file.livemd")
    true

  """
  @spec get_by([...]) :: %Notebook{} | nil
  def get_by(ops) do
    Enum.reduce(ops, from(n in Notebook), fn
      {:github_filename, github_filename}, query ->
        where(query, [notebook], notebook.github_filename == ^github_filename)

      {:github_owner_login, github_owner_login}, query ->
        where(query, [notebook], notebook.github_owner_login == ^github_owner_login)

      {:github_repo_name, github_repo_name}, query ->
        where(query, [notebook], notebook.github_repo_name == ^github_repo_name)

      {:url, url}, query ->
        where(query, [notebook], notebook.url == ^url)

      _, query ->
        query
    end)
    |> Repo.one()
  end

  @doc """
  Creates a notebook.
  It also:
  - creates the associations user and repo if they don't exist

  ## Examples

      iex> create_notebook(%{field: value})
      {:ok, %Notebook{}}

      iex> create_notebook(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_notebook(any) :: {:ok, %Notebook{}} | {:error, %Ecto.Changeset{}}
  def create_notebook(attrs \\ %{}) do
    %Notebook{}
    |> Notebook.changeset(attrs)
    |> maybe_put_repo_id(attrs)
    |> maybe_put_user_id(attrs)
    |> maybe_put_user_and_repo_assoc(attrs)
    |> Repo.insert()
    |> set_user_id(attrs)
  end

  defp set_user_id(result, %{user_id: _}), do: result

  # When we put the associations notebook.repo and notebook.repo.user
  #  we need to manually set notebook.user_id
  defp set_user_id({:ok, notebook}, _) do
    repo = Repos.get_repo!(notebook.repo_id)

    case update_notebook(notebook, %{user_id: repo.user_id}) do
      {:ok, notebook} ->
        {:ok, notebook}

      {:error, _} ->
        Logger.warn(
          "create_notebook/1 created notebook id #{notebook.id} but couldn't save notebook.user_id. However, this is deprecated as we saved notebook.repo.user_id"
        )

        {:ok, notebook}
    end
  end

  defp set_user_id({:error, changeset}, _) do
    {:error, changeset}
  end

  def maybe_put_repo_id(changeset, %{repo_id: _, user_id: _}), do: changeset
  def maybe_put_repo_id(changeset, %{repo_id: nil}), do: changeset

  def maybe_put_repo_id(changeset, %{repo_id: repo_id}) do
    repo = Repos.get_repo!(repo_id)
    Ecto.Changeset.put_change(changeset, :user_id, repo.user_id)
  end

  def maybe_put_repo_id(changeset, %{github_repo_name: nil}), do: changeset

  def maybe_put_repo_id(changeset, %{github_repo_name: github_repo_name}) do
    case Repos.get_by(%{name: github_repo_name}) do
      nil ->
        changeset

      repo ->
        changeset
        |> Ecto.Changeset.put_change(:repo_id, repo.id)
        |> Ecto.Changeset.put_change(:user_id, repo.user_id)
    end
  end

  def maybe_put_user_id(changeset, %{user_id: _}), do: changeset

  def maybe_put_user_id(changeset, %{github_owner_login: github_owner_login}) do
    case Accounts.get_by_username(github_owner_login) do
      nil -> changeset
      %User{} = user -> Ecto.Changeset.put_change(changeset, :user_id, user.id)
    end
  end

  def maybe_put_user_and_repo_assoc(changeset, attrs) do
    user_id = Ecto.Changeset.get_change(changeset, :user_id)
    repo_id = Ecto.Changeset.get_change(changeset, :repo_id)

    case {user_id, repo_id} do
      {nil, nil} ->
        Ecto.Changeset.put_assoc(changeset, :repo, %RepoSchema{
          name: attrs[:github_repo_name],
          full_name: attrs[:github_repo_full_name],
          fork: attrs[:github_repo_fork],
          user: %User{
            username: attrs[:github_owner_login],
            avatar_url: attrs[:github_owner_avatar_url]
          }
        })

      {user_id, nil} ->
        Ecto.Changeset.put_assoc(changeset, :repo, %RepoSchema{
          name: attrs.github_repo_name,
          user_id: user_id
        })

      {_user_id, _repo_id} ->
        changeset
    end
  end

  @doc """
  Creates or updates a notebook depending on url
  url (default branch url) is generated from github_html_url (commit url) if url is not present

  If url or github_html_url exist or can be generated, we create a notebook. Otherwise, we update it.
  If we create a notebook, we'll also create a user and repo if they don't exist.any()
  Yet, if we update a notebook, we do NOT create user and repo if missing.
    This should NOT be a problem as user and repo creation is handled upon creation.

  ## Examples

  iex> save_notebook(%{github_html_url: "https://raw.githubusercontent.com/elixir-nx/axon/main/notebooks/vision/mnist.livemd", ...})
  {:ok, %Notebook{}}

  iex> save_notebook(%{field: bad_value})
  {:error, %Ecto.Changeset{}}
  """
  @spec save_notebook(map) :: {:ok, %Notebook{}} | {:error, %Ecto.Changeset{}}
  def save_notebook(attrs) do
    attrs = attrs |> put_repo_id() |> put_url()

    url = attrs[:url]
    github_html_url = attrs[:github_html_url]

    notebook =
      (url && Notebooks.get_by(url: url)) ||
        (github_html_url && Notebooks.get_by(github_html_url: github_html_url))

    if notebook do
      update_notebook(notebook, attrs)
    else
      create_notebook(attrs)
    end
  end

  defp put_repo_id(%{github_repo_name: repo_name, github_owner_login: username} = attrs) do
    case Repos.get_by(%{full_name: "#{username}/#{repo_name}"}) do
      nil -> attrs
      repo -> Map.put_new(attrs, :repo_id, repo.id)
    end
  end

  defp put_repo_id(attrs), do: attrs

  defp put_url(%{github_html_url: github_html_url, repo_id: repo_id} = attrs) do
    url = build_url(%{github_html_url: github_html_url, repo_id: repo_id})
    Map.put_new(attrs, :url, url)
  end

  defp put_url(attrs), do: attrs

  defp build_url(%{repo_id: repo_id, github_html_url: github_html_url}) do
    case Repos.get_repo(repo_id) do
      nil ->
        nil

      %RepoSchema{default_branch: nil} ->
        nil

      %RepoSchema{default_branch: default_branch} ->
        Urls.default_branch_url(github_html_url, default_branch)
    end
  end

  @doc """
  Updates a notebook.

  ## Examples

      iex> update_notebook(notebook, %{field: new_value})
      {:ok, %Notebook{}}

      iex> update_notebook(notebook, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_notebook(%Notebook{}, map()) :: {:ok, %Notebook{}} | {:error, %Ecto.Changeset{}}
  def update_notebook(%Notebook{} = notebook, attrs) do
    notebook
    |> Notebook.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a notebook.

  ## Examples

      iex> delete_notebook(notebook)
      {:ok, %Notebook{}}

      iex> delete_notebook(notebook)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_notebook(%Notebook{}) :: {:ok, %Notebook{}} | {:error, %Ecto.Changeset{}}
  def delete_notebook(%Notebook{} = notebook) do
    Repo.delete(notebook)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking notebook changes.

  ## Examples

      iex> change_notebook(notebook)
      %Ecto.Changeset{data: %Notebook{}}

  """
  @spec change_notebook(%Notebook{}, map()) :: %Ecto.Changeset{}
  def change_notebook(%Notebook{} = notebook, attrs \\ %{}) do
    Notebook.changeset(notebook, attrs)
  end

  @spec count :: number
  def count() do
    from(n in Notebook,
      select: count(n.id)
    )
    |> Repo.one()
  end

  def content_fragment(%Notebook{content: nil}, _search), do: nil
  def content_fragment(_notebook, nil), do: nil

  def content_fragment(%Notebook{content: content}, search) do
    case Regex.run(~r/[^\n]{0,15}#{search}[^\n]{0,15}/i, content) do
      nil ->
        nil

      list ->
        "..." <> List.first(list) <> "..."
    end
  end
end
