"use client";

import { motion } from "framer-motion";
import Link from "next/link";

export default function PrivacyPolicy() {
  return (
    <main style={{ background: '#1a0f08', minHeight: '100vh', color: '#fff', padding: '120px 20px' }}>
      <div className="purple-glow top-left"></div>
      
      <div style={{ maxWidth: '800px', margin: '0 auto' }}>
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8 }}
        >
          <Link href="/" style={{ color: 'var(--primary)', textDecoration: 'none', marginBottom: '40px', display: 'inline-block', fontWeight: 600 }}>
            &larr; Back to Home
          </Link>
          
          <h1 style={{ fontSize: '3.5rem', marginBottom: '24px', fontFamily: 'var(--font-outfit)' }}>Privacy Policy</h1>
          <p style={{ color: '#b3b3b3', marginBottom: '40px' }}>Effective Date: May 04, 2026</p>

          <div className="glass-card" style={{ padding: '40px', lineHeight: 1.8 }}>
            <p style={{ marginBottom: '30px', color: '#fff', fontSize: '1.1rem' }}>
              SK LIVE ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and share information about you when you use our mobile application and services.
            </p>

            <section style={{ marginBottom: '40px' }}>
              <h2 style={{ fontSize: '1.8rem', marginBottom: '16px', color: '#fff' }}>1. Information Collection</h2>
              <p style={{ color: '#b3b3b3' }}>
                <strong>Account Information:</strong> When you register via Google, Facebook, or Phone, we collect your name, email, profile picture, and unique ID.
                <br /><strong>Media & Voice:</strong> We process real-time audio during voice room sessions. This data is used to facilitate communication and is not stored unless required for safety reporting.
                <br /><strong>Usage Data:</strong> We collect information about your interactions, including gifts sent, rooms joined, and time spent.
              </p>
            </section>

            <section style={{ marginBottom: '40px' }}>
              <h2 style={{ fontSize: '1.8rem', marginBottom: '16px', color: '#fff' }}>2. Data Deletion & User Rights</h2>
              <p style={{ color: '#b3b3b3' }}>
                In compliance with Google Play and Meta policies, you have the right to access, correct, or delete your data. 
                <br /><br />
                <strong>How to Delete Your Data:</strong> You can request the permanent deletion of your account and all associated data by visiting our <Link href="/delete-account" style={{ color: 'var(--primary)' }}>Data Deletion Request Page</Link> or by using the "Delete Account" option within the app settings. Once processed, all personal info, coins, and history will be permanently erased.
              </p>
            </section>

            <section style={{ marginBottom: '40px' }}>
              <h2 style={{ fontSize: '1.8rem', marginBottom: '16px', color: '#fff' }}>3. Third-Party Services</h2>
              <p style={{ color: '#b3b3b3' }}>
                We use trusted third-party SDKs to provide our services:
                <br />- <strong>ZegoCloud:</strong> For real-time voice and audio processing.
                <br />- <strong>Supabase:</strong> For secure database and authentication storage.
                <br />- <strong>Meta/Google:</strong> For optional social login features.
                <br />These partners may collect data as governed by their respective privacy policies.
              </p>
            </section>

            <section style={{ marginBottom: '40px' }}>
              <h2 style={{ fontSize: '1.8rem', marginBottom: '16px', color: '#fff' }}>4. Data Retention</h2>
              <p style={{ color: '#b3b3b3' }}>
                We retain your information as long as your account is active. If you delete your account, we will remove your personal information from our active databases within 30 days, except where retention is required by law.
              </p>
            </section>

            <section style={{ marginBottom: '40px' }}>
              <h2 style={{ fontSize: '1.8rem', marginBottom: '16px', color: '#fff' }}>5. Child Safety Standards</h2>
              <p style={{ color: '#b3b3b3' }}>
                SK LIVE strictly prohibits any form of Child Sexual Abuse Material (CSAM) or Child Sexual Abuse and Exploitation (CSAE). We have zero tolerance for such content. Any user found sharing, promoting, or engaging in such activities will be immediately banned, and their information will be reported to the relevant national authorities and law enforcement agencies. Users can report any suspicious activity directly within the app.
              </p>
            </section>

            <section>
              <h2 style={{ fontSize: '1.8rem', marginBottom: '16px', color: '#fff' }}>6. Contact for Data Protection</h2>
              <p style={{ color: '#b3b3b3' }}>
                For any privacy-related concerns or data requests, please contact our Data Protection Officer at: <strong>privacy@sklive.app</strong>
              </p>
            </section>
          </div>
        </motion.div>
      </div>
    </main>
  );
}
