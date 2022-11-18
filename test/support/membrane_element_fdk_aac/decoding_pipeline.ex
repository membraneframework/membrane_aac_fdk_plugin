defmodule Membrane.AAC.FDK.Support.DecodingPipeline do
  @moduledoc false

  alias Membrane.Testing.Pipeline

  @spec make_pipeline(Path.t(), Path.t()) :: pid()
  def make_pipeline(in_path, out_path) do
    import Membrane.ChildrenSpec

    Pipeline.start_link_supervised!(
      structure: [
        child(:file_src, %Membrane.File.Source{location: in_path})
        |> child(:decoder, Membrane.AAC.FDK.Decoder)
        |> child(:sink, %Membrane.File.Sink{location: out_path})
      ]
    )
  end
end
