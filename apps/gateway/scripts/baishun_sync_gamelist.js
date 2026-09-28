#!/usr/bin/env node
require("dotenv").config();
const {
  syncGamelistFromBaishun: syncGamelistFromBaishun,
} = require("../src/baishun_merchant");
(async () => {
  try {
    const result = await syncGamelistFromBaishun();
    console.log("[baishun-sync] ok", result);
    process.exit(0);
  } catch (err) {
    console.error("[baishun-sync] failed:", err.message);
    process.exit(1);
  }
})();
