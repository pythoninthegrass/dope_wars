# Windows container (dockurr/windows)

A Windows 11 GUI install used as a native Windows build/oracle host. Reachable
from the host machine (`mf`) over published ports.

## Access

- SSH on **port 2222** → lands in **PowerShell** (not `cmd`), key-based auth.
- noVNC on **port 8006** → the Windows desktop.
- RDP on **port 3389** (TCP + UDP).

From `mf`, connect over the LAN-bound address (ports are forwarded to the LAN
interface, not `localhost`):

```sh
ssh -p 2222 lance@192.168.8.69
```

`ssh -p 2222 ...@localhost` will fail with `Connection refused` while the LAN
address works. If the container is restarted, re-check `docker ps` for the
current port binding — the LAN IP can change.

`docker exec windows` does **not** reach the guest; it lands in the QEMU host
layer (Debian). Use SSH for anything inside Windows.

## What's installed

- **Chocolatey 2.7.4** — the package manager. Install packages through it:
  `choco install <name> -y --no-progress`.
- **Python 3.13.16** at `C:\Python313` (matches the host's pinned
  `python 3.13.16` in `.tool-versions`, and the host's `core/.venv` is
  `lib/python3.13`).
- **uv 0.13.1** (`x86_64-pc-windows-msvc`) at
  `C:\ProgramData\chocolatey\lib\uv\tools\uv.exe`.

### Known quirks

- **uv is not on PowerShell's PATH** after a Chocolatey install: no shim is
  created in `C:\ProgramData\chocolatey\bin\`, and `where.exe uv` finds nothing.
  Invoke the absolute path: `& 'C:\ProgramData\chocolatey\lib\uv\tools\uv.exe'`.
- **uv refuses to run outside a virtual environment.** To use the system
  interpreter, pass `--system`: `uv pip install --system <pkg>`.
- The Beermat 2.1 oracle lives in `C:\dopewars21\` (`DopeWars.exe`,
  `Olchk32.dll`, `cities.txt`, `oldlady.txt`, `Sounds\`). Keep it untouched —
  installs are additive in their own locations.
