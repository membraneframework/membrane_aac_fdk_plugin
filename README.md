# Membrane AAC FDK plugin

[![Hex.pm](https://img.shields.io/hexpm/v/membrane_aac_fdk_plugin.svg)](https://hex.pm/packages/membrane_aac_fdk_plugin)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/membrane_aac_fdk_plugin/)
[![CircleCI](https://circleci.com/gh/membraneframework/membrane_aac_fdk_plugin.svg?style=svg)](https://circleci.com/gh/membraneframework/membrane_aac_fdk_plugin)

AAC decoder and encoder based on FDK library.

It is part of [Membrane Multimedia Framework](https://membraneframework.org).

The docs can be found at [HexDocs](https://hexdocs.pm/membrane_aac_fdk_plugin).

## Installation

The package can be installed by adding `membrane_aac_fdk_plugin` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:membrane_aac_fdk_plugin, "~> 0.17.0"}
  ]
end
```

This package depends on the [FDK-AAC](https://github.com/mstorsjo/fdk-aac) library. The precompiled build will be pulled and linked automatically. However, should there be any problems, consider installing it manually.


### Ubuntu

(Make sure you have Multiverse repository enabled. See: <https://help.ubuntu.com/community/Repositories/Ubuntu>)

```
sudo apt-get install libfdk-aac-dev
```

### Arch/Manjaro

```
pacman -S libfdk-aac
```

### MacOS

```
brew install fdk-aac
```

## Usage

### Encoder  

The following pipeline takes wav file as input and encodes it as AAC.

```elixir
Mix.install([:membrane_file_plugin, :membrane_wav_plugin, :membrane_aac_fdk_plugin])

defmodule AAC.Pipeline do
  use Membrane.Pipeline

  @impl true
  def handle_init(_ctx, _opts) do
    structure = 
      child(:source, %Membrane.File.Source{location: "input.wav"})
      |> child(:parser, Membrane.WAV.Parser)
      |> child(:aac_encoder, Membrane.AAC.FDK.Encoder)
      |> child(:sink, %Membrane.File.Sink{location: "output.aac"})

    {[spec: structure, playback: :playing], %{}}
  end
end

{:ok, _pipeline_supervisor, _pipeline} = AAC.Pipeline.start_link([])
```

### Decoder

The following pipeline takes AAC file as input and plays it on speakers.

```elixir
Mix.install([
  :membrane_file_plugin,
  :membrane_ffmpeg_swresample_plugin,
  :membrane_aac_fdk_plugin, 
  :membrane_portaudio_plugin
])

defmodule AAC.Pipeline do
  use Membrane.Pipeline

  @impl true
  def handle_init(_ctx, _opts) do
    structure =
      child(:source, %Membrane.File.Source{location: "input.aac"})
      |> child(:aac_decoder, Membrane.AAC.FDK.Decoder)
      |> child(:converter, %Membrane.FFmpeg.SWResample.Converter{
        output_stream_format: %Membrane.RawAudio{
          sample_format: :s16le,
          sample_rate: 48000,
          channels: 2
        }
      })
      |> child(:sink, Membrane.PortAudio.Sink)

    {[spec: structure, playback: :playing], %{}}
  end
end

{:ok, _pipeline_supervisor, _pipeline} = AAC.Pipeline.start_link([])
```

## Copyright and License

Copyright 2018, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
