const fs = require("fs");

const path = require("path");

const out = path.join(__dirname, "..", "..", "sk_live", "assets", "images", "bd", "badges");

fs.mkdirSync(out, {
  recursive: true,
});

const colors = [
  ["#34D399", "#059669"],
  ["#38BDF8", "#0284C7"],
  ["#A78BFA", "#7C3AED"],
  ["#F472B6", "#DB2777"],
  ["#FBBF24", "#D97706"],
  ["#FB923C", "#EA580C"],
  ["#2DD4BF", "#0D9488"],
  ["#818CF8", "#4F46E5"],
  ["#E879F9", "#C026D3"],
  ["#FACC15", "#CA8A04"],
];

for (let i = 1; i <= 10; i++) {
  const [c1, c2] = colors[i - 1];
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">\n  <defs>\n    <linearGradient id="g${i}" x1="0" y1="0" x2="1" y2="1">\n      <stop offset="0%" stop-color="${c1}"/>\n      <stop offset="100%" stop-color="${c2}"/>\n    </linearGradient>\n  </defs>\n  <polygon points="128,18 218,68 218,168 128,218 38,168 38,68" fill="url(#g${i})" stroke="#ffffff" stroke-width="6"/>\n  <polygon points="128,42 196,82 196,154 128,194 60,154 60,82" fill="#0B0E1B" opacity="0.28"/>\n  <text x="128" y="116" text-anchor="middle" font-family="Arial Black, Helvetica, sans-serif" font-size="26" font-weight="900" fill="#ffffff">BD</text>\n  <text x="128" y="156" text-anchor="middle" font-family="Arial Black, Helvetica, sans-serif" font-size="34" font-weight="900" fill="#ffffff">LV${i}</text>\n</svg>`;
  fs.writeFileSync(path.join(out, `bd_lv${i}.svg`), svg);
}

console.log("Wrote 10 badges to", out);
