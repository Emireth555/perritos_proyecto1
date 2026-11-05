defmodule Perritos.Avistamiento do
  @moduledoc "Struct compartido con #14. Usa `lon`, no `lng`. `fecha` es NaiveDateTime."

  defstruct [:id, :nombre, :raza, :colores, :lat, :lon, :foto, :fecha]
end