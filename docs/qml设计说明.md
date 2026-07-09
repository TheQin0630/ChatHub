# QML 设计说明

## 目标

QML 层负责 ChatHub 的界面布局、视觉状态、列表模型和用户交互。它通过 `ChatController` 调用 C++ 业务能力，不直接拼接协议帧。

## 文件结构

```text
Main.qml
qml/
├── components/
│   ├── AppButton.qml
│   ├── AppLogo.qml
│   ├── Field.qml
│   ├── ReadonlyLogText.qml
│   ├── SectionTitle.qml
│   ├── StyledCheckBox.qml
│   ├── StyledComboBox.qml
│   ├── StyledTabButton.qml
│   └── ThemeSwitch.qml
└── panels/
    ├── ChannelsPanel.qml
    ├── ChatPanel.qml
    ├── TopBar.qml
    └── WorkspacePanel.qml
```

## Main.qml

`Main.qml` 是应用壳层，职责包括：

- 创建 `ApplicationWindow`。
- 维护全局主题色变量。
- 维护 `darkMode`、`chineseMode` 并持久化到 `Settings`。
- 持有 QML `ListModel`：
  - `channelListModel`
  - `messageListModel`
  - `localLogListModel`
  - `serverLogListModel`
  - `serverTopicListModel`
  - `connectionListModel`
  - `subscriberListModel`
- 连接 `ChatController` 信号，把 C++ 事件转换为 UI 模型更新。
- 管理三栏 `SplitView` 布局。
- 展示底部 toast 提示。

主要运行时状态：

- `currentTopic`：当前选中频道。
- `messageRevision`：消息列表变化版本，用于驱动聊天区刷新。
- `serverTopicLoading` / `serverLogLoading`：服务端分页请求状态。
- `selectedRuleFd` / `selectedRuleTopic` / `relationMask`：规则管理 UI 状态。

## 主布局

窗口使用纵向布局：

1. 顶部 `TopBar`。
2. 下方横向 `SplitView`：
   - 左侧 `ChannelsPanel`
   - 中间 `ChatPanel`
   - 右侧 `WorkspacePanel`

默认窗口大小：

- `width = 1280`
- `height = 800`
- `minimumWidth = 1200`
- `minimumHeight = 700`

## TopBar.qml

顶部栏职责：

- 展示 App logo 和连接状态。
- 输入服务器 IP、端口、昵称。
- 展示当前用户头像和昵称。
- 切换语言。
- 切换浅色/深色主题。
- 连接和断开服务器。

关键设计：

- 输入框在连接后禁用，避免连接中修改身份信息造成状态不一致。
- 用户头像由昵称首字母生成。
- 语言和主题切换使用动画过渡。

## ChannelsPanel.qml

左侧频道栏职责：

- 输入 topic 并请求加入频道。
- 展示已加入频道。
- 展示 pending 状态、订阅状态和未读数。
- 悬停显示 `Leave` 按钮。
- 提供 Settings 和 About 入口。

About 弹窗展示项目地址：

```text
https://github.com/TheQin0630/ChatHub
```

Settings 当前只做视觉入口，没有业务交互。

## ChatPanel.qml

中间聊天区职责：

- 展示当前频道标题和消息数量。
- 展示当前频道消息。
- 在无频道或无消息时展示空状态卡片。
- 消息气泡区分自己和他人。
- 他人消息展示昵称首字母头像。
- 底部提供频道选择、消息输入、Options 和发送按钮。
- Options 默认收起，展开后显示 QoS1 ack 和 Retain。

频道隔离策略：

- `messageModel` 保存所有频道消息。
- delegate 通过 `model.topic === currentTopic` 判断是否属于当前频道。
- 非当前频道 delegate 设置为不可见、高度为 0，避免频道切换后旧消息残留。
- `reuseItems: false` 用于降低 ListView delegate 复用造成状态错乱的风险。

空状态：

- 没有加入频道时提示加入频道。
- 已进入频道但无消息时提示开始对话。
- 已有消息时顶部显示开始对话提示卡片，消息列表继续向下展示。

## WorkspacePanel.qml

右侧工作区职责：

- Overview：显示本地会话概览。
- Server：显示服务端 topic、连接列表、订阅者列表、规则设置和关系查询。
- Logs：显示本地日志和服务端日志。

数据来源：

- 服务端 topic 列表来自 `ChatController::requestServerTopics` 和 `TopicListResponse`。
- 连接列表来自 `ConnectionListResponse`。
- 订阅者列表来自 `TopicSubscribersResponse`。
- fd-topic 关系来自 `FdTopicRelationResponse`。
- 本地日志来自 `ChatController::logAdded`。

## components

通用组件用于统一视觉：

- `AppButton`：统一按钮样式。
- `Field`：统一输入框。
- `StyledComboBox`：频道选择下拉框。
- `StyledCheckBox`：高级发送选项复选框。
- `StyledTabButton`：Workspace 页签按钮。
- `ThemeSwitch`：浅色/深色主题切换。
- `AppLogo`：左上角应用图标。
- `SectionTitle`：面板标题。
- `ReadonlyLogText`：只读日志文本。

## 主题系统

主题变量定义在 `Main.qml` 的 `appTheme` 中。颜色通过 `mixThemeColor(light, dark)` 按 `themeProgress` 混合，实现浅色和深色主题之间的过渡。

组件只读取 `theme`，不各自硬编码大面积颜色，这样可以统一调整视觉。

## 中英文切换

`chineseMode` 保存在 `Settings`，应用启动时恢复。

当前 UI 主要文案已经接入 `chineseMode`。后续如果继续扩展界面，应遵循同一模式：

```qml
text: root.chineseMode ? "中文文案" : "English text"
```

## QML 与 C++ 边界

QML 可以调用：

- `connectToServer`
- `disconnectFromServer`
- `subscribeTopic`
- `unsubscribeTopic`
- `publishMessageAdvanced`
- `requestServerTopics`
- `requestConnectionList`
- `requestTopicSubscribers`
- `requestFdTopicRelation`
- `setConnectionRule`

QML 不应该直接调用 `ProtocolAdapter` 或自行构造二进制 payload。

## 已知注意点

- 当前 UI 为桌面窗口设计，最小宽度为 1200，未按手机窄屏适配。
- 右侧 Server 的删除服务端 topic 接口 C++ 已有 `deleteTopic(topic)`，但 UI 还没有做删除按钮。
- Settings 按钮暂时没有交互。
- Forward rule 的 C++ 占位函数尚未实现真实转发规则管理。
