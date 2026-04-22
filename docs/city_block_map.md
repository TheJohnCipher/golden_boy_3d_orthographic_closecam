# City Block Map

This document matches the 2D procedural layout defined in `scripts/world/layout_data.gd`.

Use it for three things:
- Checking room boundaries (`Rect2`) for collision or shadow logic.
- Aligning NPC patrol paths with the 2D drawing logic.
- Identifying "Safe" vs "Danger" zones in the 2D oblique projection.

## Axis reference

- `X` = horizontal (0 is left, 640 is right)
- `Y` = vertical (Small values are North/Top, Large values are South/Bottom)

The level is drawn in an **Oblique Projection** with a `Y` scale of `0.65`.

## Design intent

The 2D map is organized as a series of connected halls and wings:

- **Alley**: The northernmost service route and extraction point.
- **Back Hall**: A transition zone between the alley and the main venue.
- **West Wing / East Wing**: Side lounges (Cafe and Hotel-style wings).
- **Main Hall**: The central gameplay hub (Gallery/Ballroom).
- **Foyer**: The formal entry point.
- **Plaza**: The public southern start area.

## Master layout

```text
                                 NORTH / ALLEY (Y: ~20)
+------------------------------------------------------------------------------------------------+
| NORTH BOUNDARY WALL                                                                            |
|                                                                                                |
|  ALLEY (R_ALLEY)            (Extraction Zone)                                                  |
|                                                                                                |
|      [ BACK HALL (R_BACK_HALL) ]                                                               |
|                                                                                                |
|  +----------+               +----------------------+                +----------+               |
|  | WEST WING| <-----------> |  MAIN HALL (Gallery) | <------------> | EAST WING|               |
|  | (Lounge) |               |  (R_MAIN_HALL)       |                | (Lounge) |               |
|  +----------+               +----------  ----------+                +----------+               |
|                                                                                                |
|                              [ FOYER (R_FOYER) ]                                               |
|                                                                                                |
|                              [ PLAZA (R_PLAZA) ]                                               |
|                               Player Day Start                                                 |
+------------------------------------------------------------------------------------------------+
```

## Walkable slabs

These are the large floor pieces that should always seal together. If a gap appears, start with these.

| Name | Purpose | Approx footprint |
| --- | --- | --- |
| `AvenueFloor` | Main south street | `x -36..36`, `z -28..-12` |
| `SouthSidewalk` | South walkway band | `x -29..29`, `z -14.9..-11.1` |
| `Forecourt` | Shared civic frontage | `x -27..29`, `z -10.4..-4.0` |
| `CafeFloor` + `CafeFrontCafeFloor` | West public room | `x -22..-10`, `z -2.2..9.0` |
| `AlleyFloor` | West service route | `x -32..-22`, `z -2.0..20.0` |
| `GalleryFloor` + `GalleryEntryGalleryFloor` | Main public hall | `x -6..8`, `z -2.2..10.0` |
| `HotelFloor` + `HotelEntryHotelFloor` | Hotel / private approach | `x 11..25`, `z -7.4..10.0` |
| `OfficeFloor` | Rear annex | `x 26..34`, `z 1.5..9.5` |
| `ServiceFloor` + `RearServiceLane` | Back-of-house yard | `x 12..34`, `z 13.0..23.1` |
| `SafehousePad` | Extraction room floor | `x 29..37`, `z 14.0..22.0` |

## Openings that are supposed to exist

These are designed passages, not missing walls:

- `CafeSouthA/B` leaves the cafe front door.
- `AlleySouthA/B` leaves the alley door and is now capped by `AlleySouthLintel`.
- `GallerySouthA/B` leaves the gallery front door.
- `GalleryEastA/B` leaves the transfer opening into the hotel connector and is capped by `GalleryTransferLintel`.
- `HotelSouthA/B` leaves the hotel front door.
- `HotelWestA/B` mirrors the gallery transfer and is capped by `HotelTransferLintel`.
- `OfficeWestA/B` leaves the office connector opening and is capped by `OfficeWestLintel`.
- `OfficeNorthA/B` leaves the office north opening and is capped by `OfficeNorthLintel`.
- `SafehouseWestA/B` leaves the safehouse door and is capped by `SafehouseWestLintel`.

If a hole appears somewhere that is **not** one of those openings, it should be treated as a bug.

## Roof and massing notes

The roofs are intentionally layered now:

- Every main roof slab has parapet pieces around the edge.
- `CafeUpperMassing`, `GalleryUpperMassing`, `HotelUpperMassing`, and `OfficeUpperMassing` create a stepped skyline without changing the playable shell.
- Roof clutter like `CafeRoofVent`, `GalleryRoofVentA/B`, `HotelRoofMechanicalA/B`, `OfficeRoofVent`, and `SafehouseRoofVent` is purely visual and should stay non-blocking.
- The alley canopy stays lower so the west route still feels compressed compared to the public frontage.

## Day route

```text
Player start on south avenue
  |
  v
[Bus Shelter / Newsstand]
  |
  +--> [Cafe Arcade / Mara]
  |
  +--> [Gallery Doors / Jules]
  |
  `--> [West Alley / Subway Stairs / Nico]

Day objective:
1. Build your alibi with Mara.
2. Get the pass from Jules.
3. Take route intel from Nico.
4. Press Tab to switch into the night run.
```

## Night route

```text
Night start on south frontage
  |
  v
[Forecourt]
  |
  v
[Gallery Hall]
  |
  v
[Hotel Suites]
  |
  v
[Office Connector]
  |
  v
[Rear Service Lane / Dock / Guard Two]
  |
  v
[Safehouse Door]
```

## Key anchor positions

- Day spawn: about `(-30.0, -18.5)`
- Night spawn: about `(1.0, -17.2)`
- Mara: `(-18.2, -4.8)`
- Jules: `(1.0, -1.0)`
- Nico: `(-27.6, 11.0)`
- Guard One patrol: gallery / forecourt loop
- Guard Two patrol: service yard / office rear loop
- Alden path: gallery -> hotel -> office edge -> service lane -> hotel return
- Extraction: `(33.0, 18.0)`

## Ground support note

There is still an invisible `WorldSupportFloor` below the whole level because this map is assembled from many visible slabs.

That hidden floor is a safety net, not the real fix.

If the player falls anywhere:
- note the rough `x` and `z`
- compare it against the slab table above
- check whether the fall is between visible floors, outside the intended map, or inside a supposed doorway
- patch the visible slab seam first, then keep the support floor as backup
