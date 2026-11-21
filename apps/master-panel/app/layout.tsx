import type { Metadata } from 'next';
import './globals.css';
import { Navigation } from '@/components/Navigation';
import { Toaster } from 'sonner';

export const metadata: Metadata = {
  title: 'SK Live Master Panel',
  description: 'Limited master operations panel for SK LIVE',
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="min-h-screen pb-32 font-sans antialiased">
        <main className="max-w-7xl mx-auto px-6 pt-12">{children}</main>
        <Navigation />
        <Toaster richColors position="top-right" />
      </body>
    </html>
  );
}
