defmodule DCATR.Utils do
  @moduledoc false

  def bang!(fun, args) do
    case apply(fun, args) do
      {:ok, result} -> result
      :ok -> :ok
      {:error, error} -> raise error
    end
  end
end
