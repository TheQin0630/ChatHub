import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../components"

Rectangle {
    id: root
    required property var theme
    required property var chatController
    required property var messageModel
    required property var channelModel
    required property string currentTopic
    required property int messageRevision
    required property int messageCount
    required property bool chineseMode
    property int ownRelationMask: 0
    property bool advancedSendOpen: false

    signal sendRequested(string text, bool reliable, bool retain)
    signal channelSelected(string topic)
    signal refreshRequested()

    function positionAtEnd() {
        messageView.forceLayout()
        messageView.positionViewAtEnd()
    }

    function clearMessage() {
        messageInput.clear()
    }

    function prefillMessage(message) {
        messageInput.text = message
        messageInput.forceActiveFocus()
    }

    function syncChannelCombo() {
        for (let i = 0; i < root.channelModel.count; ++i) {
            if (root.channelModel.get(i).topic === root.currentTopic) {
                channelCombo.currentIndex = i
                return
            }
        }
        channelCombo.currentIndex = -1
    }

    function avatarColor(user, own, forwarded) {
        if (own) return root.theme.accent
        if (forwarded) return root.theme.accentSoft
        const first = String(user).charCodeAt(0)
        if (first % 3 === 0) return "#dbeafe"
        if (first % 3 === 1) return "#ede9fe"
        return "#fef3c7"
    }

    function avatarTextColor(user, forwarded) {
        if (forwarded) return root.theme.accent
        const first = String(user).charCodeAt(0)
        if (first % 3 === 0) return root.theme.accent
        if (first % 3 === 1) return "#7c3aed"
        return "#b7791f"
    }

    onCurrentTopicChanged: syncChannelCombo()

    color: theme.surfaceAlt
    antialiasing: true

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 70
            color: root.theme.surfaceAlt
            border.color: root.theme.line
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Label {
                        Layout.fillWidth: true
                        text: root.currentTopic === "" ? (root.chineseMode ? "未选择频道" : "No channel selected") : "#  " + root.currentTopic
                        color: root.theme.text
                        font.pixelSize: 18
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        renderType: Text.CurveRendering
                    }

                    Label {
                        text: root.currentTopic === ""
                              ? (root.chineseMode ? "从左侧加入一个频道。" : "Join a channel from the left panel.")
                              : (root.chineseMode ? ("本次会话 " + root.messageCount + " 条消息") : (root.messageCount + " messages in this session"))
                        color: root.theme.subtext
                        font.pixelSize: 12
                        renderType: Text.CurveRendering
                    }
                }

                Row {
                    spacing: 7
                    Repeater {
                        model: [
                            { label: root.chineseMode ? "订阅" : "Sub", ok: (root.ownRelationMask & 1) !== 0 },
                            { label: root.chineseMode ? "接收" : "Recv", ok: (root.ownRelationMask & 1) !== 0 && (root.ownRelationMask & 4) === 0 },
                            { label: root.chineseMode ? "发布" : "Pub", ok: (root.ownRelationMask & 1) !== 0 && (root.ownRelationMask & 8) === 0 }
                        ]
                        delegate: Row {
                            spacing: 4
                            Rectangle { width: 7; height: 7; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: modelData.ok ? root.theme.success : root.theme.danger }
                            Label { text: modelData.label; color: root.theme.subtext; font.pixelSize: 11 }
                        }
                    }
                }

                AppButton {
                    theme: root.theme
                    Layout.preferredWidth: 84
                    text: root.chineseMode ? "刷新" : "Refresh"
                    fill: root.theme.buttonGlassBg
                    foreground: root.theme.accent
                    enabled: root.chatController.connected
                    onClicked: root.refreshRequested()
                }
            }
        }

        ListView {
            id: messageView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.currentTopic === "" ? null : root.messageModel
            spacing: 14
            leftMargin: 24
            rightMargin: 24
            topMargin: 16
            bottomMargin: 20
            reuseItems: false

            header: Item {
                width: messageView.width
                height: 0
                visible: false

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 18
                    width: Math.min(parent.width - 72, 1060)
                    height: 300
                    radius: 24
                    color: root.theme.elevated
                    border.color: root.theme.line
                    border.width: 1
                    antialiasing: true
                    opacity: parent.visible ? 1 : 0
                    scale: parent.visible ? 1 : 0.97

                    Behavior on opacity {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }

                    Behavior on scale {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 34
                        anchors.rightMargin: 34
                        anchors.topMargin: 34
                        anchors.bottomMargin: 30
                        spacing: 16

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 76
                            Layout.preferredHeight: 76
                            radius: 38
                            color: root.theme.accentSoft
                            antialiasing: true

                            Canvas {
                                anchors.centerIn: parent
                                width: 44
                                height: 44
                                antialiasing: true
                                onPaint: {
                                    const ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.strokeStyle = root.theme.accent
                                    ctx.lineWidth = 3
                                    ctx.lineJoin = "round"
                                    ctx.lineCap = "round"
                                    ctx.beginPath()
                                    ctx.moveTo(13, 12)
                                    ctx.lineTo(31, 12)
                                    ctx.quadraticCurveTo(36, 12, 36, 17)
                                    ctx.lineTo(36, 25)
                                    ctx.quadraticCurveTo(36, 30, 31, 30)
                                    ctx.lineTo(23, 30)
                                    ctx.lineTo(15, 36)
                                    ctx.lineTo(17, 30)
                                    ctx.lineTo(13, 30)
                                    ctx.quadraticCurveTo(8, 30, 8, 25)
                                    ctx.lineTo(8, 17)
                                    ctx.quadraticCurveTo(8, 12, 13, 12)
                                    ctx.stroke()
                                }
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: root.chineseMode ? "开始对话" : "Start the conversation"
                            color: root.theme.text
                            font.pixelSize: 34
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            renderType: Text.CurveRendering
                        }

                        Label {
                            Layout.fillWidth: true
                            text: root.chineseMode ? "这个频道暂时很安静。发送一条消息，或者从下面的建议开始。" : "This channel is quiet for now. Send a message or try one of the suggestions below."
                            color: root.theme.subtext
                            font.pixelSize: 16
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            renderType: Text.CurveRendering
                        }

                        Row {
                            id: headerSuggestionRow
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: Math.min(parent.width - 28, 960)
                            Layout.preferredHeight: 62
                            spacing: 12

                            Repeater {
                                model: root.chineseMode
                                       ? [{ icon: "?", label: "问个问题" }, { icon: "✎", label: "分享更新" }, { icon: "#", label: "创建频道" }, { icon: "⌁", label: "检查服务" }]
                                       : [{ icon: "?", label: "Ask a question" }, { icon: "✎", label: "Share an update" }, { icon: "#", label: "Create a channel" }, { icon: "⌁", label: "Check server status" }]

                                delegate: Rectangle {
                                    width: (headerSuggestionRow.width - headerSuggestionRow.spacing * 3) / 4
                                    height: 56
                                    radius: 15
                                    color: root.theme.buttonGlassBg
                                    border.color: root.theme.glassBorder
                                    border.width: 1
                                    antialiasing: true

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 18
                                        anchors.rightMargin: 16
                                        spacing: 10

                                        Text {
                                            width: 28
                                            height: parent.height
                                            text: modelData.icon
                                            color: root.theme.text
                                            font.pixelSize: 22
                                            font.weight: Font.Medium
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            renderType: Text.CurveRendering
                                        }

                                        Label {
                                            width: parent.width - 38
                                            height: parent.height
                                            text: modelData.label
                                            color: root.theme.text
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                            renderType: Text.CurveRendering
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            delegate: Item {
                property bool currentMessage: model.topic === root.currentTopic
                width: messageView.width - 48
                height: currentMessage ? bubble.height + 8 : 0
                visible: currentMessage
                opacity: currentMessage ? 1 : 0
                enabled: currentMessage
                clip: !currentMessage

                Rectangle {
                    id: avatar
                    visible: !model.own
                    width: 46
                    height: 46
                    radius: 23
                    anchors.left: parent.left
                    anchors.top: bubble.top
                    color: root.avatarColor(model.user, model.own, model.forwarded)
                    antialiasing: true

                    Text {
                        anchors.centerIn: parent
                        text: String(model.user).slice(0, 1).toUpperCase()
                        color: root.avatarTextColor(model.user, model.forwarded)
                        font.pixelSize: 18
                        font.weight: Font.Medium
                        renderType: Text.CurveRendering
                    }
                }

                Rectangle {
                    id: bubble
                    width: Math.min(parent.width * 0.72, Math.max(210, Math.min(parent.width - 60, bodyText.implicitWidth + 40)))
                    height: bubbleColumn.implicitHeight + 20
                    radius: 14
                    color: model.own ? root.theme.accent : root.theme.elevated
                    border.color: model.own ? "transparent" : root.theme.line
                    border.width: model.own ? 0 : 1
                    antialiasing: true
                    anchors.right: model.own ? parent.right : undefined
                    anchors.left: model.own ? undefined : avatar.right
                    anchors.leftMargin: model.own ? 0 : 12

                    Column {
                        id: bubbleColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 6

                        RowLayout {
                            width: parent.width
                            spacing: 8

                            Label {
                                Layout.fillWidth: true
                                text: model.user
                                color: model.own ? root.theme.accentText : root.theme.text
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                renderType: Text.CurveRendering
                            }

                            Label {
                                text: model.state === "sending"
                                      ? (root.chineseMode ? "发送中" : "Sending")
                                      : (model.state === "failed" ? (root.chineseMode ? "发送失败" : "Failed") : model.time)
                                color: model.own ? root.theme.ownMeta : root.theme.subtext
                                font.pixelSize: 11
                                renderType: Text.CurveRendering
                            }
                        }

                        Label {
                            visible: model.forwarded
                            text: (root.chineseMode ? "转发自 " : "Forwarded from ") + model.sourceTopic
                            color: model.own ? root.theme.ownMeta : root.theme.warning
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            width: parent.width
                            renderType: Text.CurveRendering
                        }

                        Text {
                            id: bodyText
                            width: parent.width
                            text: model.message
                            color: model.own ? root.theme.accentText : root.theme.text
                            font.pixelSize: 14
                            lineHeight: 1.18
                            wrapMode: Text.Wrap
                            maximumLineCount: 10
                            elide: Text.ElideRight
                            renderType: Text.CurveRendering
                        }
                    }
                }
            }

            Rectangle {
                id: emptyState
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 72
                width: Math.min(parent.width - 72, 1060)
                height: 300
                radius: 24
                color: root.theme.elevated
                border.color: root.theme.line
                border.width: 1
                antialiasing: true
                visible: root.messageRevision >= 0 && (root.currentTopic === "" || root.messageCount === 0)
                opacity: visible ? 1 : 0
                scale: visible ? 1 : 0.97

                Behavior on opacity {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                Behavior on scale {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 68
                    spacing: 16

                    Rectangle {
                        width: 76
                        height: 76
                        radius: 38
                        color: root.theme.accentSoft
                        antialiasing: true
                        anchors.horizontalCenter: parent.horizontalCenter

                        Canvas {
                            anchors.centerIn: parent
                            width: 44
                            height: 44
                            antialiasing: true
                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                ctx.strokeStyle = root.theme.accent
                                ctx.lineWidth = 3
                                ctx.lineJoin = "round"
                                ctx.lineCap = "round"
                                    ctx.beginPath()
                                    ctx.moveTo(13, 12)
                                    ctx.lineTo(31, 12)
                                    ctx.quadraticCurveTo(36, 12, 36, 17)
                                    ctx.lineTo(36, 25)
                                    ctx.quadraticCurveTo(36, 30, 31, 30)
                                    ctx.lineTo(23, 30)
                                    ctx.lineTo(15, 36)
                                    ctx.lineTo(17, 30)
                                    ctx.lineTo(13, 30)
                                    ctx.quadraticCurveTo(8, 30, 8, 25)
                                    ctx.lineTo(8, 17)
                                    ctx.quadraticCurveTo(8, 12, 13, 12)
                                    ctx.stroke()
                                }
                            }
                    }

                    Label {
                        width: parent.width
                        text: root.currentTopic === ""
                              ? (root.chineseMode ? "你还没有加入任何频道" : "You haven't joined any channels yet")
                              : (root.chineseMode ? "开始对话" : "Start the conversation")
                        color: root.theme.text
                        font.pixelSize: 34
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        renderType: Text.CurveRendering
                    }

                    Label {
                        width: parent.width
                        text: root.currentTopic === ""
                              ? (root.chineseMode ? "从左侧加入频道，然后开始聊天。" : "Join a channel from the left panel to start chatting.")
                              : (root.chineseMode ? "这个频道暂时很安静。发送一条消息，或者从下面的建议开始。" : "This channel is quiet for now. Send a message or try one of the suggestions below.")
                        color: root.theme.subtext
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        renderType: Text.CurveRendering
                    }

                    Row {
                        id: emptySuggestionRow
                        width: Math.min(parent.width - 28, 960)
                        height: 62
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12
                        visible: root.currentTopic !== ""

                        Repeater {
                            model: root.chineseMode
                                   ? [{ icon: "?", label: "问个问题" }, { icon: "✎", label: "分享更新" }, { icon: "#", label: "创建频道" }, { icon: "⌁", label: "检查服务" }]
                                   : [{ icon: "?", label: "Ask a question" }, { icon: "✎", label: "Share an update" }, { icon: "#", label: "Create a channel" }, { icon: "⌁", label: "Check server status" }]

                            delegate: Rectangle {
                                width: (emptySuggestionRow.width - emptySuggestionRow.spacing * 3) / 4
                                height: 56
                                radius: 15
                                color: root.theme.buttonGlassBg
                                border.color: root.theme.glassBorder
                                border.width: 1
                                antialiasing: true

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 18
                                    anchors.rightMargin: 16
                                    spacing: 10

                                    Text {
                                        width: 28
                                        height: parent.height
                                        text: modelData.icon
                                        color: root.theme.text
                                        font.pixelSize: 22
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        renderType: Text.CurveRendering
                                    }

                                    Label {
                                        width: parent.width - 38
                                        height: parent.height
                                        text: modelData.label
                                        color: root.theme.text
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                        renderType: Text.CurveRendering
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            property int targetHeight: root.advancedSendOpen ? 126 : 78
            Layout.fillWidth: true
            Layout.preferredHeight: targetHeight
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.bottomMargin: 12
            radius: 18
            color: root.theme.panel
            border.color: root.theme.line
            border.width: 1
            antialiasing: true

            Behavior on targetHeight {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    spacing: 12

                    StyledComboBox {
                        id: channelCombo
                        theme: root.theme
                        Layout.preferredWidth: Math.min(190, Math.max(150, parent.width * 0.20))
                        Layout.preferredHeight: 58
                        model: root.channelModel
                        enabled: root.channelModel.count > 0
                        onActivated: root.channelSelected(root.channelModel.get(currentIndex).topic)
                    }

                    Field {
                        id: messageInput
                        theme: root.theme
                        Layout.fillWidth: true
                        Layout.preferredHeight: 58
                        placeholderText: {
                            if (!root.chatController.connected) return root.chineseMode ? "请先连接服务器" : "Connect to server first"
                            if (root.currentTopic === "") return root.chineseMode ? "请先加入频道" : "Join a channel first"
                            return root.chineseMode ? "输入消息..." : "Type your message..."
                        }
                        enabled: root.chatController.connected && root.currentTopic !== ""
                        onAccepted: sendButton.clicked()
                    }

                    Button {
                        id: optionsButton
                        Layout.preferredWidth: 128
                        Layout.preferredHeight: 54
                        Layout.alignment: Qt.AlignVCenter
                        text: root.advancedSendOpen ? (root.chineseMode ? "完成" : "Done") : (root.chineseMode ? "选项" : "Options")
                        hoverEnabled: true
                        onClicked: root.advancedSendOpen = !root.advancedSendOpen

                        contentItem: Row {
                            anchors.centerIn: parent
                            width: Math.min(parent.width - 26, iconCanvas.width + 10 + optionsText.implicitWidth)
                            height: parent.height
                            spacing: 10

                            Canvas {
                                id: iconCanvas
                                width: 32
                                height: 28
                                anchors.verticalCenter: parent.verticalCenter
                                antialiasing: true

                                onPaint: {
                                    const ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.strokeStyle = root.theme.accent
                                    ctx.lineWidth = 2.6
                                    ctx.lineCap = "round"
                                    ctx.lineJoin = "round"

                                    ctx.beginPath()
                                    ctx.moveTo(4, 9)
                                    ctx.lineTo(17, 9)
                                    ctx.moveTo(25, 9)
                                    ctx.lineTo(29, 9)
                                    ctx.stroke()

                                    ctx.beginPath()
                                    ctx.arc(21, 9, 4, 0, Math.PI * 2)
                                    ctx.stroke()

                                    ctx.beginPath()
                                    ctx.moveTo(4, 20)
                                    ctx.lineTo(10, 20)
                                    ctx.moveTo(18, 20)
                                    ctx.lineTo(29, 20)
                                    ctx.stroke()

                                    ctx.beginPath()
                                    ctx.arc(14, 20, 4, 0, Math.PI * 2)
                                    ctx.stroke()
                                }
                            }

                            Label {
                                id: optionsText
                                height: parent.height
                                text: optionsButton.text
                                color: root.theme.text
                                font.pixelSize: 15
                                font.weight: Font.Medium
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                renderType: Text.CurveRendering
                            }
                        }

                        background: Rectangle {
                            radius: height / 2
                            color: optionsButton.hovered ? root.theme.buttonGlassHover : root.theme.buttonGlassBg
                            border.color: root.theme.glassBorder
                            border.width: 1
                            antialiasing: true

                            Behavior on color {
                                ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    Button {
                        id: sendButton
                        Layout.preferredWidth: 54
                        Layout.preferredHeight: 54
                        Layout.alignment: Qt.AlignVCenter
                        hoverEnabled: true
                        enabled: root.chatController.connected && root.currentTopic !== "" && messageInput.text.trim().length > 0
                        onClicked: root.sendRequested(messageInput.text.trim(), reliableCheck.checked, retainCheck.checked)

                        contentItem: Item {
                            Canvas {
                                anchors.centerIn: parent
                                width: 32
                                height: 32
                                antialiasing: true
                                opacity: sendButton.enabled ? 1 : 0.62

                                onPaint: {
                                    const ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.strokeStyle = root.theme.accentText
                                    ctx.lineWidth = 2.8
                                    ctx.lineCap = "round"
                                    ctx.lineJoin = "round"
                                    ctx.beginPath()
                                    ctx.moveTo(7, 16)
                                    ctx.lineTo(26, 8)
                                    ctx.lineTo(19, 26)
                                    ctx.lineTo(15, 18)
                                    ctx.lineTo(7, 16)
                                    ctx.stroke()
                                }
                            }
                        }

                        background: Rectangle {
                            radius: width / 2
                            color: sendButton.enabled
                                   ? (sendButton.hovered ? root.theme.accentHover : root.theme.accent)
                                   : root.theme.buttonDisabledBg
                            border.color: "transparent"
                            border.width: 0
                            antialiasing: true

                            Behavior on color {
                                ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.advancedSendOpen
                    opacity: root.advancedSendOpen ? 1 : 0
                    spacing: 12

                    StyledCheckBox {
                        id: reliableCheck
                        theme: root.theme
                        Layout.preferredWidth: 112
                        text: root.chineseMode ? "QoS1 确认" : "QoS1 ack"
                        description: ""
                        enabled: root.chatController.connected
                    }

                    StyledCheckBox {
                        id: retainCheck
                        theme: root.theme
                        Layout.preferredWidth: 92
                        text: root.chineseMode ? "保留" : "Retain"
                        description: ""
                        enabled: root.chatController.connected
                    }

                    Label {
                        Layout.fillWidth: true
                        text: root.chineseMode
                              ? "QoS1 等待服务端确认；Retain 请求服务端保留最新消息。"
                              : "QoS1 waits for server confirmation. Retain asks the server to keep the latest message."
                        color: root.theme.subtext
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        renderType: Text.CurveRendering
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
}
