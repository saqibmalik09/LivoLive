import type { NextConfig } from "next";
const nextConfig: NextConfig = {
  output: "standalone",
  // Keep sharp's native binaries in the Coolify/Alpine standalone image.
  serverExternalPackages: ["sharp"],
  outputFileTracingIncludes: {
    "/*": ["./node_modules/sharp/**/*", "./node_modules/@img/**/*"],
  },
  experimental: {
    serverActions: {
      bodySizeLimit: "50mb",
    },
    proxyClientMaxBodySize: "50mb",
  },
};
export default nextConfig;
