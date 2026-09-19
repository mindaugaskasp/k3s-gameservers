#!/usr/bin/env bash
# Installs the Vertical Pod Autoscaler (CRDs, recommender, updater,
# admission controller) cluster-wide via upstream's own installer.
# Optional: skip this and leave verticalPodAutoscaler.enabled off in
# chart values if you'd rather not run third-party code with a
# cluster-wide admission webhook.
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}" # /etc/rancher/k3s/k3s.yaml is root-only

if kubectl get crd verticalpodautoscalers.autoscaling.k8s.io >/dev/null 2>&1; then
  echo "VPA CRDs already present; nothing to do."
  exit 0
fi

echo "Installing Vertical Pod Autoscaler components..."
tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT

# Pinned, not just latest master: vpa-up.sh hardcodes this same tag as its
# own default (both for `git switch --detach` and for the image tag it
# substitutes into the manifests), and a plain --depth 1 clone of the
# default branch doesn't have that tag's history for the switch to find.
# Bump both this and vpa-up.sh's DEFAULT_TAG together if you upgrade.
VPA_TAG="vertical-pod-autoscaler-1.7.1"
git clone --depth 1 --branch "${VPA_TAG}" \
  https://github.com/kubernetes/autoscaler.git "${tmpdir}/autoscaler"

# vpa-up.sh's own git-switch and its cert paths are relative to its cwd,
# not its script location, so it has to be run from inside the checkout.
(cd "${tmpdir}/autoscaler/vertical-pod-autoscaler" && ./hack/vpa-up.sh)

echo "Done. Check with: kubectl get pods -n kube-system -l app=vpa-recommender"
