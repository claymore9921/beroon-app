defmodule BeroonWeb.BranchController do
  use BeroonWeb, :controller

  alias Beroon.Operations
  alias Beroon.Operations.Branch

  def index(conn, _params) do
    branches = Operations.list_branches()
    render(conn, :index, branches: branches)
  end

  def new(conn, _params) do
    changeset = Operations.change_branch(%Branch{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"branch" => branch_params}) do
    case Operations.create_branch(branch_params) do
      {:ok, branch} ->
        conn
        |> put_flash(:info, "شعبه ثبت شد.")
        |> redirect(to: ~p"/branches/#{branch}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    branch = Operations.get_branch!(id)
    render(conn, :show, branch: branch)
  end

  def edit(conn, %{"id" => id}) do
    branch = Operations.get_branch!(id)
    changeset = Operations.change_branch(branch)
    render(conn, :edit, branch: branch, changeset: changeset)
  end

  def update(conn, %{"id" => id, "branch" => branch_params}) do
    branch = Operations.get_branch!(id)

    case Operations.update_branch(branch, branch_params) do
      {:ok, branch} ->
        conn
        |> put_flash(:info, "شعبه ویرایش شد.")
        |> redirect(to: ~p"/branches/#{branch}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, branch: branch, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    branch = Operations.get_branch!(id)
    {:ok, _branch} = Operations.delete_branch(branch)

    conn
    |> put_flash(:info, "شعبه حذف شد.")
    |> redirect(to: ~p"/branches")
  end
end
