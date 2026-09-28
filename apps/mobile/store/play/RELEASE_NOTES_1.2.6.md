# LIVO / SK Live — Release Notes

## Version 1.2.6 (20) — Play Store

**Version name:** `1.2.6`  
**Version code:** `20`  
**Package:** `com.sklive.app`

---

### Play Store — “What’s new” (copy/paste, ≤500 chars)

```
What's new in 1.2.6

• Faster Lucky & Lucky Pro gifts in rooms — smoother combo and jackpot feedback
• Mention friends from the room profile card — one tap to @ them in chat
• More mini-games and game hub updates
• Clearer win announcements and gift effects in live rooms
• Stronger voice rooms — more reliable mic join and audio
• Polished splash branding and overall stability improvements
```

---

### Short variant (if Console trims hard)

```
Faster Lucky gifts, @mention from profiles, more mini-games, clearer win effects, and more reliable voice rooms. Stability fixes throughout.
```

---

### Highlights (internal / QA — do not paste to Play)

| Area | Change |
|------|--------|
| **Lucky / Lucky Pro** | Gateway settle (`gift:send`) + Redis rolls; RPC only as fallback |
| **Mentions** | Room mini profile sheet passes `onMention` from seat / member paths |
| **Games** | BAISHUN / game hub updates and room game surfaces |
| **Voice** | Orbit hardening, sitDown / openMic nullability fix |
| **UX** | Splash logo soft rounded corners |

---

### Build checklist

```bash
cd sklive-mobile
flutter clean
flutter pub get
flutter build appbundle --release
```

Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console.
