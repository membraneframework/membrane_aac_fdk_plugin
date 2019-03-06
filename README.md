# Membrane Multimedia Framework: AAC Element

This package provides elements that can be used ...

It is part of [Membrane Multimedia Framework](https://membraneframework.org).

The docs can be found at [HexDocs](https://hexdocs.pm/membrane_element_aac).

## Installation

The package can be installed by adding `membrane_element_aac` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:membrane_element_aac, "~> 0.1.0"}
  ]
end
```

This package depends on [FDK-AAC](https://github.com/mstorsjo/fdk-aac) library.

### Ubuntu
(Make sure you have Multiverse repository enabled. See: https://help.ubuntu.com/community/Repositories/Ubuntu)
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

## Copyright and License

Copyright 2018, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
