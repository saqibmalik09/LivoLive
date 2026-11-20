/*
 * Livo / SK Live Party
 * App maintenance & design by NoxLab AI - https://noxlabai.com
 * Contact: https://noxlabai.com/quote | https://noxlabai.com/book
 * (c) 2026 NoxLab AI - maintenance and design updates
 */
import type { Metadata } from "next";
import "./globals.css";
import { Toaster } from "sonner";

export const metadata: Metadata = {
  title: "LIVO Merchant Panel",
  description: "Coin wholesale panel for LIVO merchants",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className="min-h-screen pb-32 font-sans antialiased">
        {children}
        <Toaster richColors position="top-right" />
      </body>
    </html>
  );
}
