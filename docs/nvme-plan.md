# Planned: repurpose the second NVMe (ex-Windows, ~477GB) drive

Not done yet - this is the plan for when it's time to pull the trigger.
**Wiping this drive is destructive and needs an explicit go-ahead when
actually executed** - this section is prep, not a standing authorization.

Current state: `nvme0n1` is a separate physical drive from the main Linux
install (`nvme1n1`, LUKS + btrfs + snapper). Windows' usual layout (EFI,
MSR, NTFS, recovery partitions) - all disposable, nothing there is needed.

Plan: wipe it, LUKS-encrypt it to match the main drive's setup, format
btrfs, one subvolume per purpose so each can be snapshotted/rolled back
independently:

- `@games` - Steam library (`steamlibrary` or a symlinked `~/Games`).
  Keeps large game installs off the main 930GB drive.
- `@docker` - Docker's `data-root` pointed here (`/etc/docker/daemon.json`
  `"data-root"`), so container images/volumes stop competing with the main
  drive's snapshot space.
- `@sandbox` - distrobox/toolbox containers and libvirt/QEMU VM disk images.
  This covers "try another distro" far more practically than a real
  dual-boot partition: spin up an Arch/Fedora/Debian distrobox or a VM,
  break it freely, `rm -rf` it when done, main system untouched throughout.
- `@backup` - `btrfs send/receive` target for the main drive's snapper
  snapshots. A second physical drive is what actually makes a snapshot a
  backup instead of just an undo button on the same disk.
- `@media` - overflow storage / future self-hosting (photos via Immich,
  etc.) if that ever becomes a real project instead of a maybe.

Mount at `/mnt/data` (or similar) via `/etc/fstab`, referenced by UUID.
Encrypting it the same way as the main drive means one LUKS passphrase
prompt at boot unlocks both (keyfile-in-header, same pattern the main
install already uses) rather than two separate prompts.
