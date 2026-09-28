"use client";

import { motion } from "framer-motion";
import Link from "next/link";

export default function TermsAndConditions() {
  return (
    <main style={{ background: '#1a0f08', minHeight: '100vh', color: '#fff', padding: '120px 20px' }}>
      <div className="purple-glow bottom-right"></div>
      
      <div style={{ maxWidth: '800px', margin: '0 auto' }}>
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8 }}
        >
          <Link href="/" style={{ color: 'var(--primary)', textDecoration: 'none', marginBottom: '40px', display: 'inline-block', fontWeight: 600 }}>
            &larr; Back to Home
          </Link>
          
          <h1 style={{ fontSize: '3.5rem', marginBottom: '24px', fontFamily: 'var(--font-outfit)' }}>Terms & Conditions</h1>
          <p style={{ color: '#b3b3b3', marginBottom: '40px' }}>Last updated: May 04, 2026</p>

          <div className="glass-card" style={{ padding: '40px', lineHeight: 1.8 }}>
            <section style={{ marginBottom: '40px' }}>
              <h2 style={{ fontSize: '1.8rem', marginBottom: '16px', color: '#fff' }}>1. Acceptance of Terms</h2>
              <p style={{ color: '#b3b3b3' }}>
                By accessing or using SK LIVE, you agree to be bound by these Terms and Conditions. If you do not agree, you may not use our services.
              </p>
            </section>

            <section style={{ marginBottom: '40px' }}>
              <h2 style={{ fontSize: '1.8rem', marginBottom: '16px', color: '#fff' }}>2. User Conduct</h2>
              <p style={{ color: '#b3b3b3' }}>
                Users are responsible for their behavior in voice rooms and social feeds. Harassment, hate speech, and illegal activities are strictly prohibited and will result in permanent account suspension.
              </p>
            </section>

            <section style={{ marginBottom: '40px' }}>
              <h2 style={{ fontSize: '1.8rem', marginBottom: '16px', color: '#fff' }}>3. Virtual Goods & Economy</h2>
              <p style={{ color: '#b3b3b3' }}>
                Virtual coins and gifts have no real-world monetary value and are non-refundable. They are intended for use within the SK LIVE ecosystem only.
              </p>
            </section>

            <section style={{ marginBottom: '40px' }}>
              <h2 style={{ fontSize: '1.8rem', marginBottom: '16px', color: '#fff' }}>4. Host & Family Guidelines</h2>
              <p style={{ color: '#b3b3b3' }}>
                Hosts and Family creators are expected to maintain a positive environment. Commissions and earnings are subject to the platform's current policies, which may be updated periodically.
              </p>
            </section>

            <section style={{ marginBottom: '40px' }}>
              <h2 style={{ fontSize: '1.8rem', marginBottom: '16px', color: '#fff' }}>5. Child Safety Standards</h2>
              <p style={{ color: '#b3b3b3' }}>
                SK LIVE strictly prohibits any form of Child Sexual Abuse Material (CSAM) or Child Sexual Abuse and Exploitation (CSAE). We have zero tolerance for such content. Any user found sharing, promoting, or engaging in such activities will be immediately banned, and their information will be reported to the relevant national authorities and law enforcement agencies. Users can report any suspicious activity directly within the app.
              </p>
            </section>

            <section>
              <h2 style={{ fontSize: '1.8rem', marginBottom: '16px', color: '#fff' }}>6. Termination</h2>
              <p style={{ color: '#b3b3b3' }}>
                We reserve the right to terminate or suspend access to our service immediately, without prior notice or liability, for any reason whatsoever, including breach of terms.
              </p>
            </section>
          </div>
        </motion.div>
      </div>
    </main>
  );
}
