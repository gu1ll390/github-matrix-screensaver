Matrix Screensaver for macOS
============================

A Matrix "digital rain" screensaver for macOS in the style of the terminal
program [cmatrix](https://github.com/abishekvashok/cmatrix): random characters
fall in every other text column, green with a white leading character, with
several streams per column.

It is drawn natively, runs on Apple silicon and Intel Macs, and needs no
network access.

## History

This project began as the GitHub Matrix Screensaver by
[winterbe](https://github.com/winterbe/github-matrix-screensaver), which showed
recent GitHub commits in a web view hosted by Tom Robinson's
[WebSaver](https://github.com/tlrobinson/WebSaver). That version was built for
Intel only, and its commit feed no longer returns data. Version 3.0 replaces it
with the native renderer in `src/MatrixSaverView.m`; the screensaver no longer
shows GitHub activity.

## Requirements

* macOS 11 or later
* The Xcode command line tools, only if you want to rebuild (`xcode-select --install`)

## Install

The repository contains a prebuilt universal `Web.saver`.

* Clone this project, then double click `Web.saver` in the project folder and
  choose to install it. Or copy it yourself:

  ```sh
  cp -R Web.saver ~/Library/Screen\ Savers/
  ```

* Open System Settings, choose Screen Saver and select `Matrix`.

If you replace an installed copy with a new build, close and reopen System
Settings so the new build is loaded.

## Build

```sh
./build.sh
```

This compiles `src/MatrixSaverView.m` for arm64 and x86_64, copies
`src/Info.plist` into the bundle and signs `Web.saver` with an ad-hoc
signature. Apple silicon will not load unsigned code, so rebuild with the
script rather than editing the bundle by hand.

## Customize

The look is set in `src/MatrixSaverView.m`:

* `kTick` – time between steps of the rain (speed)
* the font and size in `-buildGridForSize:`
* the three colours in `-drawRect:` (green, bright green, white head)

Rebuild and reinstall after changing them.

## Uninstall

Open System Settings, choose Screen Saver, right click `Matrix` and choose
delete. Or remove the bundle:

```sh
rm -r ~/Library/Screen\ Savers/Web.saver
```

## License

See [LICENSE](LICENSE).
