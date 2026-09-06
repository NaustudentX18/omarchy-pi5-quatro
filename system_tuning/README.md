# 8GB RAM & NVMe System Tuning Subsystem
**Omarchy Quatro Pi 5 Agent Swarm**

## Overview
Optimized kernel virtual memory, paging, and I/O writeback parameters tailored specifically for Raspberry Pi 5 with 8GB LPDDR4X RAM and high-speed PCIe Gen3 NVMe SSD.

## Components

### 1. ZRAM In-Memory Compressed Swap (`zram-generator.conf`)
- **Device**: `zram0`
- **Size**: `4096MB` (4GB)
- **Compression**: `zstd` (high compression ratio and lightning throughput)
- **Swap Priority**: `100` (favors in-RAM compressed memory over any secondary NVMe swap)
- **Benefit**: Eliminates NVMe disk write thrashing under heavy multitasking workloads (browsers, IDEs, compiler jobs, local LLMs) and significantly extends NVMe flash endurance.

### 2. Kernel Virtual Memory Tuning (`99-pi5-sysctl.conf`)
- `vm.swappiness = 100`: Aggressively pages cold, idle anonymous memory into fast zram, keeping physical RAM open for filesystem cache.
- `vm.vfs_cache_pressure = 50`: Retains directory dentries and inode metadata in RAM longer to accelerate indexing, git, and filesystem responsiveness.
- `vm.dirty_background_ratio = 5`: Triggers asynchronous background writeout to NVMe when dirty pages reach 5% (~400MB on 8GB RAM), preventing large bursty flush spikes.
- `vm.dirty_ratio = 10`: Imposes a hard throttle at 10% (~800MB) before blocking processes on disk sync, eliminating UI frame drops and system micro-stutters.

## Deployment
Run `./apply_tuning.sh` as root to install `/etc/systemd/zram-generator.conf`, `/etc/sysctl.d/99-pi5-sysctl.conf`, and apply parameters immediately.
