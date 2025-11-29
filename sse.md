---
layout: default
title: cpr - Server-Sent Events (SSE)
---

# Server-Sent Events (SSE) Support

CPR supports Server-Sent Events (SSE), which allows servers to push real-time updates to clients over HTTP. SSE is a standard for unidirectional server-to-client communication over HTTP, commonly used for notifications, live updates, and streaming data.

## Basic Usage

{% raw %}
```c++
#include <cpr/cpr.h>
#include <iostream>

int main() {
    cpr::Session session;
    session.SetUrl(cpr::Url{"https://example.com/events"});

    // Set up SSE callback
    session.SetServerSentEventCallback(
        cpr::ServerSentEventCallback{
            [](cpr::ServerSentEvent&& event, intptr_t userdata) {
                std::cout << "Event Type: " << event.event << std::endl;
                std::cout << "Data: " << event.data << std::endl;

                if (event.id.has_value()) {
                    std::cout << "ID: " << event.id.value() << std::endl;
                }

                if (event.retry.has_value()) {
                    std::cout << "Retry: " << event.retry.value() << " ms" << std::endl;
                }

                // Return true to continue receiving events, false to stop
                return true;
            }
        }
    );

    cpr::Response response = session.Get();

    std::cout << "Status: " << response.status_code << std::endl;

    return 0;
}
```
{% endraw %}

## ServerSentEvent Structure

Each SSE event contains the following fields:

{% raw %}
```c++
struct ServerSentEvent {
    std::optional<std::string> id;    // Event ID for tracking/resumption
    std::string event;                // Event type (default: "message")
    std::string data;                 // Event data
    std::optional<size_t> retry;      // Reconnection time in milliseconds
};
```
{% endraw %}

## Using with User Data

You can pass custom user data to the SSE callback:

{% raw %}
```c++
#include <cpr/cpr.h>
#include <iostream>
#include <vector>

int main() {
    std::vector<std::string> received_events;

    cpr::Session session;
    session.SetUrl(cpr::Url{"https://example.com/events"});

    // Pass a pointer to user data
    session.SetServerSentEventCallback(
        cpr::ServerSentEventCallback{
            [](cpr::ServerSentEvent&& event, intptr_t userdata) {
                auto* events = reinterpret_cast<std::vector<std::string>*>(userdata);
                events->push_back(event.data);
                return true;
            },
            reinterpret_cast<intptr_t>(&received_events)
        }
    );

    session.Get();

    std::cout << "Received " << received_events.size() << " events" << std::endl;

    return 0;
}
```
{% endraw %}

## Conditional Event Processing

You can control when to stop receiving events by returning `false` from the callback:

{% raw %}
```c++
#include <cpr/cpr.h>
#include <iostream>

int main() {
    int event_count = 0;

    cpr::Session session;
    session.SetUrl(cpr::Url{"https://example.com/events"});

    session.SetServerSentEventCallback(
        cpr::ServerSentEventCallback{
            [](cpr::ServerSentEvent&& event, intptr_t userdata) {
                int* count = reinterpret_cast<int*>(userdata);
                (*count)++;

                std::cout << "Event #" << *count << ": " << event.data << std::endl;

                // Stop after receiving 10 events
                return *count < 10;
            },
            reinterpret_cast<intptr_t>(&event_count)
        }
    );

    session.Get();

    std::cout << "Processed " << event_count << " events" << std::endl;

    return 0;
}
```
{% endraw %}

## Using SetOption

SSE callbacks can be set using the `SetOption` method:

{% raw %}
```c++
#include <cpr/cpr.h>
#include <iostream>

int main() {
    cpr::Session session;

    session.SetOption(cpr::Url{"https://example.com/events"});
    session.SetOption(
        cpr::ServerSentEventCallback{
            [](cpr::ServerSentEvent&& event, intptr_t /*userdata*/) {
                std::cout << event.data << std::endl;
                return true;
            }
        }
    );

    session.Get();

    return 0;
}
```
{% endraw %}

## Event Types

SSE events can have different types. By default, events have type `"message"`, but servers can specify custom event types:

{% raw %}
```c++
session.SetServerSentEventCallback(
    cpr::ServerSentEventCallback{
        [](cpr::ServerSentEvent&& event, intptr_t /*userdata*/) {
            if (event.event == "update") {
                std::cout << "Update: " << event.data << std::endl;
            } else if (event.event == "notification") {
                std::cout << "Notification: " << event.data << std::endl;
            } else {
                std::cout << "Message: " << event.data << std::endl;
            }
            return true;
        }
    }
);
```
{% endraw %}

## Event IDs and Retry

SSE events can include additional metadata:

- **id**: A unique identifier for the event, useful for resuming connections after a disconnect
- **retry**: Server-suggested reconnection time in milliseconds

{% raw %}
```c++
std::optional<std::string> last_event_id;

session.SetServerSentEventCallback(
    cpr::ServerSentEventCallback{
        [](cpr::ServerSentEvent&& event, intptr_t userdata) {
            auto* last_id = reinterpret_cast<std::optional<std::string>*>(userdata);

            if (event.id.has_value()) {
                *last_id = event.id.value();
            }

            std::cout << "Data: " << event.data << std::endl;
            return true;
        },
        reinterpret_cast<intptr_t>(&last_event_id)
    }
);

session.Get();

// Use last_event_id to resume from last received event if needed
if (last_event_id.has_value()) {
    session.SetHeader(cpr::Header{{"Last-Event-ID", last_event_id.value()}});
    session.Get();
}
```
{% endraw %}

## SSE Format

Server-Sent Events follow this text-based format according to the [HTML5 specification](https://html.spec.whatwg.org/multipage/server-sent-events.html):

```
event: custom
id: 123
retry: 5000
data: First line of data
data: Second line of data

```

- Each event is separated by a blank line (`\n\n`)
- Multiple `data:` fields are concatenated with newlines
- Lines starting with `:` are comments and are ignored
- Events without data are ignored

## Important Notes

- **Mutual Exclusivity**: SSE callbacks are mutually exclusive with regular `WriteCallback`. If you set an SSE callback, don't set a write callback and vice versa.
- **Callback Invocation**: The callback is invoked for each complete SSE event as it's received from the server.
- **Stopping Reception**: Return `false` from the callback to stop receiving events and close the connection.
- **Comment Handling**: Comments (lines starting with `:`) are automatically ignored per the SSE specification.
- **Empty Data**: Events without data fields are ignored per the SSE specification.
- **Buffering**: The parser correctly handles chunked data, so events can arrive in multiple chunks and will be properly assembled.

## Common Use Cases

### Real-time Notifications

{% raw %}
```c++
cpr::Session session;
session.SetUrl(cpr::Url{"https://api.example.com/notifications"});
session.SetServerSentEventCallback(
    cpr::ServerSentEventCallback{
        [](cpr::ServerSentEvent&& event, intptr_t /*userdata*/) {
            if (event.event == "notification") {
                std::cout << "New notification: " << event.data << std::endl;
            }
            return true;  // Keep listening
        }
    }
);
session.Get();
```
{% endraw %}

### Live Data Streams

{% raw %}
```c++
cpr::Session session;
session.SetUrl(cpr::Url{"https://api.example.com/stock-prices"});
session.SetServerSentEventCallback(
    cpr::ServerSentEventCallback{
        [](cpr::ServerSentEvent&& event, intptr_t /*userdata*/) {
            if (event.event == "price-update") {
                // Parse JSON data and update UI
                std::cout << "Price update: " << event.data << std::endl;
            }
            return true;
        }
    }
);
session.Get();
```
{% endraw %}

### Progress Updates

{% raw %}
```c++
cpr::Session session;
session.SetUrl(cpr::Url{"https://api.example.com/long-running-task/123"});
session.SetServerSentEventCallback(
    cpr::ServerSentEventCallback{
        [](cpr::ServerSentEvent&& event, intptr_t /*userdata*/) {
            if (event.event == "progress") {
                std::cout << "Progress: " << event.data << std::endl;
            } else if (event.event == "complete") {
                std::cout << "Task completed!" << std::endl;
                return false;  // Stop listening
            }
            return true;
        }
    }
);
session.Get();
```
{% endraw %}
