# agy-toolbox-core

Camada 3 da família `*-runtime` / `*-toolbox`: estende `agy-runtime` (camada 2) sobre `scm-runtime` (camada 1), adicionando o arsenal de ferramentas CLI via `mise` (`30-toolbox.toml`), utilitários de sistema (`apt`) e suporte a Docker-in-Docker rootless (`DIND=1`).

## O que esta camada adiciona

1. **Utilitários de sistema (`apt`)**: ferramentas de texto, diff, compactação, editores (`nano`, `vim`) e dependências para Docker rootless (`iproute2`, `uidmap`, `iptables`, `fuse-overlayfs`, `slirp4netns`).
2. **Arsenal de CLI (`mise`)**: configurado em `rootfs/home/agent/.config/mise/conf.d/30-toolbox.toml` (`ast-grep`, `bat`, `choose`, `dasel`, `delta`, `difftastic`, `docker-cli`, `buildx`, `docker-compose`, `duckdb`, `eza`, `fd`, `fzf`, `grex`, `gron`, `htmlq`, `jc`, `just`, `miller`, `python`, `qsv`, `ripgrep`, `ripgrep-all`, `scc`, `sd`, `shellcheck`, `shfmt`, `uv`, `watchexec`, `yq`).
3. **Docker-in-Docker rootless (`start-dockerd.sh`)**: binários `dockerd`/`containerd`/`runc` + `docker-rootless-extras`.

## Docker (padrão)

Sem `DIND`, o `docker-cli` usa o daemon externo definido em `DOCKER_HOST`
(padrão `tcp://host.docker.internal:2375`, ou o socket do host montado).

## Docker-in-Docker (`DIND=1`)

Com `DIND=1`, o `agy.sh` (herdado da camada 2) aciona o `start-dockerd.sh` para iniciar um `dockerd` **rootless** (como o usuário `agent`, sem sudo) e aponta `DOCKER_HOST` para `unix:///tmp/docker-1000/docker.sock`. Sem `DIND=1` nada muda.

Requer `--privileged` e um volume em `/home/agent/.local/share/docker` (o overlay2
não funciona sobre o overlayfs do próprio container):

```bash
docker build -t agy-toolbox-core:latest .

docker run -it --rm \
  --privileged \
  -e DIND=1 \
  -v agy-docker:/home/agent/.local/share/docker \
  --env-file .env \
  agy-toolbox-core:latest
```

Testar dentro do container:

```bash
docker info
docker run --rm hello-world
```

Variáveis:

- `DIND=1`: habilita o dockerd interno.
- `DOCKERD_STORAGE_DRIVER`: driver de storage (padrão `overlay2`; use `fuse-overlayfs` ou `vfs` se falhar).

Logs do daemon: `/tmp/docker-1000/dockerd.log`. Se ele não subir, o `agy` inicia mesmo
assim e mantém o `DOCKER_HOST` anterior.

### Docker-in-Podman

A imagem também deve funcionar com Podman como host (ainda não validado). Comece pela
opção sem `--privileged`:

```bash
podman build -t agy-toolbox-core:latest .

podman run -it --rm \
  --device /dev/fuse --device /dev/net/tun \
  --security-opt seccomp=unconfined \
  --security-opt apparmor=unconfined \
  --security-opt label=disable \
  --security-opt unmask=ALL \
  -e DIND=1 \
  -e DOCKERD_STORAGE_DRIVER=fuse-overlayfs \
  -v agy-docker:/home/agent/.local/share/docker \
  --env-file .env \
  agy-toolbox-core:latest
```

Se falhar, tente com `--privileged` (equivalente ao exemplo do Docker):

```bash
podman run -it --rm --privileged -e DIND=1 \
  -v agy-docker:/home/agent/.local/share/docker \
  --env-file .env agy-toolbox-core:latest
```

Notas:

- Em Podman rootless, o usuário do host precisa de um range grande em `/etc/subuid` e
  `/etc/subgid` (≥ 65536) para o `newuidmap` do dockerd aninhado funcionar.
- O overlay2 nativo costuma falhar dentro de user namespace: use
  `DOCKERD_STORAGE_DRIVER=fuse-overlayfs` (ou `vfs` como último recurso, lento).
- Se o daemon não subir, veja `/tmp/docker-1000/dockerd.log`.
- Alternativa sem DinD: `podman system service` e monte o socket no container, com
  `DOCKER_HOST` apontando para ele (sem `DIND=1`).

> **Segurança:** `--privileged` dá ao container acesso quase total ao host, e o
> `agy` roda com `--dangerously-skip-permissions`. Use só em ambiente confiável.
> Alternativa sem `--privileged`: `--runtime=sysbox-runc` (requer Sysbox no host).
