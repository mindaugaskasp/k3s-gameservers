# Project Zomboid sandbox settings

Zombie count, day length, loot and the other world rules live in
`Server/<server.name>_SandboxVars.lua`, each with its choices and default in a comment above it.
The server rewrites that file when it starts, so edit it while the server is stopped
(run in `games/zomboid/`):

```sh
make scale-down-zero && kubectl -n games apply -f restore-helper-pod.yaml
kubectl -n games wait --for=condition=Ready pod/zomboid-restore-helper
kubectl -n games cp zomboid-restore-helper:/data/config/Server/<server.name>_SandboxVars.lua SandboxVars.lua
# edit SandboxVars.lua, then copy it back and start again:
kubectl -n games cp SandboxVars.lua zomboid-restore-helper:/data/config/Server/<server.name>_SandboxVars.lua
kubectl -n games delete -f restore-helper-pod.yaml && make scale-up
```

Changed settings appear under **World settings** on the website.
