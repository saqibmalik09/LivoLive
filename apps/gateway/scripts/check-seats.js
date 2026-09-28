const db = require("./src/db");
const roomId = process.argv[2] || "56511a22-c789-4ff4-abb6-3b8807339a8e";
(async () => {
  try {
    const seats = await db.loadRoomSeats(roomId);
    const meta = await db.loadRoomMeta(roomId);
    console.log("seats_ok", seats.length);
    for (const s of seats) {
      console.log(
        "seat",
        s.seat_index,
        s.user_id,
        (s.user && s.user.username) || "-",
      );
    }
    console.log("meta_ok", Boolean(meta), meta && meta.title);
    process.exit(0);
  } catch (e) {
    console.error("FAIL", e.message);
    process.exit(1);
  }
})();
