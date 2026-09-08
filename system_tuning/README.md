# 8GB RAM & NVMe System Tuning Subsystem
**Omarchy Quatro Pi 5 Agent Swarm**

## Overview
Optimized kernel virtual memory, paging, and I/O writeback parameters tailored for Raspberry Pi 5 (4-8 GB LPDDR4X RAM SKUs) and high-speed PCIe Gen3 NVMe SSD. `apply_tuning.sh` warns when the detected RAM falls outside the 4-16 GB range the dirty_bytes tuning is calibrated for.

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
- `vm.dirty_background_bytes = 200M`: Triggers asynchronous background writeout to NVMe when 200 MB of dirty pages accumulates. Specified as an explicit byte budget (rather than a % of RAM) so the value stays correct on both 4 GB and 8 GB Pi 5 SKUs; 16 GB boards may want to tune this up via `apply_tuning.sh`'s RAM-detection warning.
- `vm.dirty_ratio = 10`: Imposes a hard throttle at 10% of RAM (400MB on 4GB, 800MB on 8GB, 1.6GB on 16GB) before blocking processes on disk sync, eliminating UI frame drops and system micro-stutters.

## Deployment
Run `./apply_tuning.sh` as root to install `/etc/systemd/zram-generator.conf`, `/etc/sysctl.d/99-pi5-sysctl.conf`, and apply parameters immediately.
