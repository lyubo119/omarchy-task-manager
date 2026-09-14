.pragma library

// ═══════════════════════════════════════════════════════════════════════
// Process Data Collection
// ═══════════════════════════════════════════════════════════════════════

function processCommand() {
  // Collect all processes with CPU/memory usage, sorted by CPU desc
  return "ps -eo pid,pcpu,pmem,stat,comm --sort=-pcpu | head -200"
}

function parseProcesses(raw) {
  var lines = raw.split("\n")
  var result = []
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line === "" || i === 0) continue // skip header
    var parts = line.split(/\s+/)
    if (parts.length >= 5) {
      result.push({
        pid: parseInt(parts[0]) || 0,
        cpu: parseFloat(parts[1]) || 0,
        mem: parseFloat(parts[2]) || 0,
        status: parts[3] || "",
        name: parts.slice(4).join(" ") || ""
      })
    }
  }
  return result
}

function filterProcesses(list, filter) {
  if (!filter || filter === "") return list
  var lower = filter.toLowerCase()
  var result = []
  for (var i = 0; i < list.length; i++) {
    var p = list[i]
    if (String(p.name).toLowerCase().indexOf(lower) >= 0 ||
        String(p.pid).indexOf(lower) >= 0) {
      result.push(p)
    }
  }
  return result
}

function sortProcesses(list, column, ascending) {
  var sorted = list.slice()
  sorted.sort(function(a, b) {
    var va = a[column]
    var vb = b[column]
    if (typeof va === "string") {
      va = va.toLowerCase()
      vb = (vb || "").toLowerCase()
      return ascending ? va.localeCompare(vb) : vb.localeCompare(va)
    }
    va = Number(va) || 0
    vb = Number(vb) || 0
    return ascending ? va - vb : vb - va
  })
  return sorted
}

// ═══════════════════════════════════════════════════════════════════════
// System Info Collection
// ═══════════════════════════════════════════════════════════════════════

function systemCommand() {
  return [
    'echo "===CPU==="',
    // CPU usage from /proc/stat (calculate delta)
    'top -bn1 | head -5 | grep "Cpu(s)"',
    // CPU model
    'cat /proc/cpuinfo | grep "model name" | head -1',
    // Cores and threads
    'nproc',
    'cat /proc/cpuinfo | grep -c "^processor"',
    // Frequency
    'cat /proc/cpuinfo | grep "cpu MHz" | head -1',
    // Load average
    'cat /proc/loadavg',
    'echo "===MEM==="',
    // Memory info
    'free -h | grep Mem',
    'free -h | grep Swap',
    'echo "===DISK==="',
    // Disk usage
    'df -h --output=target,used,size,pcent | grep -E "^/|^/home|^/boot|^/root|^/tmp|^/var|^/usr|^/opt"',
    'echo "===NET==="',
    // Network interface and traffic
    'ip route get 1.1.1.1 2>/dev/null | head -1',
    'cat /sys/class/net/$(ip route get 1.1.1.1 2>/dev/null | awk \'{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}\' | head -1)/statistics/rx_bytes 2>/dev/null || echo 0',
    'cat /sys/class/net/$(ip route get 1.1.1.1 2>/dev/null | awk \'{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}\' | head -1)/statistics/tx_bytes 2>/dev/null || echo 0',
    'hostname -I 2>/dev/null | awk \'{print $1}\'',
    'echo "===GPU==="',
    // GPU info (try nvidia-smi, then lspci)
    'nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader 2>/dev/null || echo "NVIDIA_NOT_FOUND"',
    'lspci | grep -i vga | head -1',
    'echo "===UPTIME==="',
    'uptime -p 2>/dev/null || uptime'
  ].join("\n")
}

function parseSystemInfo(raw) {
  var sections = raw.split("===")
  var result = { cpu: {}, memory: {}, disk: {}, network: {}, gpu: {}, uptime: "" }

  for (var i = 0; i < sections.length; i++) {
    var section = sections[i].trim()
    if (section.indexOf("CPU") === 0) {
      result.cpu = parseCPUSection(section)
    } else if (section.indexOf("MEM") === 0) {
      result.memory = parseMemSection(section)
    } else if (section.indexOf("DISK") === 0) {
      result.disk = parseDiskSection(section)
    } else if (section.indexOf("NET") === 0) {
      result.network = parseNetSection(section)
    } else if (section.indexOf("GPU") === 0) {
      result.gpu = parseGPUSection(section)
    } else if (section.indexOf("UPTIME") === 0) {
      result.uptime = parseUptime(section)
    }
  }
  return result
}

function parseCPUSection(raw) {
  var lines = raw.split("\n")
  var cpu = { usage: 0, model: "", cores: 0, threads: 0, freq: "", loadAvg: "" }

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line.indexOf("Cpu(s)") >= 0) {
      // Parse "Cpu(s): 12.5%us,  2.3%sy,  0.0%ni, 84.2%id,  0.8%wa,  0.0%hi,  0.2%si"
      var match = line.match(/([\d.]+)%?\s*(?:us|idle)/)
      if (match) {
        var us = parseFloat(line.match(/([\d.]+)%?us/)?.[1] || "0") || 0
        var sy = parseFloat(line.match(/([\d.]+)%?sy/)?.[1] || "0") || 0
        cpu.usage = Math.min(100, us + sy)
      }
      // Also try idle-based calculation
      var idleMatch = line.match(/([\d.]+)%?id/)
      if (idleMatch) {
        cpu.usage = Math.max(0, 100 - parseFloat(idleMatch[1]))
      }
    } else if (line.indexOf("model name") >= 0) {
      cpu.model = line.split(":")[1]?.trim() || ""
      // Truncate long model names
      if (cpu.model.length > 30) cpu.model = cpu.model.substring(0, 27) + "..."
    } else if (line.match(/^\d+$/) && cpu.cores === 0) {
      cpu.cores = parseInt(line) || 0
    } else if (line.match(/^\d+$/) && cpu.cores > 0 && cpu.threads === 0) {
      cpu.threads = parseInt(line) || 0
    } else if (line.indexOf("cpu MHz") >= 0) {
      var mhz = parseFloat(line.split(":")[1]) || 0
      if (mhz > 1000) cpu.freq = (mhz / 1000).toFixed(1) + " GHz"
      else cpu.freq = mhz.toFixed(0) + " MHz"
    } else if (line.match(/^[\d.]+ [\d.]+ [\d.]+/)) {
      cpu.loadAvg = line.split(" ").slice(0, 3).join(" ")
    }
  }

  if (cpu.threads === 0) cpu.threads = cpu.cores
  return cpu
}

function parseMemSection(raw) {
  var lines = raw.split("\n")
  var mem = { total: "", used: "", available: "", cached: "", usage: 0, swapTotal: "", swapUsed: "" }

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line.indexOf("Mem:") === 0) {
      var parts = line.split(/\s+/)
      mem.total = parts[1] || ""
      mem.used = parts[2] || ""
      mem.available = parts[6] || parts[3] || ""
      mem.cached = parts[5] || ""
      // Calculate usage percentage
      var totalBytes = parseSizeBytes(mem.total)
      var usedBytes = parseSizeBytes(mem.used)
      if (totalBytes > 0) mem.usage = (usedBytes / totalBytes) * 100
    } else if (line.indexOf("Swap:") === 0) {
      var sparts = line.split(/\s+/)
      mem.swapTotal = sparts[1] || ""
      mem.swapUsed = sparts[2] || ""
    }
  }
  return mem
}

function parseDiskSection(raw) {
  var lines = raw.split("\n")
  var partitions = []

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line === "" || line.indexOf("===") >= 0) continue
    var parts = line.split(/\s+/)
    if (parts.length >= 4) {
      var usage = parseFloat(parts[3]) || 0
      partitions.push({
        mount: parts[0] || "",
        used: parts[1] || "",
        total: parts[2] || "",
        usage: usage
      })
    }
  }
  return { partitions: partitions }
}

function parseNetSection(raw) {
  var lines = raw.split("\n")
  var net = { interface: "", rx: "", tx: "", ip: "" }

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line.indexOf("dev") >= 0) {
      var match = line.match(/dev\s+(\S+)/)
      if (match) net.interface = match[1]
    } else if (line.match(/^\d+$/) && net.rx === "") {
      net.rx = formatBytes(parseInt(line))
    } else if (line.match(/^\d+$/) && net.tx === "") {
      net.tx = formatBytes(parseInt(line))
    } else if (line.match(/^[\d.]+$/)) {
      net.ip = line
    }
  }
  return net
}

function parseGPUSection(raw) {
  var lines = raw.split("\n")
  var gpu = { model: "", usage: "", memory: "", temp: "" }

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line.indexOf("NVIDIA_NOT_FOUND") >= 0) {
      // Try lspci fallback
      continue
    }
    if (line.indexOf(",") >= 0) {
      // nvidia-smi CSV: name, util%, mem_used, mem_total, temp
      var parts = line.split(",").map(function(s) { return s.trim() })
      if (parts.length >= 5) {
        gpu.model = parts[0]
        gpu.usage = parts[1]
        gpu.memory = parts[2] + " / " + parts[3]
        gpu.temp = parts[4]
      }
    } else if (line.indexOf("VGA") >= 0 || line.indexOf("3D") >= 0) {
      // lspci fallback
      var match = line.match(/:\s*(.+?)(?:\s*\[|$)/)
      if (match) gpu.model = match[1].trim()
    }
  }
  return gpu
}

function parseUptime(raw) {
  var lines = raw.split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line.indexOf("up ") >= 0) return line
    if (line.indexOf("Uptime:") >= 0) return line.replace("Uptime:", "").trim()
    if (line.match(/\d+\s+(day|hour|min|week|month)/)) return line
  }
  return ""
}

// ═══════════════════════════════════════════════════════════════════════
// Services
// ═══════════════════════════════════════════════════════════════════════

function serviceCommand() {
  return "systemctl list-units --type=service --all --no-pager --no-legend 2>/dev/null | head -150"
}

function parseServices(raw) {
  var lines = raw.split("\n")
  var result = []
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line === "") continue
    var parts = line.split(/\s+/)
    if (parts.length >= 4) {
      var name = parts[0].replace(".service", "")
      var load = parts[1] || ""
      var active = parts[2] === "active" || parts[2] === "running"
      var sub = parts[3] || ""
      var desc = parts.slice(4).join(" ") || ""
      result.push({
        name: name,
        load: load,
        active: active,
        status: parts[2] || "",
        sub: sub,
        type: sub,
        description: desc
      })
    }
  }
  // Sort: running first, then alphabetical
  result.sort(function(a, b) {
    if (a.active && !b.active) return -1
    if (!a.active && b.active) return 1
    return a.name.localeCompare(b.name)
  })
  return result
}

function filterServices(list, filter) {
  if (!filter || filter === "") return list
  var lower = filter.toLowerCase()
  var result = []
  for (var i = 0; i < list.length; i++) {
    var s = list[i]
    if (s.name.toLowerCase().indexOf(lower) >= 0 ||
        s.description.toLowerCase().indexOf(lower) >= 0) {
      result.push(s)
    }
  }
  return result
}

// ═══════════════════════════════════════════════════════════════════════
// Agents
// ═══════════════════════════════════════════════════════════════════════

function agentCommand() {
  return [
    // Check for Claude Code sessions
    'echo "===CLAUDE==="',
    'ls -t ~/.claude/projects/ 2>/dev/null | head -5',
    // Check for running claude processes
    'ps aux 2>/dev/null | grep -E "claude|codex" | grep -v grep | head -10',
    'echo "===SESSIONS==="',
    // Look for active session files
    'find ~/.claude -name "*.jsonl" -newer /tmp -mmin -60 2>/dev/null | head -5',
    'echo "===PROCESSES==="',
    'ps -eo pid,comm,pcpu,pmem --sort=-pcpu | grep -iE "claude|codex|node.*claude|python.*agent" | head -10'
  ].join("\n")
}

function parseAgents(raw) {
  var sections = raw.split("===")
  var sessions = []

  for (var i = 0; i < sections.length; i++) {
    var section = sections[i].trim()
    if (section.indexOf("CLAUDE") >= 0) {
      var lines = section.split("\n")
      for (var j = 0; j < lines.length; j++) {
        var line = lines[j].trim()
        if (line !== "" && line.indexOf("CLAUDE") < 0) {
          sessions.push({
            name: "Claude Code - " + line,
            status: "active",
            active: true,
            model: "claude",
            project: line,
            pid: 0
          })
        }
      }
    } else if (section.indexOf("PROCESSES") >= 0) {
      var plines = section.split("\n")
      for (var k = 0; k < plines.length; k++) {
        var pline = plines[k].trim()
        if (pline === "" || pline.indexOf("PROCESSES") >= 0) continue
        var parts = pline.split(/\s+/)
        if (parts.length >= 4) {
          var pid = parseInt(parts[0]) || 0
          var comm = parts[1] || ""
          var cpu = parts[2] || "0"
          var mem = parts[3] || "0"
          // Avoid duplicates
          var exists = false
          for (var m = 0; m < sessions.length; m++) {
            if (sessions[m].pid === pid) { exists = true; break }
          }
          if (!exists && pid > 0) {
            sessions.push({
              name: comm,
              status: "running",
              active: true,
              model: comm,
              pid: pid,
              cpu: cpu,
              mem: mem
            })
          }
        }
      }
    }
  }

  // If no sessions found, show a placeholder
  if (sessions.length === 0) {
    sessions.push({
      name: "No Active Sessions",
      status: "idle",
      active: false,
      model: "",
      pid: 0
    })
  }

  return sessions
}

// ═══════════════════════════════════════════════════════════════════════
// Utility
// ═══════════════════════════════════════════════════════════════════════

function formatBytes(bytes) {
  if (bytes === 0) return "0 B"
  var units = ["B", "KB", "MB", "GB", "TB"]
  var i = Math.floor(Math.log(bytes) / Math.log(1024))
  if (i >= units.length) i = units.length - 1
  return (bytes / Math.pow(1024, i)).toFixed(1) + " " + units[i]
}

function parseSizeBytes(str) {
  if (!str) return 0
  str = str.trim().toUpperCase()
  var num = parseFloat(str)
  if (isNaN(num)) return 0
  if (str.indexOf("T") >= 0) return num * 1024 * 1024 * 1024 * 1024
  if (str.indexOf("G") >= 0) return num * 1024 * 1024 * 1024
  if (str.indexOf("M") >= 0) return num * 1024 * 1024
  if (str.indexOf("K") >= 0) return num * 1024
  return num
}
