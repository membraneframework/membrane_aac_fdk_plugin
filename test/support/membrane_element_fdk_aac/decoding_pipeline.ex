defmodule Membrane.AAC.FDK.Support.DecodingPipeline do
  @moduledoc false

  import Membrane.ChildrenSpec

  alias Membrane.Testing.Pipeline

  @spec make_pipeline(Path.t(), Path.t()) :: GenServer.on_start()
  def make_pipeline(in_path, out_path) do
    Pipeline.start_link(
      structure: [
        child(:file_src, %Membrane.File.Source{location: in_path})
        |> child(:decoder, Membrane.AAC.FDK.Decoder)
        |> child(:sink, %Membrane.File.Sink{location: out_path})
      ]
    )
  end
end
