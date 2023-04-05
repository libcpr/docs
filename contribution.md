---
layout: default
title: cpr - For Developers
---

## Overview and Filesystem Structure
Here we aim to cover some topics that will make getting into CPR development and debugging easier. This is not intended to be a thorough documentation of each function, class and template within the project. Rather, it aims to ease the process of contributing to CPR by covering some relevant topics.

In this document, we will be referencing files by their filename, relative to the appropriate root folder. Here are some particularly relevant ones, relative to project root:

* Header files have the suffix `.h` and are located in [`include/cpr`](https://github.com/libcpr/cpr/tree/master/include/cpr).
* Source files have the suffix `.cpp` and are located in [`cpr`](https://github.com/libcpr/cpr/tree/master/cpr).
* Most files related to testing are located in [`test`](https://github.com/libcpr/cpr/tree/master/test).

## Building, Testing and Debugging
For a project that relies on template meta programming, such as CPR, compiling tests ensures that templates are instantiated during compilation.
Test and debug options are controlled via a set of CMake variables.
They are located inside the root [`CMakeLists.txt`](https://github.com/libcpr/cpr/blob/master/CMakeLists.txt) file.
Take a look at the option definitions starting with `cpr_option(...)`.
We'd like to single out `CPR_BUILD_TESTS` and `CPR_DEBUG_SANITIZER_FLAG_ALL`, which enable building tests and the usage of a number of sanitizers. A debug build could be achieved as follows:

{% raw %}
```bash
# Make a build directory inside project root
$ mkdir build && cd build

# Make a Debug build with tests and sanitizers enabled
$ cmake -DCPR_BUILD_TESTS=ON -DCPR_DEBUG_SANITIZER_FLAG_ALL=ON -DCMAKE_BUILD_TYPE=Debug ..

# Build the project. The '--parallel' part enables parallel build tasks. Without specifying any number behind `--parallel`, you allow CMake to pick the appropriate number of parallel build tasks.
# To set a specific number (n) of parallel build tasks: '--paralle n'
# You may use a different number depending on your hardware, or omit this bit.
$ cmake --build . --parallel

# Run all tests
$ cmake --build . --target test --parallel

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
Here we briefly describe different functional parts of CPR, and mention the headers that are most relevant to them. As any software project's, of course, CPR's parts are interconnected, and most classes play a part in most operations.
We will constrain ourselves to the most crucial ones.
Where relevant headers are suggested, it's recommended to also look at the appropriate source file, if it exists.
### The API Interface
Relevant Headers: [`api.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/api.h), [`cpr.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/cpr.h)

Here we have the templates that are instantiated to create the cpr API methods. The namespace `priv` contains internal functions, particularly relevant for the `Multi`-methods.
### The Session class
Relevant Headers: [`session.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/session.h)

This class implements most of the logic used by `cpr`. Here, the `curl` `easy-` or `multi-` sessions are constructed, executed, the result packed in a `Response` instance and returned. It is _Moveable_, not _Copyable_, and can have shared ownership. Usage of the `Session` class usually entails construction, the setting of various parameters, either through the `Session::SetParam` methods like, for example, `Session::SetUrl`, or the equivalent polymorphic `Session::SetOption` method, and finally calling the appropriate method, like `Session::Get`. The set-up for the `curl` session happens, to a large degree, inside the `Session::PrepareAction` methods (where `Action` is the corresponding HTTP action).

### Response Wrappers
Relevant Headers: [`response.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/response.h), [`async_wrapper.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/async_wrapper.h), [`error.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/error.h)

Responses from API/Session actions come packaged in these classes. `Response` is the main container for a response, while `cpr::AsyncWrapper` is a container for a (cancellable or non-cancellable) asynchronous response with an interface compatible with [`std::future`](https://en.cppreference.com/w/cpp/thread/future). The class `Error` works as an object-oriented container to describe errors that occur during transfer.

### Parameter Containers
Relevant Headers: [`accept_encoding.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/accept_encoding.h), [`auth.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/auth.h), [`bearer.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/bearer.h), [`body.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/body.h), [`buffer.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/buffer.h), [`callback.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/callback.h), [`cert_info.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/cert_info.h), [`connect_timeout.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/connect_timeout.h), [`cookies.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/cookies.h), [`cprtypes.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/cprtypes.h), [`file.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/file.h), [`http_version.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/http_version.h), [`interface.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/interface.h), [`limit_rate.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/limit_rate.h), [`local_port.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/local_port.h), [`local_port_range.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/local_port_range.h), [`parameters.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/parameters.h), [`low_speed.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/low_speed.h), [`payload.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/payload.h), [`proxies.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/proxies.h), [`proxyauth.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/proxyauth.h), [`range.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/range.h), [`redirect.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/redirect.h), [`reserve_size.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/reserve_size.h), [`resolve.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/resolve.h), [`ssl_options.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/ssl_options.h)

These containers are intended to be provided to API functions in order to generate template instantiations that execute the specific request(s). They contain limited logic, and much of their functionality is contingent on their constructors. They are aimed to be used in order to supply arguments to `CPR` requests in an object-oriented way. To see how they are handled, it usually is a good idea to look at the implementation of the polymorphic `Session::SetOption` method.

### Infrastructure for Asynchronous Requests
Relevant Headers: [`async.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/async.h), [`singleton.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/singleton.h), [`threadpool.h`](https://github.com/libcpr/cpr/blob/master/include/cpr/threadpool.h)

These headers are used by the Asynchronous and Multiple Asynchronous requests API features. They are used to instantiate a [`std::packaged_task`](https://en.cppreference.com/w/cpp/thread/packaged_task), which is emplaced on a queue (see `Threadpool::tasks`), and the `std::future` associated with the task is returned by the API function to the caller wrapped in a `cpr::AsyncWrapper`.
Elements of the `tasks` queue are popped by worker threads of `cpr::GlobalThreadpool` (see `async.h`), and processed by instantiating a `cpr::Session` and resolving the request within the thread. Once the return value of the request has been generated (usually a `cpr::Response`), it can be gotten through `AsyncWrapper::get`.

## Testing and Writing Tests
Test suites for CPR use the [gtest](https://google.github.io/googletest/) framework, and CPR's own [HttpServer](https://github.com/libcpr/cpr/blob/master/test/httpServer.hpp) in order to test behaviours. To see the various URIs that can be used to test different aspects of CPR's functionality, in may be useful to look at the implementation of [`HttpServer::OnRequest`](https://github.com/libcpr/cpr/blob/master/test/httpServer.cpp), and then at the different `HttpServer::OnRequest<URIName>` methods for a more detailed look at each URI's implementation.
