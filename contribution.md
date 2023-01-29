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
$ ./bin/session_tests --help
```
{% endraw %}

