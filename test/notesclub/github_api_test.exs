defmodule Notesclub.GithubAPITest do
  use Notesclub.DataCase

  alias Notesclub.GithubAPI

  import Mock

  @valid_reponse %Req.Response{
    status: 200,
    body: %{
      "items" => [
        %{
          "name" => "structs.livemd",
          "html_url" =>
            "https://github.com/charlieroth/elixir-notebooks/blob/68716ab303da9b98e21be9c04a3c86770ab7c819/structs.livemd",
          "repository" => %{
            "name" => "elixir-notebooks",
            "full_name" => "charlieroth/elixir-notebooks",
            "private" => false,
            "fork" => false,
            "owner" => %{
              "avatar_url" => "https://avatars.githubusercontent.com/u/13981427?v=4",
              "login" => "charlieroth"
            }
          }
        },
        %{
          "name" => "collections.livemd",
          "html_url" =>
            "https://github.com/charlieroth/elixir-notebooks/blob/48c66fbaac086bd98ea5891d8e47b20c49097d83/collections.livemd",
          "private" => false,
          "repository" => %{
            "name" => "elixir-notebooks",
            "full_name" => "charlieroth/elixir-notebooks",
            "private" => false,
            "fork" => false,
            "owner" => %{
              "login" => "charlieroth",
              "avatar_url" => "https://avatars.githubusercontent.com/u/13981427?v=4"
            }
          }
        }
      ],
      "total_count" => 2446
    }
  }

  describe "GithubAPI.Search" do
    test "get/3 returns notebooks" do
      with_mocks([
        {Req, [:passthrough], [get!: fn _url, _options -> @valid_reponse end]},
        {GithubAPI, [:passthrough], [check_github_api_key: fn -> false end]}
      ]) do
        assert {
                 :ok,
                 %GithubAPI{
                   notebooks_data: [
                     %{
                       github_filename: "structs.livemd",
                       github_html_url:
                         "https://github.com/charlieroth/elixir-notebooks/blob/68716ab303da9b98e21be9c04a3c86770ab7c819/structs.livemd",
                       github_owner_avatar_url:
                         "https://avatars.githubusercontent.com/u/13981427?v=4",
                       github_owner_login: "charlieroth",
                       github_repo_name: "elixir-notebooks",
                       github_repo_full_name: "charlieroth/elixir-notebooks",
                       github_repo_fork: false
                     },
                     %{
                       github_filename: "collections.livemd",
                       github_html_url:
                         "https://github.com/charlieroth/elixir-notebooks/blob/48c66fbaac086bd98ea5891d8e47b20c49097d83/collections.livemd",
                       github_owner_avatar_url:
                         "https://avatars.githubusercontent.com/u/13981427?v=4",
                       github_owner_login: "charlieroth",
                       github_repo_name: "elixir-notebooks",
                       github_repo_full_name: "charlieroth/elixir-notebooks",
                       github_repo_fork: false
                     }
                   ],
                   response: @valid_reponse,
                   url: _url
                 }
               } = GithubAPI.get(per_page: 2, page: 1, order: :asc)
      end
    end

    @tag :github_api
    test "confirm github_api_key exists" do
      assert Application.get_env(:notesclub, :github_api_key), "There is no :github_api_key"
    end

    @tag :github_api
    test "get/1 it returns the notebooks from the user" do
      {:ok, %Notesclub.GithubAPI{notebooks_data: notebook_data}} =
        GithubAPI.get(username: "DockYard-Academy", per_page: 2, page: 1, order: "ASC")

      Enum.each(notebook_data, fn item ->
        assert item.github_owner_login == "DockYard-Academy"
      end)
    end

    @tag :github_api
    test "get/1 it returns two notebooks when no username is passed" do
      {:ok, %Notesclub.GithubAPI{notebooks_data: notebook_data}} =
        GithubAPI.get(per_page: 2, page: 1, order: "ASC")

      assert length(notebook_data) == 2
    end
  end
end
