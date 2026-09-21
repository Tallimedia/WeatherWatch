# Finnish RoadWeather — Privacy Policy

_Effective 2026-09-21. Contact: iot@tallimedia.com_

This policy covers the **Finnish RoadWeather** app for cars with Google built-in. It is
run by a private individual, not a company.

**The short version: the app has no account, and nothing about you is stored.**

## What is stored

Nothing that identifies you.

There is no sign-in, no account and no registration. The app never asks for your name,
email address, phone number or vehicle identity, and it has no way to recognise you
between uses.

## Location

The app uses your car's location, and only for one purpose: to work out which road
weather station and which road section you are nearest to.

- Your coordinates are sent to the app's own backend at `roadweather.tallimedia.com`
  each time the app fetches a reading.
- They are used to answer that request and then discarded. **They are not written to a
  database, and they are not written to server logs** — the server deliberately redacts
  coordinates from its access log, so no record of where you have been is created.
- They are not sent to any third party. The app asks the Finnish Meteorological
  Institute and Fintraffic for data about a *place*, not about you.
- If you decline the location permission, the app shows no road conditions. It does not
  fall back to tracking you another way.

## What the app does not do

- No advertising, and no advertising identifiers.
- No analytics, no crash reporting, no tracking of any kind.
- No third-party SDKs.
- Nothing is sold or shared with anyone.

## Server logs

The backend keeps ordinary technical logs — the path requested, the response status and
the time — for operating and debugging the service. Coordinates are removed before
anything is written. These logs are not used to build a profile of anyone, and there is
nothing in them that identifies a person or a vehicle.

## Data sources

Weather and road station observations come from the **Finnish Meteorological Institute**,
licensed CC BY 4.0. Road conditions and road condition forecasts come from
**Fintraffic** — *Source: Fintraffic / digitraffic.fi, license CC 4.0 BY*. The app is
independent and is not affiliated with, or endorsed by, either organisation.

## Changes

If this policy changes, the date at the top changes with it. The text is published from
the app's own source repository, so the policy shown here and the one committed cannot
disagree.

## Contact

Questions about this policy: iot@tallimedia.com
