import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

Panel {
  id: root
  moduleName: "lyubo119.task-manager"
  ipcTarget: "lyubo119.task-manager"
  manageIpc: false

  // ── Theme ──────────────────────────────────────────────────────────
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color surface: Color.popups.background
  readonly property color accent: Color.accent
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // ── Tab state ──────────────────────────────────────────────────────
  property string activeTab: setting("defaultTab", "processes")
  readonly property var tabs: ["processes", "performance", "services", "agents"]
  readonly property var tabLabels: ({
    "processes": "Processes",
    "performance": "Performance",
    "services": "Services",
    "agents": "Agents"
  })
  readonly property var tabIcons: ({
    "processes": "\u{EFBF}",
    "performance": "\u{EB2A}",
    "services": "\u{E768}",
    "agents": "\u{E69E}"
  })

  // ── Process state ──────────────────────────────────────────────────
  property var processList: []
  property string processSortColumn: "cpu"
  property bool processSortAsc: false
  property string processFilter: ""
  property int processSelectedIndex: -1
  property bool cursorActive: false

  // ── Performance state ──────────────────────────────────────────────
  property var cpuInfo: ({})
  property var memoryInfo: ({})
  property var diskInfo: ({})
  property var networkInfo: ({})
  property var gpuInfo: ({})
  property var uptimeInfo: ""
  property var cpuHistory: []
  property var memHistory: []

  // ── Services state ─────────────────────────────────────────────────
  property var serviceList: []
  property string serviceFilter: ""
  property int serviceSelectedIndex: -1

  // ── Agents state ───────────────────────────────────────────────────
  property var agentSessions: []
  property int agentSelectedIndex: -1
  property string agentChatInput: ""
  property var agentChatMessages: []

  // ── Refresh ────────────────────────────────────────────────────────
  property double nowMs: Date.now()

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function selectTab(tab) {
    activeTab = tab
    processSelectedIndex = -1
    serviceSelectedIndex = -1
    agentSelectedIndex = -1
  }

  // ── IPC ────────────────────────────────────────────────────────────
  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refreshAll() }
    function tab(name): void { root.selectTab(String(name || "processes")) }
  }

  // ── Data refresh ───────────────────────────────────────────────────
  function refreshAll() {
    nowMs = Date.now()
    if (!procCollector.running) procCollector.running = true
    if (!sysCollector.running) sysCollector.running = true
    if (activeTab === "services" && !svcCollector.running) svcCollector.running = true
    if (activeTab === "agents" && !agentCollector.running) agentCollector.running = true
  }

  // ── Process actions ────────────────────────────────────────────────
  function endProcess(pid) {
    if (pid > 0) {
      processAction.target = "kill " + pid
      processAction.running = true
    }
  }

  function killProcess(pid) {
    if (pid > 0) {
      processAction.target = "kill -9 " + pid
      processAction.running = true
    }
  }

  function openTerminal(pid) {
    if (root.bar) {
      var cmd = "alacritty --hold -e sh -c 'echo PID:" + pid + "; cat /proc/" + pid + "/status 2>/dev/null; echo; echo Press enter to close; read'"
      root.bar.run(cmd)
    }
  }

  // ── Service actions ────────────────────────────────────────────────
  function toggleService(name, enable) {
    serviceAction.target = (enable ? "systemctl enable --now " : "systemctl disable --now ") + name
    serviceAction.running = true
    Qt.callLater(function() { svcCollector.running = true })
  }

  function restartService(name) {
    serviceAction.target = "systemctl restart " + name
    serviceAction.running = true
  }

  // ── Agent chat ─────────────────────────────────────────────────────
  function sendAgentMessage() {
    if (agentChatInput.trim() === "") return
    var msg = agentChatInput.trim()
    agentChatMessages.push({ "role": "user", "text": msg, "time": Date.now() })
    agentChatInput = ""
    agentChatMessages = agentChatMessages
    // Send via IPC to Claude Code session if available
    agentChatSend.target = msg
    agentChatSend.running = true
  }

  // ── Keyboard ───────────────────────────────────────────────────────
  function handleKey(key) {
    if (key === "h" || key === "Left") {
      var idx = tabs.indexOf(activeTab)
      if (idx > 0) selectTab(tabs[idx - 1])
    } else if (key === "l" || key === "Right") {
      var idx2 = tabs.indexOf(activeTab)
      if (idx2 < tabs.length - 1) selectTab(tabs[idx2 + 1])
    } else if (key === "j" || key === "Down") {
      if (activeTab === "processes" && processList.length > 0)
        processSelectedIndex = Math.min(processSelectedIndex + 1, processList.length - 1)
      else if (activeTab === "services" && serviceList.length > 0)
        serviceSelectedIndex = Math.min(serviceSelectedIndex + 1, serviceList.length - 1)
    } else if (key === "k" || key === "Up") {
      if (activeTab === "processes")
        processSelectedIndex = Math.max(processSelectedIndex - 1, 0)
      else if (activeTab === "services")
        serviceSelectedIndex = Math.max(serviceSelectedIndex - 1, 0)
    } else if (key === "r" || key === "R") {
      refreshAll()
    } else if (key === "x" || key === "X") {
      if (activeTab === "processes" && processSelectedIndex >= 0) {
        var proc = processList[processSelectedIndex]
        if (proc) endProcess(proc.pid)
      }
    } else if (key === "Delete") {
      if (activeTab === "processes" && processSelectedIndex >= 0) {
        var proc2 = processList[processSelectedIndex]
        if (proc2) killProcess(proc2.pid)
      }
    } else if (key === "Escape") {
      root.close()
    } else if (key === "Tab") {
      root.switchPanel(1)
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // UI
  // ══════════════════════════════════════════════════════════════════════

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: refreshAll()

  onOpenedChanged: if (opened) {
    cursorActive = false
    processSelectedIndex = -1
    serviceSelectedIndex = -1
    agentSelectedIndex = -1
    refreshAll()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  // ── Bar button ─────────────────────────────────────────────────────
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\u{EFBF}"
    active: root.processList.length > 0
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) {
        if (root.bar) root.bar.run("alacritty -e htop")
      } else {
        root.toggle()
      }
    }
  }

  // ── Timer ──────────────────────────────────────────────────────────
  Timer {
    interval: setting("refreshIntervalMs", 2000)
    running: root.opened
    repeat: true
    onTriggered: refreshAll()
  }

  Timer {
    interval: 30000
    running: root.opened
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  // ══════════════════════════════════════════════════════════════════════
  // PANEL POPUP
  // ══════════════════════════════════════════════════════════════════════

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(520))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight, Style.space(680))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) {
          var idx = tabs.indexOf(activeTab)
          var next = idx + dx
          if (next >= 0 && next < tabs.length) selectTab(tabs[next])
        }
        if (dy !== 0) handleKey(dy > 0 ? "j" : "k")
      }
      onActivateRequested: refreshAll()
      onCloseRequested: root.close()
      onTabRequested: function(dir) { root.switchPanel(dir) }
      onTextKey: function(t) { handleKey(t) }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: mainColumn
          width: panelFlick.width
          spacing: Style.space(8)

          // ── Tab bar ──────────────────────────────────────────────
          Row {
            width: parent.width
            spacing: 2

            Repeater {
              model: root.tabs

              Rectangle {
                required property string modelData
                required property int index
                width: (parent.width - 2 * (root.tabs.length - 1)) / root.tabs.length
                height: Style.space(36)
                radius: Style.cornerRadius
                color: root.activeTab === modelData
                  ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)
                  : "transparent"

                Column {
                  anchors.centerIn: parent
                  spacing: 2

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.tabIcons[modelData] || ""
                    color: root.activeTab === modelData ? root.foreground : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.tabLabels[modelData] || modelData
                    color: root.activeTab === modelData ? root.foreground : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.small
                    font.bold: root.activeTab === modelData
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  onClicked: root.selectTab(modelData)
                  cursorShape: Qt.PointingHandCursor
                }
              }
            }
          }

          // ── Tab separator ───────────────────────────────────────
          Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)
          }

          // ══════════════════════════════════════════════════════════
          // PROCESSES TAB
          // ══════════════════════════════════════════════════════════
          Column {
            visible: root.activeTab === "processes"
            width: parent.width
            spacing: Style.space(6)

            // Filter bar
            Row {
              width: parent.width
              spacing: Style.space(6)

              Rectangle {
                width: parent.width
                height: Style.space(32)
                radius: Style.cornerRadius
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
                border.width: 1
                border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

                TextInput {
                  id: filterInput
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  verticalAlignment: Text.AlignVCenter
                  clip: true
                  text: root.processFilter
                  onTextChanged: root.processFilter = text

                  Text {
                    visible: filterInput.text === "" && !filterInput.activeFocus
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u{F422} Filter processes..."
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                }
              }
            }

            // Column headers
            Row {
              width: parent.width
              spacing: 0

              readonly property var columns: [
                { label: "Name", key: "name", flex: 3 },
                { label: "PID", key: "pid", flex: 1 },
                { label: "CPU%", key: "cpu", flex: 1 },
                { label: "Mem%", key: "mem", flex: 1 },
                { label: "Status", key: "status", flex: 1 }
              ]

              Repeater {
                model: parent.columns

                Rectangle {
                  required property var modelData
                  required property int index
                  width: parent.width * modelData.flex / 8
                  height: Style.space(28)
                  color: "transparent"

                  Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(6)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(4)

                    Text {
                      text: modelData.label
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: root.processSortColumn === modelData.key
                    }
                    Text {
                      visible: root.processSortColumn === modelData.key
                      text: root.processSortAsc ? "\u{25B2}" : "\u{25BC}"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.small - 2
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    onClicked: {
                      if (root.processSortColumn === modelData.key)
                        root.processSortAsc = !root.processSortAsc
                      else {
                        root.processSortColumn = modelData.key
                        root.processSortAsc = modelData.key === "name"
                      }
                    }
                  }
                }
              }
            }

            // Separator
            Rectangle {
              width: parent.width
              height: 1
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)
            }

            // Process list
            Column {
              width: parent.width
              spacing: 0

              Repeater {
                model: {
                  var filtered = Model.filterProcesses(root.processList, root.processFilter)
                  return Model.sortProcesses(filtered, root.processSortColumn, root.processSortAsc)
                }

                Rectangle {
                  required property var modelData
                  required property int index
                  width: parent.width
                  height: Style.space(28)
                  radius: Style.cornerRadius / 2
                  color: root.processSelectedIndex === index
                    ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                    : index % 2 === 0
                      ? "transparent"
                      : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.03)

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(6)
                    anchors.rightMargin: Style.space(6)

                    Text {
                      width: parent.width * 3 / 8
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.name || ""
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      elide: Text.ElideRight
                      maximumLineCount: 1
                    }
                    Text {
                      width: parent.width * 1 / 8
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.pid || ""
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                    }
                    Text {
                      width: parent.width * 1 / 8
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.cpu >= 10 ? modelData.cpu.toFixed(0) : modelData.cpu.toFixed(1)
                      color: modelData.cpu > 50 ? root.urgent : root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                    }
                    Text {
                      width: parent.width * 1 / 8
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.mem >= 10 ? modelData.mem.toFixed(0) : modelData.mem.toFixed(1)
                      color: modelData.mem > 50 ? root.urgent : root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                    }
                    Text {
                      width: parent.width * 2 / 8
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.status || ""
                      color: modelData.status === "Z" ? root.urgent : root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    onClicked: {
                      root.cursorActive = true
                      root.processSelectedIndex = index
                    }
                    onDoubleClicked: root.openTerminal(modelData.pid)
                  }
                }
              }

              // Empty state
              Text {
                visible: root.processList.length === 0
                width: parent.width
                topPadding: Style.space(24)
                text: "Loading processes..."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                horizontalAlignment: Text.AlignHCenter
              }
            }

            // Process count
            Text {
              width: parent.width
              text: root.processList.length + " processes"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
            }
          }

          // ══════════════════════════════════════════════════════════
          // PERFORMANCE TAB
          // ══════════════════════════════════════════════════════════
          Column {
            visible: root.activeTab === "performance"
            width: parent.width
            spacing: Style.space(12)

            // CPU Section
            PanelSectionHeader {
              width: parent.width
              text: "CPU"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              // CPU bar
              Row {
                width: parent.width
                spacing: Style.space(8)

                Text {
                  width: Style.space(60)
                  text: root.cpuInfo.model || "CPU"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                }

                Rectangle {
                  width: parent.width - Style.space(68)
                  height: Style.space(16)
                  radius: Style.cornerRadius / 2
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)

                  Rectangle {
                    width: parent.width * (root.cpuInfo.usage || 0) / 100
                    height: parent.height
                    radius: parent.radius
                    color: (root.cpuInfo.usage || 0) > 80 ? root.urgent : root.accent

                    Behavior on width { NumberAnimation { duration: 300 } }
                  }

                  Text {
                    anchors.centerIn: parent
                    text: (root.cpuInfo.usage || 0).toFixed(1) + "%"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }

              // CPU details
              Grid {
                width: parent.width
                columns: 2
                columnSpacing: Style.space(12)
                rowSpacing: Style.space(4)

                Text { text: "Cores:"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                Text { text: root.cpuInfo.cores || "—"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                Text { text: "Threads:"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                Text { text: root.cpuInfo.threads || "—"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                Text { text: "Frequency:"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                Text { text: root.cpuInfo.freq || "—"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                Text { text: "Load avg:"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                Text { text: root.cpuInfo.loadAvg || "—"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              }

              // CPU sparkline
              Canvas {
                id: cpuSparkline
                width: parent.width
                height: Style.space(40)
                onPaint: {
                  var ctx = getContext("2d")
                  ctx.clearRect(0, 0, width, height)
                  if (root.cpuHistory.length < 2) return
                  ctx.beginPath()
                  ctx.strokeStyle = Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.8)
                  ctx.lineWidth = 1.5
                  var step = width / (root.cpuHistory.length - 1)
                  for (var i = 0; i < root.cpuHistory.length; i++) {
                    var x = i * step
                    var y = height - (root.cpuHistory[i] / 100) * height
                    if (i === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                  }
                  ctx.stroke()
                  // Fill under
                  ctx.lineTo(width, height)
                  ctx.lineTo(0, height)
                  ctx.closePath()
                  ctx.fillStyle = Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.1)
                  ctx.fill()
                }
                Connections {
                  target: root
                  function onCpuHistoryChanged() { cpuSparkline.requestPaint() }
                }
              }
            }

            // Memory Section
            PanelSectionHeader {
              width: parent.width
              text: "MEMORY"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              // Memory bar
              Row {
                width: parent.width
                spacing: Style.space(8)

                Text {
                  width: Style.space(60)
                  text: "RAM"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Rectangle {
                  width: parent.width - Style.space(68)
                  height: Style.space(16)
                  radius: Style.cornerRadius / 2
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)

                  Rectangle {
                    width: parent.width * (root.memoryInfo.usage || 0) / 100
                    height: parent.height
                    radius: parent.radius
                    color: (root.memoryInfo.usage || 0) > 85 ? root.urgent : root.accent

                    Behavior on width { NumberAnimation { duration: 300 } }
                  }

                  Text {
                    anchors.centerIn: parent
                    text: (root.memoryInfo.used || "0") + " / " + (root.memoryInfo.total || "0")
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }

              Grid {
                width: parent.width
                columns: 2
                columnSpacing: Style.space(12)
                rowSpacing: Style.space(4)

                Text { text: "Used:"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                Text { text: root.memoryInfo.used || "—"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                Text { text: "Available:"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                Text { text: root.memoryInfo.available || "—"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                Text { text: "Cached:"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                Text { text: root.memoryInfo.cached || "—"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                Text { text: "Swap:"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                Text { text: (root.memoryInfo.swapUsed || "0") + " / " + (root.memoryInfo.swapTotal || "0"); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              }
            }

            // Disk Section
            PanelSectionHeader {
              width: parent.width
              text: "DISK"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: root.diskInfo.partitions || []

                Row {
                  required property var modelData
                  required property int index
                  width: parent.width
                  spacing: Style.space(8)

                  Text {
                    width: Style.space(60)
                    text: modelData.mount || ""
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideRight
                  }

                  Rectangle {
                    width: parent.width - Style.space(68)
                    height: Style.space(14)
                    radius: Style.cornerRadius / 2
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)

                    Rectangle {
                      width: parent.width * (modelData.usage || 0) / 100
                      height: parent.height
                      radius: parent.radius
                      color: (modelData.usage || 0) > 90 ? root.urgent : root.accent
                    }

                    Text {
                      anchors.centerIn: parent
                      text: (modelData.used || "") + " / " + (modelData.total || "") + " (" + (modelData.usage || 0).toFixed(0) + "%)"
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.small
                    }
                  }
                }
              }

              Text {
                visible: !root.diskInfo.partitions || root.diskInfo.partitions.length === 0
                text: "No disk data"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            // Network Section
            PanelSectionHeader {
              width: parent.width
              text: "NETWORK"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Grid {
              width: parent.width
              columns: 2
              columnSpacing: Style.space(12)
              rowSpacing: Style.space(4)

              Text { text: "Interface:"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Text { text: root.networkInfo.interface || "—"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Text { text: "RX:"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Text { text: root.networkInfo.rx || "—"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Text { text: "TX:"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Text { text: root.networkInfo.tx || "—"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Text { text: "IP:"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Text { text: root.networkInfo.ip || "—"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
            }

            // GPU Section
            PanelSectionHeader {
              visible: !!root.gpuInfo.model
              width: parent.width
              text: "GPU"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Grid {
              visible: !!root.gpuInfo.model
              width: parent.width
              columns: 2
              columnSpacing: Style.space(12)
              rowSpacing: Style.space(4)

              Text { text: "Model:"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Text { text: root.gpuInfo.model || "—"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Text { text: "Usage:"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Text { text: root.gpuInfo.usage || "—"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Text { text: "Memory:"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Text { text: root.gpuInfo.memory || "—"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Text { text: "Temp:"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Text { text: root.gpuInfo.temp || "—"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
            }

            // Uptime
            PanelSeparator { width: parent.width; foreground: root.foreground }
            Text {
              width: parent.width
              text: "Uptime: " + (root.uptimeInfo || "—")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          // ══════════════════════════════════════════════════════════
          // SERVICES TAB
          // ══════════════════════════════════════════════════════════
          Column {
            visible: root.activeTab === "services"
            width: parent.width
            spacing: Style.space(6)

            // Filter
            Rectangle {
              width: parent.width
              height: Style.space(32)
              radius: Style.cornerRadius
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
              border.width: 1
              border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

              TextInput {
                anchors.fill: parent
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                verticalAlignment: Text.AlignVCenter
                clip: true
                text: root.serviceFilter
                onTextChanged: root.serviceFilter = text

                Text {
                  visible: parent.text === "" && !parent.activeFocus
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: "\u{F422} Filter services..."
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }

            // Service headers
            Row {
              width: parent.width
              Rectangle { width: parent.width * 0.4; height: Style.space(28); color: "transparent"
                Text { anchors.left: parent.left; anchors.leftMargin: Style.space(6); anchors.verticalCenter: parent.verticalCenter
                  text: "Service"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true } }
              Rectangle { width: parent.width * 0.2; height: Style.space(28); color: "transparent"
                Text { anchors.centerIn: parent; text: "Status"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true } }
              Rectangle { width: parent.width * 0.2; height: Style.space(28); color: "transparent"
                Text { anchors.centerIn: parent; text: "Type"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true } }
              Rectangle { width: parent.width * 0.2; height: Style.space(28); color: "transparent"
                Text { anchors.centerIn: parent; text: "Action"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true } }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1) }

            // Service list
            Column {
              width: parent.width
              spacing: 0

              Repeater {
                model: Model.filterServices(root.serviceList, root.serviceFilter)

                Rectangle {
                  required property var modelData
                  required property int index
                  width: parent.width
                  height: Style.space(28)
                  radius: Style.cornerRadius / 2
                  color: root.serviceSelectedIndex === index
                    ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                    : index % 2 === 0 ? "transparent" : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.03)

                  Row {
                    anchors.fill: parent

                    Rectangle { width: parent.width * 0.4; height: parent.height; color: "transparent"
                      Text { anchors.left: parent.left; anchors.leftMargin: Style.space(6); anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name || ""; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall
                        elide: Text.ElideRight; maximumLineCount: 1 } }
                    Rectangle { width: parent.width * 0.2; height: parent.height; color: "transparent"
                      Text { anchors.centerIn: parent
                        text: modelData.active ? "Running" : "Stopped"
                        color: modelData.active ? "#4ade80" : root.dim
                        font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall } }
                    Rectangle { width: parent.width * 0.2; height: parent.height; color: "transparent"
                      Text { anchors.centerIn: parent
                        text: modelData.type || ""
                        color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption } }
                    Rectangle { width: parent.width * 0.2; height: parent.height; color: "transparent"
                      Text { anchors.centerIn: parent
                        text: modelData.active ? "\u{25A0}" : "\u{25B6}"
                        color: modelData.active ? root.urgent : "#4ade80"
                        font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }

                      MouseArea {
                        anchors.fill: parent
                        onClicked: root.toggleService(modelData.name, !modelData.active)
                        cursorShape: Qt.PointingHandCursor
                      }
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    onClicked: { root.cursorActive = true; root.serviceSelectedIndex = index }
                    onDoubleClicked: root.restartService(modelData.name)
                  }
                }
              }
            }

            Text {
              visible: root.serviceList.length === 0
              width: parent.width
              topPadding: Style.space(24)
              text: "Loading services..."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
            }

            Text {
              width: parent.width
              text: Model.filterServices(root.serviceList, root.serviceFilter).length + " services"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
            }
          }

          // ══════════════════════════════════════════════════════════
          // AGENTS TAB
          // ══════════════════════════════════════════════════════════
          Column {
            visible: root.activeTab === "agents"
            width: parent.width
            spacing: Style.space(8)

            // Agent header
            PanelSectionHeader {
              width: parent.width
              text: "ACTIVE AGENTS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            // Agent list
            Column {
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: root.agentSessions

                Rectangle {
                  required property var modelData
                  required property int index
                  width: parent.width
                  height: Style.space(48)
                  radius: Style.cornerRadius
                  color: root.agentSelectedIndex === index
                    ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                    : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
                  border.width: 1
                  border.color: root.agentSelectedIndex === index
                    ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.3)
                    : "transparent"

                  Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    spacing: Style.space(8)

                    // Status indicator
                    Rectangle {
                      width: Style.space(10)
                      height: Style.space(10)
                      radius: Style.space(5)
                      anchors.verticalCenter: parent.verticalCenter
                      color: modelData.active ? "#4ade80" : root.dim
                    }

                    Column {
                      width: parent.width - Style.space(18)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: 2

                      Text {
                        text: modelData.name || "Unknown Agent"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                        elide: Text.ElideRight
                      }
                      Text {
                        text: (modelData.status || "idle") + (modelData.model ? " · " + modelData.model : "")
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    onClicked: {
                      root.cursorActive = true
                      root.agentSelectedIndex = index
                    }
                  }
                }
              }

              Text {
                visible: root.agentSessions.length === 0
                width: parent.width
                topPadding: Style.space(16)
                text: "No active agent sessions found.\nStart a Claude Code or Codex session to see agents here."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
              }
            }

            // Chat section
            PanelSeparator { width: parent.width; foreground: root.foreground }

            PanelSectionHeader {
              width: parent.width
              text: "CHAT"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            // Chat messages
            Rectangle {
              width: parent.width
              height: Style.space(160)
              radius: Style.cornerRadius
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.03)
              border.width: 1
              border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)

              Flickable {
                id: chatFlick
                anchors.fill: parent
                anchors.margins: Style.space(8)
                contentWidth: width
                contentHeight: chatColumn.implicitHeight
                clip: true
                flickableDirection: Flickable.VerticalFlick
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                Column {
                  id: chatColumn
                  width: parent.width
                  spacing: Style.space(6)

                  Repeater {
                    model: root.agentChatMessages

                    Rectangle {
                      required property var modelData
                      width: parent.width
                      height: chatText.implicitHeight + Style.space(12)
                      radius: Style.cornerRadius
                      color: modelData.role === "user"
                        ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.1)
                        : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)

                      Column {
                        anchors.fill: parent
                        anchors.margins: Style.space(6)
                        spacing: 2

                        Text {
                          text: modelData.role === "user" ? "You" : "Agent"
                          color: modelData.role === "user" ? root.accent : root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.small
                          font.bold: true
                        }
                        Text {
                          id: chatText
                          width: parent.width
                          text: modelData.text || ""
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.bodySmall
                          wrapMode: Text.WordWrap
                        }
                      }
                    }
                  }

                  Text {
                    visible: root.agentChatMessages.length === 0
                    width: parent.width
                    topPadding: Style.space(12)
                    text: "Select an agent and type a message below."
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    horizontalAlignment: Text.AlignHCenter
                  }
                }
              }
            }

            // Chat input
            Rectangle {
              width: parent.width
              height: Style.space(36)
              radius: Style.cornerRadius
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
              border.width: 1
              border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)

              Row {
                anchors.fill: parent
                anchors.margins: Style.space(4)

                TextInput {
                  width: parent.width - Style.space(40)
                  height: parent.height
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  verticalAlignment: Text.AlignVCenter
                  clip: true
                  text: root.agentChatInput
                  onTextChanged: root.agentChatInput = text
                  onAccepted: root.sendAgentMessage()

                  Text {
                    visible: parent.text === "" && !parent.activeFocus
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Type a message..."
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                }

                Rectangle {
                  width: Style.space(32)
                  height: parent.height
                  radius: Style.cornerRadius / 2
                  color: root.agentChatInput.trim() !== "" ? root.accent : "transparent"

                  Text {
                    anchors.centerIn: parent
                    text: "\u{27A4}"
                    color: root.agentChatInput.trim() !== "" ? root.foreground : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                  }

                  MouseArea {
                    anchors.fill: parent
                    enabled: root.agentChatInput.trim() !== ""
                    onClicked: root.sendAgentMessage()
                    cursorShape: Qt.PointingHandCursor
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // DATA COLLECTION PROCESSES
  // ══════════════════════════════════════════════════════════════════════

  // Process collector
  Process {
    id: procCollector
    command: ["sh", "-c", Model.processCommand()]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var result = Model.parseProcesses(text || "")
        root.processList = result
        root.cpuHistory.push(root.cpuInfo.usage || 0)
        if (root.cpuHistory.length > 60) root.cpuHistory.shift()
        root.cpuHistory = root.cpuHistory
      }
    }
  }

  // System info collector
  Process {
    id: sysCollector
    command: ["sh", "-c", Model.systemCommand()]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var data = Model.parseSystemInfo(text || "")
        root.cpuInfo = data.cpu || {}
        root.memoryInfo = data.memory || {}
        root.diskInfo = data.disk || {}
        root.networkInfo = data.network || {}
        root.gpuInfo = data.gpu || {}
        root.uptimeInfo = data.uptime || ""
      }
    }
  }

  // Service collector
  Process {
    id: svcCollector
    command: ["sh", "-c", Model.serviceCommand()]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.serviceList = Model.parseServices(text || "")
      }
    }
  }

  // Agent collector
  Process {
    id: agentCollector
    command: ["sh", "-c", Model.agentCommand()]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.agentSessions = Model.parseAgents(text || "")
      }
    }
  }

  // Process action (kill/signal)
  Process {
    id: processAction
    command: ["sh", "-c", target]
    property string target: ""
    onExited: {
      Qt.callLater(function() { procCollector.running = true })
    }
  }

  // Service action
  Process {
    id: serviceAction
    command: ["pkexec", "sh", "-c", target]
    property string target: ""
  }

  // Agent chat send
  Process {
    id: agentChatSend
    command: ["sh", "-c", "echo " + target + " | xargs -I{} timeout 5 claude-cli --print '{}' 2>/dev/null || echo 'Agent not available'"]
    property string target: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var response = (text || "").trim()
        if (response !== "") {
          root.agentChatMessages.push({ "role": "agent", "text": response, "time": Date.now() })
          root.agentChatMessages = root.agentChatMessages
        }
      }
    }
  }
}
