# Confidential Cluster Operator (cocl-operator)

This repository provides downstream customizations for the `trusted-execution-clusters` operator. It uses a patch-based system to modify the upstream source code before building and deploying.

## Prerequisites

- `git`
- `go` (version 1.21+)
- `rust` & `cargo`
- `kind` (v0.17.0+)
- `kubectl`
- A container runtime CLI (`podman` or `docker`).
- `patch`

## Workflow

### 1. Configure Upstream Source

The `sync-source-config.txt` file defines the upstream repository and the specific commit to be used. You can modify this file to target a different version of the upstream operator.

### 2. Set Up Local Cluster & Deploy

The following steps will sync the source code, apply customizations, and deploy the operator to a local `kind` cluster.

```bash
# 1. Sync the upstream source code
source sync-source-config.txt
./hack/sync-source.sh "${UPSTREAM_REPO}" "${UPSTREAM_REF}" "${DEST_DIR}"

# 2. Apply downstream customizations to the Makefile
patch -p1 < 0001-combined-makefile-customizations.patch

# 3. Install build tools (like yq) and create the kind cluster
export CONTAINER_CLI=docker  # Skip this if you use podman
export RUNTIME=docker # Skip this if you use podman
make -C operator build-tools
make -C operator cluster-up

# 4. Generate the deployment manifests
make -C operator REGISTRY=localhost:5000 manifests

# 5. Build the images and deploy the operator
make -C operator REGISTRY=localhost:5000 push
# Replace TRUSTEE_ADDR with the the IP address that the libvirt VM can access.
make -C operator TRUSTEE_ADDR=192.168.122.1 install
```

### Cleaning Up

To tear down the `kind` cluster and remove all deployed resources, run:

```bash
make -C operator cluster-down
```
