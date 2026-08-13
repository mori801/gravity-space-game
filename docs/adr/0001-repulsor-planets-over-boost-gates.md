# ADR-0001: Repulsor planets (negative mass) over boost gates for Iteration 1

**Date**: 2026-08-13
**Status**: accepted
**Deciders**: Session orchestrator (CEO role), informed by two parallel Plan-agent proposals

## Context

Iteration 1 of the 5-iteration content roadmap needed exactly one new physics-affecting mechanic that composes with the existing additive-acceleration gravity/wind model, plus a small teaching tier (~4 levels), without touching win/lose semantics or introducing reflex/timing-pressure gameplay. Two candidate mechanics were dispatched to independent Plan agents for investigation: repulsor planets (negative-mass `PlanetSpec`) and boost gates (a one-time directional velocity impulse zone).

## Decision

Implement repulsor planets: `PlanetSpec.mass` may be negative, producing a repulsive force via the existing `gravitationalAcceleration()` inverse-square physics in `lib/game/physics/gravity.dart`, with zero changes to that function's math (the sign flip on `magnitude` already reverses `addScaled`'s effect). Visual distinction is a hollow ring vs. filled disc in `Planet.render()`.

## Alternatives Considered

### Alternative 1: Repulsor planets (negative mass)
- **Pros**: Zero physics code changes — the existing inverse-square formula already produces correct repulsion for negative mass. No new mutable state, no new spec class, no new reset-path bookkeeping. `isRepulsor` is derived purely from `mass < 0`, so there's one source of truth and no way for a level author to set the flag inconsistently with the mass sign.
- **Cons**: Less mechanically novel than a one-shot impulse — it's "the same force, flipped," not a new interaction verb.
- **Why not rejected**: This is the chosen option.

### Alternative 2: Boost gates (one-time directional impulse)
- **Pros**: A genuinely new puzzle feel — "plan your pass through a single decisive kick" — distinct from anything in the game today.
- **Cons**: Requires edge-triggered swept-segment detection (not a per-frame additive check), a new `Set<int>` of "already consumed this attempt" per-gate state that must be correctly cleared across `resetLevel()`, `retrySameShot()`, and `loadLevel()`, a new public `Rocket.applyImpulse()` mutator reaching outside the normal integration step, a new gate-shaped component with a "spent" visual state, and roughly double the file footprint of the wind-zone mechanic it most resembles.
- **Why not**: The planner's own honest complexity assessment placed this "on par with, arguably above, the wormhole mechanic" — the most stateful mechanic in the codebase today — rather than the wind-zone-sized effort a first iteration should target. Given Iteration 1's explicit goal of a small, low-risk mechanic, the state-management risk (an easy exploit if trigger-clearing is missed on any one of three reset paths) wasn't justified for the puzzle-design gain, especially with a whole roadmap of later iterations to introduce higher-complexity mechanics once the pipeline itself is proven out.

## Consequences

### Positive
- Iteration 1 shipped with a one-line game-loop change (`isRepulsor: planetSpec.mass < 0`) and zero new mutable per-attempt state — no reset-path bugs possible by construction.
- The mechanic is immediately combinable with existing systems (orbit motion, multi-target, wormholes) for free, since it's just a sign flip on an existing field rather than a new spec type requiring its own composition rules.
- Sets a low-risk precedent for "first iteration should be the simplest viable mechanic" for future roadmap resets.

### Negative
- Boost gates' "single decisive kick" puzzle feel remains unbuilt; if wanted later, it will cost roughly wormhole-level implementation effort whenever it's picked up.
- Repulsors alone don't teach the swept-segment/edge-triggering pattern that later mechanics (e.g. a future one-shot pickup) would need — that groundwork is deferred.

### Risks
- None specific to this decision; the chosen mechanic's simplicity was explicitly the risk-reduction goal.
