defmodule Perritos.RutaTest do
  use ExUnit.Case, async: true

  doctest Perritos.Geo
  doctest Perritos.Ruta

  alias Perritos.{Geo, Ruta}

  defp perro(id, lat, lon), do: %{id: id, nombre: "perro#{id}", lat: lat, lon: lon}
  defp ids(ruta), do: Enum.map(ruta.orden, & &1.id)

  test "lista vacía produce ruta vacía" do
    assert Ruta.proponer({0.0, 0.0}, []) == %{orden: [], distancia_total_m: 0.0}
  end

  test "un solo perro: una parada y su distancia" do
    ruta = Ruta.proponer({0.0, 0.0}, [perro(1, 0.0, 0.01)])

    assert ids(ruta) == [1]
    assert_in_delta ruta.distancia_total_m, Geo.distancia({0.0, 0.0}, {0.0, 0.01}), 0.1
  end

  test "visita siempre al más cercano de donde está parado" do
    perros = [perro(1, 0.0, 0.03), perro(2, 0.0, 0.01), perro(3, 0.0, 0.02)]

    assert ids(Ruta.proponer({0.0, 0.0}, perros)) == [2, 3, 1]
  end

  test "en un empate gana el primero de la lista" do
    perros = [perro(1, 0.01, 0.0), perro(2, -0.01, 0.0)]

    assert ids(Ruta.proponer({0.0, 0.0}, perros)) == [1, 2]
  end

  test "la distancia total es la suma de los tramos" do
    perros = [perro(1, 0.0, 0.03), perro(2, 0.0, 0.01), perro(3, 0.0, 0.02)]
    ruta = Ruta.proponer({0.0, 0.0}, perros)

    suma = ruta.orden |> Enum.map(& &1.distancia_m) |> Enum.sum()
    assert_in_delta ruta.distancia_total_m, suma, 0.2
  end

  test "en_zona deja fuera a los perros lejanos, y puede quedar vacía" do
    perros = [perro(1, 0.0, 0.001), perro(2, 0.0, 0.5)]

    assert Enum.map(Ruta.en_zona(perros, {0.0, 0.0}, 500), & &1.id) == [1]
    assert Ruta.en_zona(perros, {10.0, 10.0}, 500) == []
  end

  test "proponer acepta cualquier función de distancia" do
    perros = [perro(1, 0.0, 0.01), perro(2, 0.0, 0.02)]
    al_mas_lejano = fn a, b -> -Geo.distancia(a, b) end

    assert ids(Ruta.proponer({0.0, 0.0}, perros)) == [1, 2]
    assert ids(Ruta.proponer({0.0, 0.0}, perros, al_mas_lejano)) == [2, 1]
  end

  test "distancia_desde regresa una función" do
    medir = Ruta.distancia_desde({0.0, 0.0})

    assert is_function(medir, 1)
    assert medir.(perro(1, 0.0, 0.0)) == 0.0
  end
end
