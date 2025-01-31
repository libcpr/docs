---
layout: default
title: cpr - C++ Requests
---

# Curl for People

C++ Requests is a simple wrapper around [libcurl](http://curl.haxx.se/libcurl) inspired by the excellent [Python Requests](https://github.com/kennethreitz/requests) project.

Despite its name, libcurl's easy interface is anything but, and making mistakes misusing it is a common source of error and frustration. Using the more expressive language facilities of C++17, this library captures the essence of making network calls into a few concise idioms.

Here's a quick GET request:

{% raw %}
```c++
#include <cpr/cpr.h>

int main(int argc, char** argv) {
    cpr::Response r = cpr::Get(cpr::Url{"https://api.github.com/repos/libcpr/cpr/contributors"},
                      cpr::Authentication{"user", "pass", cpr::AuthMode::BASIC},
                      cpr::Parameters{{"anon", "true"}, {"key", "value"}});
    r.status_code;                  // 200
    r.header["content-type"];       // application/json; charset=utf-8
    r.text;                         // JSON text string
}
```
{% endraw %}

And here's [less functional, more complicated code, without cpr](https://gist.github.com/whoshuu/2dc858b8730079602044).

## Features

C++ Requests currently supports:

* Custom headers
* URL-encoded parameters
* URL-encoded POST values
* Multipart form POST upload
* File POST upload
* Basic authentication
* Digest authentication
* NTLM authentication
* Connection and request timeout specification
* Timeout for low speed connection
* Asynchronous requests
* :cookie: support!
* Proxy support
* Callback interfaces
* PUT methods
* DELETE methods
* HEAD methods
* OPTIONS methods
* PATCH methods
* Thread Safe access to [libCurl](https://curl.haxx.se/libcurl/c/threadsafe.html)
* OpenSSL and WinSSL support for HTTPS requests
* Manual domain name resolution

## Planned

Support for the following will be forthcoming (in rough order of implementation priority):

* [Streamed requests](https://github.com/libcpr/cpr/issues/25)

and much more!

## Usage

### CMake

#### fetch_content:
If you already have a CMake project you need to integrate C++ Requests with, the primary way is to use `fetch_content`.
Add the following to your `CMakeLists.txt`.


```cmake
include(FetchContent)
FetchContent_Declare(cpr GIT_REPOSITORY https://github.com/libcpr/cpr.git
                         GIT_TAG 1.10.5) # Replace with your desired version from: https://github.com/libcpr/cpr/releases
FetchContent_MakeAvailable(cpr)
```

This will produce the target `cpr::cpr` which you can link against the typical way:

```cmake
target_link_libraries(your_target_name PRIVATE cpr::cpr)
```

That should do it!
There's no need to handle `libcurl` yourself. All dependencies are taken care of for you.
All of this can be found in an example [**here**](https://github.com/libcpr/example-cmake-fetch-content).

#### find_package():
If you prefer not to use `fetch_content`, you can download, build, and install the library and then use CMake `find_package()` function to integrate it into a project.

**Note:** this feature is feasible only if CPR_USE_SYSTEM_CURL is set. (see [#645](https://github.com/libcpr/cpr/pull/645))
```Bash
git clone https://github.com/libcpr/cpr.git
cd cpr && mkdir build && cd build
cmake .. -DCPR_USE_SYSTEM_CURL=ON
cmake --build . --parallel
sudo cmake --install .
```
#### Build Static Library
As an alternative if you want to switch between a static or shared version of cpr use ['-DBUILD_SHARED_LIBS=ON/OFF'](https://cmake.org/cmake/help/latest/variable/BUILD_SHARED_LIBS.html).
```Bash
git clone https://github.com/libcpr/cpr.git
cd cpr && mkdir build && cd build
cmake .. -DCPR_USE_SYSTEM_CURL=ON -DBUILD_SHARED_LIBS=OFF
cmake --build . --parallel
sudo cmake --install .
```

In your `CMakeLists.txt`:
```cmake
find_package(cpr REQUIRED)
add_executable(your_target_name your_target_name.cpp)
target_link_libraries(your_target_name PRIVATE cpr::cpr)
```

#### Tests
`cpr` provides a bunch of tests that can be executed via the following commands.
```Bash
git clone https://github.com/libcpr/cpr.git
cd cpr && mkdir build && cd build
cmake .. -DCPR_BUILD_TESTS=ON # There are other test related options like 'CPR_BUILD_TESTS_SSL' and 'CPR_BUILD_TESTS_PROXY'
cmake --build . --parallel
ctest -VV # -VV is optional since it enables verbose output
```

### Bazel

Please refer to [hedronvision/bazel-make-cc-https-easy](https://github.com/hedronvision/bazel-make-cc-https-easy).

### Packages for Linux Distributions

Alternatively, you may install a package specific to your Linux distribution. Since so few distributions currently have a package for cpr, most users will not be able to run your program with this approach.

Currently, we are aware of packages for the following distributions:

* [Arch Linux (AUR)](https://aur.archlinux.org/packages/cpr)
* [Fedora Linux](https://src.fedoraproject.org/rpms/cpr)

If there's no package for your distribution, try making one! If you do, and it is added to your distribution's repositories, please submit a pull request to add it to the list above. However, please only do this if you plan to actively maintain the package.

### NuGet Package

For Windows, there is also a libcpr NuGet package available. Currently, x86 and x64 builds are supported with release and debug configuration.

The package can be found here: [NuGet.org](https://www.nuget.org/packages/libcpr/)

### Port for macOS

On macOS you may install cpr via [MacPorts.org](https://ports.macports.org/port/cpr) (arm64, x86_64, powerpc)

## Requirements

The only explicit requirements are:

* a `C++17` compatible compiler such as Clang or GCC. The minimum required version of GCC is unknown, so if anyone has trouble building this library with a specific version of GCC, do let us know
* in case you only have a `C++11` compatible compiler available, all versions below cpr 1.9.x are for you. The 1.10.0 release of cpr switches to `C++17` as a requirement.
* If you would like to perform https requests `OpenSSL` and its development libraries are required.
* If you do not use the built-in version of [curl](https://github.com/curl/curl) but instead use your systems version, make sure you use a version `>= 7.64.0`. Lower versions are not supported. This means you need Debian `>= 10` or Ubuntu `>= 20.04 LTS`.

### Building cpr - Using vcpkg

You can download and install cpr using the [vcpkg](https://github.com/Microsoft/vcpkg) dependency manager:
```Bash
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
./bootstrap-vcpkg.sh
./vcpkg integrate install
./vcpkg install cpr
```
The `cpr` port in vcpkg is kept up to date by Microsoft team members and community contributors. If the version is out of date, please [create an issue or pull request](https://github.com/Microsoft/vcpkg) on the vcpkg repository.

### Building cpr - Using Conan

You can download and install `cpr` using the [Conan](https://conan.io/) package manager. Setup your CMakeLists.txt (see [Conan documentation](https://docs.conan.io/en/latest/integrations/build_system.html) on how to use MSBuild, Meson and others).
An example can be found [**here**](https://github.com/libcpr/example-cmake-conan).

The `cpr` package in Conan is kept up to date by Conan contributors. If the version is out of date, please [create an issue or pull request](https://github.com/conan-io/conan-center-index) on the `conan-center-index` repository.

### Building cpr with Meson 

Meson is available in all Linux/BSD distros and on MacOS in their main repository. Once installed just make a directory `cpr_test` and enter it and run:

``` bash
meson init -l cpp -n cpr-test
```

It creates a .cpp file in the directory root and a meson.build just like this.

Now to make `cpr` available to the project, make a `subprojects` directory and install it with:

``` bash
meson wrap install cpr
```

This creates a meson wrap file in `subprojects/cpr.wrap`. We then need to add it as a dependency in the `meson.build` file:

```conf
project('cpr-test', 'cpp',
  version : '0.1',
  default_options : ['warning_level=3', 'cpp_std=c++17'])

cpr_dep = dependency('cpr')

exe = executable('cpr-test', 'cpr_test.cpp', dependencies: [ cpr_dep ], install: true)

test('basic', exe)
```

and now just paste the example usage in the top of page in the new .cpp file, do some modification and build/compile the project:

``` bash
meson setup builddir --wipe
meson compile -C builddir
./builddir/cpr-test
```

That's it. For more information check out on the Meson website: https://mesonbuild.com

## Testing `docs` in a container image 

With your image builder ready, either [Docker](docker.com) or [Podman](podman.io), build it like:

```
podman build . --tag cpr-image
podman run --rm -it -p 4000:4000 -v ${PWD}:/app -w /app cpr-image
```

Then go to `localhost:4000` with your web browser or [curl](curl.se). That's it!

## Contributing

Please fork this repository and contribute back using [pull requests](https://github.com/libcpr/cpr/pulls). Features can be requested using [issues](https://github.com/libcpr/cpr/issues). All code, comments, and critiques are greatly appreciated.
