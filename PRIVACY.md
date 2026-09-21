# FIWeatherWatch — Privacy Policy

_Effective 2026-09-21. Contact: iot@tallimedia.com_

This policy explains what the app stores and why. It is run by a private
individual, not a company.

**The short version: the app has no account, and nothing about you is stored.**

## What is stored

Nothing that identifies you.

There is no sign-in, no account and no pairing step. The app never asks for your
name, email, or any credential, and there is nothing to revoke.

Your settings — the place, the station, the buoy, your wind and wave limits,
units — are held **on your own watch and in Garmin Connect Mobile**, by Garmin's
own settings mechanism. They are not sent to the backend as a profile and they
are not stored there.

## What is sent when you open the app

To fetch weather, the watch asks the backend for it. That request carries only:

- **The place name** you chose (for example "Helsinki") or a station id
- **A wave buoy id**, if you picked one rather than leaving it automatic
- **A display language**, taken from your watch's own language setting

That is the whole request. It contains no identifier for you or your watch, and
two people asking for the same place send identical requests.

## Location

**The app does not use your watch's GPS.** Weather is served for the place you
typed into the settings, not for where you are. The app does not request the
Positioning permission, so it could not read your location even if it tried.

## Where it runs

On a self-hosted server operated by the app author. It keeps a short-lived cache
of weather responses — minutes, not hours — so that repeated requests do not
hammer the Finnish Meteorological Institute's service. That cache is keyed on
place names and station ids, never on anything about who asked.

No analytics, no advertising, no tracking of any kind.

## Third parties

- **The Finnish Meteorological Institute** provides the weather data, through
  their public open data service. The backend fetches it; your watch never
  contacts FMI directly.
- **Garmin's Connect IQ platform** relays requests between your watch and the
  backend, and is subject to Garmin's own terms and privacy policy.

## Deleting your data

There is nothing held about you to delete. Removing the app from your watch
removes the settings with it.
