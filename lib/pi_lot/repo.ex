defmodule PiLot.Repo do
  use Ecto.Repo,
    otp_app: :pi_lot,
    adapter: Ecto.Adapters.SQLite3
end
