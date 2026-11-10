#!/usr/bin/env bash
# Runs a game's helm upgrade, then puts the StatefulSet back to the replica count it had
# before. Helm keeps each revision's rendered manifest, so --atomic's rollback re-applies
# whatever count that older revision was rendered with: it can stop a running game, or pin
# a game at 0 so nothing starts it again.
# Usage: upgrade-release.sh <namespace> <release> <helm upgrade argument ...>
set -euo pipefail
namespace=$1 release=$2
shift 2

read_replica_count() {
  kubectl -n "$namespace" get statefulset "$release" -o jsonpath='{.spec.replicas}' 2>/dev/null || true
}

# Empty on a first install, when there is no StatefulSet yet to keep the count of.
replica_count_before_upgrade=$(read_replica_count)

restore_replica_count() {
  [ -n "$replica_count_before_upgrade" ] || return 0
  local replica_count_now
  replica_count_now=$(read_replica_count)
  [ "$replica_count_now" != "$replica_count_before_upgrade" ] || return 0
  echo "The release left $release at $replica_count_now replica(s);" \
    "putting it back to $replica_count_before_upgrade" >&2
  kubectl -n "$namespace" scale "statefulset/$release" --replicas="$replica_count_before_upgrade"
}
trap restore_replica_count EXIT

helm upgrade --install "$@"
