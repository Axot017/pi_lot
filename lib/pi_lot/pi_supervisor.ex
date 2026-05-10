defmodule PiLot.PiSupervisor do
  @moduledoc false

  use DynamicSupervisor

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok), do: DynamicSupervisor.init(strategy: :one_for_one)

  def start_session(opts) do
    DynamicSupervisor.start_child(__MODULE__, {PiLot.PiSession, opts})
  end
end
