# Brim

A macOS menu bar timer that displays as a thin colored bar at the very top of your screen. The bar depletes from right to left as time runs out, giving you an always-visible sense of how much time is left.

On MacBooks with a notch, the bar wraps around the notch in a continuous U-shape.

Written to help me visually keep track of time remaining for tasks in an everpresent but unobtrusive way.

## Install

```bash
git clone https://github.com/jhartzler/brim.git
cd brim
./scripts/build-app.sh
cp -R build/Brim.app /Applications/
```

Requires Xcode Command Line Tools and macOS 14+.

## Usage

Launch Brim from Applications or Spotlight. A cap icon appears in your menu bar. Click it to:

- Start a timer with presets (5, 15, 25, 45 minutes)
- Enter a custom duration
- Change bar and flash colors in Settings
- Stop a running timer

You can also start timers via URL scheme:

```
brim://start?minutes=25
brim://stop
```

## Build

```bash
./scripts/build-app.sh
```

This compiles a release build, assembles the .app bundle, and ad-hoc code signs it.

To run without installing:

```bash
build/Brim.app/Contents/MacOS/Brim &
```
