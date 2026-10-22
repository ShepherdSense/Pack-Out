PACK OUT by Shepherd — TABLET STATION (Samsung Galaxy Tab S6 Lite)
================================================================

WHAT IT IS
One tablet is the whole station. No computer, no member phones, no
network needed to run it. Every piece of gear has its own photo —
the photo is its icon everywhere. Members tap their name, pick a
category (Radio, Laser, Tools...), a sub-category when there is
one (Silvus, L3/Harris...), then tap the gear's photo — or look it
up by serial anytime. Confirm, done. The Southern
voice plays from the tablet speakers. Staff get a PIN-locked
dashboard: live board, log, registry, roster, reports via CSV.

BUILD THE APK (on the Windows PC)
1. Double-click BUILD_APK.bat in this folder.
   It uses the same Flutter setup as the Shepherd builds.
2. When it finishes, PackOut.apk sits in this folder.

PUT IT ON THE TABLET — UPDATES INCLUDED
1. Copy PackOut.apk to the Tab S6 Lite (USB cable, Drive, however
   you like).
2. On the tablet, tap the file and install it. Android will ask to
   allow installs from that source — allow it (one time).
3. UPDATING later versions works exactly the same way: tap the new
   APK and it installs OVER the current app. Your registry, roster,
   log, photos, and staff PIN all carry over — nothing to delete,
   nothing to set up again. (Android only allows this because every
   update is signed with the same key — see below.)

FIRST RUN
- Open "Pack Out By Shepherd". Allow the camera permission.
- Sample gear + 4 sample members are preloaded so you can test
  immediately. Delete the samples you don't want in staff mode —
  they stay deleted.
- Staff mode: tap the staff icon (top right) and enter 2468. That
  default PIN only gets you to a one-time setup where you choose
  your real staff PIN — staff mode won't open until you do. Five
  wrong PIN tries pauses unlocking for 60 seconds, and staff mode
  locks itself after 3 idle minutes.
- Register your real gear in staff mode: Registry -> Register
  equipment. Type the serial (the field opens on a number pad —
  tap the ABC button when you need letters), name it, and take its
  photo. Either camera works: flip right on the photo screen, or
  set the default in staff Settings. That photo becomes the item's
  icon on every screen. Retake it anytime from the item's Edit.
- The Category field is how members browse: type it as
  "Radio / Silvus" and the item files itself under Radio, then
  Silvus. Just "Radio" (no slash) means the category alone. Edit
  an item's Category anytime to reorganize — the browser rebuilds
  itself from whatever is registered.

DAILY USE
- Leave the tablet plugged in on its stand, app open. The app keeps
  the screen awake while it's open; setting the tablet's screen
  timeout to "never" as well (Settings -> Display) is a good
  belt-and-suspenders.
- A member flow left untouched for 90 seconds cancels itself back
  to the name grid, so nobody checks gear out under the wrong name.
- Members never see staff mode; it locks when you tap Lock, and by
  itself after 3 idle minutes.
- Check-in works the same as check-out: tap your name, tap the
  gear. The station knows who's holding it — the same tap brings
  it back in.

KEEP THE SIGNING KEY (important for future updates)
The android folder holds key.properties and
equipment-station-release.jks — together they sign the app. Keep
this whole project folder backed up. If a future updated APK is
ever signed with a different key, Android will refuse to install
it over the station app, and removing the app to force it would
erase the tablet's registry, roster, log, and photos.

DATA / BACKUP
Everything lives on the tablet: registry, roster, log, and the
equipment photos. From staff mode, Settings -> Export log as CSV
shares a spreadsheet copy of the log — do that on a rhythm. Be
clear-eyed: the CSV is a copy of the log only; the photos stay on
the tablet, so the tablet itself is the record.

HONEST LIMITS
- The staff PIN is a light lock for a trusted building, not a
  security system.
- Gear with no photo yet shows the Shepherd icon as a stand-in
  until staff takes one.
- Voice clips are bundled; if a clip ever fails, the line still
  shows on screen as a caption.
