defmodule Perritos.ConsultaTest do
  use ExUnit.Case, async: true
  doctest Perritos.Consulta

  alias Perritos.{Consulta, Parametros}

  test "where combina criterios con AND y junta parámetros en orden" do
    {sql, params} = Consulta.where(%{raza: "Poodle", desde: ~D[2026-11-01]})
    assert sql =~ "r.nombre = ? AND p.fecha_registro >= ?"
    assert params == ["Poodle", ~N[2026-11-01 00:00:00]]
  end

  test "hasta incluye todo el día final" do
    {_sql, params} = Consulta.where(%{hasta: ~D[2026-11-05]})
    assert params == [~N[2026-11-06 00:00:00]]
  end

  test "parsear convierte textos y rechaza basura" do
    assert {:ok, %{raza: "Pitbull", metros: 500.0, desde: ~D[2026-11-01]}} =
             Parametros.parsear(%{"raza" => "Pitbull", "metros" => "500", "desde" => "2026-11-01"})

    assert {:ok, %{raza: nil}} = Parametros.parsear(%{"raza" => ""})
    assert {:error, "desde inválido"} = Parametros.parsear(%{"desde" => "mal"})
    assert {:error, "lat inválido"} = Parametros.parsear(%{"lat" => "abc"})
  end
end