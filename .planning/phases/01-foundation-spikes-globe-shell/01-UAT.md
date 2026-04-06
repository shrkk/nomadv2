---
status: complete
phase: 01-foundation-spikes-globe-shell
source: 01-01-SUMMARY.md, 01-02-SUMMARY.md, 01-03-SUMMARY.md, 01-04-SUMMARY.md
started: 2026-04-05T00:00:00Z
updated: 2026-04-05T20:20:00Z
---

## Current Test

[testing complete]

## Tests

### 1. App Launch
expected: App launches without crashing. No red error screen. The globe/map view appears as the root view (not a blank screen or placeholder ContentView).
result: pass

### 2. Map/Globe Renders
expected: A map or globe fills the screen. Rahul switched from RealityKit to Apple Maps — you should see a globe-style or map-style Earth view. It should not be blank or show a loading spinner indefinitely.
result: pass

### 3. Visited Country Highlights
expected: 5 countries (Japan, France, Kenya, Australia, Brazil) are visually highlighted on the map/globe in amber/orange color. Other countries should appear in the default style.
result: pass

### 4. Drag / Pan Rotation
expected: Dragging on the globe/map rotates or pans it. The view responds to finger movement and repositions.
result: pass

### 5. Pinch to Zoom
expected: Pinching in/out on the globe/map zooms in or out. The zoom level changes in response to the gesture.
result: pass

### 6. Pinpoints Visible on Map
expected: 5 amber/orange pinpoint dots or markers appear on the map at city locations — Tokyo (Japan), Paris (France), Nairobi (Kenya), Sydney (Australia), Rio de Janeiro (Brazil).
result: pass

### 7. Tap Pinpoint → ProfileSheet
expected: Tapping one of the pinpoint markers opens a bottom sheet (ProfileSheet). The sheet shows "Your Journeys" header in amber, a "5 countries visited" caption, and a list of trip cards. Sheet background has the amber gradient + grain texture (PanelGradient).
result: pass

### 8. ProfileSheet Drag Handle
expected: The ProfileSheet can be dragged up to full screen or pulled down to medium height. It has at least two detent sizes (.medium and .large).
result: pass

### 9. Tap Trip Card → TripDetailSheet
expected: Tapping a trip card in the ProfileSheet opens a second sheet (TripDetailSheet). It shows the city name in amber, a date, divider line, stub stats (steps, distance, places), and a "No stops recorded" empty state. PanelGradient background applies.
result: pass

### 10. Custom Fonts Render
expected: Text in the sheets uses the custom fonts — Playfair Display (serif, for headers like "Your Journeys") and Inter (sans-serif, for body/caption text). Text should not fall back to system font.
result: pass

## Summary

total: 10
passed: 10
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none yet]
