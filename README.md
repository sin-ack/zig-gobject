# zig-gobject

Bindings for GObject-based libraries (such as GTK) generated using GObject
introspection data.

## Usage

To use the bindings, add the `bindings` branch of this repository to
`build.zig.zon` and use the `addBindingModule` function exposed by `build.zig`:

```zig
// exe is the compilation step for your applicaton
exe.addModule("gtk", zig_gobject.addBindingModule(b, exe, "gtk-4.0"));
```

There are examples of this pattern in the `examples` and `test` subprojects.

## Examples

There are several examples in the `examples` directory, which is itself a
runnable project (depending on the `bindings` directory as a dependency). To
ensure the bindings are generated and run the example project launcher, run
`zig build run-example`.

## Development environment

The bindings generated by this project cover a wide variety of libraries, and it
can be annoying and inconvenient to install these libraries on a host system for
testing purposes. The best way to get a consistent environment for testing is to
use [Flatpak](https://flatpak.org/):

1. Install `flatpak`.
2. Install the base SDK dependencies:
   - `flatpak install org.freedesktop.Sdk//22.08`
   - `flatpak install org.gnome.Sdk//44`
3. Install the Zig master extension for the Freedesktop SDK. This is not (yet)
   available on Flathub, so it must be built and installed manually.
   1. Install `flatpak-builder`.
   2. Clone https://github.com/ianprime0509/org.freedesktop.Sdk.Extension.ziglang-master
   3. Inside the clone, run `flatpak-builder --user --install build-dir org.freedesktop.Sdk.Extension.ziglang-master.yml`.

The steps above only need to be done once per GNOME SDK version. To enter a
development environment:

1. Run `flatpak run --filesystem=home --share=network org.gnome.Sdk//44`
   (the `--filesystem=home` part of the command makes your home directory
   available within the container, and the `--share=network` part of the command
   allows network access to fetch dependencies from `build.zig.zon`).
2. Within the spawned shell, run `. /usr/lib/sdk/ziglang-master/enable.sh` to
   add Zig to your `PATH` (don't forget the `.` at the beginning of that
   command).

## Running the binding generator

Running the binding generator requires GIR files to process. The easiest way to
get the full set of required GIR files is to set up a Flatpak development
environment as described in the previous section. Otherwise, a custom set of
bindings can be built by running the `zig-gobject` binary directly.

To generate all available bindings using the files under `lib/gir-files`, run
`zig build codegen`. This will generate bindings to the `bindings` directory,
which can be used as a dependency (using the Zig package manager) in other
projects.

The underlying `zig-gobject` binary can be built using `zig build` and run
directly if more control is required over the source of the bindings (for
example, to run on a different set of GIR files as input).

## Further reading

- [Binding strategy](./doc/binding-strategy.md)

## License

This project is released under the [Zero-Clause BSD
License](https://spdx.org/licenses/0BSD.html). The libraries exposed by the
generated bindings are subject to their own licenses.
