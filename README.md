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
    {:membrane_aac_fdk_plugin, "~> 0.11"}
  ]
end
```

This package depends on [FDK-AAC](https://github.com/mstorsjo/fdk-aac) library.

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
defmodule AAC.Pipeline do
  use Membrane.Pipeline

  @impl true
  def handle_init(_) do
    children = [
      source: %Membrane.File.Source{location: "input.wav"},
      parser: Membrane.WAV.Parser,
      aac_encoder: Membrane.AAC.FDK.Encoder,
      sink: %Membrane.File.Sink{location: "output.aac"}
    ]

    links = [
      link(:source)
      |> to(:parser)
      |> to(:aac_encoder)
      |> to(:sink)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end
end
```

### Decoder

The following pipeline takes AAC file as input and plays it on speakers.

```elixir
defmodule AAC.Pipeline do
  use Membrane.Pipeline

  @impl true
  def handle_init(_) do
    children = [
      source: %Membrane.File.Source{location: "input.aac"},
      aac_decoder: Membrane.AAC.FDK.Decoder,
      converter: %Membrane.FFmpeg.SWResample.Converter{
        output_caps: %Membrane.Caps.Audio.Raw{
          format: :s16le,
          sample_rate: 48000,
          channels: 2
        }
      },
      sink: Membrane.PortAudio.Sink
    ]

    links = [
      link(:source)
      |> to(:aac_decoder)
      |> to(:converter)
      |> to(:sink)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end
end
```

## Copyright and License

Copyright 2018, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
