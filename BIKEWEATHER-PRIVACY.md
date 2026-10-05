# Bike Weather — Privacy Policy

_Effective 2026-10-05. Contact: iot@tallimedia.com_

This policy covers the **Bike Weather** apps for Garmin Edge bike computers (a data
field and a radar app). It is run by a private individual, not a company.

**The short version: the app has no account, and nothing about you is stored.**

## What is stored

Nothing that identifies you.

There is no sign-in, no account and no registration. The app never asks for your name,
email address, phone number or any device identity, and it has no way to recognise you
between rides.

Your settings (alert thresholds, units, which value a field shows) are kept by Garmin
Connect on your own Garmin account and devices. They never reach the app's backend.

## Location

The app uses your Edge's GPS position, and only for one purpose: to fetch the weather,
rain nowcast and radar picture for where you are.

- Your coordinates are sent to the app's own backend at `bikeweather.tallimedia.com`
  each time the app refreshes, every few minutes while it is running. On an Edge the
  request is relayed over Bluetooth by the Garmin Connect app on your paired phone.
- They are used to answer that request and then discarded. **They are not written to a
  database, and they are not written to server logs** — the server deliberately redacts
  coordinates from its access log, so no record of where you have been is created.
- For a few minutes the server keeps the *weather* it fetched, filed under your position
  rounded to about one kilometre, in memory only, so that repeated requests do not hit
  the weather services again. This is not a record of you and is gone when it expires or
  the service restarts.
- To get the weather, the backend asks the **Finnish Meteorological Institute** and
  **MET Norway** for data at that rounded position. Those requests come from the
  backend's server, not from your device, and carry nothing that identifies you.
- If you decline location access, the app shows no local conditions. It does not fall
  back to tracking you another way.

## What the app does not do

- No advertising, and no advertising identifiers.
- No analytics, no crash reporting, no tracking of any kind.
- No third-party SDKs.
- Nothing is sold or shared with anyone.

## Server logs

The backend keeps ordinary technical logs — the path requested, the response status and
the time — for operating and debugging the service. Coordinates are removed before
anything is written. These logs are not used to build a profile of anyone.

## Other parties involved

- **Garmin.** The apps run on Garmin devices and reach the internet through Garmin
  Connect on your phone. Garmin's own privacy policy governs that part.
- **Cloudflare.** Traffic to `bikeweather.tallimedia.com` passes through Cloudflare, which
  handles network details such as IP addresses under its own policy.

## Data sources

Weather observations, forecasts, lightning and radar come from the **Finnish
Meteorological Institute**, licensed CC BY 4.0. The two-hour rain nowcast comes from
**MET Norway**, licensed CC BY 4.0. The app is independent and is not affiliated with, or
endorsed by, Garmin or either institute.

## Changes

If this policy changes, the date at the top changes with it. The text is published from
the app's own source repository, so the policy shown here and the one committed cannot
disagree.

## Contact

Questions about this policy: iot@tallimedia.com
