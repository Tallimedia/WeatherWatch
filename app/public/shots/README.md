# Site images

`raw-*.png`  simulator captures, cropped to circles in the dark "Every screen" grid
`pg*.png`    framed device shots, used at full size in the app intro
`settings-*.png`  Garmin Connect settings screens, shown as thumbnails in Setup

The four the Setup section looks for:

    settings-main.png     the Settings menu — Land / Sea / Display / Units
    settings-land.png     Land: place, wind limit, cold, hot
    settings-sea.png      Sea: station, buoy, wind limit, wave limit
    settings-display.png  Display: page order, glance slots
    settings-units.png    Units: wind, distance
    settings-buoy.png     Wave buoy list, open

Regenerate them from phone screenshots with:

    python3 Screenshots/crop_settings.py <folder-with-the-screenshots>

which strips the iOS status bar and the dead black below the last setting.

Any that are missing remove themselves from the page, and the whole column
goes if none of them load — so the section is never a grid of broken images.
Drop the files in, redeploy, and they appear.
