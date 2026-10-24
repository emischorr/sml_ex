defmodule Sml.Fixtures do
  @moduledoc false

  @dir Path.expand("../fixtures", __DIR__)

  def load(name) do
    @dir
    |> Path.join("#{name}.hex")
    |> File.read!()
    |> String.trim()
    |> Base.decode16!(case: :mixed)
  end
end
