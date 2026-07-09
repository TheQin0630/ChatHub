# src 设计说明

## 目标

`src/` 承担 ChatHub 的非 UI 逻辑，包括 TCP 网络、协议适配和业务控制。设计目标是让 QML 只处理界面状态和交互，不直接接触二进制协议细节。

## 目录结构

```text
src/
├── controller/
│   ├── ChatController.h
│   └── ChatController.cpp
├── network/
│   ├── NetworkClient.h
│   └── NetworkClient.cpp
└── protocol/
    ├── ProtocolAdapter.h
    └── ProtocolAdapter.cpp
```

## 分层职责

### ProtocolAdapter

位置：

```text
src/protocol/ProtocolAdapter.h
src/protocol/ProtocolAdapter.cpp
```

职责：

- 定义 `MessageType` 枚举。
- 定义通用帧结构 `Frame`。
- 将业务请求打包为二进制帧。
- 从 TCP 缓冲区中解析完整帧。
- 解析分页日志、topic 列表、连接列表、订阅者列表、规则响应等 payload。
- 校验 topic 和 payload 长度。

重要约束：

- 这是协议变化的隔离层。服务端字段变化时，优先修改 `ProtocolAdapter`，不要让 UI 或网络层直接拼协议。
- `tryParse` 支持 TCP 半包和粘包：数据不够时返回 `Incomplete`，数据完整时消费缓冲区，非法时返回 `Invalid`。

### NetworkClient

位置：

```text
src/network/NetworkClient.h
src/network/NetworkClient.cpp
```

职责：

- 管理 `QTcpSocket`。
- 连接和断开服务器。
- 发送 `ProtocolAdapter::Frame`。
- 接收 TCP 字节流并缓存。
- 使用 `ProtocolAdapter::tryParse` 拆出完整帧。
- 通过 Qt signal 上报连接、断开、网络错误、解析错误和收到的帧。

事件循环保护：

- `MaxFramesPerDrain = 12`
- `MaxDrainMillis = 6`

这两个限制避免一次性处理大量帧时长时间占用 UI 线程。剩余缓冲区会通过 `QTimer::singleShot(0, ...)` 继续处理。

### ChatController

位置：

```text
src/controller/ChatController.h
src/controller/ChatController.cpp
```

职责：

- 暴露给 QML 的 `Q_PROPERTY`：
  - `connected`
  - `busy`
  - `statusText`
- 暴露给 QML 的 `Q_INVOKABLE`：
  - 连接/断开。
  - 订阅/退订 topic。
  - 普通发送和高级发送。
  - 查询服务端日志、topic、连接列表、订阅者、fd-topic 关系。
  - 创建/删除 topic。
  - 设置连接级规则。
- 维护业务状态：
  - 当前昵称。
  - 已确认频道集合。
  - 待确认发送队列。
  - packetId/requestId/clientMessageId 自增编号。
- 处理服务端帧并转换为 QML 信号。

确认策略：

- 订阅成功以 `SubscribeAck` 为准。
- 普通发布以 `PublishAck` 为准。
- QoS1 扩展发布以 `PubRec1` 和 packetId 为准。
- 退订当前服务端无 ack，客户端发送成功后立即从本地频道集合移除。

## QML 交互接口

`ChatController` 通过信号把业务事件传给 QML：

- `channelConfirmed(topic)`：频道订阅确认。
- `channelRemoved(topic)`：频道被移除。
- `outgoingMessageQueued(...)`：发送消息已进入待确认队列。
- `outgoingMessageConfirmed(clientMessageId)`：消息确认。
- `incomingMessage(...)`：收到消息。
- `serverLogsReceived(...)`：收到服务端日志页。
- `serverTopicsReceived(...)`：收到服务端 topic 页。
- `serverConnectionsReceived(...)`：收到连接列表。
- `topicSubscribersReceived(...)`：收到 topic 订阅者。
- `fdTopicRelationReceived(...)`：收到 fd-topic 关系。
- `ruleSetResult(status)`：规则设置结果。
- `userMessage(message)`：需要 toast 展示的用户提示。

## 错误处理

- 网络错误由 `NetworkClient::networkError` 转发到 `ChatController`，再通过 `userMessage` 和本地日志提示用户。
- 协议解析错误由 `parseError` 上报，不让异常数据导致程序崩溃。
- 发送前检查连接状态、topic 合法性、payload 长度和当前频道订阅状态。

## 当前未完成或后置能力

- `addForwardRule` 和 `deleteForwardRule` 目前只提示尚未实现，尚未对接真实转发规则接口。
- `setRule` 要求先选择连接，实际逻辑由 `setConnectionRule` 完成。
- 退订没有服务端 ack 流程，当前是发送成功后本地移除。
- mock server 不覆盖所有高级管理帧。

## 测试现状

`tests/protocol_tests.cpp` 覆盖 `ProtocolAdapter` 的主要编解码和解析函数。

`tests/network_client_tests.cpp` 覆盖 `NetworkClient` 对 TCP 粘包突发帧的拆帧能力和事件循环响应性。

## 后续测试建议

- 为 `ChatController` 增加 fake `NetworkClient` 或本地 mock server 测试，覆盖状态流和 ack/reject 分支。
- 增加 QML 自动化测试或人工测试清单，覆盖布局、空状态、语言切换和主题切换。
- 增加端到端测试脚本，启动 mock server 和两个客户端验证互发消息。
- 增加异常路径测试：连接失败、非法帧、topic 非法、payload 超长、服务端拒绝订阅和发布。
