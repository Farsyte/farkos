@LAZYGLOBAL off.

// Flight Control for Sounding Rockets:
// - lower stage is a booster.
// - upper stage is a rocket.
// - we have no attitude control.
// - we have no throttle control.
// - payload separates and parachutes down.

// Wait until all of the world exists. Until we do this, it is best to
// not rely on any data about the vessel other than its name.

wait until ship:unpacked.

// CONFIGURATION

local solid_fuel_name is "NGNC".	// CONFIG: name to fuel burned by lower stage.
local solid_fuel_min_pct is 12.		// CONFIG: fuel threshold for when to act.

// Note on solid_fuel_min_pct: use 5% for Tiny Tim, or 12% for 2.5KS-18000.

// Computations we can do before launch

function find_resource { parameter n.	// UTILITY: find bookkeeping for this record.
    for r in ship:resources if r:name=n return r. }

local solid_fuel is find_resource(solid_fuel_name).
local solid_fuel_min is solid_fuel:capacity * solid_fuel_min_pct / 100.

// FLIGHT ENGINEER MUST HIT SPACE BAR TO START FLIGHT.
// This allows the engineer to run final checks and
// arrange displays appropriately.

// The lower stage is "tiny tim" or "2.5KS-18000" booster. When
// the flight engineer hits SPACE BAR, the booster ignites.

// The upper stage engine (Aerobee or XSLT-1) must be ignited before
// the lower stage burns out. Experimentation shows that it is safe
// for us to trigger separation at the same time.

wait until (solid_fuel:amount < solid_fuel_min) and stage:ready. stage.

// Jettison the engine and (nearly) empty tank when we hit 80km,
// or when we start descending (to handle the "engine failed" case).

wait until (altitude>80000 or verticalspeed<0) and stage:ready. stage.

// Arm the parachute when we are descending and below 40km.
wait until (altitude<40000 and verticalspeed<0) and stage:ready. stage.
