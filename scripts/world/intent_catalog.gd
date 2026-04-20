extends RefCounted

# Central object intent registry used by the procedural world builder.
# Keep exact names and prefixes here so future refactors can rename/move meshes
# while preserving clear author intent metadata.
const EXACT = {
	"WorldSupportFloor": "Hidden collision safety slab under the whole level. It prevents physics tunneling or accidental fall-through at block seams.",
	"AlleyFloor": "Primary traversal lane and stealth route. This is the asphalt spine that all mission paths are tuned around.",
	"WestCurb": "Raised west curb that visually frames the alley and creates subtle elevation contrast against the main lane.",
	"EastCurb": "Raised east curb mirroring the west side for readable street proportions and route boundaries.",
	"WestTransitionFloor": "Secondary west floor band between curb and facade. It softens the transition from street to storefront.",
	"EastTransitionFloor": "Secondary east floor band between curb and facade. It mirrors west side cadence for spatial balance.",
	"WestWall": "Main west building mass used as the primary occlusion and silhouette wall for the alley canyon.",
	"EastWall": "Main east building mass used as the mirrored occlusion and silhouette wall for the alley canyon.",
	"OfficeTower": "Secondary tower volume on the east side used to break the roofline and add skyline hierarchy.",
	"SouthBoundary": "Hard mission boundary at the south edge. Prevents out-of-bounds traversal and keeps encounters framed.",
	"NorthBoundary": "Hard mission boundary at the north edge near extraction. Used for gameplay containment.",
	"WestBoundary": "West hard wall boundary that blocks leaving the play corridor and supports stealth line-of-sight tuning.",
	"EastBoundary": "East hard wall boundary that blocks leaving the play corridor and supports stealth line-of-sight tuning.",
	"WestBuildingRail": "Hidden collision rail for west massing to prevent edge clipping into decorative facade meshes.",
	"EastBuildingRail": "Hidden collision rail for east massing to prevent edge clipping into decorative facade meshes.",
	"WestBench": "West social prop landmark for daytime contact beats and navigation memory.",
	"EastBench": "East social prop landmark that mirrors west bench readability and supports route orientation.",
	"WestPlanter": "West greenery prop introducing material contrast and soft cover reads.",
	"EastPlanter": "East greenery prop introducing material contrast and soft cover reads.",
	"WestCounter": "West service counter prop that reads as a cafe/bar frontage at street level.",
	"EastBar": "East bar counter landmark used as a contact anchor and visual destination cue.",
	"CenterPodium": "Center landmark pedestal for scene focus and objective readability in the middle corridor.",
	"Van": "Large parked vehicle prop used as mid-lane obstruction and stealth path shaper.",
	"Crate1": "Moveable-looking cargo crate prop used as environmental clutter and cover-like silhouette.",
	"Dumpster": "Heavy utility bin prop that communicates service alley function and adds depth layering.",
	"WestDoor1": "West utility door prop for facade storytelling and clear ground-floor scale reference.",
	"EastDoor1": "East utility door prop for facade storytelling and clear ground-floor scale reference.",
	"TrashBag1": "Soft waste bag clutter prop used to break hard-edge repetition in the alley.",
	"TrashBag2": "Companion waste bag clutter prop to avoid mirrored repetition in debris placement.",
	"Pipe": "Vertical service pipe used to suggest practical building infrastructure at street scale.",
	"Pipe2": "Secondary service pipe to avoid single-prop staging and improve facade credibility.",
}

const PREFIX = {
	"WestRoof": "West roofline and coping family defining top silhouette rhythm for the west block.",
	"EastRoof": "East roofline and coping family defining top silhouette rhythm for the east block.",
	"WestBasePlinth": "West facade base family that grounds wall masses and reduces plain-box reads.",
	"EastBasePlinth": "East facade base family that grounds wall masses and reduces plain-box reads.",
	"WestSocle": "West lower facade belt course used to add architectural layering near pedestrian eye level.",
	"EastSocle": "East lower facade belt course used to add architectural layering near pedestrian eye level.",
	"WestWindowPanel": "West glazing bands representing floor-by-floor windows and interior depth reads.",
	"EastWindowPanel": "East glazing bands representing floor-by-floor windows and interior depth reads.",
	"WestLintel": "West horizontal lintel courses that separate facade tiers and improve vertical scale perception.",
	"EastLintel": "East horizontal lintel courses that separate facade tiers and improve vertical scale perception.",
	"WestHood": "West decorative hood/cornice strips that reduce flatness and catch highlights.",
	"EastHood": "East decorative hood/cornice strips that reduce flatness and catch highlights.",
	"WestCornice": "West top cornice cap that finishes the facade and sharpens skyline contrast.",
	"EastCornice": "East top cornice cap that finishes the facade and sharpens skyline contrast.",
	"WestChimney": "West chimney stacks and caps used for rooftop storytelling and silhouette breakup.",
	"EastChimney": "East chimney stacks and caps used for rooftop storytelling and silhouette breakup.",
	"WestFireEscape": "West fire-escape bars and uprights creating readable emergency egress structure.",
	"EastFireEscape": "East fire-escape bars and uprights creating readable emergency egress structure.",
	"WestPilaster": "West vertical pilaster rhythm to break long wall spans into human-scale bays.",
	"EastPilaster": "East vertical pilaster rhythm to break long wall spans into human-scale bays.",
	"WestWallBand": "West subtle facade banding used as weathering/detail breakup across long surfaces.",
	"EastWallBand": "East subtle facade banding used as weathering/detail breakup across long surfaces.",
	"WestWeathering": "West weathering streak overlays for age and material variation.",
	"EastWeathering": "East weathering streak overlays for age and material variation.",
	"WestGroundDetail": "West ground-level base darkening for dirt accumulation and contact shadow reads.",
	"EastGroundDetail": "East ground-level base darkening for dirt accumulation and contact shadow reads.",
	"WestEntry": "West entry steps and awnings defining where players read ground-level access points.",
	"EastEntry": "East entry steps and awnings defining where players read ground-level access points.",
	"WestDoorPanel": "West decorative door panel set used to imply active storefront and service access.",
	"EastDoorPanel": "East decorative door panel set used to imply active storefront and service access.",
	"WestDoorFrame": "West door frame trim family for depth and threshold readability.",
	"EastDoorFrame": "East door frame trim family for depth and threshold readability.",
	"WestDoorLintel": "West door lintels that mark structural headers above entries.",
	"EastDoorLintel": "East door lintels that mark structural headers above entries.",
	"WestDoorGlow": "West emissive strips used as nighttime guidance accents near entries.",
	"EastDoorGlow": "East emissive strips used as nighttime guidance accents near entries.",
	"WestBench": "West bench detail family including back/seat/support pieces for furniture readability.",
	"EastBench": "East bench detail family including back/seat/support pieces for furniture readability.",
	"WestPlanter": "West planter detail family including rim/soil layers for prop depth.",
	"EastPlanter": "East planter detail family including rim/soil layers for prop depth.",
	"WestCounter": "West service counter detail surfaces defining top working plane and edge trim.",
	"EastBar": "East bar detail surfaces defining top working plane and edge trim.",
	"CenterPodium": "Center podium trim and glow family that signals an intentional focal landmark.",
	"Van": "Vehicle detail family including windows, handles, roof cap, bumper, and wheel additions.",
	"Crate": "Cargo crate detail family with lid/strap accents to avoid plain box silhouettes.",
	"Dumpster": "Dumpster detail family with lid, handles, and wheel accents for industrial readability.",
	"StreetMark": "Painted lane markings used for directional rhythm and street-scale cues.",
	"WestBox": "West clutter box family used to make alcoves feel occupied and lived-in.",
	"EastBox": "East clutter box family used to make alcoves feel occupied and lived-in.",
	"WestSign": "West signage family and mounts that imply shop identity and local context.",
	"EastSign": "East signage family and mounts that imply shop identity and local context.",
	"WestLamp": "West lamp posts/heads that reinforce night lighting logic and facade scale.",
	"EastLamp": "East lamp posts/heads that reinforce night lighting logic and facade scale.",
	"WestGraffiti": "West graffiti overlays for narrative wear and social texture.",
	"EastGraffiti": "East graffiti overlays for narrative wear and social texture.",
	"WestBoarding": "West boarded panel props implying renovation/closure storytelling.",
	"EastBoarding": "East boarded panel props implying renovation/closure storytelling.",
	"WestMullion": "West mullion crossbars that subdivide glazing and reduce flat panel reads.",
	"EastMullion": "East mullion crossbars that subdivide glazing and reduce flat panel reads.",
	"WestAccentLight": "West emissive accent strips used to articulate facade depth at night.",
	"EastAccentLight": "East emissive accent strips used to articulate facade depth at night.",
	"DayRouteMarker": "Non-blocking daytime route beacon used to teach contact locations.",
}

static func resolve(name: String) -> String:
	if EXACT.has(name):
		return EXACT[name]
	for prefix in PREFIX.keys():
		if name.begins_with(prefix):
			return PREFIX[prefix]

	var lower := name.to_lower()
	if lower.contains("door"):
		return "Facade entry object. It provides a clear human-scale cue and helps players parse what is walkable architecture versus background massing."
	if lower.contains("window"):
		return "Glazing/readability object. It exists to break wall repetition and reinforce believable floor-by-floor structure."
	if lower.contains("wall") or lower.contains("building"):
		return "Structural massing object. It defines sightlines, navigation pressure, and alley enclosure."
	if lower.contains("marker"):
		return "Gameplay guidance marker. It communicates objective or route context without adding collision."
	if lower.contains("shadowzone"):
		return "Stealth helper volume. It marks where the player can hide and affects detection logic."
	return "General-purpose procedural blockout object. Keep it named and grouped so later art pass swaps are straightforward."
