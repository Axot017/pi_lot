defmodule PiLot.Projects do
  @moduledoc """
  Project allowlist and discovery for pi workspaces.
  """

  @type project :: %{
          id: String.t(),
          name: String.t(),
          path: String.t(),
          display_path: String.t()
        }

  def root do
    configured =
      Application.get_env(:pi_lot, :projects_dir) || System.get_env("PI_WEBUI_PROJECTS_DIR")

    path = configured || Path.expand("~/Projects")
    canonical_dir(path)
  end

  def list_projects do
    with {:ok, root} <- root(),
         {:ok, entries} <- File.ls(root) do
      entries
      |> Enum.reject(&String.starts_with?(&1, "."))
      |> Enum.map(&Path.join(root, &1))
      |> Enum.filter(&valid_project_dir?(root, &1))
      |> Enum.map(&project_from_path/1)
      |> Enum.sort_by(&String.downcase(&1.name))
    else
      _ -> []
    end
  end

  def get_project(id) when is_binary(id) do
    Enum.find(list_projects(), &(&1.id == id))
  end

  def default_project do
    list_projects() |> List.first()
  end

  def valid_project_path?(path) when is_binary(path) do
    with {:ok, root} <- root(),
         {:ok, canonical} <- canonical_dir(path) do
      valid_project_dir?(root, canonical)
    else
      _ -> false
    end
  end

  defp valid_project_dir?(root, path) do
    with {:ok, stat} <- File.lstat(path),
         true <- stat.type == :directory,
         {:ok, canonical} <- canonical_dir(path) do
      parent = Path.dirname(canonical)
      parent == root and not symlink?(path)
    else
      _ -> false
    end
  end

  defp symlink?(path) do
    case File.lstat(path) do
      {:ok, %{type: :symlink}} -> true
      _ -> false
    end
  end

  defp project_from_path(path) do
    {:ok, canonical} = canonical_dir(path)
    name = Path.basename(canonical)

    %{
      id: id_for_path(canonical),
      name: name,
      path: canonical,
      display_path: display_path(canonical)
    }
  end

  def id_for_path(path) do
    path
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 16)
  end

  defp canonical_dir(path) do
    expanded = Path.expand(path)

    if File.dir?(expanded) do
      {:ok, expanded}
    else
      {:error, :not_dir}
    end
  end

  def display_path(path) do
    home = Path.expand("~")

    if String.starts_with?(path, home) do
      "~" <> String.replace_prefix(path, home, "")
    else
      path
    end
  end
end
