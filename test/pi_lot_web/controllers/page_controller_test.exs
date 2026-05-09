defmodule PiLotWeb.PageControllerTest do
  use PiLotWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "PiLot"
    assert response =~ "Add project session workspace"
    assert response =~ "Send prompt"
  end
end
