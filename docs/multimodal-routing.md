# Multimodal routing

## Tant Kyi Taung crossing

Tant Kyi Taung is on the west bank of the Ayeyarwady, so it must not be joined
to Bagan by a fictional road line. The app models the journey as road → ferry
or boat → road:

1. Road route to Bu Paya Jetty in Old Bagan.
2. Ferry/boat crossing to Tant Kyi motor jetty.
3. Road route from the west-bank jetty to Tant Kyi Taung Pagoda.

The terminal coordinates and the mapped ferry geometry are stored in
`assets/data/multimodal_routes.json`. The map renders that geometry as a
dashed blue transfer segment with boat-terminal markers; it follows the
original OpenStreetMap ferry way, not a guessed river-centre curve. It is still
not presented as a live vessel track. Ferry availability and schedules are not
invented, so the app asks travellers to confirm locally.

## Evidence used for the curated connection

- [Global New Light of Myanmar](https://www.gnlm.com.mm/tourists-stream-to-buu-pagoda-riverside-for-scenic-wall-sunset-glow/)
  reports a boat jetty at Buu Pagoda for travel to Tantkyi Mountain.
- [Bagan travel guidance](https://en.wikivoyage.org/wiki/Bagan) describes
  reaching Tant Kyi Taung by boat from Bu Paya in Old Bagan.
- Terminal coordinates are from OpenStreetMap data (queried through Overpass):
  Bu Paya jetty node `2099627821` and Tant Kyi motor jetty node `2099627812`.
- Ferry geometry follows OpenStreetMap ferry way `199983114`, which connects
  the two curated terminal coordinates.

This is intentionally data-driven so future ferry connections can be added
without changing map UI or routing logic.
