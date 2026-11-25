# PvP Flag Timer

> **Archived in November 2026.** EllesmereUI 9.8.9 and later can show the PvP flag countdown beside the Faction/PvP Indicator on its player frame. Turn it on with PvP Flagged Timer under Unit Frames > Main Frames > Extras, with the player frame selected.
>
> EllesmereUI's timer text is always white, while this addon lets you pick the color. This addon is no longer maintained.

A World of Warcraft Forever addon that shows the time left on your PvP flag, under the PvP crest on your player frame. It only shows while the flag is counting down. A flag you turn on with `/pvp` doesn't expire, so it has no countdown.

## Requirements

- The WoW Forever client (Interface 16001).
- EllesmereUI for the settings page. The timer attaches to the crest that Blizzard's `UnitFrameUtil.UpdateUnitPvPIndicator` paints, which both Blizzard's player frame and EllesmereUI's Blizzard-style unit frames use.

## Install

Put this folder in `World of Warcraft/_forever_/Interface/AddOns/` and name it exactly `PvPFlagTimer`. GitHub's "Download ZIP" unpacks to `PvPFlagTimer-main`; rename it, because WoW only loads a folder whose name matches the `.toc` file inside it.

## Use

- `/pvptimer` opens the settings page: text size, color, and X and Y offset. The default is 12-point text in the gold of the level number.
- `/pvptimer test` shows a 15-second sample.
- `/pvptimer check` reports the hook, the crests it found and the timer values.
- `/pvptimer reset` restores the defaults.

## How it works

A post-hook on `UnitFrameUtil.UpdateUnitPvPIndicator` collects the player's crest textures, so nothing of EllesmereUI's is read or hooked. The countdown sits in a frame parented to the crest's parent, and it only changes parent outside combat. The text uses EllesmereUI's unit frame font, or the game's standard font when EllesmereUI isn't loaded.

## Tests

`lua5.1 tests/harness.lua PvPFlagTimer.lua`, run from this folder, loads the addon against stubbed WoW API functions.
