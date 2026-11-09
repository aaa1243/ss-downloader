# SS Tools Downloader

A small Windows app for Minecraft screensharers. It downloads the forensic tools you need for a screenshare onto the PC being checked, all into one folder, and deletes them again when you're done.

## What it does

- **Presets for the length of the SS.** Pick Short, Medium or Long and the right tools get ticked. You can still tick or untick tools one by one.
- **Downloads everything in one go** into `C:\SSTools`, one folder per tool. Zips are extracted automatically, and the files are unblocked so they open without warnings.
- **Gets the latest version** of GitHub tools straight from their releases. If one link is down, it tries a backup link.
- **Opens websites** for tools that need a sign-up, an installer or a scanner PIN.
- **Scanner PIN box.** Type an Ocean or Echo PIN to open the scan for the user.
- **Live status and log** for every tool (queued, downloading, done, failed), with a Retry failed button.
- **Cleanup button.** Closes any tool still running from `C:\SSTools` and deletes the whole folder after the SS.

## Tools included

| Preset | Tools |
| --- | --- |
| Short | Ocean, Echo, System Informer, WinPrefetchView, PathsParser, BAM Parser, Everything |
| Medium | Short + Registry Explorer, bstrings, JournalTrace, Prefetch Parser, USBDeview, Vigils Task Parser, Vigil Registry Scanner, FTK Imager |
| Long | Medium + Timeline Explorer, WxTCmd, AmcacheParser, MFTECmd, PECmd, Hayabusa, AlternateStreamView, LastActivityView, Process Parser, PcaSvc Executed, WinPmem, RAMPSParser, RAMDumpExplorer, PowerShell-Hunter, Detect It Easy, Recuva, Stream Detector, detect.ac tools |

All tools belong to their original authors. This app only downloads them from their official sources.

### RAM tools

For fileless PowerShell bypasses, the Long preset includes a full RAM workflow:

1. **WinPmem** dumps the RAM: `winpmem_mini_x64.exe ram.raw` (run as admin).
2. **[RAMPSParser](https://github.com/aaa1243/ram-ps-parser)** pulls PowerShell commands out of the dump and flags reverse shells, download and execute, encoded commands, Defender tampering and anti-forensics: `RAMPSParser.exe -Path .\ram.raw`
3. **RAMDumpExplorer** for a general look through the same dump.

## How to use

1. Download `SSDownloader.exe` from the [Releases](../../releases/latest) page.
2. Run it on the PC being screenshared. If Windows SmartScreen shows a warning, click **More info > Run anyway** (the exe is unsigned).
3. Pick a preset, then click **Download selected**.
4. Do the SS. Use **Open folder** to get to the tools.
5. When you're finished, click **Cleanup** to delete everything.

You can also run the script directly without the exe:

```
powershell -ExecutionPolicy Bypass -File .\SSDownloader-GUI.ps1
```

## Editing the tool list

All tools are listed in the `$Tools` section at the top of `SSDownloader-GUI.ps1`. Each line has a name, a tier (`S`, `M` or `L`) and one of:

- `url`: a direct download link (add backup links to the list)
- `github`: a GitHub repo, plus a pattern for which release file to grab
- `page`: a website that gets opened instead

To make the PIN box open a scan directly, put the scanner's PIN link format in `$ScannerLinks`, with `{0}` where the PIN goes.

## Building the exe

Every push to `main` checks the script for errors and builds `SSDownloader.exe` with [ps2exe](https://github.com/MScholtes/PS2EXE) through GitHub Actions. Get it from the **Actions** tab under Artifacts, or push a tag like `v1.0.1` to attach it to a release.

## Notes

- Requires Windows 10 or 11.
- Cleanup only deletes `C:\SSTools`. It doesn't touch anything else on the PC.
- If System Informer's kernel driver is still loaded, a file may stay locked after cleanup. Restarting the PC releases it.
- Some antiviruses flag ps2exe-built apps as false positives. The full source is in this repo if anyone wants to check it.
