# Images

Every image this repo runs is pinned as `tag@sha256:...`. The tag stays for
readability; the digest is what the kubelet and podman actually resolve, so a tag
that moves upstream cannot change what runs here.

Where the pins live:

- **Game servers:** `repository`, `tag` and `digest` in `games/<game>/chart/values.yaml`.
  The chart renders `repository:tag@digest`.
- **Helm helpers:** `_backup.tpl` and `_status-metrics.tpl` name their image inline.
- **Platform:** `platform/**/*.yaml` and `game-server/restore-helper-pod.yaml`.
- **Built here:** the status-metrics and Terraria images are tagged by commit and
  pushed to the in-cluster registry, so they need no digest; their base images are pinned.

Several game images carry `tag: latest` on purpose: upstream publishes no versions.
Four of them (V Rising, Dragonwilds, Palworld, Satisfactory) update the game itself
with steamcmd on every start, so the digest pins the wrapper, not the game build.

## Bumping a pin

Renovate opens the PRs (`renovate.json`): grouped for digests, one per game server
image, and its own for anything with a vulnerability alert. Merging a PR only changes
git -- the cluster still needs `make deploy` from the game or platform folder, which
gates on nobody being online.

To read a digest by hand:

```bash
repo=library/alpine tag=3.20   # "library/<name>" for official images
token=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$repo:pull" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
curl -sI -H "Authorization: Bearer $token" -H 'Accept: application/vnd.oci.image.index.v1+json' \
  -H 'Accept: application/vnd.docker.distribution.manifest.list.v2+json' \
  "https://registry-1.docker.io/v2/$repo/manifests/$tag" | tr -d '\r' | sed -n 's/^docker-content-digest: //p'
```

`grep -rn 'sha256:' games platform game-server --include='*.yaml' --include='*.tpl' --include=Dockerfile`
lists every pin.
