defmodule Perritos.BusquedaTest do
  use ExUnit.Case, async: true
  doctest Perritos.Busqueda

  alias Perritos.{Avistamiento, Busqueda}

  defp perrito(attrs \\ []) do
    base = [
      id: 1,
      nombre: "Firulais",
      raza: "Labrador Retriever",
      colores: ["Café", "Blanco"],
      lat: 25.42,
      lon: -101.0,
      foto: "f.jpg",
      fecha: ~N[2026-11-01 10:00:00]
    ]

    struct(Avistamiento, Keyword.merge(base, attrs))
  end

  test "caso borde: sin filtros, todos acepta y alguno rechaza" do
    assert Busqueda.todos([]).(perrito())
    refute Busqueda.alguno([]).(perrito())
  end

  test "caso borde: filtro que no coincide" do
    refute Busqueda.por_raza("Poodle").(perrito())
    refute Busqueda.por_color("negro").(perrito())
  end

  test "Y: exige todos los criterios" do
    ambos = Busqueda.todos([Busqueda.por_raza("labrador retriever"), Busqueda.por_color("café")])
    assert ambos.(perrito())
    refute ambos.(perrito(colores: ["Negro"]))
  end

  test "O: basta con uno" do
    uno = Busqueda.alguno([Busqueda.por_raza("Poodle"), Busqueda.por_color("blanco")])
    assert uno.(perrito())
    refute uno.(perrito(colores: ["Negro"]))
  end

  test "caso borde: radio justo en el borde" do
    p = perrito(lat: 25.43)
    d = Busqueda.distancia_m(25.42, -101.0, p.lat, p.lon)
    assert Busqueda.por_radio(25.42, -101.0, d).(p)
    refute Busqueda.por_radio(25.42, -101.0, d - 1).(p)
  end

  test "fechas: extremos inclusivos y rango abierto" do
    assert Busqueda.por_fechas(~D[2026-11-01], ~D[2026-11-01]).(perrito())
    assert Busqueda.por_fechas(nil, nil).(perrito())
    refute Busqueda.por_fechas(~D[2026-11-02], nil).(perrito())
  end

  test "aplicar_filtro deja solo los que cumplen" do
    lista = [perrito(), perrito(id: 2, raza: "Poodle")]

    assert [%Avistamiento{id: 1}] =
             Busqueda.aplicar_filtro(lista, Busqueda.por_raza("labrador retriever"))
  end

  test "filtros/1 convierte criterios en filtros y todos/1 los combina" do
    criterios = %{raza: "Labrador Retriever", color: nil, desde: nil, hasta: nil}
    filtro = criterios |> Busqueda.filtros() |> Busqueda.todos()

    assert filtro.(perrito())
    refute filtro.(perrito(raza: "Poodle"))
  end
end