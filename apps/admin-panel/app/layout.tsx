import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { Navigation } from "@/components/Navigation";
import { Toaster } from "sonner";
const inter = Inter({ subsets: ["latin"] });
export const metadata: Metadata = {
  title: "SK LIVE Admin",
  description: "Advanced Management Panel for SK LIVE",
};
export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${inter.className} min-h-screen pb-32`}>
        <main className="max-w-7xl mx-auto px-6 pt-12">{children}</main>
        <Navigation />
        <Toaster richColors position="top-right" />
      </body>
    </html>
  );
}
