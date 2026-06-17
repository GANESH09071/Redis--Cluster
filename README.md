# Redis Cluster Lifecycle Tool with Ansible

A production-grade command-line interface (`redis-tool`) built to automate the provisioning, status monitoring, data integrity validation, and zero-downtime rolling upgrades of a 6-node Redis Cluster running in containerized environments (Docker/Podman).

---

## Architecture Overview

1. **Host Orchestration (`redis-tool`)**: A Python 3 command-line script that executes checks, manages docker container infrastructure, seeds/verifies data, and invokes Ansible playbooks under the hood.
2. **Infrastructure**: Defined via `infra/compose.yml` and `infra/Containerfile` (Ubuntu 22.04 base). It spins up 6 nodes on a custom bridge network (`redis-net`) with static IPs `10.10.0.11` to `10.10.0.16`.
3. **Configuration Management**: A custom Ansible role (`ansible/roles/redis`) handles downloading, compiling from source (ensuring the exact version requested), configuring cluster parameters, starting the servers, and waiting for node availability.

---

## Prerequisites

The tool automatically performs a dependency check on startup. You must have:
1. **Container Runtime**: Docker (Docker Desktop on Windows/macOS, or Docker Engine on Linux) or Podman.
2. **Ansible**: `ansible-playbook` 2.14 or higher installed in the environment where the script is executed.

3. **Execution Permissions**: The `redis-tool` script must be marked as executable (on Linux/macOS/WSL):
   ```bash
   chmod +x redis-tool
   ```
   run this above command before provision.

---


## Commands

### 1. Provision the Cluster
Installs the specified version of Redis, configures it, and forms the cluster (3 masters, 3 replicas):
```bash
./redis-tool provision --version 7.0.15 --masters 3 --replicas-per-master 1
```

### 2. Check Cluster Status
Displays a beautiful dashboard showing cluster health, roles, master/replica mapping, slot ranges, key counts, and memory usage:
```bash
./redis-tool status
```

### 3. Seed Data
Generates and inserts 1000 deterministic key-value pairs (using SHA256 hashes of the keys) with cross-cluster slot routing:
```bash
./redis-tool data seed --keys 1000
```

### 4. Verify Data
Validates that all 1000 seeded keys exist and their values match the expected SHA256 signature:
```bash
./redis-tool data verify
```

### 5. Rolling Upgrade
Performs a safe, zero-downtime upgrade of all nodes to the target version:
```bash
./redis-tool upgrade --target-version 7.2.6 --strategy rolling
```

### 6. Full Verification
Runs all five health-check suites (Data Integrity, Version Consistency, Topology Health, Cluster State, and Replication Lag):
```bash
./redis-tool verify --full
```
### 7. Rollback (Stretch)
Downgrades the cluster back to a previous version using the same zero-downtime rolling strategy:
```bash
./redis-tool rollback --target-version 7.0.15
```

### 8. Add Nodes (Scale Out)
Scales out the cluster by adding a specified even number of nodes, provisioning them, and rebalancing the slots across the new topology:
```bash
./redis-tool scale --add-nodes 2
```

### 9. Remove Node (Scale In)
Scales in the cluster by migrating slots away from the target node, removing it from the cluster topology, and tearing down the container:
```bash
./redis-tool scale --remove-node <node_id_or_name>
```

---

## Rolling Upgrade Strategy

To achieve **zero client-visible downtime** during the upgrade:
1. **Pre-flight Checks**: Verifies cluster health, confirms all nodes are reachable, and runs a data integrity check to establish a baseline.
2. **Replicas First**: Upgrades all replica nodes one at a time. A replica is stopped, upgraded, restarted, and the tool blocks until `master_link_status` is `up` and the cluster returns to `ok`. This ensures no failovers are triggered during this stage and backup capacity is maintained.
3. **Masters with Failover**: Upgrades master nodes one at a time. For each master:
   * It triggers a `CLUSTER FAILOVER` on its upgraded replica.
   * This performs a clean, coordinated role swap where the replica becomes the master.
   * Once the swap is confirmed, the former master (now a replica) is stopped, upgraded, restarted, and synchronized with its new master.
4. **Post-Upgrade Verification**: Re-runs the full suite of data and topology checks.

---

## Assumptions & Trade-offs

- **Source Compilation**: Compiling Redis from source ensures that exact version numbers (e.g. `7.0.15`, `7.2.6`) are installed, rather than depending on whatever versions happen to be in the OS package repositories.
- **SSH Key Inject**: SSH keys are automatically generated under `ansible/ssh/` on first run and mounted to the containers. This removes the need to pre-configure passwords or host SSH keys manually.

## Known Limitations
   Rollback is manual and requires operator intervention.
   Simultaneous failures of multiple nodes are not automatically recovered.
   Production features such as monitoring, alerting, and backup management are outside the scope of this project.