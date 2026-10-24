# ScrapKeeper

Small, dependency-free World of Warcraft Retail addon written in Lua. Automatically sells eligible grey-quality junk when you open a merchant.

## Safety by default

- Only poor-quality (grey) items with a known positive vendor price.
- Skips locked items, quest items, lootable containers, unknown metadata and protected IDs.
- Scans backpack and four equipped bags only.
- Hold **Shift** while opening a merchant to skip; hold it during selling to stop.
- Stops after **12 stacks per visit** to limit pressure on the merchant buyback list. Existing buyback entries can still be displaced.
- Sells one stack at a time, rechecks the slot, and waits for it to become empty before proceeding.
- Closing the merchant, entering combat or disabling automation cancels the session.
- Unconfirmed sales time out without retries. The summary excludes pending sales; reported value is based on cached vendor prices.

Default: automatic selling is **on**. Use `/sk off` before opening a merchant if you want to configure your keep list first. Another junk-selling addon can interfere with sale confirmation; enable only one.

## Install

Copy the **ScrapKeeper** folder into:

```text
World of Warcraft/_retail_/Interface/AddOns/ScrapKeeper/
```

The TOC must be at `AddOns/ScrapKeeper/ScrapKeeper.toc`, not inside an extra nested folder. Restart the game or reload the UI.

The TOC targets interface **120005**; this is an API baseline, not a claim of live client certification. On a newer client check `/dump select(4, GetBuildInfo())` and enable “Load out of date AddOns” if required. Retail only; Classic compatibility is not claimed.

## Commands

| Command | Action |
| --- | --- |
| `/sk preview` | Count eligible stacks and estimate vendor value without selling |
| `/sk off` / `/sk on` | Disable / enable automatic selling |
| `/sk keep 12345` | Protect every stack of that item ID |
| `/sk unkeep 12345` | Remove protection |
| `/sk list` | Show protected IDs |

`/scrapkeeper` also works. Keep/unkeep accept item links. Settings persist account-wide in SavedVariables.

## Development

Run `lua tests/run.lua` from the repository root (Lua 5.1+). Tests use mocked WoW APIs; **an in-game smoke test is still required**.

Manual smoke test:
1. Disable other auto-vendor addons; use expendable grey items.
2. Run preview; protect one item and verify the count changes.
3. Open a merchant holding Shift: nothing should sell.
4. Reopen without Shift: eligible stacks sell, protected/non-grey items stay.
5. Close the merchant mid-sale; confirm no later calls occur.
6. Reopen with more than 12 stacks; check the cap and buyback behavior.

No repair automation, external botting, or inventory deletion.

## API references

- [Blizzard generated Container API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua)
- [Blizzard UI source](https://github.com/Gethe/wow-ui-source)

## License

MIT.
