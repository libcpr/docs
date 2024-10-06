---
layout: default
title: cpr - Advanced Usage
---

## Version Macros
CPR exposes a couple of preprocessor macros with version information.

{% raw %}
```c++
/**
 * CPR version as a string.
 **/
#define CPR_VERSION "1.7.0"

/**
 * CPR version split up into parts.
 **/
#define CPR_VERSION_MAJOR 1
#define CPR_VERSION_MINOR 7
#define CPR_VERSION_PATCH 0

/**
 * CPR version as a single hex digit.
 * it can be split up into three parts:
 * 0xAABBCC
 * AA: The current CPR major version number in a hex format.
 * BB: The current CPR minor version number in a hex format.
 * CC: The current CPR patch version number in a hex format.
 *
 * Examples:
 * '0x010702' -> 01.07.02 -> CPR_VERSION: 1.7.2
 * '0xA13722' -> A1.37.22 -> CPR_VERSION: 161.55.34
 **/
#define CPR_VERSION_NUM 0x010702
```
{% endraw %}

## Response Objects

`Response` objects are bags of data. Their sole purpose is to give the client information at the end of a request -- there's nothing in the API that uses a `Response` after it gets back to you. This reasoning drove the decision to make the member fields of the response public and mutable.

A `Response` has these fields and methods:

{% raw %}
```c++
long status_code;               // The HTTP status code for the request
std::string text;               // The body of the HTTP response
Header header;                  // A map-like collection of the header fields
Url url;                        // The effective URL of the ultimate request
double elapsed;                 // The total time of the request in seconds
Cookies cookies;                // A vector-like collection of cookies returned in the request
Error error;                    // An error object containing the error code and a message
std::string raw_header;         // The raw header string
std::string status_line;        // The status line of the respone
std::string reason;             // The reason for the status code
cpr_off_t uploaded_bytes;       // How many bytes have been send to the server
cpr_off_t downloaded_bytes;     // How many bytes have been received from the server
long redirect_count;            // How many redirects occurred

std::vector<CertInfo> GetCertInfos(); // Returns a vector of certificate information objects (HTTPS only)
```
{% endraw %}

and they're dead simple to access:

{% raw %}
```c++
cpr::Response r = cpr::Get(cpr::Url{"http://www.httpbin.org/get"});
if(r.status_code == 0)
    std::cerr << r.error.message << std::endl;
else if (r.status_code >= 400) {
    std::cerr << "Error [" << r.status_code << "] making request" << std::endl;
} else {
    std::cout << "Request took " << r.elapsed << std::endl;
    std::cout << "Body:" << std::endl << r.text;
}
```
{% endraw %}

The `Header` is essentially a map with an important modification. Its keys are case insensitive as required by [RFC 7230](http://tools.ietf.org/html/rfc7230#section-3.2):

```c++
cpr::Response r = cpr::Get(cpr::Url{"http://www.httpbin.org/get"});
std::cout << r.header["content-type"] << std::endl;
std::cout << r.header["Content-Type"] << std::endl;
std::cout << r.header["CoNtEnT-tYpE"] << std::endl;
```

All of these should print the same value, `"application/json"`.

On the other hand, Cookies are accessed through a vector-like interface, and you could access and check kinds of fields of a cookie:

```c++
cpr::Response r = cpr::Get(cpr::Url{"http://www.httpbin.org/cookies/set?cookies=yummy"});
for(const auto &cookie : r.cookies) {
    std::cout << cookie.GetDomain() << ":";
    std::cout << cookie.IsIncludingSubdomains() << ":";
    std::cout << cookie.GetPath() << ":";
    std::cout << cookie.IsHttpsOnly() << ":";
    std::cout << cookie.GetExpiresString() << ":";
    std::cout << cookie.GetName() << ":";
    std::cout << cookie.GetValue() << std::endl;
    // For example, this will print:
    // www.httpbin.org:0:/:0:Thu, 01 Jan 1970 00:00:00 GMT:cookies:yummy
}
```

As you can see, the `Response` object is completely transparent. All of its data fields are accessible at all times, and since its only useful to you insofar as it has information to communicate, you can let it fall out of scope safely when you're done with it.

## Request Headers

Speaking of the `Header`, you can set custom headers in the request call. The object is exactly the same:

{% raw %}
```c++
cpr::Response r = cpr::Get(cpr::Url{"http://www.httpbin.org/headers"},
                  cpr::Header{{"accept", "application/json"}});
std::cout << r.text << std::endl;

/*
 * "headers": {
 *   "Accept": "application/json",
 *   "Host": "www.httpbin.org",
 *   "User-Agent": "curl/7.42.0-DEV"
 * }
 */
```
{% endraw %}

Furthermore, it is even possible to set several header parameters from different sources. For example, this is helpful when injecting header parameters into the request from different helpers:

{% raw %}
```c++
template<class ...Ts>
cpr::Response myGet(Ts&& ...ts) {
    return cpr::Get(std::forward<Ts>(ts)...,
           cpr::Header{{"Authorization", "token"}});
}

...

cpr::Response r = cpr::myGet(cpr::Url{"http://www.httpbin.org/headers"},
                  cpr::Header{{"accept", "application/json"}});
std::cout << r.text << std::endl;

/*
 * "headers": {
 *   "Accept": "application/json",
 *   "Accept-Encoding": "deflate, gzip",
 *   "Authorization": "token",
 *   "Host": "www.httpbin.org",
 *   "User-Agent": "curl/7.81.0"
 * }
 */
```
{% endraw %}

You've probably noticed a similarity between `Header`, `Parameters`, `Payload`, and `Multipart`. They all have constructors of the form:

{% raw %}
```c++
cpr::Header header = cpr::Header{{"header-key", "header-value"}};
cpr::Parameters parameters = cpr::Parameters{{"parameter-key", "parameter-value"}};
cpr::Payload payload = cpr::Payload{{"payload-key", "payload-value"}};
cpr::Multipart multipart = cpr::Multipart{{"multipart-key", "multipart-value"}};
```
{% endraw %}

This isn't an accident -- all of these are map-like objects and their syntax is identical because their semantics depends entirely on the object type. Additionally, it's practical to have `Parameters`, `Payload`, and `Multipart` be swappable because APIs sometimes don't strictly differentiate between them.

## Session Objects

Under the hood, all calls to the primary API modify an object called a `Session` before performing the request. This is the only truly stateful piece of the library, and for most applications it isn't necessary to act on a `Session` directly, preferring to let the library handle it for you.

However, in cases where it is useful to hold on to state, you can use a `Session`:

{% raw %}
```c++
cpr::Url url = cpr::Url{"http://www.httpbin.org/get"};
cpr::Parameters parameters = cpr::Parameters{{"hello", "world"}};
cpr::Session session;
session.SetUrl(url);
session.SetParameters(parameters);

cpr::Response r = session.Get();        // Equivalent to cpr::Get(url, parameters);
std::cout << r.url << std::endl;        // Prints http://www.httpbin.org/get?hello=world

cpr::Parameters new_parameters = cpr::Parameters{{"key", "value"}};
session.SetParameters(new_parameters);

cpr::Response new_r = session.Get();    // Equivalent to cpr::Get(url, new_parameters);
std::cout << new_r.url << std::endl;    // Prints http://www.httpbin.org/get?key=value
```
{% endraw %}

`Session` also allows you to get the full request URL before a request is actually made:

{% raw %}
```c++
cpr::Url url = cpr::Url{"http://www.httpbin.org/get"};
cpr::Parameters parameters = cpr::Parameters{{"hello", "world"}};
cpr::Session session;
session.SetUrl(url);
session.SetParameters(parameters);

std::string fullRequestUrl = session.GetFullRequestUrl();
std::cout << fullRequestUrl << std::endl;   // Prints http://www.httpbin.org/get?hello=world
```
{% endraw %}

`Session` actually exposes two different interfaces for setting the same option. If you wanted you can do this instead of the above:

{% raw %}
```c++
cpr::Url url = cpr::Url{"http://www.httpbin.org/get"};
cpr::Parameters parameters = cpr::Parameters{{"hello", "world"}};
cpr::Session session;
session.SetOption(url);
session.SetOption(parameters);
cpr::Response r = session.Get();
```
{% endraw %}

This is important so it bears emphasizing: *for each configuration option (like `Url`, `Parameters`), there's a corresponding method `Set<ObjectName>` and a `SetOption(<Object>)`*. The second interface is to facilitate the template metaprogramming magic that lets the API expose order-less methods.

The key to all of this is actually the way [libcurl](http://curl.haxx.se/libcurl/) is designed. It uses a somewhat [policy-based design](https://en.wikipedia.org/wiki/Policy-based_design) that relies configuring a single library object (the `curl` handle). Each option configured into that object changes its behavior in mostly orthogonal ways.

`Session` leverages that and exposes a more modern interface that's free of the macro-heavy hulkiness of libcurl. Understanding the policy-based design of libcurl is important for understanding the way the `Session` object behaves.

`Session` may also be used in scenarios when you want to benefit from `cpr`'s API for settings options and getting results back, but you need to perform the http request using `curl`'s advanced api such as `curl_multi_socket_action()`. In this case, you need to:

1. prepare the request using one of `PrepareGet`, `PreparePut`, etc... instead of `Get`, `Put`, ... respectively
2. perform the request yourself using `curl`'s API, fetching  the `curl` handle from the session using `GetCurlHolder()`
3. once `curl`is done, give the resulting `CURLcode` to the session using `Complete()` and get the `Response` objet

Keep in mind that `Session` is stateful, which means that you can't prepare multiple requests concurrently using the same `Session`: a request must be completed before you prepare the next one.

{% raw %}
```c++
cpr::Url url = cpr::Url{"http://www.httpbin.org/get"};
cpr::Session session;
session.SetOption(url);
session.PrepareGet();

// Here, curl_easy_perform would typically be replaced
// by a more complex scheme using curl_multi API
CURLcode curl_result = curl_easy_perform(session.GetCurlHolder()->handle);

cpr::Response response = session.Complete(curl_result);
```
{% endraw %}

### Thread Safety

A `cpr::Session` object by default is not thread safe, meaning you are not allowed to set multiple options (e.g. `SetBody(..)`, `SetHeader(..)`) in parallel.
Preparing and executing a web request needs to be done sequentially, but not single threaded.

To further exploit parallelism and take advantage of reusing `cpr::Session` objects take a look at the asynchronous `cpr::Session` interface (e.g. `cpr::AsyncResponse asyncResponse = session.GetAsync();`).
Internally `cpr::ThreadPool` gets used for this, handling all requests (Ref: [Asynchronous Requests](#asynchronous-requests)).


## HTTP Compression

HTTP compression is a capability that can improve transfer speed and bandwidth utilization between web servers and web clients.
When you issue a HTTP request, you could specify the supported compression schemes in the header: Accept-Encoding.
With this setting, you could avoid unexpected compression schemes or use the desired schemes:

{% raw %}
```c++
cpr::Response r = cpr::Get(cpr::Url{"http://www.httpbin.org/get"},
                  cpr::AcceptEncoding{{cpr::AcceptEncodingMethods::deflate, cpr::AcceptEncodingMethods::gzip, cpr::AcceptEncodingMethods::zlib}});
// or you could specify specific schemes with the customized string
cpr::Response r = cpr::Get(cpr::Url{"http://www.httpbin.org/get"},
                  cpr::AcceptEncoding{{"deflate", "gzip", "zlib"}});
```
{% endraw %}

Also, you could use `cpr::Session` to make the connection stateful:

{% raw %}
```c++
cpr::Url url{server->GetBaseUrl() + "/check_accept_encoding.html"};
cpr::Session session;
session.SetUrl(url);

session.SetAcceptEncoding({{cpr::AcceptEncodingMethods::deflate, cpr::AcceptEncodingMethods::gzip, cpr::AcceptEncodingMethods::zlib}});
// or you could specify specific schemes with the customized string
session.SetAcceptEncoding({{"deflate", "gzip", "zlib"}});

Response response = session.Get();
```
{% endraw %}

### Defaults

To allow `cpr` and therefore `libcurl` decide which compressions are accepted, or just to enable all supported compression methods, pass an empty list to `cpr::AcceptEncoding`.
**This is also the default behavior if nothing else gets configured.**

{% raw %}
```c++
// An empty list of accepted encodings in combination with a direct request without any state
cpr::Response r = cpr::Get(cpr::Url{"http://www.httpbin.org/get"},
                  cpr::AcceptEncoding{});

// An empty list of accepted encodings in combination with a stateful cpr::Session object
session.SetAcceptEncoding(cpr::AcceptEncoding{});
```
{% endraw %}

### Disabling the `Accept-Encoding` Header

By default `cpr` and therefore `libcurl` will always include an `Accept-Encoding` header. To disable this behavior one can simply pass the `cpr::AcceptEncodingMethods::disabled` or `"disabled"` directly as a `std::string` to `cpr::AcceptEncoding`.

> ⚠️ **WARNING**<br>
> Including `cpr::AcceptEncodingMethods::disabled` or `"disabled"` does not allow any other values/encodings to be passed to `cpr::AcceptEncoding`!<br>
> If you ignore this a `std::invalid_argument` exception wil be thrown during session establishment.

{% raw %}
```c++
cpr::Session session;
session.SetUrl("https://example.com");
session.SetAcceptEncoding({AcceptEncodingMethods::disabled}); // Disable setting the `Accept-Encoding` header
Response response = session.Get();
```
{% endraw %}

{% raw %}
```c++
cpr::Session session;
session.SetUrl("https://example.com");
session.SetAcceptEncoding({"disabled"}); // Disable setting the `Accept-Encoding` header
Response response = session.Get();
```
{% endraw %}

{% raw %}
```c++
cpr::Session session;
session.SetUrl("https://example.com");
session.SetAcceptEncoding({AcceptEncodingMethods::disabled, AcceptEncodingMethods::deflate});
Response response = session.Get(); // An exception of type `std::invalid_argument` will be thrown here since multiple values are passed to `AcceptEncoding` where one of them is `disabled`
```
{% endraw %}

For more information, please refer to [HTTP compression - Wikipedia](https://en.wikipedia.org/wiki/HTTP_compression) and [CURLOPT_ACCEPT_ENCODING](https://curl.se/libcurl/c/CURLOPT_ACCEPT_ENCODING.html).

## Large Responses

In case you expect a large string as a response, you should reserve space for it beforehand to prevent it from being moved and resized too often.
For example, we expect the server to return roughly 4 million characters in this response with a chunk size of 256 characters. Without reserving space for 4 million characters beforehand, the string have to be moved roughly five times in case it grows exponentially.
In reality, this usually happens less, since we usually receive larger chunks from the server.

So to get around this one could do the following:
{% raw %}
```c++
cpr::Response r = cpr::Get(cpr::Url{"http://xxx/file"},
                  cpr::ReserveSize{1024 * 1024 * 4});   // Reserve space for at least 4 million characters
```
{% endraw %}

## Asynchronous Requests

Making an asynchronous request uses a similar but separate interface:

```c++
AsyncResponse fr = cpr::GetAsync(cpr::Url{"http://www.httpbin.org/get"});
// Sometime later...
cpr::Response r = fr.get(); // This blocks until the request is complete
std::cout << r.text << std::endl;
```

The call is otherwise identical except instead of `Get`, it's `GetAsync`. Similarly for POST requests, you would call `PostAsync`. The return value of an asynchronous call is actually an `AsyncWrapper<Response>`, which exposes public member functions analogous to those of [`std::future<T>`](https://en.cppreference.com/w/cpp/thread/future):

```c++
cpr::AsyncResponse fr = cpr::GetAsync(cpr::Url{"http://www.httpbin.org/get"});
fr.wait(); // This waits until the request is complete
cpr::Response r = fr.get(); // Since the request is complete, this returns immediately
std::cout << r.text << std::endl;
```

You can even put a bunch of requests into a `std` container and get them all later:

{% raw %}
```c++
std::vector<cpr::AsyncResponse> container{};
cpr::Url url = cpr::Url{"http://www.httpbin.org/get"};
for (int i = 0; i < 10; ++i) {
    container.emplace_back(cpr::GetAsync(url, cpr::Parameters{{"i", std::to_string(i)}}));
}
// Sometime later
for (cpr::AsyncResponse& ar: container) {
    cpr::Response r = ar.get();
    std::cout << r.text << std::endl;
}
```
{% endraw %}

Alternatively, you can use the  `Multi<method>Async` to bundle multiple requests and execute them in parallel. The requests' parameters are delivered as positional arguments to an async method of your choice, packed in `std::tuple` or `std::array`s, just like the `Multi<method>` API functions. `MultiAsync` makes use of `cpr`'s threadpool-based parallelism, and also offers the capability to **cancel transactions** while they are underway. Here's an example:

{% raw %}
```c++
// The second template parameter denotes a cancellable transaction
using AsyncResC = cpr::AsyncWrapper<Response, true>;

cpr::Url postUrl{"http://www.httpbin.org/post"};
std::vector<AsyncResC>responses{MultiPostAsync(
    std::tuple{post_url, cpr::Payload{{"name", "Alice"}}},
    std::tuple{post_url, cpr::Payload{{"role", "admin"}}}
    // ...
)};
// If the first transaction isn't completed within 10 ms, we'd like to cancel all of them
bool all_cancelled{false};
if(responses.at(0).wait_for(std::chrono::milliseconds(10)) == std::future_status::timeout) {
    all_cancelled = true;
    for(AsyncResC& res: responses) {
        all_cancelled &= (res.Cancel() == CancellationResult::success);
    }
}
// If not cancelled, process results
```
{% endraw %}


Asynchronous requests can also be performed using a `cpr::Session` object. It is important to note that the asynchronous request is performed directly on the session object, modifying it in the process.
To ensure that the lifetime of the session is properly extended, the session object used **must be** managed by a `std::shared_ptr`. This restriction is necessary because the implementation uses `std::shared_from_this` to pass a pointer to the ansynchronous lambda function which would otherwise throw a `std::bad_weak_ptr` exception.
Here is an example for an asynchronous get request which uses a session object:

{% raw %}
```c++
std::shared_ptr<cpr::Session> session = std::make_shared<cpr::Session>();
cpr::Url url = cpr::Url{"http://www.httpbin.org/get"};
session->SetUrl(url);
cpr::AsyncResponse fr = session->GetAsync();
cpr::Response r = fr.get();
std::cout << r.text << std::endl;
```
{% endraw %}

An important note to make here is that arguments passed to an asynchronous call are copied. Under the hood, an asychronous call through the library's API is done with `std::async`. By default, for memory safety, all arguments are copied (or moved if temporary) because there's no syntax level guarantee that the arguments will live beyond the scope of the request.

It's possible to force `std::async` out of this default so that the arguments are passed by reference as opposed to value. Currently, however, `cpr::<method>Async` has no support for forced pass by reference, though this is planned for a future release.

## Asynchronous Callbacks

C++ Requests also supports a callback interface for asynchronous requests. Using the callback interface, you pass in a functor (lambda, function pointer, etc.) as the first argument, and then pass in the rest of the options you normally would in a blocking request. The functor needs to have a single parameter, a `Response` object -- this response is populated when the request completes and the function body executes.

Here's a simple example:

```c++
auto future_text = cpr::GetCallback([](cpr::Response r) {
        return r.text;
    }, cpr::Url{"http://www.httpbin.org/get"});
// Sometime later
if (future_text.wait_for(std::chrono::seconds(0)) == std::future_status::ready) {
    std::cout << future_text.get() << std::endl;
}
```

There are a couple of key features to point out here:

1. The return value is a `std::string`. This isn't hardcoded -- the callback is free to return any value it pleases! When it's time to get that value, a check for if the request is complete is made, and a simple `.get()` call on the future grabs the correct value. This flexibility makes the callback interface delightfully simple, generic, and effective!
2. The lambda capture is empty, but absolutely doesn't need to be. Anything that can be captured inside a lambda normally can be captured in a lambda passed into the callback interface. This additional vector of flexibility makes it highly preferable to use lambdas, though any functor with a `Response` parameter will compile and work.

Additionally, you can enforce immutability of the `Response` simply with a `const Response&` parameter instead of `Response`.

As with asynchronous requests, asynchronous callbacks can also be used on a shared pointer of a `cpr::Session` object. This **must be** a `std::shared_ptr`, since the implementation uses `std::shared_from_this` which would otherwise throw a `std::bad_weak_ptr` exception. The usage is similar to the use without a session object:
{% raw %}
```c++
std::shared_ptr<cpr::Session> session = std::make_shared<cpr::Session>();
cpr::Url url = cpr::Url{"http://www.httpbin.org/get"};
session->SetUrl(url);
auto future_text = session->GetCallback([](Response r) {
        return r.text;
    });
// Sometime later
if (future_text.wait_for(std::chrono::seconds(0)) == std::future_status::ready) {
    std::cout << future_text.get() << std::endl;
}
```
{% endraw %}

## Setting a Timeout

It's possible to set a timeout for your request if you have strict timing requirements:

```c++
#include <assert.h>

cpr::Response r = cpr::Get(cpr::Url{"http://www.httpbin.org/get"},
                  cpr::Timeout{1000}); // Let's hope we aren't using Time Warner Cable
assert(r.elapsed <= 1); // Less than one second should have elapsed
```

For the sake of simplicity, the duration can also be specified via `std::chrono_literal`:
```c++
#include <cassert>
#include <chrono>

using namespace std::chrono_literals;

cpr::Response r = cpr::Get(cpr::Url{"http://www.httpbin.org/get"},
                  cpr::Timeout{1s}); // Let's hope we aren't using Time Warner Cable
assert(r.elapsed <= 1); // Less than one second should have elapsed
```

Setting the `Timeout` option sets the maximum allowed time the transfer operation can take. Since C++ Requests is built on top of libcurl, it's important to know what setting this `Timeout` does to the request. You can find more information about the specific libcurl option [here](http://curl.haxx.se/libcurl/c/CURLOPT_TIMEOUT_MS.html).

## Setting Callbacks

You can optionally set callbacks for a request. Currently there is support for read, header, write, progress, and debug callbacks.

### ReadCallback

This callback function will be called every time `libcurl` is ready for data to be sent to the server, and provides for streaming uploads.

The callback signature looks like this.

```c++
  bool readCallback(char* buffer, size_t & length, intptr_t userdata);
```

Provide the callback with the ReadCallback options object.  Only one read callback may be set.
When called, `length` is the length of `buffer`.  `buffer` should be filled with data, and `length` updated to how much was filled.
Return `true` on success, or `false` to **cancel** the transfer.

### HeaderCallback

This callback function gets called by `libcurl` once for each non-data line received from the server.
This includes empty lines and the `HTTP` status line.  `\r\n` endings are preserved.

The callback signature looks like this.

```c++
  bool headerCallback(std::string_view & data, intptr_t userdata);
```

Provide the callback with the HeaderCallback options object.  Only one header callback may be set.
When a header callback is set, the Response object's `header` member will not be filled.
Return `true` on success, or `false` to **cancel** the transfer.

### WriteCallback

This callback function gets called by `libcurl` as soon as there is data received that needs to be saved, and provides for streaming downloads.
You could buffer data in your own way, or write every chunk immediately out to some other stream or file.

The callback signature looks like this.

```c++
  bool writeCallback(std::string_view & data, intptr_t userdata);
```

Provide the callback with the WriteCallback options object.  Only one write callback may be set.
When a write callback is set, the Response object's `text` member will not be filled.
Return `true` on success, or `false` to **cancel** the transfer.

### ProgressCallback

While data is being transferred it will be called very frequently, and during slow periods like when nothing is being transferred it can slow down to about one call per second. The callback gets told how much data `libcurl` will transfer and has transferred, in number of bytes.

The callback signature looks like this.

```c++
  bool progressCallback(cpr_off_t downloadTotal, cpr_off_t downloadNow, cpr_off_t uploadTotal, cpr_off_t uploadNow, intptr_t userdata);
```

The values are in bytes.  Return `true` to continue the transfer, and `false` to **cancel** it.

Here is an example of using the callback.

```c++
int main(int argc, char** argv) {
    cpr::Response r = cpr::Get(cpr::Url{"http://www.httpbin.org/get"},
                      cpr::ProgressCallback([&](cpr_off_t downloadTotal, cpr_off_t downloadNow, cpr_off_t uploadTotal, cpr_off_t uploadNow, intptr_t userdata) -> bool
    {
        std::cout << "Downloaded " << downloadNow << " / " << downloadTotal << " bytes." << std::endl;
        return true;
    }));
    return 0;
}
```

### DebugCallback

This is called by `libcurl` for verbose debugging information, including all data transferred.

The callback signature looks like this.

```c++
  enum class DebugCallback::InfoType {
    TEXT = 0,
    HEADER_IN = 1,
    HEADER_OUT = 2,
    DATA_IN = 3,
    DATA_OUT = 4,
    SSL_DATA_IN = 5,
    SSL_DATA_OUT = 6,
  };
  void debugCallback(DebugCallback::InfoType type, std::string data, intptr_t userdata);
```

`type` represents the type of the content, whereas `data` contains the content itself.  Debug messages have type `TEXT`.


## Using Proxies

`Proxies`, like `Parameters`, are map-like objects. It's easy to set one:

{% raw %}
```c++
cpr::Response r = cpr::Get(cpr::Url{"http://www.httpbin.org/get"},
                  cpr::Proxies{{"http", "http://www.fakeproxy.com"}});
std::cout << r.url << std::endl; // Prints http://www.httpbin.org/get, not the proxy url
```
{% endraw %}

It doesn't look immediately useful to have `Proxies` behave like a map, but when used with a `Session` it's more obvious:

{% raw %}
```c++
cpr::Session session;
session.SetProxies({{"http", "http://www.fakeproxy.com"},
                    {"https", "http://www.anotherproxy.com"}})
session.SetUrl("http://www.httpbin.org/get");
{
    cpr::Response r = session.Get();
    std::cout << r.url << std::endl; // Prints http://www.httpbin.org/get after going
                                     // through http://www.fakeproxy.com
}
session.SetUrl("https://www.httpbin.org/get");
{
    cpr::Response r = session.Get();
    std::cout << r.url << std::endl; // Prints https://www.httpbin.org/get after going
                                     // through http://www.anotherproxy.com
}
```
{% endraw %}

Setting `Proxies` on a `Session` lets you intelligently route requests using different protocols through different proxies without having to respecify anything but the request `Url`.

Sometimes a proxy requires authentication, and now that we are used to map-like objects - you know the drill. Proxy username/password pairs must be URL encoded, so we need to take care of that.

{% raw %}
```c++
cpr::Response r = cpr::Get(cpr::Url{"http://www.httpbin.org/get"},
                  cpr::Proxies{{"http", "http://www.fake_auth_proxy.com"}},
                  cpr::ProxyAuthentication{{"http", EncodedAuthentiction{"user", "pass"}}});
std::cout << r.text << std::endl;
/*
 * {
 *   "args": {},
 *   "headers": {
 *     ..
 *   },
 *   "url": "http://httpbin.org/get"
 * }
 */
```
{% endraw %}

## Sending Cookies

Earlier you saw how to grab a cookie from the request:

```c++
cpr::Response r = cpr::Get(cpr::Url{"http://www.httpbin.org/cookies/set?cookies=yummy"});
for(const auto &cookie : r.cookies) {
    std::cout << cookie.GetDomain() << ":";
    std::cout << cookie.IsIncludingSubdomains() << ":";
    std::cout << cookie.GetPath() << ":";
    std::cout << cookie.IsHttpsOnly() << ":";
    std::cout << cookie.GetExpiresString() << ":";
    std::cout << cookie.GetName() << ":";
    std::cout << cookie.GetValue() << std::endl;
    // For example, this will print:
    // www.httpbin.org:0:/:0:Thu, 01 Jan 1970 00:00:00 GMT:cookies:yummy
}
```

You can send back cookies using the same object:

```c++
cpr::Response r = cpr::Get(cpr::Url{"http://www.httpbin.org/cookies/set?cookies=yummy"});
cpr::Response another_r = cpr::Get(cpr::Url{"http://www.httpbin.org/cookies"}, r.cookies);
std::cout << another_r.text << std::endl;

/*
 * {
 *   "cookies": {
 *     "cookie": "yummy"
 *   }
 * }
 */
```

 This is especially useful because `Cookies` often go from server to client and back to the server. Setting new `Cookies` should not look surprising at all:

{% raw %}
```c++
cpr::Response r = cpr::Get(cpr::Url{"http://www.httpbin.org/cookies"},
                  cpr::Cookies{{"ice cream", "is delicious"}});
std::cout << r.text << std::endl;

/*
 * {
 *   "cookies": {
 *     "ice%20cream": "is%20delicious"
 *   }
 * }
 */
```
{% endraw %}

By default `Cookies` and their values will be URL-encoded.
Although this is recommend, it is not mandatory for `Cookies` to be URL-encoded.
{% raw %}
```
[...]
To maximize compatibility with user agents, servers that wish to
store arbitrary data in a cookie-value SHOULD encode that data, for
example, using Base64 [RFC4648].
[...]
```
{% endraw %}
Source: [RFC6265](https://www.ietf.org/rfc/rfc6265.txt)

URL-encoding for `Cookies` can be disabled by setting `encode = false` in the `Cookie` constructor.
{% raw %}
```c++
cpr::Response r = cpr::Get(cpr::Url{"http://www.httpbin.org/cookies"},
                  cpr::Cookies{{"ice cream", "is delicious"}}, false);
std::cout << r.text << std::endl;

/*
 * {
 *   "cookies": {
 *     "ice cream": "is delicious"
 *   }
 * }
 */
```
{% endraw %}

## PUT and PATCH Requests

PUT and PATCH requests work identically to POST requests, with the only modification being that the specified HTTP method is `"PUT"` or `"PATCH"` instead of `"POST"`. Use this when the semantics of the API you're calling implements special behavior for these requests:

{% raw %}
```c++
#include <assert.h>

// We can't POST to the "/put" endpoint so the status code is rightly 405
assert(cpr::Post(cpr::Url{"http://www.httpbin.org/put"},
                 cpr::Payload{{"key", "value"}}).status_code == 405);

// On the other hand, this works just fine
cpr::Response r = cpr::Put(cpr::Url{"http://www.httpbin.org/put"},
                  cpr::Payload{{"key", "value"}});
std::cout << r.text << std::endl;

/*
 * {
 *   "args": {},
 *   "data": "",
 *   "files": {},
 *   "form": {
 *     "key": "value"
 *   },
 *   "headers": {
 *     ..
 *     "Content-Type": "application/x-www-form-urlencoded",
 *     ..
 *   },
 *   "json": null,
 *   "url": "https://httpbin.org/put"
 * }
 */
```
{% endraw %}

Most often, PUTs are used to update an existing object with a new object. Of course, there's no guarantee that any particular API uses PUT semantics this way, so use it only when it makes sense to. Here's a sample PATCH request, it's essentially identical:

{% raw %}
```c++
#include <assert.h>

// We can't POST or PUT to the "/patch" endpoint so the status code is rightly 405
assert(cpr::Post(cpr::Url{"http://www.httpbin.org/patch"},
                 cpr::Payload{{"key", "value"}}).status_code == 405);
assert(cpr::Put(cpr::Url{"http://www.httpbin.org/patch"},
                cpr::Payload{{"key", "value"}}).status_code == 405);

// On the other hand, this works just fine[libcurl](http://curl.haxx.se/libcurl/)
cpr::Response r = cpr::Patch(cpr::Url{"http://www.httpbin.org/patch"},
                    cpr::Payload{{"key", "value"}});
std::cout << r.text << std::endl;

/*
 * {
 *   "args": {},
 *   "data": "",
 *   "files": {},
 *   "form": {
 *     "key": "value"
 *   },
 *   "headers": {
 *     ..
 *     "Content-Type": "application/x-www-form-urlencoded",
 *     ..
 *   },
 *   "json": null,
 *   "url": "https://httpbin.org/patch"
 * }
 */
```
{% endraw %}

As with PUT, PATCH only works if the method is supported by the API you're sending the request to.

## Download File

CPR specifically provides an interface for downloading files.

### Download To File

Download to file is simple:

{% raw %}
```c++
    std::ofstream of("1.jpg", std::ios::binary);
    cpr::Response r = cpr::Download(of, cpr::Url{"http://www.httpbin.org/1.jpg"});
    std::cout << "http status code = " << r.status_code << std::endl << std::endl;
```
{% endraw %}

### Download With Callback

When downloading a small file, you might want to allocate enough memory to hold the data you read before starting the download. This is where 'GetDownloadFileLength()' comes in.

{% raw %}
```c++
struct File
{
    void*  file_buf;   // file data will be save to
    int64_t read_len;  // file bytes
};
bool write_data(std::string data, intptr_t userdata)
{
    File* pf = reinterpret_cast<File*>(userdata);
    memcpy(pf->file_buf + pf->read_len, data.data(), data.size());
    pf->read_len += data.size();
    return true; // Return `true` on success, or `false` to **cancel** the transfer.
}
void download_to_mem(File &f)
{
    cpr::Session session;
    session.SetUrl(cpr::Url{"http://www.httpbin.org/1.jpg"});
    f.read_len = session.GetDownloadFileLength();
    f.file_buf = malloc(f.read_len);
    cpr::Result r = session.Download(cpr::WriteCallback{write_data, reinterpret_cast<File*>(&f)});
}
int main()
{
    File f{nullptr, 0};
    download_to_mem(f);
    // do something
    free(f.file_buf); // free file data buf
    return 0;
}
```
{% endraw %}

## Other Request Methods

C++ Requests also supports `DELETE`, `PATCH`, `HEAD`, and `OPTIONS` methods in the expected forms:

```c++
// Regular, blocking modes
cpr::Response delete_response = cpr::Delete(cpr::Url{"http://www.httpbin.org/delete"});
cpr::Response patch_response = cpr::Patch(cpr::Url{"http://www.httpbin.org/patch"});
cpr::Response head_response = cpr::Head(cpr::Url{"http://www.httpbin.org/get"});
cpr::Response options_response = cpr::OPTIONS(cpr::Url{"http://www.httpbin.org/get"});

// Asynchronous, future mode
AsyncResponse async_delete_response = cpr::DeleteAsync(cpr::Url{"http://www.httpbin.org/delete"});
AsyncResponse async_patch_response = cpr::PatchAsync(cpr::Url{"http://www.httpbin.org/get"});
AsyncResponse async_head_response = cpr::HeadAsync(cpr::Url{"http://www.httpbin.org/get"});
AsyncResponse async_options_response = cpr::OptionsAsync(cpr::Url{"http://www.httpbin.org/get"});

// Asynchronous, callback mode
auto cb_delete_response = cpr::DeleteCallback([](cpr::Response r) {
        return r.text;
    }, cpr::Url{"http://www.httpbin.org/delete"});
auto cb_patch_response = cpr::PatchCallback([](cpr::Response r) {
        return r.text;
    }, cpr::Url{"http://www.httpbin.org/patch"});
auto cb_head_response = cpr::HeadCallback([](cpr::Response r) {
        return r.status_code;
    }, cpr::Url{"http://www.httpbin.org/get"});
auto cb_options_response = cpr::OptionsCallback([](cpr::Response r) {
        return r.status_code;
    }, cpr::Url{"http://www.httpbin.org/get"});
```

## HTTPS Options

CPR verifies SSL certificates for HTTPS requests, just like a web browser. By default, SSL verification is enabled.

```c++
cpr::Response r = cpr::Get(cpr::Url{"https://www.httpbin.org/get"});
```

The underlying implementation automatically switches to SSL/TLS if `libcurl` provides the appropriate support.

You can also further customize the behavior of the SSL/TLS protocol by passing more configuration items to the request.

### SSL/TLS Version

The SSL/TLS protocol has evolved in many different versions for security and performance reasons.

Starting with version 7.39, `libcurl` uses TLS v1.0 by default.

If you have security and performance concerns, you can force a newer version of the protocol.

```c++
cpr::SslOptions sslOpts = cpr::Ssl(ssl:TLSv1_2{});
cpr::Response r = cpr::Get(cpr::Url{"https://www.httpbin.org/get"}, sslOpts);
```

Or a lower but insecure version of the protocol for compatibility reasons.

* `TLSv1`: TLS v1.0 or later
* `SSLv2`: SSL v2 (but not SSLv3)
* `SSLv3`: SSL v3 (but not SSLv2)
* `TLSv1_0`: TLS v1.0 or later (libcurl 7.34.0)
* `TLSv1_1`: TLS v1.1 or later (libcurl 7.34.0)
* `TLSv1_2`: TLS v1.2 or later (libcurl 7.34.0)
* `TLSv1_3`: TLS v1.3 or later (libcurl 7.52.0)
* `MaxTLSVersion`: maximum supported TLS version, or the default value from the SSL library is used. (libcurl 7.54.0)
* `MaxTLSv1_0`: maximum supported TLS version as TLS v1.0. (libcurl 7.54.0)
* `MaxTLSv1_1`: maximum supported TLS version as TLS v1.1. (libcurl 7.54.0)
* `MaxTLSv1_2`: maximum supported TLS version as TLS v1.2. (libcurl 7.54.0)
* `MaxTLSv1_3`: maximum supported TLS version as TLS v1.3. (libcurl 7.54.0)

### ALPN and NPN

Some older HTTPS services do not support ALPN and NPN negotiation, which may result in connections not being established properly. Compatibility issues can be resolved by disabling ALPN/NPN support for the request.

```c++
cpr::SslOptions sslOpts = cpr::Ssl(ssl::ALPN{false}, ssl::NPN{false});
cpr::Response r = cpr::Get(cpr::Url{"https://www.httpbin.org/get"}, sslOpts);
```

* `ALPN`: [ALPN](https://en.wikipedia.org/wiki/Application-Layer_Protocol_Negotiation) in the SSL handshake. (libcurl 7.36.0)

> Application-Layer Protocol Negotiation (ALPN) is a Transport Layer Security (TLS) extension that allows the application layer to negotiate which protocol should be performed over a secure connection in a manner that avoids additional round trips and which is independent of the application-layer protocols. It is needed by secure HTTP/2 connections, which improves the compression of web pages and reduces their latency compared to HTTP/1.x. The ALPN and HTTP/2 standards emerged from development work done by Google on the now withdrawn SPDY protocol.

* `NPN`: [NPN](https://www.imperialviolet.org/2013/03/20/alpn.html) in the SSL handshake. (libcurl 7.36.0)

> NPN, or Next Protocol Negotiation, allows a TLS connection to negotiate which application-level protocol will be running across it.

### Verify SSL/TLS Certificate and Status

By default, the Libcurl library attempts to verify the SSL/TLS protocol server-side certificate and its status.

If you wish to connect to a server that uses a self-signed certificate, you can turn off the corresponding check with the `VerifyHost`, `VerifyPeer` and `VerifyStatus` options.

* `VerifyHost`: the server cert is for the server it is known as.
* `VerifyPeer`: the authenticity of the peer's certificate.
* `VerifyStatus`: the status of the server cert using the "Certificate Status Request" TLS extension (aka. OCSP stapling). (libcurl 7.41.0)

### Pinned Public Key

When negotiating a TLS or SSL connection, the server sends a certificate indicating its identity.
A public key is extracted from this certificate and if it does not exactly match the public key provided to this option,
`libcurl` (and therefore `CPR`) will abort the connection before sending or receiving any data.

You can specify the public key using the `PinnedPublicKey` option.
The string can be the file name of your pinned public key. The file format expected is "PEM" or "DER".
The string can also be any number of base64 encoded sha256 hashes preceded by "sha256//" and separated by ";"

```c++
cpr::SslOptions sslOpts = cpr::Ssl(ssl::PinnedPublicKey{"pubkey.pem"});
/* OR
cpr::SslOptions sslOpts = cpr::Ssl(ssl::PinnedPublicKey{"sha256//J0dKy1gw45muM4o/vm/tskFQ2BWudtp9XLxaW7OtowQ="});
*/
cpr::Response r = cpr::Get(cpr::Url{"https://www.httpbin.org/get"}, sslOpts);
```

If you do not have the server's public key file you can extract it from the server's certificate:

``` bash
# retrieve the server's certificate if you don't already have it
#
# be sure to examine the certificate to see if it is what you expected
#
# Windows-specific:
# - Use NUL instead of /dev/null.
# - OpenSSL may wait for input instead of disconnecting. Hit enter.
# - If you don't have sed, then just copy the certificate into a file:
#   Lines from -----BEGIN CERTIFICATE----- to -----END CERTIFICATE-----.
#
openssl s_client -servername www.httpbin.org -connect www.httpbin.org:443 < /dev/null | sed -n "/-----BEGIN/,/-----END/p" > www.httpbin.org.pem

# extract public key in pem format from certificate
openssl x509 -in www.httpbin.org.pem -pubkey -noout > www.httpbin.org.pubkey.pem

# convert public key from pem to der
openssl asn1parse -noout -inform pem -in www.httpbin.org.pubkey.pem -out www.httpbin.org.pubkey.der

# sha256 hash and base64 encode der to string for use
openssl dgst -sha256 -binary www.httpbin.org.pubkey.der | openssl base64
```

### SSL Client Certificate

Some HTTPS services require client certificates to be given at the time of connection for authentication and authorization.

You can specify filepaths using `std::string` or `filesystem::path` for client certificates and private keys using the `CertFile` and `KeyFile` options.
When using `libcurl` 7.71.0 or newer, you can also pass a private key using the `KeyBlob` option.

Private key as a key path:
```c++
cpr::SslOptions sslOpts = cpr::Ssl(ssl::CertFile{"cert.pem"}, ssl::KeyFile{"key.pem"});
cpr::Response r = cpr::Get(cpr::Url{"https://www.httpbin.org/get"}, sslOpts);
```
Private key as a blob (`libcurl` 7.71.0 or newer):
```c++
cpr::SslOptions sslOpts = cpr::Ssl(ssl::CertFile{"cert.pem"}, ssl::KeyBlob{"-----BEGIN RSA PRIVATE KEY-----[...]"});
cpr::Response r = cpr::Get(cpr::Url{"https://www.httpbin.org/get"}, sslOpts);
```

The default certificate and private key files are in PEM format, and DER format files can also be imported via `DerCert` and `DerKey` if desired.

### Certificate Authority (CA) Bundle

By default, `libcurl` uses the operating system's root certificate chain to authenticate peer certificate.

If you need to verify a self-signed certificate, you can use the `CaInfo` to specify the CA certificate bundle file, or `CaPath` to specify the directory where multiple CA certificate files are located. If `libcurl` is built against OpenSSL, the certificate directory must be prepared using the openssl `c_rehash` utility.

Another option to check self-signed certificates is to load CA certificates directly from a `std::string` buffer that is stored in `CaBuffer`. However, this requires `libcurl` 7.11.0 or newer and is currently only available for OpenSSL.
```c++
cpr::SslOptions sslOpts = cpr::Ssl(ssl::CaBuffer{"-----BEGIN CERTIFICATE-----[...]"});
cpr::Response r = cpr::Get(cpr::Url{"https://www.httpbin.org/get"}, sslOpts);
```

### Retrieving Certificate Information

After a successful request, it is possible to retrieve multiple certificates. The return value is of type `std::vector<CertInfo>`. There are multiple entries per certificate. An example can be found bellow:

```c++
Url url = "https://github.com";
Response response = cpr::Get(url);
std::vector<CertInfo> certInfos = response.GetCertInfos();
for (const CertInfo& certInfo : certInfos) {
    for (const std::string& entry : certInfo) {
        std::cout << entry << std::endl;
    }
}
```

The output could look like:
```
[...]
Subject:C = US, ST = California, L = San Francisco, O = "GitHub, Inc.", CN = github.com
Issuer:C = US, O = DigiCert Inc, CN = DigiCert TLS Hybrid ECC SHA384 2020 CA1
Version:2
Serial Number:05189a54ebe8c7e903e0ab0d925545de
Signature Algorithm:ecdsa-with-SHA384
Public Key Algorithm:id-ecPublicKey
X509v3 Authority Key Identifier:keyid:0A:BC:08:29:17:8C:A5:39:6D:7A:0E:CE:33:C7:2E:B3:ED:FB:C3:7A
[...]
```

## Interface

It is also possible to specify the outgoing interface used by [libcurl](http://curl.haxx.se/libcurl/).
By default the TCP stack decides which interface to use for this request.
You can change this behavior by passing the `cpr::Interface` option to your request.
Passing an empty string corresponds to passing a `nullptr` to `CURLOPT_INTERFACE`.
Further details: https://curl.se/libcurl/c/CURLOPT_INTERFACE.html

{% raw %}
```c++
cpr::Response r = cpr::Get(cpr::Url{"http://www.httpbin.org/get"},
                  cpr::Interface{""}); // Let the TCP stack decide (same as default)
```
{% endraw %}

{% raw %}
```c++
cpr::Response r = cpr::Get(cpr::Url{"http://www.httpbin.org/get"},
                  cpr::Interface{"eth0"}); // eth0 will be used as outgoing interface
```
{% endraw %}

A `cpr::Interface` object can also be created via `std::string_view` instead of `std::string`.

## Local Port and Range

Sometimes it is necessary to specify the local port number for the socket used by [libcurl](http://curl.haxx.se/libcurl/).
By default the TCP stack decides which local port to use.
You can change this behaviour by passing the `cpr::LocalPort` option to your request or by calling `Session::SetLocalPort`.
When specifying a local port it is also recommended to specify a range if possible as the configured port might already be used.
This can be achieved by passing the `cpr::LocalPortRange` option to the request or by calling `Session::SetLocalPortRange`
Further details: https://curl.se/libcurl/c/CURLOPT_LOCALPORT.html, https://curl.se/libcurl/c/CURLOPT_LOCALPORTRANGE.html

{% raw %}
```c++
cpr::Response r = cpr::Get(cpr::Url{"http://www.httpbin.org/get"},
                  cpr::LocalPort{50000},        // local port number 50000 will be used as source port
                  cpr::LocalPortRange{100});    // if port 50000 is already in use the first free port up to 50099 will be used
```
{% endraw %}

## Redirects

For configuring the behavior once a redirect occurs, the `cpr::Redirect` class exists.
It houses three attributes

* `maximum`: The maximum number of redirects to follow. Default: `50L`. `0`: Refuse any redirects. `-1`: Infinite number of redirects.
* `follow`: Follow 3xx redirects. Default: `true`.
* `cont_send_cred`: Continue to send authentication (user+password) credentials when following locations, even when hostname changed. Default: false
* `post_flags`: Flags to control how to act after a redirect for a post request. Default: `PostRedirectFlags::POST_ALL`.

In the following example we will follow up to 42 redirects and in case we encounter a 301 or 302 redirect, we will post again.

{% raw %}
```c++
cpr::Response r = cpr::Post(cpr::Url{"http://www.httpbin.org/get"},
                  cpr::Payload{{"key", "value"}},
                  cpr::Redirect{42L, true, false, PostRedirectFlags::POST_301 | PostRedirectFlags::POST_302});
```
{% endraw %}

## HTTP Protocol Version

To change the HTTP protocol version, the `cpr::HttpVersion` class exists.
It takes a `cpr::HttpVersionCode`, which changes the underlying HTTP protocol version used.
Possible values are:

* `VERSION_NONE`: Let libcurl decide which version is the best.
* `VERSION_1_0`: Enforce HTTP 1.0 requests.
* `VERSION_1_1`: Enforce HTTP 1.1 requests.
* `VERSION_2_0`: Attempt HTTP 2.0 requests. Fallback to HTTP 1.1 if negotiation fails. Requires libcurl > 7.33.0.
* `VERSION_2_0_TLS`: Attempt HTTP 2.0 for HTTPS requests only. Fallback to HTTP 1.1 if negotiation fails. HTTP 1.1 will be used for HTTP connections. Requires libcurl > 7.47.0.
* `VERSION_2_0_PRIOR_KNOWLEDGE`: Start HTTP 2.0 for HTTP requests. Requires prior knowledge that the server supports HTTP 2.0. For HTTPS requests we will negotiate the protocol version in the TLS handshake. Requires libcurl > 7.49.0.
* `VERSION_3_0`: Attempt HTTP 3.0 requests. Requires prior knowledge that the server supports HTTP 3.0 since there is no gracefully downgrade. Fallback to HTTP 1.1 if negotiation fails. Requires libcurl > 7.66.0.

{% raw %}
```c++
cpr::Response r = cpr::Get(cpr::Url{"http://google.de"},
                  cpr::HttpVersion{cpr::HttpVersionCode::VERSION_2_0});
```
{% endraw %}

## Range Requests

HTTP range requests can be used to receive only a part of a HTTP message. This allows specific access to required areas of large files or to pause downloads and resume them later.

To make a simple HTTP range request, the range options need to be set as follows:

{% raw %}
```c++
cpr::Response r = cpr::Get(cpr::Url{"http://www.httpbin.org/headers"},
                           cpr::Range{1, 5});
std::cout << r.text << std::endl;
/*
 * {
 *   "headers": {
 *     "Range": "bytes=1-5",
 *     ...
 *   }
 * }
 */
```
{% endraw %}

To leave parts of the range empty,  `std::nullopt` can be specified as the boundary index when creating the partial range:

{% raw %}
```c++
cpr::Response r = cpr::Get(cpr::Url{"http://www.httpbin.org/headers"},
                           cpr::Range{std::nullopt, 5});
std::cout << r.text << std::endl;
/*
 * {
 *   "headers": {
 *     "Range": "bytes=-5",
 *     ...
 *   }
 * }
 */
```
{% endraw %}

Moreover, multiple ranges can be specified in a single request with `cpr::MultiRange`:

{% raw %}
```c++
cpr::Response r = cpr::Get(cpr::Url{"http://www.httpbin.org/headers"},
                           cpr::MultiRange{cpr::Range{1, 3}, cpr::Range{5, 6}});
std::cout << r.text << std::endl;
/*
 * {
 *   "headers": {
 *     "Range": "bytes=1-3, 5-6",
 *     ...
 *   }
 * }
 */
```
{% endraw %}

As always, there is of course also the possibility to set the range of a session object manually:

{% raw %}
```c++
cpr::Session session;
session.SetOption(cpr::Range{1, 3});                    // Alternative: SetRange()
session.SetOption(cpr::MultiRange{cpr::Range{1, 3},
                                  cpr::Range{5, 6}});   // Alternative: SetMultiRange()
```
{% endraw %}

## Interceptors

Cpr offers the possibility to pass user-implemented interceptors to a session, which can then monitor, modify and repeat requests.

### Single Session

Each interceptor implementation must inherit from the abstract class `cpr::Interceptor` for intercepting regular `cpr::Sessions` objects.
The inherited class has to implement the function `cpr::Response intercept(cpr::Session& session)`.
This function is automatically called for every added interceptor during the request with the session object belonging to the request passed as a parameter.
An essential point of the intercept function is that it must call the `cpr::Response proceed(Session& session)` function implemented in `cpr::Interceptor`.
This is necessary to continue the request and get the `cpr::Response` object.

Here is an example implementation for an interceptor that logs the request without changing it:

{% raw %}
```c++
class LoggingInterceptor : public cpr::Interceptor {
  public:
    cpr::Response intercept(cpr::Session& session) override {
        // Log the request URL
        std::cout << "Request url: " << session.GetFullRequestUrl() << std::endl;

        // Proceed the request and save the response
        cpr::Response response = proceed(session);

        // Log response status code
        std::cout << "Response status code: " << response.status_code << std::endl;

        // Return the stored response
        return response;
    }
};
```
{% endraw %}

To add one or more concrete interceptor implementations to a session, they can be passed to `Session::AddInterceptor(const std::shared_ptr<Interceptor>& pinterceptor)`:

{% raw %}
```c++
// Setup the session
cpr::Url url{"https://www.httpbin.org/get"};
cpr::Session session;
session.SetUrl(url);

// Add an interceptor to the session
session.AddInterceptor(std::make_shared<LoggingInterceptor>());
```
{% endraw %}

If interceptors have been added to the session, the intercept functions of each added interceptor is automatically called during the next request. The interceptors are thereby selected according to the first-in-first-out principle.

{% raw %}
```c++
// Make a get request to the session we have previously added our LoggingInterceptor to
Response response = session.Get();

/*
* Output produced by the LoggingInterceptor:
*   Request url: https://www.httpbin.org/get
*   Response status code: 200
*/
```
{% endraw %}

It should be noted that interceptors can make changes to the session object that is later passed to the proceed function and can thus fundamentally change the request. Of course, the returned response object can also be modified.

In addition, interceptors can even change the http method of the request by passing the proceed method another parameter of the enum type `cpr::Interceptor::ProceedHttpMethod`. The parameter required for download requests is also simply passed to the proceed method. For example we can implement an interceptor which changes the request method to `HEAD`:

{% raw %}
```c++
class ChangeRequestMethodToHeadInterceptor : public Interceptor {
  public:
    Response intercept(Session& session) override {
        // Change the request http method to HEAD
        return proceed(session, Interceptor::ProceedHttpMethod::HEAD_REQUEST);
    }
};
```
{% endraw %}

### Multiperform

It is also possible to intercept `cpr::InterceptorMulti` calls.
Each interceptor implementation must inherit from the abstract class `cpr::InterceptorMulti` for intercepting `cpr::MultiPerform` objects.
The inherited class has to implement the function `std::vector<Response> intercept(MultiPerform&)`.
This function is automatically called for every added interceptor during the request with the session object belonging to the request passed as a parameter.
An essential point of the intercept function is that it must call the `std::vector<Response> proceed()` for `cpr::InterceptorMulti`) function implemented in `cpr::Interceptor` (`cpr::InterceptorMulti`). This is necessary to continue the request and get the `cpr::Response` (`std::vector<Response>`) object.

Here is an example implementation for an interceptor that logs the request without changing it:

{% raw %}
```c++
#include <iostream>
#include <vector>
#include <memory>
#include <cpr/cpr.h>

class LoggingInterceptorMulti : public InterceptorMulti {
  public:
    std::vector<Response> intercept(MultiPerform& multi) {
        // Log the request URL
        std::cout << "Request url:  " << multi.GetSessions().front().first->GetFullRequestUrl(); << '\n';

        // Proceed the request and save the response
        std::vector<cpr::Response> response = proceed(multi);

        // Log response status code
        std::cout << "Response status code:  " << response.front().status_code << '\n';

        // Return the stored response
        return response;
    }
};

int main() {
    Url url{"https://www.httpbin.org/get"};
    std::shared_ptr<Session> session = std::make_shared<Session>();
    session->SetUrl(url);

    MultiPerform multi;
    multi.AddSession(session);
    multi.AddInterceptor(std::make_shared<LoggingInterceptorMulti>());

    std::vector<Response> response = multi.Get();
}

/*
* Output produced by the LoggingInterceptorMulti:
*   Request url: https://www.httpbin.org/get
*   Response status code: 200
*/
```
{% endraw %}

## Multi-Perform

`cpr::MultiPerform` allows one to efficiently perform multiple requestst in a non-blocking fashion. To perform such a multi-perform, one must first create a `cpr::MultiPerform` object and add the desired session objects as shared pointers using the `AddSession` member function of `cpr::MultiPerform`:

{% raw %}
```c++
// Create and setup session objects
cpr::Url url{"https://www.httpbin.org/get"};
std::shared_ptr<cpr::Session> session_1 = std::make_shared<cpr::Session>();
std::shared_ptr<cpr::Session> session_2 = std::make_shared<cpr::Session>();
session_1->SetUrl(url);
session_2->SetUrl(url);

// Create MultiPerform object
cpr::MultiPerform multiperform;

// Add sessions to the MultiPerform
multiperform.AddSession(session_1);
multiperform.AddSession(session_2);
```
{% endraw %}

After adding the session objects, one can use the functions `Get`, `Delete`, `Put`, `Head`, `Options`, `Patch`, `Post`, and `Download` to execute the respective HTTP request on all added session objects and receive a vector of `cpr::Response` objects:

{% raw %}
```c++
// Perform GET request on all previously added sessions
std::vector<cpr::Response> responses = multiperform.Get();
```
{% endraw %}

Since added sessions should not be used by their own as long as they are in use by a MultiPerform, it is possible to remove added sessions with `RemoveSession`:

{% raw %}
```c++
// Remove the first session from the MultiPerform
multiperform.RemoveSession(session_1);
```
{% endraw %}

In addition, it is possible to make several different HTTP requests in one MultiPerform. To do this, one has to pass the HTTP method belonging to the session as the second parameter when adding it with `AddSession` and then execute the `Perform` function:

{% raw %}
```c++
// Add sessions to the MultiPerform and specifying the HTTP Method
multiperform.AddSession(session_1, cpr::MultiPerform::HttpMethod::GET_REQUEST);
multiperform.AddSession(session_2, cpr::MultiPerform::HttpMethod::HEAD_REQUEST);

// Perform the specified method per session
multiperform.Perform();
```
{% endraw %}

Note that `cpr::MultiPerform::HttpMethod::DOWNLOAD_REQUEST` cannot be combined with other request methods.

Finally, for ease of use, there are the following API functions, which automatically create a MultiPerform object and required session objects to perform a multi perform: `cpr::MultiGet`, `cpr::MultiDelete`, `cpr::MultiPut`, `cpr::MultiHead`, `cpr::MultiOptions`, `cpr::MultiPatch`, `cpr::MultiPost`:
{% raw %}
```c++
// Performs two HTTP Get requests to https://www.httpbin.org/get, where the first one has an additional timeout option set.
// The number of parameter tuples specifies the number of sessions which will be internally created
std::vector<Response> responses = MultiGet(std::tuple<Url, Timeout>{Url{"https://www.httpbin.org/get"}, Timeout{1000}}, std::tuple<Url>{Url{"https://www.httpbin.org/get"}});
```
{% endraw %}

## Manual domain name resolution (Resolve)

It is possible to specify which IP address should a specific domain name and port combination resolve to. It is possible to provide such a list of hostnames, addresses and ports. For example, it is possible to specify that www.example.com using port 443 should resolve to 127.0.0.1, but www.example.com using port 80 should resolve to 127.0.0.2, whereas subdomain.example.com using ports 443 and 80 should resolve to 127.0.0.3.

{% raw %}
```c++
cpr::Response getResponse = cpr::Get(cpr::Url{"https://www.example.com"},
                                     std::vector<cpr::Resolve>({cpr::Resolve{"www.example.com", "127.0.0.1", {443}},
                                                                cpr::Resolve{"www.example.com", "127.0.0.2", {80}}},
                                                                cpr::Resolve{"subdomain.example.com", "127.0.0.3"}}));
// Not specifying any ports defaults to 80 and 443
```
{% endraw %}

It is also possible to use the ```setResolve``` and ```setResolves``` methods, however, it should be noted that each invocation clears any previous values set before. In other words, do not use multiple consecutive calls to ```setResolve``` to set multiple manual resolutions, instead create a vector of ```cpr::Resolve```-s and pass them to ```setResolves```.
