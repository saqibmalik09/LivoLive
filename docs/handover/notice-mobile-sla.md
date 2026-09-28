# Written notice — mobile bug resolution suspended

Send by email (Clause 13.2 makes email a valid notice channel). Purpose: establish, before the
first mobile bug is reported, that mobile-side resolution is blocked by a Clause 5.1(a) failure
to provide materials — which engages Clause 4.6 and suspends the Clause 4.3 same-day obligation
for mobile only.

---

**Subject:** Notice — Android bug resolution blocked pending delivery of the `orbit_voice` package
(Ref. INX/LIVO/MSA/2026-01)

Dear Mr. Daim Sada,

We write in connection with the Software Maintenance & Support Agreement dated 27 September 2026
(Ref. INX/LIVO/MSA/2026-01).

In the course of taking over maintenance we have established that the Flutter mobile application
**cannot be compiled** in its current state. Its `pubspec.yaml` requires the package `orbit_voice`
version 0.4.0, resolved from a local path (`orbit-voice/packages/orbit_voice`) that was not
included in any of the materials provided to us. The package is a genuine runtime dependency —
its native library `liborbit_denoise.so` is present in the released APK — and no public substitute
exists.

Accordingly, and pursuant to Clause 5.1(a), we request that you provide the complete
`orbit_voice` 0.4.0 package at the earliest opportunity.

Please note that until it is received:

1. We are unable to produce any Android build, and therefore unable to Resolve any Bug in the
   mobile application as "Resolve" is defined in Clause 1.1.
2. In accordance with Clause 4.6, the resulting delay arises from a factor outside our reasonable
   control, namely the Client's provision of materials under Clause 5. The timelines in Clause 4.3
   are extended accordingly **in respect of mobile-application Bugs only**.
3. Clause 5.2 applies to any delay so caused.

This does not affect the remainder of the Platform. Bugs in the backend, the room gateway, the
admin, master and super-admin panels, the Supabase edge functions and the database remain fully
within scope and will continue to be Resolved on the same-day basis set out in Clause 4.3.

We will confirm in writing as soon as the package is received and mobile timelines resume.

Yours sincerely,

Asad Ali
Chairperson, INEXIA IT SOLUTION (PVT.) LTD.
inexiapk@gmail.com · 0325 9420004
