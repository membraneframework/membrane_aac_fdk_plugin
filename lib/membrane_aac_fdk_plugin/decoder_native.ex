defmodule Membrane.AAC.FDK.Decoder.Native do
  @moduledoc false
  # Interface module for native AAC decoder.

  use Unifex.Loader

  @type t() :: reference()

  @spec create!() :: reference() | no_return()
  def create!() do
    case create() do
      {:ok, ref} -> ref
      {:error, reason} -> raise "Cannot create native decoder: #{inspect(reason)}"
    end
  end

  @spec fill!(binary(), t()) :: :ok
  def fill!(payload, native) do
    case fill(payload, native) do
      :ok -> :ok
      {:error, reason} -> raise "Failed to fill decoder's buffer: #{inspect(reason)}"
    end
  end
end
