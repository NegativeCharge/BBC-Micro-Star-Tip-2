# Star Tip 2 (BBC Micro Port)

This project is a BBC Micro port of Tim Follin's **Star Tip 2**, originally ported to the Commodore PET by David Given.  
The music is by Tim Follin; the code for this port is by Negative Charge (June 2025).

See details on the original [Star Tip 2](http://www.breakintoprogram.co.uk/hardware/computers/zx-spectrum/sound) and David Given's [Commodore PET port](https://gist.github.com/davidgiven/ca1631e072b894602437aebef4504526)

## Features

- Plays the full Star Tip 2 music on BBC Micro hardware or emulator.
- Uses the SN76489 sound chip via the System VIA.
- Written in 6502 assembly, assembled with [BeebAsm](https://github.com/stardot/beebasm).

## File Structure

- `main.asm` — Main 6502 assembly source code.
- `main.ssd` — Assembled disk image for use with BBC Micro emulators.
- `.vscode/` — VS Code configuration for building and testing.
- `README.md` — This file.

## Building

To build the project, you need [BeebAsm](https://github.com/stardot/beebasm) installed and available in your PATH, and the BeebVSC extension for Visual Studio Code.

From the command line:

```sh
BeebAsm.exe -v -i [main.asm](http://_vscodecontentref_/0) -do [main.ssd](http://_vscodecontentref_/1) -boot play
```

## License

The code for this port is released under [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/).  
See [LICENSE.md](LICENSE.md)