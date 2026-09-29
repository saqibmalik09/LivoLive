# Issue triage — client list, 29 Sep 2026

Classified against agreement INX/LIVO/MSA/2026-01. Three outcomes:
**Covered** (Clause 2.1(a) bug fixing, no charge), **Chargeable** (Clause 3.1 Additional Work,
needs a written quote and the client's written approval under Clause 3.2), and
**Ours** (a defect we introduced — fixed free, not billable).

A "Bug" is defined in Clause 1.1 as a defect causing a module to fail to operate as it
operated, **or was designed to operate**, at the Effective Date — **and which can be corrected
without a Rebuild**. That last part is the dividing line: if a fix requires rewriting core
logic, database structure or an integration, it stops being a Bug and becomes Additional Work
under Clause 3.1(b).

## Covered by maintenance — no charge

| # | Issue | Why |
|---|---|---|
| Room 1 | Moving between mic seats shows a duplicate user + error | Seat-move logic malfunctioning. Clear Bug. |
| Room 2 | Blacklisted user re-entering gets a black screen | Blacklist path failing. Clear Bug. |
| Room 3 | Wallet still shows old balance until app restart | Stale client state after a transaction. Clear Bug. |
| Room 4 | Gift animation very late, sometimes never shows | Existing feature not performing as designed. |
| Room 5 | Lucky gift animation shows a black hole, DP doesn't fit | Rendering defect in an existing animation. |
| App 2b | Custom SVGA animations don't play correctly | Existing feature malfunctioning. |

## Ours to fix — no charge, not Additional Work

| # | Issue | Why |
|---|---|---|
| Room 7 | Voice late on entering, drops mid-speech, frequent reconnecting | Introduced by our LiveKit migration. The ~5s delay was fixed 29 Sep (publish permission is now granted on the live connection). Remaining drop/reconnect behaviour is ours to finish. |
| Room 7b | "Voice not clear" | Almost certainly the loss of DeepFilterNet noise suppression, a known consequence of moving off the vendor's `orbit_voice` package. Fully restoring it requires that package from the client. |

We introduced these while performing work that was itself Additional Work. Defects in our own
work are never billable.

## Chargeable — Additional Work

| # | Issue | Clause | Note |
|---|---|---|---|
| App 4 | Home screen brightness too low | 3.1(c) — UI/UX change requested by the Client, not required to resolve a Bug | Small job |
| Room 8 | Mic seat frames should display larger | 3.1(c) — same | Small job |
| App 5 | "Overall app very slow, optimise it" | 3.1(g) — performance work beyond the capacity of the current architecture | The large one. Needs scoping, not a single fix. |
| App 2a | Store items slow to load | 3.1(g) if it needs caching/query redesign; **covered** if it turns out to be a simple defect | Diagnose before quoting |

**Correct the premise on App 5.** The client reasons that 17 GB free RAM on the VPS means the app
should be fast. Those are unrelated: the slowness is in the Flutter client — image and SVGA
decoding, list rendering, state rebuilds, a 200 MB install — not in server memory. Adding server
resources will not make the app faster. This needs profiling on a real device, which is a scoped
piece of work.

## Already built — needs releasing, not building

| # | Issue | Status |
|---|---|---|
| App 3 | Room pin option | **Already implemented** in the unreleased v1.3.0: `pinned_party_rooms_provider.dart`, `home_pinned_rooms_section.dart`, and migrations `20260922113000_room_pin_to_party.sql` and `20260922120000_room_pin_slots_1_2_3.sql`. |

Users are on **v1.2.5**. Versions 1.2.9 and 1.3.0 were built but never released, so this feature
has been sitting unshipped. No development is needed — it needs a release, which is blocked on
the missing `orbit_voice` package. If the client instead wants the pin behaviour *changed*, that
change is Additional Work under 3.1(c).

## Needs diagnosis before classifying

| # | Issue | Note |
|---|---|---|
| App 1 | App restarts instead of resuming when reopened | If Android is killing the process because of the app's memory footprint, the fix may be a Rebuild of state handling → 3.1(b). If it is a state-restoration defect, it is a Bug → covered. Diagnose first, classify after. |
| Room 6 | Room reward / ranking issue | Client is sending a video. Classify once the actual behaviour is known. If a calculation is wrong, it is a Bug; if the rules are being changed, 3.1(c). |

## Recommended reply

1. Confirm the covered items are in hand and will follow the Clause 4.3 same-day process as they
   are reported individually.
2. State plainly that the voice items are ours and already being addressed at no charge.
3. Point out that room pin already exists and ships with the next release.
4. Quote the two UI changes and the performance work separately. Consider doing the two small UI
   changes at no charge as goodwill — but say in writing that they are Additional Work being
   waived, so it does not set a precedent that UI changes are included.
5. Ask for the ranking video and for a reproduction case on the store-loading delay.
