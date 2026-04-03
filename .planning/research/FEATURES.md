# Feature Landscape: Nomad — iOS Travel Logging App

**Domain:** Native iOS travel logging / traveler identity app
**Researched:** 2026-04-03
**Overall confidence:** MEDIUM-HIGH (core travel app patterns well-documented; archetype specifics required synthesis from multiple sources)

---

## Table Stakes

Features users expect from any travel logging app. Missing = feels incomplete, users churn immediately.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| GPS route recording (background) | Every travel logger does this; it's the data foundation | High | Requires CoreLocation `Always` permission; iOS 18 requires active `CLServiceSession`; significant battery cost if done naively |
| Visited countries map / fill | The visual "I've been here" reward is the core identity hook | Medium | MapKit can highlight country polygons; needs country boundary data (GeoJSON) |
| Manual trip start/stop | Users don't trust auto-detection alone; they need control | Low | Simple UI — "+" button to start, explicit end action |
| Photo attachment to trips | Travel logging without photos feels sterile | Medium | PHPhotoLibrary integration with date-range filtering to surface photos from trip window |
| Offline-first operation | Travelers are frequently without signal; data loss here = immediate delete | High | All GPS trace + place log writes to local store first; sync on reconnect |
| Trip timeline / history | Users need to see what they've logged; without it the app is a black box | Low | Chronological list of trips, newest first — already in spec |
| Country/region statistics | "Countries visited" is the number-one vanity stat for travelers | Low | Aggregate from trip data; core engagement driver |
| Privacy controls (private by default) | Persistent location data is sensitive; users need clear control | Low | Private by default, opt into sharing |
| Shareable output | The "Strava screenshot" moment — the reason people use the app at all | Medium | See Differentiators for detail |

---

## Differentiators

Features that make Nomad compelling versus generic trip loggers (Polarsteps, Google Maps Timeline, etc.). Not baseline expectations, but what drives word of mouth.

### 1. Interactive 3D Globe as Home View

**Value:** Transforms passive data into an identity statement. The globe makes your travel history feel like a living artifact, not a list. No mainstream travel logging app uses a true interactive 3D globe as the primary navigation surface.

**Complexity:** High

**Notes:**
- MapKit's `MKMapView` in `.globe` style supports this natively in iOS 16+
- Countries must be visually highlighted — requires custom overlay rendering with GeoJSON polygon data
- Subtle glow/pulse effect on visited countries is the visual wow moment — handle carefully in design phase
- Globe must remain as persistent backdrop when bottom sheets are open (Z-axis layering challenge)

**Dependency:** Requires country tracking data from trip logging

---

### 2. Strava-Style Route Maps (GPS Trace + Named Pins)

**Value:** Strava proved that a clean route visualization with meaningful stats is intrinsically shareable. Nobody screenshots a spreadsheet, but everyone screenshots a route map. The dual-layer approach (continuous trace line + named place pins at stops) is richer than Polarsteps' point-to-point lines.

**Complexity:** Medium-High

**Notes:**
- GPS trace: `MKPolyline` overlay on `MKMapView`
- Named pins: `MKAnnotation` with visit order numbers and place names
- Strava's 2025 "Sticker Stats" feature (distance, time, route line) is the reference UX for shareable cards — add trip-specific stats (steps, distance, top place types)
- Map style for route display should use muted/minimal tile style so route stands out
- Route quality degrades if GPS samples are sparse indoors; design for graceful fallback

**Dependency:** Requires GPS trace data from background location recording; named pins require place check-in or stop detection

---

### 3. Traveler Archetype / Identity System

**Value:** This is the "what kind of traveler are you?" hook that makes the app feel like a personality mirror, not just a logger. Archetypes give users an identity to share and a reason to keep logging — each trip refines who they are.

**Complexity:** Medium

**Research finding:** Industry archetype systems (Bain, QVI, Trafalgar) converge on 5–8 types. The Foursquare taxonomy uses 1,200+ place categories organized into ~11 top-level domains. For Nomad, the right number of archetypes is **6–8** — enough to feel differentiated, few enough to feel meaningful. Fewer than 5 feels generic; more than 9 loses distinctiveness.

**Recommended Place-Type Taxonomy (7 categories):**

| Category | Example Places | Archetype Signal |
|----------|---------------|-----------------|
| Food & Drink | Restaurants, cafes, bars, food markets, bakeries | Foodie / Culinary Explorer |
| Culture & History | Museums, galleries, historic sites, churches, monuments | Culture Seeker |
| Nature & Outdoors | Parks, trails, beaches, mountains, national parks | Adventurer / Nature Lover |
| Nightlife & Entertainment | Bars, clubs, live music venues, theaters | Night Owl / Social Traveler |
| Wellness | Spas, gyms, yoga studios, hot springs | Wellness Traveler |
| Local & Neighborhood | Markets, neighborhood cafes, local shops, residential streets | Slow Traveler / Immersive |
| Transit & Logistics | Airports, train stations, hotels | (excluded from archetype scoring — pure travel overhead) |

**Recommended 8 Traveler Archetypes:**

| Archetype | Dominant Place Signal | Secondary Signal | Description |
|-----------|-----------------------|-----------------|-------------|
| The Culinary Nomad | Food & Drink (>40%) | Local & Neighborhood | Eats their way through every destination |
| The Culture Seeker | Culture & History (>40%) | Local & Neighborhood | Lives in museums and historic quarters |
| The Adventurer | Nature & Outdoors (>35%) | Wellness | Hikes, beaches, national parks |
| The Night Owl | Nightlife (>35%) | Food & Drink | Comes alive after dark |
| The Slow Traveler | Local & Neighborhood (>40%) | Food & Drink | Lingers, explores on foot, avoids tourist traps |
| The Wellness Wanderer | Wellness (>35%) | Nature & Outdoors | Retreats, spas, mindful movement |
| The Globetrotter | Balanced across types, >20 countries | High trip frequency | Quantity over depth; collects countries |
| The Urban Explorer | Culture + Food + Nightlife (city-heavy) | Low nature score | City creature — never leaves the metropolis |

**Archetype derivation logic:**
- Calculate place-type distribution across all logged trips
- Apply weighted scoring (recent trips weighted more than older)
- Assign primary archetype based on dominant category (>35% threshold)
- Surface as single label + one-line description on Passport
- Update dynamically — archetype can shift as user logs more trips
- Show "Your mix" as a small distribution chart alongside the archetype label

**Dependency:** Requires place check-ins with category tagging; minimum ~3 trips logged before archetype is meaningful

---

### 4. Shareable Trip Cards and Traveler Passport

**Value:** Strava's most powerful growth mechanic is the shareable activity card — people post it to Instagram without Strava needing to do anything. Travel deserves the same. Nomad's shareable outputs should be beautiful enough to post without editing.

**Complexity:** Medium

**What makes a travel card viral (from Strava, Polarsteps, and "Travel Wrapped" patterns):**
- Bold, high-contrast visual — the route map or globe snippet is the hero element
- 3–5 stats in large type (not a wall of data)
- Subtle branding that drives attribution without feeling like an ad
- Portrait format (9:16 ratio) for Stories-first sharing
- One-tap copy to clipboard / share sheet

**Trip Card — recommended data to show:**
- Route map (GPS trace + top 3 named stops)
- City/region name + country
- Date and duration (e.g. "3 days in Lisbon")
- Step count or distance
- Top place category icon (foodie, culture, etc.)
- Small Nomad wordmark bottom-right

**Traveler Passport Card — recommended data to show:**
- World map silhouette with visited countries filled
- Countries visited count (large, bold)
- Traveler archetype label + icon
- Top 3 countries by time spent
- Total distance or steps (lifetime)
- Years active / trips logged
- User handle + profile photo

**Dependency:** Globe and route map must be renderable as static image for share sheet; requires `UIGraphicsImageRenderer` snapshot of MapKit view

---

### 5. "Travel Wrapped" Annual Recap

**Value:** Spotify Wrapped proved that personalized year-in-review content is the highest-engagement feature any app can ship. Every major platform now has a version. For a travel app, the emotional resonance is even higher — travel is deeply personal. Polarsteps launched their 2025 Unpacked feature; this is now an expected differentiator for apps in this category.

**Complexity:** Medium

**What to include in Nomad's annual recap:**
- Total countries visited that year
- Total distance traveled
- Total steps (from HealthKit)
- Favorite city (most days spent)
- Traveler archetype for the year
- Place-type distribution (your year as a Foodie: 42% food, 28% culture…)
- Number of day trips logged
- Furthest point from home
- A single hero shareable card summarizing the year

**Notes:**
- Release timing: December 15–January 5 window (Polarsteps model) or on trip anniversary
- Show as a swipeable story sequence (slide-by-slide), not one dense screen
- Each stat slide should be individually shareable
- "Your year as a [Archetype]" framing is more compelling than raw numbers alone

**Dependency:** Requires at least one full year of logged data; HealthKit integration for steps

---

### 6. Photo Gallery Integration (Apple Photos, Trip-Scoped)

**Value:** Photos are how people remember trips. Auto-surfacing photos from a trip's date range removes the friction of manual upload. Polarsteps requires manual photo upload — this is a genuine gap Nomad can close.

**Complexity:** Medium

**Pattern:**
- At trip view open, query `PHAsset` for photos in the trip's date range and approximate geographic bounding box
- Show as a scrollable gallery in the trip detail panel
- Do not copy photos to app storage — reference in-place to avoid storage bloat
- Let users pin specific photos to named stops on the route

**Dependency:** Photos framework permission granted at onboarding; trip must have date/time bounds

---

### 7. HealthKit Steps Integration

**Value:** Steps and distance ground travel data in something physical and real. "I walked 28,000 steps through Kyoto" is a powerful stat. It also surfaces naturally in shareable cards.

**Complexity:** Low

**Notes:**
- Query `HKQuantityType.stepCount` for trip date range
- Aggregate distance from `HKQuantityType.distanceWalkingRunning`
- Show on trip detail and in passport stats
- No write access needed — read only

**Dependency:** HealthKit permission at onboarding

---

## Anti-Features

Features to explicitly NOT build in v1 (or at all). These are traps that cost engineering time without proportionate user value, or that actively harm the experience.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Activity feed / social timeline | Requires significant trust and moderation infrastructure; Polarsteps has it and users mostly ignore it in favor of direct sharing | Profile-viewing only (friends see your globe + passport, not a feed) |
| Real-time location sharing ("find my friend") | Privacy liability, scope creep, requires infrastructure; already has Family Sharing, Find My | Out of scope entirely |
| In-app booking / planning | Planning apps (Wanderlog) do this well; adding it makes Nomad a worse version of existing tools | Focus on post-trip logging and identity; let users book elsewhere |
| Automatic place suggestions / recommendations | Requires a recommendations engine, content curation, and freshness maintenance | Surface place categories from foursquare API; don't curate content |
| Leaderboards / country count competition | Can feel toxic ("I've been to 94 countries and you've only been to 12"); alienates casual travelers | Show personal stats and archetype; no public ranking |
| Push notifications for friends' activity | "Your friend just visited Bangkok" is noise that kills daily active users; Polarsteps users complain about this | Notification only for own trip detection prompt |
| Custom mapping engine | Massive engineering cost; MapKit covers all required visualization needs | Use MapKit throughout — globe, routes, country fill |
| Expense tracking | Different user mental model (work vs. memory); opens a different product category | Out of scope; recommend linking to Splitwise if users ask |
| Itinerary planning / future trips | Pre-trip planning is a different workflow; Nomad's value is post-trip reflection | Log only past/current trips; no future itinerary feature |
| Web app / Android version | Dilutes focus; Apple ecosystem integration is a core differentiator (HealthKit, Photos, MapKit) | Native iOS only for v1 |
| AI travel recommendations ("go to X, you'll love it") | High engineering cost, requires user trust, can feel presumptuous | The archetype system communicates identity without prescribing behavior |

---

## Feature Dependencies

```
CoreLocation background permission
  └── GPS trace recording
        └── Route visualization (MapKit polyline)
              └── Trip Card (shareable route map)
              └── Visited countries tracking
                    └── Globe (highlighted countries)
                    └── Passport world map

PHPhotoLibrary permission
  └── Trip photo gallery (date/location scoped)
        └── Photo pins on route map (optional enhancement)

HealthKit permission
  └── Steps + distance per trip
        └── Trip card stats
        └── Annual Wrapped stats

Place check-ins (manual or stop-detected)
  └── Place category tagging
        └── Traveler archetype calculation
              └── Passport archetype display
              └── Annual Wrapped archetype-of-year
        └── Named pins on route map

Trip logging (GPS trace + place check-ins + date bounds)
  └── Everything above
        └── Annual Wrapped (requires sufficient logged trips)

Friends social graph (v2)
  └── Requires: User handles, Firebase auth, Firestore social graph
  └── Globe view (friends' countries)
  └── Passport view (friends' stats)
  └── Does NOT require: feed, notifications, real-time anything
```

---

## MVP Recommendation

**Prioritize (must-ship for meaningful experience):**

1. Background GPS trace recording + manual trip start/stop — data foundation; without this, nothing else works
2. Globe home view with visited country highlight — the core identity moment; the reason to download
3. Route map visualization (GPS trace + named pins) — the Strava moment; the reason to share
4. Traveler Passport with archetype + country stats — the "who am I as a traveler" payoff
5. Trip photo gallery (Apple Photos integration) — removes the biggest friction of competing apps
6. Shareable trip card and passport card — the viral/growth mechanism; should be beautiful on day one

**Defer but design for:**

7. Travel Wrapped annual recap — needs accumulated data; build data model correctly from day one so this is additive
8. Friends feature — complex social infrastructure; defer to v2 but design handle system and Firestore structure to support it

**Do not build:**
- Anything in the anti-features list above

---

## Trip Auto-Detection: Recommended Pattern

**Context:** The spec calls for hybrid detection — user can manually start OR app detects travel. This is the right call. The risk is being annoying.

**Recommended implementation (3 tiers, in order of preference):**

1. **Geofence departure** — Set a geofence around the user's home city (established at onboarding from "home city" setting). When device exits the geofence radius, send a single notification: "Looks like you left [City]. Start a Nomad trip?" User taps yes/no. One notification, high relevance.

2. **Significant location change** — Use `startMonitoringSignificantLocationChanges()` (cell-tower based, low battery cost) to detect city-scale movement. When a new significant location is detected outside home geofence, send the same prompt. Works even if app was suspended.

3. **Manual only (fallback)** — If the user has dismissed 3+ auto-prompts in a row, switch to manual-only mode and stop sending detection notifications. The user has signaled they don't want it.

**Anti-pattern to avoid:** Continuous GPS polling to detect movement is battery-prohibitive and will get the app flagged by iOS battery warnings. Use significant location change monitoring (`CLLocationManager`) instead — it wakes the app on cell-tower handoffs and uses essentially no battery.

**iOS 18 note (MEDIUM confidence — verify at implementation):** `CLServiceSession` is now required to keep location delivery active. Research suggests apps not using it may have background location delivery interrupted. Verify against Apple's current CoreLocation documentation before implementing background detection.

---

## Passport Stats: What Travelers Find Meaningful

**Based on:** Polarsteps user research, NomadMania community data, "been" app reviews.

**High signal (show prominently):**
- Countries visited (count + percentage of world) — the #1 vanity stat; universally meaningful
- Traveler archetype — personalizes the experience; gives identity
- Days traveled (total and this year)
- Favorite destination (most time spent)
- Total distance (lifetime)
- Continents visited

**Medium signal (show in stats section):**
- Total steps (lifetime from HealthKit)
- Furthest point from home
- Most visited city
- Trips logged (count)
- Most common place type

**Low signal (avoid or hide in details):**
- Average speed traveled — feels like a data dump
- Transit time — uninteresting
- Countries ranked by "travel freedom index" — out of scope, feels judgmental
- Any stat that invites comparison with other users (no leaderboards)

**Key insight from NomadMania community:** Travelers find qualitative milestones more meaningful than raw numbers. "First trip to Asia" or "10th country" hits differently than "11,240 km traveled." Consider milestone moments alongside raw stats.

---

## Sources

- [Polarsteps Review: A 2025 Detailed Look (Wandrly)](https://www.wandrly.app/reviews/polarsteps) — MEDIUM confidence
- [Announcing Polarsteps Unpacked 2025 (Polarsteps News)](https://news.polarsteps.com/news/polarsteps-unpacked-and-2025-travel-report-the-year-in-travel) — HIGH confidence
- [Strava Sticker Stats Spring 2025 (BikeRadar)](https://www.bikeradar.com/news/strava-sticker-stats-spring-2025-updates) — HIGH confidence
- [Five Key Traveler Archetypes (Hospitality News Magazine)](https://www.hospitalitynewsmag.com/what-are-the-five-key-archetypes-of-travelers1/) — MEDIUM confidence (Bain & Company research)
- [Six Travel Personality Types (myqvi.com)](https://www.myqvi.com/travel-personality-types-guide/) — MEDIUM confidence
- [How to Build a Wrapped Feature (Trophy)](https://trophy.so/blog/how-to-build-wrapped-feature) — HIGH confidence
- [Foursquare Place Categories](https://docs.foursquare.com/data-products/docs/categories) — HIGH confidence (1,200+ category taxonomy)
- [NomadMania Trip Statistics 2025](https://nomadmania.com/trips2025-beta/) — MEDIUM confidence
- [iOS Geofencing Limitations (Radar)](https://radar.com/blog/limitations-of-ios-geofencing) — HIGH confidence (technical)
- [CLLocationManager Significant Location Changes (Apple Developer)](https://developer.apple.com/documentation/corelocation/cllocationmanager/startmonitoringsignificantlocationchanges()) — HIGH confidence (official Apple docs)
- [Gamification in Travel Apps 2025 (Guul Games)](https://guul.games/blog/gamification-in-travel-apps-driving-engagement-and-loyalty-2025) — MEDIUM confidence
- [Travel App Trends 2026 (Boldare)](https://www.boldare.com/blog/travel-app-trends-2026-complete-guide/) — MEDIUM confidence
- [Wanderlog vs Polarsteps Comparison (Wandrly)](https://www.wandrly.app/comparisons/wanderlog-vs-polarsteps) — MEDIUM confidence
