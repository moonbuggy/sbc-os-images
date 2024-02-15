# Single Board Computer OS Images
Sometimes it can be tricky to get an OS running on a single board computer. It
seems sensible to put working images somewhere I won't lose them. Thus..

## Building
These are so far just Armbian images with minor modifications, built with
[their build system](https://github.com/armbian/build).

To build, copy the `userpatches/` folder into the Armbian build root and then
aim it at one of the `config-<board>.conf` files with:

```sh
./compile.sh BOARD=<board>
```

### Patches
New kernel patches can be added to the Armbian build system via the path
`userpatches/kernel/archive/<family>-<version>/` (e.g.
`userpatches/kernel/archive/sunxi-6.1/`).

## Links
*   <https://github.com/moonbuggy/sbc-power-status-boards>
