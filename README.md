# flolilo's PowerShell-Scripts

**All my often used scripts.**
While I put quite some effort in some of them (especially the EXIF ones), I still do not think that they would require the effort of being standalone repositories. In reality, this is more of a private repo to prevent screw-ups; of course, you can use or modify any of the tools to your liking.
Of course, some of them could potentially do nasty things, especially since they are not very well tested. So please, don't trust any of the scripts blindly!

Below is a list of folders that tries to sort the scripts in some general categories and the name of the scripts at hand, including a small description:

## [EXIF manipulation](./EXIF_manipulation)

These tools use [exiftool](https://sno.phy.queensu.ca/~phil/exiftool/).

### [exif_tool](./EXIF_manipulation/exif_tool.ps1)

Remove EXIF-entries in pictures (and re-add copyright information).

### [exif_transfer](./EXIF_manipulation/exif_transfer.ps1)

Transfer EXIF information from one file to another.

### [XYZtoJPEG](./EXIF_manipulation/XYZtoJPEG.ps1)

Use [ImageMagick](https://www.imagemagick.org/) to convert TIFs to JPEGs - and save all metadata.

## [ffmpeg tools](./ffmpeg_tools)

These tools (mostly) use [FFmpeg](https://ffmpeg.org/).

### [compare_via_ffmpeg](./ffmpeg_tools/compare_via_ffmpeg.ps1)

Easy-to-use tool to create difference videos.

### [kamera_gui](./ffmpeg_tools/kamera_gui.ps1)

Old version of [`security-cam_gui`](./ffmpeg_tools/security-cam_gui.ps1) - will get delted after [`security-cam_gui`](./ffmpeg_tools/security-cam_gui.ps1) is validated.

### [oldcodec_searchanddestroy](./ffmpeg_tools/oldcodec_searchanddestroy.ps1)

Search for old codecs with [FFprobe](https://ffmpeg.org/). If wanted, delete them.

### [oldcodec_transcode](./ffmpeg_tools/oldcodec_transcode.ps1)

Now almost completely implemented in [`oldcodec_searchanddestroy`](./ffmpeg_tools/oldcodec_searchanddestroy.ps1). Transcode files in batch with.

### [screencapture](./ffmpeg_tools/screencapture.ps1)

Capture your desktop, then render the video web-compliantly .

### [security-cam_gui](./ffmpeg_tools/security-cam_gui.ps1)

Re-encode file from the SD-card of the main station of security cams.

### [split-quadscreen](./ffmpeg_tools/split-quadscreen.ps1)

Split a (quadscreen-)video into parts.

### [transcodetomp3](./ffmpeg_tools/transcodetomp3.ps1)

Transcode non-MP3-files to MP3.

## [file tools](./file_tools)

Tools that re-sort, delete, clean up, ... folders.

### [find_extensions](./file_tools/find_extensions.ps1)

Look for files with other extensions than the specified (helps at cleaning up).

### [foobar_datamover](./file_tools/foobar_datamover.ps1)

Move MP3s after converting them with foobar, so they make sense again.

### [pictures_cleanup](./file_tools/pictures_cleanup.ps1)

Clean up (sub)folders with unneeded files (e.g. SideCar-files).

### [robocopy-gui](./file_tools/robocopy-gui.ps1)

**Not complete!** Attempt to create a GUI for robocopy.

### [treecmd](./file_tools/treecmd.ps1)

Powershell-implementation of [`tree`](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-xp/bb491019(v=technet.10)).

## [LAN tools](./LAN_tools)

Tools that work around my network.

### [automount_smb](./LAN_tools/automount_smb.ps1)

Automount SMB-shares (to circumvent the inability to browse after disabling SMBv1).

### [catalog_backup](./LAN_tools/catalog_backup.ps1)

For backing up picture catalogs using [7-zip](http://www.7-zip.org/).

### [mysqldump_bash.sh](./LAN_tools/mysqldump_bash.sh)

_**Not** a PowerShell-script, but a Bash-script._ Make backups of a complete MySQL database via `mysqldump`, then `gzip` it. Delete old files if `>128MB` are used.

### [mysqldump_powershell](./LAN_tools/mysqldump_powershell.ps1)

**Not yet working!** A PowerShell-implementation of [`mysqldump_bash.sh`](./LAN_tools/mysqldump_bash.sh).

### [wakeonlan](./LAN_tools/wakeonlan.ps1)

Wakes server(s) up if they are not yet running, using [wolcmd](https://www.depicus.com/wake-on-lan/wake-on-lan-cmd).

## [system tools](./system_tools)

Tools that interact with Windows.

### [cpuwatch](./system_tools/cpuwatch.ps1)

Document the computer's CPU- and RAM-stats (into a CSV-file).

### [ipconfig_replacement](./system_tools/ipconfig_replacement.ps1)

**Not complete!** A playground for replacing `ipconfig`. Or not.

### [powershell_doubleclick-behavior](./system_tools/powershell_doubleclick-behavior.ps1)

Change behavior of a double-click on `.ps1`-files in Windows Explorer.

### [preventsleep](./system_tools/preventsleep.ps1)

Prevent the computer from going to standby - options for forever, certain CPU threshold, or running processes.

### [profile](./system_tools/profile.ps1)

My profile-file.

### [remove_registry_entries](./system_tools/remove_registry_entries.ps1)

Remove some unnecessary context menu entries. **Could quite possibly damage your system, so be careful!**

### [remove_win10_apps](./system_tools/remove_win10_apps.ps1)

Ask user which unnecessary apps to uninstall. **Could quite possibly damage your system, so be careful!**

### [_fortryingoutloud](./_fortryingoutloud.ps1)

Just a few (old) tests I like to keep around.