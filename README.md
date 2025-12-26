# Confidential Cluster Operator (cocl-operator)

This repository provides downstream customizations for the `trusted-execution-clusters` operator. It uses a patch-based system to modify the upstream source code before building and deploying.

## Prerequisites

- `git`
- `go` (version 1.25)
- `rust` & `cargo`
- `kind` (v0.17.0+)
- `kubectl`
- A container runtime CLI (`podman` or `docker`).
- `patch`

## Workflow

### Configure Upstream Source

The `sync-source-config.txt` file defines the upstream repository and the specific commit to be used. You can modify this file to target a different version of the upstream operator.

```bash
# 1. Sync the upstream source code
source sync-source-config.txt
./hack/sync-source.sh "${UPSTREAM_REPO}" "${UPSTREAM_REF}" "${DEST_DIR}"

# 2. Apply downstream customizations to the Makefile
patch -p1 < 0001-combined-makefile-customizations.patch
```

### Set Up Local Cluster & Deploy

The following steps will sync the source code, apply customizations, and deploy the operator to a local `kind` cluster.

```bash
# 1. Install build tools (like yq) and create the kind cluster
export CONTAINER_CLI=docker  # Skip this if you use podman
export RUNTIME=docker # Skip this if you use podman
make -C operator build-tools
make -C operator cluster-up

# 2. Generate the deployment manifests
make -C operator REGISTRY=localhost:5000 manifests

# 3. Build the images and deploy the operator
make -C operator REGISTRY=localhost:5000 push
# Replace TRUSTEE_ADDR with the the IP address that the libvirt VM can access.
make -C operator TRUSTEE_ADDR=192.168.122.1 install
```

### Cleaning Up

To tear down the `kind` cluster and remove all deployed resources, run:

```bash
make -C operator cluster-down
```
### OLM Bundle Workflow

This operator can be packaged and deployed as an OLM bundle. This workflow supports deploying to any Kubernetes cluster with access to a container registry.

**1. Prerequisites**
Sync the upstream source code first, then for local development (kind):

```bash
# Set RUNTIME=docker if using Docker instead of Podman
make -C operator cluster-up
# Login to your remote container registry (e.g., quay.io)
docker login quay.io
# Install OLM on your target cluster
operator-sdk olm install
```

**2. Set Environment Variables**

Define the container registry, image tag, and CLI.

```bash
export REGISTRY=quay.io/<your-username>
export TAG=0.1.0
export CONTAINER_CLI=docker # or podman
```
> **Note:** The `TAG` must be a valid semantic version (e.g., `0.1.0`). OLM does not support tags like `latest` for bundle versions.

**3. Build, Validate, and Push**

The `push-all` target builds all operator images, generates the bundle, builds the bundle image, and pushes everything to the specified `$REGISTRY`.

```bash
make -C operator push-all
```

**4. Deploy the Bundle**

Deploy the bundle to your cluster. We use `confidential-clusters` as an example namespace.

```bash
kubectl create namespace confidential-clusters || true
operator-sdk run bundle ${REGISTRY}/cocl-operator-bundle:${TAG} --namespace confidential-clusters
```

**5. Create the Custom Resource**

Once the operator is running, you need to create a `TrustedExecutionCluster` custom resource to make it functional.

First, you must update the example CR with the correct public address for the Trustee service, which must be accessible from your worker nodes or VMs.

```bash
# Determine an address reachable by the VMs (for libvirt, usually the bridge IP)
ip route | grep virbr0
# Example output:
# 192.168.122.0/24 dev virbr0 proto kernel scope link src 192.168.122.1
export TRUSTEE_ADDR=192.168.122.1

# Update the CR with the trustee address (yq is installed via `make build-tools`)
yq -i '.spec.publicTrusteeAddr = "'$TRUSTEE_ADDR':8080"' \
  operator/config/deploy/trusted_execution_cluster_cr.yaml

# Apply the configured CRs
kubectl apply -f operator/config/deploy/trusted_execution_cluster_cr.yaml
kubectl apply -f operator/config/deploy/approved_image_cr.yaml
kubectl apply -f operator/kind/kbs-forward.yaml
kubectl apply -f operator/kind/register-forward.yaml
```

#### **Cleaning Up the Bundle Deployment**

To remove all resources deployed by the bundle, use the `cleanup` command with the operator's package name:

```bash
(cd /tmp && operator-sdk cleanup cocl-operator --namespace confidential-clusters)
```

### Quick Start Cleanup

To clean up your environment after running the non-OLM `Quick Start` method, execute the following commands:
```bash
make cluster-cleanup
# Note: You must use the same RUNTIME environment variable for `cluster-down`
# that you used for `cluster-up`. For example:
# RUNTIME=docker make cluster-down
make cluster-down
make clean
```

## Licenses

See [LICENSES](LICENSES).
