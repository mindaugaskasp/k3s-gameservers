#!/usr/bin/env bash
# Optional: installs VPA cluster-wide, incl. an admission webhook.
# https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}" # /etc/rancher/k3s/k3s.yaml is root-only

if kubectl get crd verticalpodautoscalers.autoscaling.k8s.io >/dev/null 2>&1; then
  echo "VPA CRDs already present; nothing to do."
  exit 0
fi

echo "Installing Vertical Pod Autoscaler components..."
tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT

# Must match vpa-up.sh's DEFAULT_TAG: it checks out that tag, which a
# shallow clone of master lacks. Bump both together.
VPA_TAG="vertical-pod-autoscaler-1.7.1"
git clone --depth 1 --branch "${VPA_TAG}" \
  https://github.com/kubernetes/autoscaler.git "${tmpdir}/autoscaler"

# vpa-up.sh's own git-switch and its cert paths are relative to its cwd,
# not its script location, so it has to be run from inside the checkout.
(cd "${tmpdir}/autoscaler/vertical-pod-autoscaler" && ./hack/vpa-up.sh)

echo "Done. Check with: kubectl get pods -n kube-system -l app=vpa-recommender"
