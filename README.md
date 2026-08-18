# Athar

A resizable quote widget for the Mac desktop, with a proper Arabic font library.
Everything's unlocked. No account, no network.

![Athar](docs/images/banner.png)

## Install

Grab `Athar.dmg` from [Releases](../../releases), drag it into Applications.
Needs macOS 14+.

It's ad-hoc signed, so run this before you open it the first time or macOS will
block it:

```bash
xattr -dr com.apple.quarantine /Applications/Athar.app
```

Building it yourself skips that:

```bash
git clone https://github.com/thehmzr/athar-macos.git && cd athar-macos
./build.sh --install
```

It lives in the menu bar, no Dock icon.

To remove: `rm -rf /Applications/Athar.app ~/Library/Application\ Support/Athar`

## What it does

Drag any edge to resize, 160x110 up to a full-width banner. The text resizes
itself to fit. You can run as many widgets as you want, each set up differently.

Sits on the desktop, or as a normal window, or always on top. Can be locked in
place, made click-through, or shown on every Space.

Shuffles anywhere from every 10 seconds to once a day, random or in order.

### Fonts

24 Arabic faces - Naskh, Kufic, Ruq'ah, Nasta'liq, display, modern. Amiri,
Scheherazade New, Aref Ruqaa, Reem Kufi, Noto Nastaliq, Cairo and others. RTL
with proper shaping and diacritics.

![Arabic faces](docs/images/settings-typography.png)

### Looks

10 presets. Solid, gradient, glass or image backgrounds. Separate colours for
the quote, translation, attribution and border.

![Dark themes](docs/images/themes-dark.png)
![Light themes](docs/images/themes-light.png)

Glass tracks the system light/dark setting, text included.

![Glass in dark and light](docs/images/glass-adaptive.png)

### Quotes

297 of them, 103 English and 194 Arabic. Qur'an, hadith, poetry, proverbs,
philosophy, literature. Filter by language, source, category or length. Arabic
scripture gets an English translation underneath.

![Filtering](docs/images/settings-content.png)

You can switch off any source you don't want, favourite things, sort them into
collections, or add your own quotes.

![Included content](docs/images/settings-library.png)

## Licence

Code is public domain, see [LICENSE](LICENSE).

Fonts are SIL OFL 1.1. See [CREDITS.md](CREDITS.md) for fonts and where the text
came from.
