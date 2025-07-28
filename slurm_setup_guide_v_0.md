# Slurm Setup Guide (v0.1)
A concise, repeatable playbook for bringing up Slurm 25.05 + CUDA on a fresh Linux server that will host multiple simultaneous users.

---
## 0 .  Hardware & Firmware checklist
| Component | Best practice |
|-----------|---------------|
| **CPU**   | Enable **all** cores + HT in BIOS. Verify `lscpu` shows expected logical CPUs. |
| **GPU**   | Use server‑class cards or GeForce w/ recent driver. 1 GPU = 1 Slurm GRES. |
| **Boot**  | UEFI, secure‑boot optional. `iommu=on` if you plan passthrough/containers. |
| **BIOS updates** | Flash latest firmware before install to avoid micro‑code quirks. |

---
## 1 .  OS installation
* **Ubuntu 22.04 LTS** or newer, minimal install.
* Set static hostname (e.g. `merlin`), time‑syncd enabled.
* Create an admin user (e.g. `arthur`) & add to `sudo`.

---
## 2 .  Base packages
```bash
sudo apt update && sudo apt install -y \
    build-essential fakeroot devscripts equivs \
    munge libmunge-dev libhwloc-dev libjson-c-dev \
    nvidia-driver-550 ssh ufw  # optional firewall
```
* **Munge**: generates `/etc/munge/munge.key` → `chmod 600` & `chown munge:munge`.
* **Driver**: reboot & `nvidia-smi` ⇒ banner OK.

---
## 3 .  Build & install Slurm 25.05 debs
```bash
wget https://download.schedmd.com/slurm/slurm-25.05.1.tar.bz2
mkdir -p ~/builds/slurm/25.05.1 && cd ~/builds/slurm/25.05.1
tar xf ../../slurm-25.05.1.tar.bz2 && cd slurm-25.05.1
mk-build-deps -i debian/control        # installs build‑depends
debuild -b -uc -us                     # produces *.deb one dir up
sudo apt install ../slurm-smd_*amd64.deb \
                 ../slurm-smd-client_*amd64.deb \
                 ../slurm-smd-slurmctld_*amd64.deb \
                 ../slurm-smd-slurmd_*amd64.deb
```
Packages drop Systemd units in `/lib/systemd/system/`.

---
## 4 .  Service accounts & directories
```bash
sudo useradd -r -c "Slurm" -d /var/lib/slurm -s /usr/sbin/nologin slurm
sudo mkdir -p /var/spool/{slurm-llnl,slurmd} /var/log/slurm
sudo chown -R slurm:slurm /var/spool/slurm-llnl /var/spool/slurmd /var/log/slurm
```

---
## 5 .  Core configuration files
### `/etc/slurm/slurm.conf` (single‑node template)
```conf
ClusterName=mlcluster
ControlMachine=merlin
SlurmUser=slurm
SlurmdUser=root
AuthType=auth/munge
CryptoType=crypto/munge
StateSaveLocation=/var/spool/slurm-llnl
SlurmdSpoolDir=/var/spool/slurmd
SlurmctldLogFile=/var/log/slurm/slurmctld.log
SlurmdLogFile=/var/log/slurm/slurmd.log
ProctrackType=proctrack/cgroup
TaskPlugin=task/affinity,task/cgroup
SchedulerType=sched/backfill
SelectType=select/cons_tres
SelectTypeParameters=CR_Core_Memory
GresTypes=gpu
NodeName=merlin CPUs=16 Sockets=1 CoresPerSocket=8 ThreadsPerCore=2 \
        RealMemory=31925 Gres=gpu:nvidia_geforce_rtx_4070_ti_super:1 State=UNKNOWN
PartitionName=mlnodes Nodes=merlin Default=YES MaxTime=INFINITE State=UP
```
* Run `slurmd -C` and paste its `NodeName=` line to match CPU topology.

### `/etc/slurm/gres.conf`
```
AutoDetect=nvml               # or explicit lines: Name=gpu Type=rtx4070… File=/dev/nvidia0
```

### `/etc/slurm/cgroup.conf`
```
ConstrainCores=yes
ConstrainDevices=yes
ConstrainRAMSpace=yes
AllowedDevicesFile=/dev/null  # slurmd will chown GPUs to job cgroup
```

---
## 6 .  Enable & start services
```bash
sudo systemctl enable --now munge slurmctld slurmd
sudo scontrol reconfigure              # reload after edits
```
`journalctl -u slurmctld -u slurmd -f` for live logs.

---
## 7 .  Sanity tests
```bash
sinfo -N -o "%n %t %c %G"          # expect idle node, GPU listed
srun --gres=gpu:1 --pty nvidia-smi  # banner must appear
sbatch torch_test.sh                # see sample script below
```
`torch_test.sh` minimal:
```bash
#!/bin/bash
#SBATCH --gres=gpu:1
python - <<'PY'
import torch, os
print(torch.__version__, torch.version.cuda, torch.cuda.is_available())
PY
```

---
## 8 .  Multi‑user best practices
* Add every ML user to `video` group **or** keep cgroup `ConstrainDevices=yes`.
* Encourage `#SBATCH --gres=gpu:<n>` instead of hard‑coding IDs.
* Default partition = short/interactive; create long/training partitions with QoS.
* Enable accounting:
  * Install `slurm-smd-slurmdbd` package.
  * Configure MySQL/MariaDB → set `AccountingStorageType=accounting_storage/mysql`.
* Use `sacctmgr` to create accounts & enforce GPU/hour limits.

---
## 9 .  Monitoring / dashboards
| Tool | Purpose | Notes |
|------|---------|-------|
| **sview** | GTK app for live job/node view | `apt install slurm-smd-sview`. |
| **slurmrestd** | REST/JSON API | ships in Slurm; enable for Grafana. |
| **prometheus-slurm-exporter** | Exposes metrics | scrape with Prometheus → Grafana. |
| **Grafana dashboard** | Jobs, GPU util, queue depth | Use `mixins/slurm/grafana_dashboards/*`. |
| **nv-sm-plugin** | GPU per‑job utilisation | Requires DCGM, integrates with exporter. |

---
## 10 .  Upgrade & maintenance
* Build new RPM/DEB into **/usr/local/src/slurm/<ver>/**, install via `apt`.  
  Reusing spool & log dirs preserves jobs/history.
* Always restart `munge → slurmctld → slurmd` in that order.
* Backup `/etc/slurm`, `/var/spool/slurm-llnl`, database daily.

---
## 11 .  Common troubleshooting quick‑ref
| Symptom | Check | Fix |
|---------|-------|-----|
| `is_available=False` in PyTorch | `CUDA_VISIBLE_DEVICES`, `/dev/nvidia*`, group perms | add `--gres`, join `video`. |
| Node INVAL | mismatch CPU counts | `slurmd -C` → update `slurm.conf`, `scontrol reconfig`. |
| `Plugin initialization failed` | cgroup v1 vs v2 mismatch | purge `cgroup-lite`, stay on cgroup v2, or upgrade Slurm. |
| `fatal: Can not recover assoc_usage state` | state files from old version | `rm -rf /var/spool/slurm-llnl/*`. |

---
### Appendix A – minimal sbatch template
```bash
#!/bin/bash
#SBATCH -J myjob
#SBATCH -p mlnodes
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=12G
#SBATCH -t 08:00:00
#SBATCH -o slurm-%j.out

module load cuda/12.4  # if using modules
source ~/venvs/torch/bin/activate

python train.py --epochs 10
```

---
*Last updated: 2025‑07‑28*

