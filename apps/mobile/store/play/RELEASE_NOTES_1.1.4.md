# SK Live — Release Notes

## Version 1.1.4 (6) — Play Store

**Version name:** `1.1.4`  
**Version code:** `6`  
**Package:** `com.sklive.app`

---

### Play Store — “What’s new” (copy/paste)

```
What's new in 1.1.4

• Smoother Home experience — banners, room covers, and rank frames load faster
• Room Top 1–3 cards now show covers and frames more reliably
• Promo banners display fully without awkward cropping (Home & Profile)
• Refreshed Hot tab visuals and navigation artwork
• Stronger room management tools for authorized support staff
• Android 15 stability — voice service no longer starts automatically on device boot
• Performance and stability improvements across rooms, gifts, and profile
```

---

### Highlights (internal / QA)

| Area | Change |
|------|--------|
| **Caching** | Hive-backed cache for banners, room covers, podium frames, games row, and user media — faster cold starts and fewer network waits |
| **Home Top-3** | Sparse Room Daily boards backfill from weekly/monthly; rank frames attach to slots 1–3 |
| **Banners** | Top, mid-feed, and profile carousels use contain-fit + correct aspect (admin upload size **1080×320**) |
| **Party / Hot UI** | Updated top/bottom theme art and nav icons; task shortcut aligned under top banners |
| **Super Admin** | Active `super_bd` staff can enter locked rooms without PIN and use host-level manage tools (ownership unchanged) |
| **Android 15 / Play** | Disabled `autoStartOnBoot` for voice FGS; removed `BootReceiver` so microphone service is never started from `BOOT_COMPLETED` (fixes Play “Restricted foreground service types” attention) |

---

### Admin reminder

Promo banners (Home / Mid-feed / Profile) must be uploaded at **1080×320px** (2× `2160×640` also accepted).

---

### Build checklist

```bash
cd sklive-mobile
flutter clean
flutter pub get
flutter build appbundle --release
```

Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console → Production (or Internal testing first).
