defmodule PiLot.PiSupervisor do
  @moduledoc """
  Dynamic supervisor for active pi RPC sessions.
  """

  use DynamicSupervisor

  alias PiLot.PiSession

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_session(project, session_file \\ nil) do
    spec = {PiSession, %{project: project, session_file: session_file}}

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      other -> other
    end
  end
end
