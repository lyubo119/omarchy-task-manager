# omarchy-task-manager

A Windows Task Manager-style system monitor plugin for [Omarchy](https://omarchy.org/) Linux.

![License](https://img.shields.io/badge/license-MIT-blue)
![Platform](https://img.shields.io/badge/platform-Arch%20Linux-blue)
![Omarchy](https://img.shields.io/badge/Omarchy-plugin-green)

## Features

A full-featured system monitor that lives in your Omarchy status bar, inspired by the Windows Task Manager.

### Processes Tab
- **Live process list** sorted by CPU usage
- **Sort by any column** — Name, PID, CPU%, Memory%, Status (click headers)
- **Filter processes** — type to search by name or PID
- **Kill processes** — select and press `x` to end, `Delete` to force kill
- **Open details** — double-click a process to open its status in a terminal
- Real-time CPU and memory percentage per process

### Performance Tab
- **CPU** — usage bar, model name, cores, threads, frequency, load average
- **CPU sparkline** — real-time usage graph over time
- **Memory** — used/total bar, available, cached, swap usage
- **Disk** — partition usage bars for all mounted filesystems
- **Network** — interface name, RX/TX totals, IP address
- **GPU** — NVIDIA GPU stats via nvidia-smi (model, usage, memory, temperature)
- **Uptime** — system uptime display

### Services Tab
- **Systemd service list** with running/stopped status
- **Filter services** by name or description
- **Toggle services** — click the play/stop button to enable/disable
- **Restart services** — double-click to restart
- Running services highlighted in green

### Agents Tab
- **Active agent sessions** — shows Claude Code, Codex, and other AI agent processes
- **Session details** — name, status, model, CPU/memory usage
- **Chat interface** — send messages to active agent sessions
- Real-time process monitoring for AI coding agents

## Installation

### Prerequisites
- [Omarchy](https://omarchy.org/) Linux system
- Quickshell (comes with Omarchy)

### Install

```bash
# Clone the repository
git clone https://github.com/lyubo119/omarchy-task-manager.git

# Copy to Omarchy plugins directory
cp -r omarchy-task-manager ~/.config/omarchy/plugins/lyubo119.task-manager

# Enable the plugin
omarchy plugin enable lyubo119.task-manager

# Add to bar (right section, after monitor widget)
omarchy bar move lyubo119.task-manager --section right --after omarchy.monitor
```

### Quick Install (one-liner)

```bash
git clone https://github.com/lyubo119/omarchy-task-manager.git && \
cp -r omarchy-task-manager ~/.config/omarchy/plugins/lyubo119.task-manager && \
omarchy plugin enable lyubo119.task-manager && \
omarchy bar move lyubo119.task-manager --section right --after omarchy.monitor
```

## Usage

Click the task manager icon (📊) in the bar to open the panel.

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `h` / `Left` | Previous tab |
| `l` / `Right` | Next tab |
| `j` / `Down` | Select next item |
| `k` / `Up` | Select previous item |
| `r` | Refresh all data |
| `x` | End selected process (SIGTERM) |
| `Delete` | Force kill selected process (SIGKILL) |
| `Tab` | Switch to next bar panel |
| `Escape` | Close panel |

### Mouse Controls

- **Left click** bar icon: Toggle panel
- **Right click** bar icon: Open htop in terminal
- **Click tab**: Switch between Processes/Performance/Services/Agents
- **Click process/service**: Select it
- **Double-click process**: Open details in terminal
- **Double-click service**: Restart service
- **Click service toggle**: Enable/disable service

## Configuration

Configure in `~/.config/omarchy/shell.json` under the widget entry:

```json
{
  "id": "lyubo119.task-manager",
  "refreshIntervalMs": 2000,
  "defaultTab": "processes"
}
```

| Setting | Default | Description |
|---------|---------|-------------|
| `refreshIntervalMs` | `2000` | Data refresh interval in milliseconds (500-10000) |
| `defaultTab` | `"processes"` | Tab shown on open: `processes`, `performance`, `services`, `agents` |

## Permissions

- Process listing: No special permissions needed
- Service management: Uses `pkexec` for systemd operations (will prompt for password)
- Process killing: Only works for your own processes (standard Unix permissions)

## Troubleshooting

### Plugin not showing in bar
```bash
# Rescan plugins
omarchy-shell shell rescanPlugins

# Verify it's enabled
omarchy plugin list | grep task-manager
```

### No GPU stats
GPU monitoring requires `nvidia-smi` (NVIDIA proprietary drivers) or falls back to `lspci` for basic model info.

### Service management not working
Service enable/disable/restart requires admin privileges. The plugin uses `pkexec` which will show a graphical password prompt.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions welcome! Please open an issue or PR on GitHub.

## Acknowledgments

- Built for the [Omarchy](https://omarchy.org/) Linux distribution
- Uses [Quickshell](https://quickshell.outfoxxed.me/) for the UI
- Inspired by the Windows Task Manager
