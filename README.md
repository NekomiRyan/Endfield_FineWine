[![build](https://github.com/stoicswe/Endfield_FineWine/actions/workflows/build.yml/badge.svg)](https://github.com/stoicswe/Endfield_FineWine/actions/workflows/build.yml)

[![nightly](https://github.com/stoicswe/Endfield_FineWine/actions/workflows/nightly.yml/badge.svg)](https://github.com/stoicswe/Endfield_FineWine/actions/workflows/nightly.yml)

[![Generate Wiki Documentation](https://github.com/stoicswe/Endfield_FineWine/actions/workflows/update-wiki.yml/badge.svg)](https://github.com/stoicswe/Endfield_FineWine/actions/workflows/update-wiki.yml)

# Endfield_FineWine — Arknights: Endfield on Apple Silicon macOS

Run **Arknights: Endfield** on an Apple Silicon Mac through a **custom-patched CrossOver Wine** — past the game's VMProtect/TenProtect armor, past the **ACE anti-cheat**, rendering through Apple's **D3DMetal**, all the way into gameplay. CodeWeavers rated Endfield *"Installs, Will Not Run"* and the community consensus was that CrossOver + Endfield was impossible; this repository is the first known working setup, plus the full engineering write-up of how it was found.

> **What this is:** a set of **patches** to CrossOver's (LGPL) Wine, plus **scripts** and **documentation** to build and deploy them. It does **not** contain or redistribute CrossOver, Wine, Apple's Game Porting Toolkit, or the game — you bring your own licensed copies of each.
>
> **Scope & ethics:** own the game; this is compatibility work (the same category as Valve's Proton on Linux) — no in-game advantage, no modified game logic, no DRM circumvention. Running the game in an unsupported configuration may violate its Terms of Service; that risk is yours (see [LICENSE](LICENSE)). Not affiliated with Gryphline/Hypergryph, Tencent, CodeWeavers, or Apple.

## Features

- ✅ VMProtect/TenProtect protector (`EndfieldBase.dll`) passes
- ✅ **ACE anti-cheat** passes fully — `ACE-Base64.dll`, `ACE-Service64.exe`, kernel driver `ACE-BASE.sys`
- ✅ Unity engine loads and renders through **Apple D3DMetal**
- ✅ **Login screen + gameplay** verified on Apple M4 Pro, M3, and a base M4 with 16 GB (playable at low settings — [performance notes](docs/14-performance-on-16gb-macs.md))
- Tested on macOS 27.0 and macOS 26.5 with CrossOver 26.2.0; other Apple Silicon chips and nearby versions are expected to work
- One cosmetic residual: a background ACE thread aborts on `ntoskrnl.exe.PsGetProcessExitStatus`; the game reaches login/gameplay regardless

## Quick Start

| | |
|---|---|
| **Mac** | Apple Silicon (M-series); Intel not supported |
| **macOS** | 15 (Sequoia) or newer — tested on 27.0 / 26.5 |
| **Rosetta 2** | required: `softwareupdate --install-rosetta --agree-to-license` |
| **CrossOver** | **26.2**, licensed, from [codeweavers.com](https://www.codeweavers.com/crossover) |
| **Xcode CLT / Homebrew** | `xcode-select --install` · [brew.sh](https://brew.sh) |
| **Disk / time** | ~5 GB for the build tree; build ~20–60 min |

```bash
git clone <your-fork-url> Endfield_FineWine && cd Endfield_FineWine

./scripts/build-wine.sh all          # 1. build the patched Wine (deps -> fetch -> patch -> configure -> build)

./scripts/swap-into-crossover.sh     # 2. deploy into a copy of CrossOver -> /Applications/CrossOver_Endfield_Patch.app

./scripts/create-bottle.sh           # 3. create the "Arknights Endfield" bottle (Win11 64-bit, D3DMetal + DLSS + MSync)
                                     #    …then install the Gryphline launcher into it via CrossOver's GUI

open /Applications/CrossOver_Endfield_Patch.app   # 4. run the game — NOT the stock CrossOver app
                                     #    in the launcher: dropdown next to Start -> "Launch with DirectX 11"
                                     #    (the plain Start button uses the game's default Vulkan renderer, which
                                     #    white-screens under CrossOver 26.2)
```

Full requirements, a manual (auditable) deployment, the bottle/Gryphline setup, and launch options: **[docs/installation.md](docs/installation.md)**.

## How it works (short version)

Two newly-discovered **Rosetta 2** bugs, plus a port of the Linux **dw-proton** anti-cheat patches:

1. **Rosetta faults on a plain NOP.** VMProtect emits `0F 1F` multi-byte NOPs by the 100k; Rosetta wrongly raises an illegal-instruction fault on them. Fix: skip the NOP.
2. **Rosetta mis-classifies a privileged instruction.** ACE's driver reads `CR3` (`mov rbx, cr3`) as an anti-VM probe; under Rosetta this arrives as an *invalid-opcode* fault instead of `#GP`, so ACE got the wrong exception. Fix: deliver `EXCEPTION_PRIV_INSTRUCTION`, like Linux.
3. **dw-proton port:** 17 `ntoskrnl.exe` function backports + the `KiUser*Dispatcher` int3 spoof + a QPC-timing patch clear the ACE-init blockers.

Both Rosetta fixes are ~40 lines in `dlls/ntdll/unix/signal_x86_64.c` and help a whole class of protected games on Apple Silicon (cf. WineHQ **Bug 45083**). Full engineering story: **[docs/13-working-solution.md](docs/13-working-solution.md)** and the [docs/](docs/README.md) set.

## Documentation

The full guides live in [docs/](docs/README.md) — and are published to the project **wiki** by [git-wiki-builder](https://github.com/MakerCorn/git-wiki-builder) (see [.github/workflows/update-wiki.yml](.github/workflows/update-wiki.yml)):

| | |
|---|---|
| [Installation & setup](docs/installation.md) | requirements, building, deploying into CrossOver, bottle + game install, running, debug logging |
| [Graphics & performance](docs/graphics-performance.md) | the DirectX 11 rule, backend selection, the optional GPTK4 upgrade |
| [Troubleshooting](docs/troubleshooting.md) | damaged bundle, white screen, error 1114, and other common failures |
| [Performance on 16 GB Macs](docs/14-performance-on-16gb-macs.md) | measured memory/CPU/GPU numbers, settings that play well |
| [The working solution](docs/13-working-solution.md) | the full engineering write-up — start of the deep dive |
| [docs index](docs/README.md) | all guides, research, and project history |

## Repository layout

```
patches/            The Wine patches (LGPL — see below)
  stage1-macos/       our two Rosetta fixes + build/msync fixes
  stage2-dwproton/    the ported dw-proton anti-cheat patches (em-backports + misc)
scripts/            build-wine.sh, swap-into-crossover.sh, bottle/launch/debug helpers
patcher-app/        FineWine Patcher.app — the GUI module swap for end users
docs/               user guides + the full engineering write-up (start at docs/README.md)
build/              (gitignored) the Wine source + build output you generate
```

## License

- **Scripts (`scripts/`) and documentation (`docs/`, README):** [MIT](LICENSE).
- **Patches (`patches/`):** these are modifications to **Wine**, so they are **LGPL-2.1-or-later** (Wine's license) — MIT cannot relicense them. The `stage2-dwproton/` patches originate from the **dw-proton (Dawn Winery)** project and retain their upstream authors' rights. See [patches/README.md](patches/README.md).
- This repo **does not distribute** Wine, CrossOver, Apple's GPTK, MoltenVK, or the game. Get each from its source, under its own license.

## Credits

- **[dw-proton / Dawn Winery](https://dawn.wine/)** — the Linux ACE/Endfield patches that stage 2 ports.
- **[CodeWeavers CrossOver](https://www.codeweavers.com/crossover)** and the **[Wine](https://www.winehq.org/)** project — the foundation this builds on.
- **[Apple Game Porting Toolkit](https://developer.apple.com/games/game-porting-toolkit/)** — D3DMetal.
- **WineHQ Bug 45083** reporters — the prior art that framed the Rosetta VMProtect problem.

## Contributing / upstreaming

The two Rosetta signal-handling fixes are general CrossOver-on-Apple-Silicon bugs and are worth reporting to **CodeWeavers** (with Bug 45083 as reference). PRs to improve the build/deploy scripts, packaging (e.g. a CXPatcher-style overlay), and testing on more chips/macOS versions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).