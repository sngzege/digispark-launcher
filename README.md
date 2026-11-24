# digispark-launcher

Script repository for a Digispark (ATtiny85) plug-and-run launcher.

The card carries fixed firmware. When plugged in it selects the OS (via Num
Lock), opens a terminal, and fetches and runs the **dispatcher** from this
repository. The operation logic lives in these scripts, not on the card, so
you develop here without reflashing.

> **Scope:** Windows (PowerShell) is the supported target. The Linux
> dispatcher (`dispatch.sh`) and its tests are kept as infrastructure, but no
> Linux operations ship. Linux is not a development target.

## Flow

1. The dispatcher (`dispatch.ps1`) runs `ops/0` automatically.
2. It then shows a named menu (from `ops/menu`) and loops: fetch and run the
   selected `ops/<N>`, ask again. `q` quits.

## Layout

```
.env           Shared settings read by all scripts (see below)
ops/menu       Menu labels (N=Label) shown by the dispatcher
dispatch.ps1   Windows dispatcher (PowerShell)
dispatch.sh    Linux dispatcher (bash) - infrastructure, no Linux ops
ops/0.ps1      Operation that runs automatically on connect
ops/1.ps1      Disk Cleaner
ops/2.ps1      System Health Report (read-only)
ops/3.ps1      Log / Diagnostics
ops/4.ps1      Reserved (placeholder)
tests/         dispatch.sh unit tests
firmware/      Card firmware (flashed once; untouched during script dev)
```

## The menu (`ops/menu`)

The dispatcher fetches `ops/menu` and shows each `N=Label` line as a named
option (e.g. `1 - Disk Cleaner`). To name a new operation, add one line here;
to show a new slot (such as `4`), add its line. If the manifest cannot be
fetched the dispatcher falls back to a numeric menu. `q` always quits.

## Development

- To change an operation, edit `ops/<N>.ps1` and push to `main`. The card
  fetches the current version on every run.
- Keep comments minimal (a short file header); output text is English.

## Shared settings (`.env`)

The dispatcher fetches `.env` on every run and loads its `KEY=VALUE` lines as
environment variables (it parses `NAME=value` only; it runs no code). Scripts
read them as `$env:GH_OWNER` (PowerShell). When a value repeats across scripts
(repo name, host, port, default user), put it here so it changes in one place.

**The firmware cannot read `.env`** (it is compiled), so the initial fetch URL
stays fixed there; `.env` is only for the dispatcher and ops.

**SECURITY:** `.env` lives in this **public** repo. Never put a password,
token, API key, product key, or personal IP here - only non-secret config.

## Tests

```bash
bash tests/test_dispatch.sh
```

## Security

This repo is **public**. Never put secrets in any script. The card runs code
on insert (BadUSB pattern); use it only on your own machines.
