import type { NextConfig } from "next";
const nextConfig: NextConfig = {
  output: "standalone",
  // Keep sharp's native binaries in the Coolify/Alpine standalone image.
  serverExternalPackages: ["sharp"],
  outputFileTracingIncludes: {
    "/*": ["./node_modules/sharp/**/*", "./node_modules/@img/**/*"],
  },
  // Docker builds on the VPS used to hang for 30+ minutes on
  // "Running TypeScript..." after a successful compile — tsc thrashing on
  // swap. Skip the second typecheck in image builds; `next build` still
  // compiles. Run `npx tsc --noEmit` locally / in CI when you need it.
  typescript: {
    ignoreBuildErrors: process.env.DOCKER_BUILD === "1",
  },
  experimental: {
    serverActions: {
      bodySizeLimit: "50mb",
    },
    proxyClientMaxBodySize: "50mb",
  },
};
export default nextConfig;
