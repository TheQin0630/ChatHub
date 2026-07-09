# ChatHub

ChatHub is a Qt 6 desktop client for a topic-based publish/subscribe chat system.

## Features

- TCP client connection management
- Topic subscription and unsubscribe flow
- Topic-based message publishing and receiving
- Server topic list view
- Connection rule management UI
- Light/dark theme switch
- Chinese/English UI switch

## Build

Open the project in Qt Creator, or build with CMake using a Qt 6.10+ kit:

```powershell
cmake --build build\Desktop_Qt_6_11_1_MinGW_64_bit_Debug
```

## Tests

```powershell
ctest --test-dir build\Desktop_Qt_6_11_1_MinGW_64_bit_Debug --output-on-failure
```
