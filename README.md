# Vendor Price Plus

Vendor Price Plus shows the vendor value of an item on its tooltip: the price of one item, and the price of the whole stack when you are holding more than one.

Version 1.2.3 fixes a combat tooltip error. Hovering an item on the action bar, such as a stack of Lesser Mana Potions, was throwing:

`attempt to perform arithmetic on local 'count' (a secret number value, while execution tainted by 'VendorPricePlus')`

That happened at `VendorPricePlus.lua` in `SetPrice`, called from the `SetAction` tooltip hook.

## Why the count is secret

Current Classic (1.15.9), TBC Anniversary (2.5.6), Mists, WoW Forever, and Retail clients can return **secret numbers** from combat APIs. `GetActionCount()` is one of them while you are in combat. It is the number painted on the action button, including how many of that potion are in your bags.

Addon code may store a secret number and may hand it to Blizzard widgets. It may not multiply or compare it. `sellPrice * count` is that forbidden step, so the tooltip script stopped before any vendor line was added.

There is no supported way for an addon to turn that secret back into a normal number. The action button can still draw it, because Blizzard's own code is allowed to. The addon is not.

## What this version does

For an item on the action bar, the usable count is also available from `GetItemCount()` / `C_Item.GetItemCount()`. That inventory call still returns an ordinary number, and for a potion it is the same bag count `GetActionCount()` was providing. The tooltip multiplies the vendor price by that number, so a stack still shows both the unit price and the stack total.

`GetItemCount()` is only used for action-bar items. A single bag slot, mail attachment, or auction stack keeps its own count, because the total in your bags can be larger than that one stack.

If the inventory count is secret as well, the tooltip shows the per-item vendor price and leaves the stack total off. It does not raise the arithmetic error.

Outside combat, `GetActionCount()` is a normal number and the tooltip uses it directly, as before.

## Install

1. Close World of Warcraft, or be ready to `/reload` after the files are in place.
2. Copy the `VendorPricePlus` folder into that client's `Interface/AddOns` directory, replacing the addon that is already there.
3. Start the client, or run `/reload` from chat.

The folder name must stay `VendorPricePlus`, and `VendorPricePlus.toc` must sit directly inside it.

## Check the fix without the game

The secret-number behavior is covered by a small Lua 5.1 test. From this directory:

```
lua5.1 tests/secret_count_test.lua
```

It replays the potion tooltip from the combat error: a secret action count, item `3385`, and a readable bag count of 20. The stack line must use 20, and a secret bag-slot count must not be multiplied.

## Clients

| Client | Status |
| --- | --- |
| WoW Forever | Supported |
| TBC Anniversary | Supported |
| Classic Era / Hardcore / Season of Discovery | Supported |
| Mists of Pandaria Classic | Loaded by the same code; not separately tested |
| Retail | Loaded by the same code; not separately tested |

`/vpp` opens the settings panel on WoW Forever.

## Layout

- `VendorPricePlus/Compat.lua` — client API differences, including secret-number checks
- `VendorPricePlus/VendorPricePlus.lua` — tooltip vendor prices
- `VendorPricePlus/Options.lua` — Forever settings
- `VendorPricePlus/Integrations.lua` — Auctionator and other tooltip hosts

Vendor Price Plus is based on the [v1.2.2 source](https://github.com/DustinChecketts/VendorPricePlus/tree/v1.2.2) by StormtrooperTK421 and is released under the MIT License. The original Vendor Price addon was by Ketho17 and Icesythe7.
