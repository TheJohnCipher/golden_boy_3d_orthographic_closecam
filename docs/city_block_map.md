# City Block Map

This document matches the current procedural level in `scripts/world_3d.gd`.

Use it for three things:
- checking the actual block proportions before moving geometry
- seeing which openings are intentional and which surfaces should be fully sealed
- keeping the day and night routes aligned with the rebuilt city frontage

## Axis reference

- `X-` = west / left side of the block
- `X+` = east / right side of the block
- `Z-` = south / avenue side
- `Z+` = north / service side

The level starts on the **south avenue** and pushes deeper into the block as `Z` increases.

## Design intent

The city is now built as a stepped frontage instead of a row of unrelated boxes:

- **Cafe** on the west side is a low public arcade with a smaller upper mass.
- **Gallery** is the civic centerpiece with the cleanest forecourt, taller upper mass, and the clearest front door.
- **Hotel** is the luxury anchor with the deepest frontage, strongest canopy, and the tallest upper mass.
- **Office annex** is a tighter rear connector, not a full second hero building.
- **Service yard + safehouse** form the back-of-house escape route.

The play space remains one compact stealth block, but the visible massing now sells a more professional city scale:

- roof slabs are capped with parapets
- major openings have lintels
- upper masses step back from the playable shell
- the skyline reads as layered frontage instead of flat boxes

## Master layout

```text
                                 NORTH / SERVICE EDGE (+Z)
+------------------------------------------------------------------------------------------------+
| NORTH BOUNDARY / BACKDROP TOWERS                                                               |
|                                                                                                |
|  WEST ALLEY                 GALLERY REAR        HOTEL / OFFICE REAR          SAFEHOUSE        |
|  subway stairs              bench, plinths      office bridge, dock, yard     green door      |
|  Nico intel                 Alden crosses here  Guard Two patrol               extraction      |
|                                                                                                |
|  x -32..-22                 x -6..8             x 12..34                      x 29..36        |
|                                                                                                |
|  +----------+               +--------------+    +------------+------+          +------+       |
|  |          |               |              |    |            |      |          |      |       |
|  |  ALLEY   |               |   GALLERY    |----|   HOTEL    |OFFICE|----------| SAFE |       |
|  |          |               |              |    |            |      |          |HOUSE |       |
|  +----  ----+               +------  ------+    +------  -----+------+          +--  --+       |
|       alley door                   main door            main door                  west door     |
|                                                                                                |
|----------------------------- FORECOURT / CIVIC PLAZA / HOTEL DROP-OFF ------------------------|
|                                                                                                |
|   cafe arcade tables          sculpture court          gallery queue           valet runner     |
|   Mara contact                day crossing             Jules contact           night approach    |
|                                                                                                |
|  +------------+               +--------------+         +------------+                          |
|  |    CAFE    |               |   GALLERY    |         |   HOTEL    |                          |
|  |            |               |              |         |            |                          |
|  +-----  -----+               +------  ------+         +-----  -----+                          |
|                                                                                                |
|--------------------------- SOUTH AVENUE / CROSSWALK / STREET MEDIANS -------------------------|
|  bus shelter + newsstand        player start west           medians + taxis + lamp posts       |
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
