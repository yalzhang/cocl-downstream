# Confidential Cluster Operator (cocl-operator)

This repository provides downstream customizations for the `trusted-execution-clusters` operator. Customizations are applied via command-line variable overrides and a manifest customization script.

## Prerequisites

- `git`
- `go` (version 1.25+)
- `rust` & `cargo`
- `kind` (v0.17.0+)
- `kubectl`
- A container runtime CLI (`podman` or `docker`)

## Local Development

### Configure Upstream Source

The git submodule pointer defines the specific upstream commit to be used. To update to a different version:

```bash
cd operator
git fetch
git checkout <desired-commit-or-tag>
cd ..
git add operator
git commit -m "Update upstream operator to <version>"
```

### Deploy to Local Cluster

Sync the source code, apply customizations, and deploy the operator to a local `kind` cluster:

```bash
# Sync the upstream source code via git submodule
git submodule update --init

# Install build tools and create the kind cluster
export CONTAINER_CLI=docker  # Skip this if you use podman
export RUNTIME=docker        # Skip this if you use podman
make -C operator build-tools
make -C operator cluster-up

# Generate the deployment manifests with customized names
export NAMESPACE=confidential-clusters
export REGISTRY=localhost:5000
export TAG=latest
make -C operator \
  NAMESPACE=${NAMESPACE} \
  REGISTRY=${REGISTRY} \
  OPERATOR_IMAGE=${REGISTRY}/cocl-operator:${TAG} \
  manifests
./hack/customize-manifests.sh

# Build and push the images
make -C operator \
  REGISTRY=${REGISTRY} \
  OPERATOR_IMAGE=${REGISTRY}/cocl-operator:${TAG} \
  push

# Deploy the operator
# Replace TRUSTEE_ADDR with the IP address that the libvirt VM can access
make -C operator \
  NAMESPACE=${NAMESPACE} \
  TRUSTEE_ADDR=192.168.122.1 \
  install
```

### Clean Up

To tear down the `kind` cluster:

```bash
make -C operator cluster-down
```

## Building the OLM Bundle

The OLM bundle enables distribution of the operator through OperatorHub or OLM catalogs.

### Build the Bundle Image

Build with default settings:

```bash
docker build -f Containerfile.bundle -t cocl-operator-bundle:latest .
```

Build with custom image references:

```bash
docker build -f Containerfile.bundle \
  --build-arg OPERATOR_IMAGE=quay.io/myorg/cocl-operator:0.1.0 \
  --build-arg COMPUTE_PCRS_IMAGE=quay.io/myorg/compute-pcrs:0.1.0 \
  --build-arg REG_SERVER_IMAGE=quay.io/myorg/registration-server:0.1.0 \
  --build-arg TRUSTEE_IMAGE=quay.io/myorg/key-broker-service:latest \
  --build-arg TAG=0.1.0 \
  --build-arg NAMESPACE=confidential-clusters \
  -t quay.io/myorg/cocl-operator-bundle:0.1.0 .
```

### How the Bundle Build Works

The bundle build process:

1. Uses the upstream source code from the git submodule (at the commit specified by the submodule pointer)
2. Generates the OLM bundle using upstream's workflow
3. Applies downstream customizations (renames to cocl-operator, updates branding)
4. Creates a minimal OLM bundle image with only manifests and metadata

**Note**: For Konflux builds, ensure the pipeline is configured to initialize git submodules during the clone-repository task.

### Test the Bundle

**Prerequisites**: OLM (Operator Lifecycle Manager) and `operator-sdk` must be installed.

```bash
# Push bundle image to a registry
docker push quay.io/myorg/cocl-operator-bundle:0.1.0

# Deploy the operator
operator-sdk run bundle quay.io/myorg/cocl-operator-bundle:0.1.0

# Verify installation
kubectl get csv -n confidential-clusters
kubectl get pods -n confidential-clusters
```

**Note**: For production deployment via OperatorHub, the bundle is consumed through the catalog publishing workflow.

## Creating Custom Resources

After deploying the operator (via either local development or OLM bundle), create the required custom resources.

### TrustedExecutionCluster

Create a TrustedExecutionCluster CR to configure the confidential cluster:

```bash
# Replace TRUSTEE_ADDR with the IP address that VMs can access
cat <<EOF | kubectl apply -f -
apiVersion: trusted-execution-clusters.io/v1alpha1
kind: TrustedExecutionCluster
metadata:
  name: confidential-cluster
  namespace: confidential-clusters
spec:
  pcrsComputeImage: "quay.io/myorg/compute-pcrs:0.1.0"
  registerServerImage: "quay.io/myorg/registration-server:0.1.0"
  trusteeImage: "quay.io/trusted-execution-clusters/key-broker-service:tpm-verifier-built-in-as-20250711"
  publicTrusteeAddr: "192.168.122.1:8080"
EOF
```

### ApprovedImage

Create an ApprovedImage CR to specify which container images are approved for execution:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: trusted-execution-clusters.io/v1alpha1
kind: ApprovedImage
metadata:
  name: coreos
  namespace: confidential-clusters
spec:
  image: quay.io/trusted-execution-clusters/fedora-coreos@sha256:e71dad00aa0e3d70540e726a0c66407e3004d96e045ab6c253186e327a2419e5
EOF
```

### Verify Resources

```bash
kubectl get trustedexecutionclusters -n confidential-clusters
kubectl get approvedimages -n confidential-clusters
```

## Starting Confidential VMs

After creating the custom resources, you can start confidential VMs that will register with the cluster.

