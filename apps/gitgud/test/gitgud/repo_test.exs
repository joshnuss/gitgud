defmodule GitGud.RepoTest do
  use GitGud.DataCase

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.RepoQuery

  @valid_attrs %{path: "project-awesome", name: "My Awesome Project", description: "Awesome things are going on here!"}

  setup do
    user = User.register!(name: "Mario Flach", username: "redrabbit", email: "m.flach@almightycouch.com", password: "test1234")

    on_exit fn ->
      File.rm_rf!(Path.join(Application.get_env(:gitgud, :git_dir), user.username))
    end

    {:ok, %{user: user}}
  end

  test "creates a bare repository and ensures that git directory exists", %{user: user} do
    params = Map.put(@valid_attrs, :owner_id, user.id)
    assert {:ok, repo, pid} = Repo.create(params)
    assert File.dir?(Repo.git_dir(repo))
    assert Geef.Repository.bare?(pid)
  end

  test "fails to create a repository with invalid params", %{user: user} do
    params = Map.put(@valid_attrs, :owner_id, user.id)
    assert {:error, changeset} = Repo.create(%{params|path: "foo$bar"})
    assert "has invalid format" in errors_on(changeset).path
    assert {:error, changeset} = Repo.create(%{params|path: "xy"})
    assert "should be at least 3 character(s)" in errors_on(changeset).path
  end

  test "fails to create two repositories with same path", %{user: user} do
    params = Map.put(@valid_attrs, :owner_id, user.id)
    assert {:ok, _repo, _pid} = Repo.create(params)
    assert {:error, changeset} = Repo.create(params)
    assert "has already been taken" in errors_on(changeset).path
  end

  test "gets all repositories owned by a user", %{user: user} do
    params = Map.put(@valid_attrs, :owner_id, user.id)
    repos =
      1..5
      |> Enum.map(fn i -> update_in(params.path, &"#{&1}-#{i}") end)
      |> Enum.map(&Repo.create!/1)
      |> Enum.map(&elem(&1, 0))
      |> QuerySet.preload(:owner)
    assert repos == RepoQuery.user_repositories(user)
  end

  test "gets a single repository by a user/path pair", %{user: user} do
    params = Map.put(@valid_attrs, :owner_id, user.id)
    assert {:ok, repo, _pid} = Repo.create(params)
    repo = QuerySet.preload(repo, :owner)
    assert ^repo = RepoQuery.user_repository(user, repo.path)
  end

  test "updates a repository and ensures that git directory has been renamed", %{user: user} do
    params = Map.put(@valid_attrs, :owner_id, user.id)
    assert {:ok, old_repo, _pid} = Repo.create(params)
    assert {:ok, new_repo} = Repo.update(old_repo, path: "project-super-awesome", name: "My Super Awesome Project")
    refute File.dir?(Repo.git_dir(old_repo))
    assert File.dir?(Repo.git_dir(new_repo))
  end

  test "deletes a repository and ensures that git directly has been removed", %{user: user} do
    params = Map.put(@valid_attrs, :owner_id, user.id)
    assert {:ok, repo, _pid} = Repo.create(params)
    assert {:ok, repo} = Repo.delete(repo)
    refute File.dir?(Repo.git_dir(repo))
  end
end