# Tulasi Game merchant callbacks (SK Live)

Single file: `index.ts` — Dashboard editor se paste + Deploy.

Function name: **`tulasi-game`**
Verify JWT: **OFF**

Proxy (Tulasi dashboard callback, not this Edge URL):

`https://tulasi.skliveparty.online/game/game/`

This Edge (proxy upstream only):

`https://pbobnvkscssgfpynmdhl.supabase.co/functions/v1/tulasi-game/`

## Secrets

Dashboard → Project Settings → Edge Functions → Secrets

| Name | Value |
|---|---|
| `TULASI_MERCHANT_ID` | `1503241` |
| `TULASI_PLATFORM_PUBLIC_KEY` | Tulasi **platform** public PEM (`-----BEGIN PUBLIC KEY-----` …) |
| `TULASI_MERCHANT_PRIVATE_KEY` | Merchant **1503241** private PEM |
| `TULASI_COIN_MAX` | **Optional.** Set karo (e.g. `100000`) to game mein balance cap. Poora wallet ke liye delete karo ya `none`. |
| `TULASI_PATTI_MIN_PAYOUT` | **Optional.** Kitna payout mile to top patti chale. Default `1000`. Round ka stake minus nahi hota — net loss par bhi patti chalti hai. Purana naam `TULASI_PATTI_MIN_NET` bhi chal jata hai. |
| `TULASI_PATTI_SETTLE_MS` | **Optional.** Bets ka intezar (ms) win ke baad, kyunke kuch SUBTRACT callbacks ADD ke baad aate hain. Default `1800`. |
| `TULASI_DEBUG` | **Optional.** `true` sirf temporary troubleshooting ke liye. Default off rakho; full payload logging callback bursts ko slow karti hai. `TIMING` aur errors debug off par bhi log hote hain. |

PEM poora paste, newlines ke sath (`\n` escaped bhi chalta hai). Git mein mat commit.

`SUPABASE_URL` / `SERVICE_ROLE` auto — set mat karo.

> **Rave Star aur SK Live ek hi Tulasi merchant `1503241` share karte hain.**
> Tulasi ek hi callback URL deta hai, isliye proxy dono Edges ko wahi encrypted
> body forward karta hai. Dono par **bilkul same** `TULASI_PLATFORM_PUBLIC_KEY`
> aur `TULASI_MERCHANT_PRIVATE_KEY` honi chahiye — Rave ke project se copy karke
> yahan paste karo. Alag key = har request `Encryption block is invalid`.

## Editor deploy

1. Edge Functions → `tulasi-game` (name exactly `tulasi-game`)
2. Verify JWT **off**
3. Poori `index.ts` paste → Deploy

## Troubleshoot: `Encryption block is invalid`

Yeh node-forge ka RSA decrypt error hai — request hamare merchant private key se
khul nahi rahi. Deploy ke baad logs mein har request pe yeh lines aati hain:

```
[tulasi-game] IN     { route: "userInformation", ... }
[tulasi-game] KEYS   { merchant: { fp: "b3f1…9a2c" }, platform: { fp: … } }
[tulasi-game] BODY   { chars: 344, chunks: 1, preview: "…" }
[tulasi-game] DECRYPT_FAIL { err: "Encryption block is invalid." }
```

Order mein check karo:

1. **`KEYS.merchant.fp`** — Rave Star Edge ke logs mein bhi yahi line aati hai.
   Dono ka `fp` **exactly same** hona chahiye (same merchant `1503241`). Alag hai
   to SK Live pe galat PEM laga hai — Rave wali copy karo. Yahi 90% cases ki wajah.
2. **`KEYS.merchant.begin`** — `-----BEGIN RSA PRIVATE KEY-----` ya
   `-----BEGIN PRIVATE KEY-----`. `parse_fail` aaye to PEM adhoora paste hua hai.
3. **`BODY.chunks`** — `0` matlab body khaali (proxy galat forward kar raha).
4. Platform/merchant key ulte to nahi lag gaye — `TULASI_PLATFORM_PUBLIC_KEY`
   **public** hota hai, `TULASI_MERCHANT_PRIVATE_KEY` **private**.

`DECRYPT_FAIL` ab crash nahi karta, `{"code":0,"msg":"decrypt_failed"}` return
karta hai, taake Tulasi retry loop mein na phanse.

## Notes

- `avatar` jaan-boojh kar khaali bhejte hain. Lamba Supabase avatar URL payload
  ko 2nd RSA chunk mein dhakel deta hai aur kuch H5 builds sirf pehla chunk
  decrypt karte hain → login fail.
- `updateGameList` admin ke `is_active` / `category_id` / `sort_order` ko
  overwrite **nahi** karta. Sync sirf naam, icon, URL aur Tulasi metadata
  refresh karta hai, taake admin ka hide/show toggle qaayam rahe.
- Dusre merchant ka catalog aaye to skip hota hai (`skippedOtherMerchant` log).

## Win patti (upar wali winning patti)

Tulasi H5 hamara `reportGameWin` bridge call nahi karti, isliye patti yahan se
banti hai. `updateBalance` mein `type = 1` (payout credit) hone par:

1. Response pehle chala jata hai; patti ka kaam background mein hota hai
   (`TULASI_PATTI_SETTLE_MS` wait, taake late bet callbacks bhi gin liye jaayen).
2. Us round ke bets milte hain — `snapshot->>gameEndTimestamp` se round match
   hota hai, warna last 90s ka window. Sab se zyada repeat hone wali single bet
   amount `betUnit` hoti hai (tie mein chhoti amount), Rave Star ki tarah.
3. **payout hi banner ki amount hai.** `payout < TULASI_PATTI_MIN_PAYOUT` ho to
   patti skip (log: `patti SKIP`) — round ka stake minus nahi hota, isliye net
   loss wale round par bhi patti chalti hai. Multiplier = `payout / betUnit`;
   losing slots ki baqi stake multiplier mein count nahi hoti. Tier
   `broadcast_room_win` jaisa (`x250` / `x500` caps).
4. Row `global_win_announcements` mein jati hai `server_broadcast = true` ke sath.

App gateway se pattis leta hai, aur server-side rows ke liye alag se Postgres
insert feed sunta hai (`server_broadcast = true` wale hi). Isi liye gift aur
first-party game wins dobara nahi chalte — un ka flag `false` rehta hai.

Logs:

```
[tulasi-game] patti OUT  { reward_coins: 4800, bonus_multiplier: 5, payout: 6000, staked: 1200, betUnit: 1200 }
[tulasi-game] patti SKIP { payout: 6000, staked: 6800, net: -800, min: 1000 }
```
