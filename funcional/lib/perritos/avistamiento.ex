defmodule Perritos.Avistamiento do
  @moduledoc """
  Un avistamiento de perrito. Sólo datos, sin lógica.

  Lo comparten todas las funcionalidades:

    * `colores` es una lista de textos con los nombres del catálogo,
      el color principal primero (ej. `["Negro", "Blanco"]`).
    * `raza` es el nombre de la raza, o `nil` si no se sabe.
    * `lat` y `lon` son números (float), no `Decimal`.
    * `fecha` es un `NaiveDateTime`.
  """

  @derive {Jason.Encoder, only: [:id, :nombre, :raza, :colores, :lat, :lon, :foto, :fecha]}
  defstruct [:id, :nombre, :raza, :colores, :lat, :lon, :foto, :fecha]
end
