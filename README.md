# ChatHub

ChatHub 是一个基于 Qt 6 / QML 的桌面聊天室客户端，用 topic 发布/订阅模型包装聊天室频道。客户端通过 TCP 连接课程联调服务器，支持订阅频道、退订频道、发送消息、接收消息、查看服务端频道列表、查看本地日志、设置连接级规则，并提供中英文切换、深浅主题切换和 Windows 可执行包部署。

## 最新发布

当前版本：[ChatHub v0.1.0](https://github.com/TheQin0630/ChatHub/releases/tag/v0.1.0)

- Windows x64 运行包：[ChatHub-win64.zip](https://github.com/TheQin0630/ChatHub/releases/download/v0.1.0/ChatHub-win64.zip)
- 包含别名、连接管理、完整本地 mock 与联调测试。

## 功能概览

- 顶部连接栏：服务器 IP、端口、昵称、连接/断开、当前用户、语言切换、深浅主题切换。
- 左侧频道栏：输入 topic 加入频道、频道列表、未读数、退订、Settings/About 入口。
- 中间聊天区：当前频道标题、消息气泡、头像首字母、空状态提示、频道选择、消息输入、发送按钮、QoS1/Retain 选项。
- 右侧 Workspace：Overview、Server、Logs 三个视图，展示频道概览、服务端频道列表、连接/订阅者/规则状态、本地日志。
- 协议适配：所有二进制帧打包和解析集中在 `ProtocolAdapter`，UI 不直接拼协议。
- 网络层：`NetworkClient` 只负责 TCP 连接、缓冲区拆帧、发送帧和错误信号。
- 控制层：`ChatController` 负责连接状态、订阅确认、发布确认、服务端列表查询和 QML 信号桥接。

## 项目结构

```text
ChatHub/
├── CMakeLists.txt
├── main.cpp
├── Main.qml
├── src/
│   ├── controller/
│   ├── network/
│   └── protocol/
├── qml/
│   ├── components/
│   └── panels/
├── resources/
├── tests/
└── docs/
```

## 文档

- [用户端使用说明](docs/用户端使用说明.md)
- [通信协议](docs/通信协议.md)
- [src 设计说明](docs/src设计说明.md)
- [QML 设计说明](docs/qml设计说明.md)

## 构建环境

- Qt 6.10 或更高版本，当前项目已在 Qt 6.11.1 MinGW 64-bit kit 下验证。
- CMake 3.16 或更高版本。
- Windows 下推荐使用 Qt Creator 打开项目，也可以使用 PowerShell 执行 CMake 命令。

## 构建

Debug 构建：

```powershell
cmake --build build\Desktop_Qt_6_11_1_MinGW_64_bit_Debug
```

Release 构建：

```powershell
cmake --build build\Desktop_Qt_6_11_1_MinGW_64_bit_Release --config Release
```

## 测试

运行 Debug 测试：

```powershell
ctest --test-dir build\Desktop_Qt_6_11_1_MinGW_64_bit_Debug --output-on-failure
```

运行 Release 测试：

```powershell
ctest --test-dir build\Desktop_Qt_6_11_1_MinGW_64_bit_Release --output-on-failure
```

运行 QML lint：

```powershell
cmake --build build\Desktop_Qt_6_11_1_MinGW_64_bit_Debug --target ChatHub_qmllint
```

当前测试覆盖：

- `protocol_tests`：验证二进制帧打包/解析、聊天 payload、扩展发布、QoS1、Retain、分页响应、规则请求、连接列表、订阅者列表、关系查询、输入校验。
- `network_client_tests`：使用本地 `QTcpServer` 突发发送 240 个帧，验证 `NetworkClient` 连续拆帧能力和事件循环响应性。

后续建议补充：

- `ChatController` 状态流测试：连接、订阅、发布、ack、reject、断线和错误提示。
- Mock server 端到端测试：两个客户端订阅同一 topic 后互发消息。
- QML UI 测试：频道切换、空状态、按钮启用/禁用、语言/主题持久化。
- 打包 smoke test：在无 Qt 开发环境的机器上启动 `dist/ChatHub-win64/ChatHub.exe`。

## Mock Server

项目提供 `tests/mock_server.py` 作为本地全协议演示服务器，支持频道、订阅、普通/可靠/保留消息、别名、连接/订阅者查询、规则、强制退订与日志分页。完整命令、自动化测试和答辩流程见 [联调与演示指南](docs/联调与演示指南.md)。

```powershell
python tests\mock_server.py --host 127.0.0.1 --port 1883
```

然后启动两个 ChatHub 客户端，连接 `127.0.0.1:1883`，加入相同频道即可验证收发。

## 打包

Release exe 生成后，可使用 Qt 的 `windeployqt` 收集运行依赖：

```powershell
windeployqt --release --qmldir . dist\ChatHub-win64\ChatHub.exe
```

当前本地发布包路径：

```text
dist/ChatHub-win64/
dist/ChatHub-win64.zip
```

`build/`、`dist/`、可执行文件和 DLL 属于构建产物，默认不提交到 Git。
