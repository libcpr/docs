---
layout: default
title: cpr - For Developers
---

## Overview and Filesystem Structure
Here we aim to cover some topics that will make getting into CPR development and debugging easier. This is not intended to be a thorough documentation of each function, class and template within the project. Rather, it aims to ease the process of contributing to CPR by covering some relevant topics.

In this document, we will be referencing files by their filename, relative to the appropriate root folder. Here are some particularly relevant ones, relative to project root:

* header files have the suffix `.h` and are located in `include/cpr`.
* source files have the suffix `.cpp` and are located in `cpr`.
* most files related to testing are located in `test`.

## Building, Testing and Debugging
For a project that relies on template metaprogramming, such as CPR, compiling tests ensures that templates are instantiated during compilation. Testing and debugging features are enabled through setting certain cmake variables, which can be found in full in `CMakeLists.txt`. We'd like to single out `CPR_BUILD_TESTS` and `CPR_DEBUG_SANITIZER_FLAG_ALL`, which enable the building of tests and the usage of a number of sanitizers. A debug build could be achieved as follows:

{% raw %}
```bash
# Make a build directory inside project root
$ mkdir build && cd build

# Make a Debug build with tests and sanitizers enabled
$ cmake -DCPR_BUILD_TESTS=1 -DCPR_DEBUG_SANITIZER_FLAG_ALL=1 -DCMAKE_BUILD_TYPE=Debug ..

# Build the project. The '-- -j7' part enables parallelization of build tasks.
# You may use a different number depending on your hardware, or omit this bit.
$ cmake --build . -- -j7

# Run all tests
$ cmake --build . --target test

# Run a specific test set
$ ./bin/session_tests

# See more options to run test suites, such as isolating specific tests
$ ./bin/download_tests --help

# Debug a test set
$ gdb ./bin/multiperform_tests

# See all targets for different Makefiles
$ make help
$ cd test && make help
```
{% endraw %}

## Project Structure
Here we will briefly describe different functional parts of CPR, and mention the headers that are most relevant to them. As any software project's, of course, CPR's parts are interconnected, and most classes play a part in most operations. Here, we will constrain ourselves to the most crucial ones. Where relevant headers are suggested, it's recommended to also look at the appropriate source file, if it exists.
### The API Interface
Relevant Headers: `api.h`, `cpr.h`

Here we have the templates that are instantiated to create the cpr API methods. The namespace `priv` contains the intternal functions, particularly relevant for the `Multi`-methods.
### The Session class
Relevant Headers: `session.h`

This class implements most of the logic used by `cpr`. Here, the `curl` `easy-` or `multi-` sessions are constructed, executed, the result packed in a `Response` instance and returned. It is _Moveable_, not _Copyable_, and can have shared ownership. Usage of the `Session` class usually entails construction, the setting of various parameters, either through the `Session::SetParam` methods like, for example, `Session::SetUrl`, or the equivalent polymorphic `Session::SetOption` method, and finally calling the appropriate method, like `Session::Get`. The set-up for the `curl` session happens, to a large degree, inside the `Session::PrepareAction` methods (where `Action` is the corresponding HTTP action).
