# flolilos-PoShScripts
**All my often used PowerShell-scripts:**


# EXIF_tools
These tools use [exiftool](https://sno.phy.queensu.ca/~phil/exiftool/).

## exif_tool
Remove EXIF-entries in pictures (and re-add copyright information).
## exif_transfer
Transfer EXIF information from one file to another.
## XYZtoJPEG
Use [imagemagick](https://www.imagemagick.org/) to convert TIFs to JPEGs - and save all metadata.


# ffmpeg_tools
These tools (mostly) use [FFmpeg](https://ffmpeg.org/).

## compare_via_ffmpeg
Easy-to-use tool to create difference videos.
## kamera_gui
Old version of `security-cam_gui` - will get delted after `security-cam_gui` is validated.
## oldcodec_searchanddestroy
Search for old codecs with [FFprobe](https://ffmpeg.org/). If wanted, delete them.
## oldcodec_transcode
Now almost completely implemented in `oldcodec_searchanddestroy`. Transcode files in batch with.
## screencapture
Capture your desktop, then render the video web-compliantly .
## security-cam_gui
Re-encode file from the SD-card of the main station of security cams.
## split-quadscreen
Split a (quadscreen-)video into parts.
## transcodetomp3
Transcode non-MP§-files to MP3.


# file_tools
Tools that re-sort, delete, clean up, ... folders.

## find_extensions
Look for files with other extensions than the specified (helps at cleaning up).
## foobar_datamover
Move MP3s after converting them with foobar, so they make sense again.
## pictures_cleanup
Clean up (sub)folders with unneeded files (e.g. SideCar-files).
## robocopy-gui
**Not complete!** Attempt to create a GUI for robocopy.
## treecmd
Powershell-implementation of [`tree`](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-xp/bb491019(v=technet.10)).


# LAN_tools
Tools that work around my network.

## automount_smb
Automount SMB-shares (to circumvent the inability to browse after disabling SMBv1).
## catalog_backup
For backing up picture catalogs using [7-zip](http://www.7-zip.org/).
## mysqldump_bash.sh
_**Not** a PowerShell-script, but a Bash-script._ Make backups of a complete MySQL database via `mysqldump`, then `gzip` it. Delete old files if `>128MB` are used.
## mysqldump_powershell
**Not yet working!** A PowerShell-implementation of `mysqldump_bash.sh`.
## wakeonlan
Wakes server(s) up if they are not yet running, using [wolcmd](https://www.depicus.com/wake-on-lan/wake-on-lan-cmd).


# system_tools
Tools that interact with Windows.

## cpuwatch
Document the computer's CPU- and RAM-stats (into a CSV-file).
## ipconfig_replacement
**Not complete!** A playground for replacing `ipconfig`. Or not.
## powershell_doubleclick-behavior
Change behavior of a double-click on `.ps1`-files in Windows Explorer.
## preventsleep
Prevent the computer from going to standby - options for forever, certain CPU threshold, or running processes.
## profile
My profile-file.
## remove_registry_entries
Remove some unnecessary context menu entries. **Could quite possibly damage your system, so be careful!**
## remove_win10_apps
Ask user which unnecessary apps to uninstall. **Could quite possibly damage your system, so be careful!**


## _fortryingoutloud
Just a few (old) tests I like to keep around.