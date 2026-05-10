defmodule PiLot.Projects do
  @moduledoc """
  Discovers and validates allowlisted project directories.
  """

  defstruct [:id, :name, :path, :display_path]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          path: String.t(),
          display_path: String.t()
        }

  def root do
    configured = System.get_env("PI_WEBUI_PROJECTS_DIR") || Path.expand("~/Projects")
    Path.expand(configured)
  end

  def list_projects do
    root = root()

    with true <- File.dir?(root),
         {:ok, names} <- File.ls(root) do
      names
      |> Enum.reject(&String.starts_with?(&1, "."))
      |> Enum.map(&Path.join(root, &1))
      |> Enum.filter(&valid_project_dir?(root, &1))
      |> Enum.map(&build_project/1)
      |> Enum.sort_by(&String.downcase(&1.name))
    else
      _ -> []
    end
  end

  def get_project(id) when is_binary(id) do
    Enum.find(list_projects(), &(&1.id == id))
  end

  def root_status do
    root = root()
    %{path: root, exists?: File.dir?(root)}
  end

  defp valid_project_dir?(root, path) do
    File.dir?(path) and not symlink?(path) and under_root?(root, path)
  end

  defp build_project(path) do
    path = canonical(path)
    name = Path.basename(path)

    %__MODULE__{
      id: id_for(path),
      name: name,
      path: path,
      display_path: abbreviate_home(path)
    }
  end

  def id_for(path) do
    path
    |> canonical()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 16)
  end

  def canonical(path), do: Path.expand(path)

  defp under_root?(root, path) do
    root = canonical(root)
    path = canonical(path)
    path == root or String.starts_with?(path, root <> "/")
  end

  defp symlink?(path) do
    case File.lstat(path) do
      {:ok, %{type: :symlink}} -> true
      _ -> false
    end
  end

  defp abbreviate_home(path) do
    home = Path.expand("~")

    if path == home or String.starts_with?(path, home <> "/") do
      "~" <> String.replace_prefix(path, home, "")
    else
      path
    end
  end
end
