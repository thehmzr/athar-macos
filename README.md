# Athar

Resizable quote widget for the Mac desktop, with a proper Arabic font library.
Everything's unlocked. No account, no network.

![Athar](docs/images/banner.png)

## Install

Get `Athar.dmg` from [Releases](../../releases), drag into Applications.
Needs macOS 14+.

ad-hoc signed, so run this before you open it the first time:

```bash
xattr -dr com.apple.quarantine /Applications/Athar.app
```

Building it yourself:

```bash
git clone https://github.com/thehmzr/athar-macos.git && cd athar-macos
./build.sh --install
```

lives in the menu bar, no Dock icon.

To remove: `rm -rf /Applications/Athar.app ~/Library/Application\ Support/Athar`

## WFuncion

Drag any edge to resize, 160x110 up to a full-width banner. text resizes
itself to fit. run as many widgets as you want, each set up differently.


Shuffles also

### Fonts

different fonts 

![Arabic faces](docs/images/settings-typography.png)

### appearances

10 presets. Solid, gradient, glass or image backgrounds.

![Dark themes](docs/images/themes-dark.png)
![Light themes](docs/images/themes-light.png)

align system light/dark setting, text included.

![Glass in dark and light](docs/images/glass-adaptive.png)

### Quotes

297 of them, 103 English and 194 Arabic. Qur'an, hadith, poetry, proverbs,
philosophy, literature. Filter by language, source, category or length. Arabic
scripture gets an English translation underneath.

can delete any of them if wanted

![Filtering](docs/images/settings-content.png)

switch off any source you don't want, favourite things, sort them into
collections, or add your own quotes.

![Included content](docs/images/settings-library.png)

## Licence

Code is public domain, see [LICENSE](LICENSE).

Fonts are SIL OFL 1.1. See [CREDITS.md](CREDITS.md) for fonts and where the text
came from.
