"use client";

import { motion } from "framer-motion";
import Link from "next/link";

export default function ChildSafetyStandards() {
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

          <h1 style={{ fontSize: '3.5rem', marginBottom: '24px', fontFamily: 'var(--font-outfit)' }}>
            Child Safety Standards
          </h1>
          <p style={{ color: '#b3b3b3', marginBottom: '40px' }}>
            SK LIVE: Voice Chat Rooms · Last updated: July 25, 2026
          </p>

          <div className="glass-card" style={{ padding: '40px', lineHeight: 1.8 }}>
            <p style={{ marginBottom: '30px', color: '#fff', fontSize: '1.1rem' }}>
              SK LIVE (“SK LIVE: Voice Chat Rooms”) is committed to protecting users and preventing
              Child Sexual Abuse and Exploitation (CSAE), including Child Sexual Abuse Material (CSAM).
              This page sets out our publicly published standards against CSAE.
            </p>

            <section style={{ marginBottom: '40px' }}>
              <h2 style={{ fontSize: '1.8rem', marginBottom: '16px', color: '#fff' }}>1. Zero Tolerance for CSAE / CSAM</h2>
              <p style={{ color: '#b3b3b3' }}>
                We strictly prohibit any content, behavior, or activity that involves the sexual
                exploitation, abuse, or endangerment of minors. This includes creating, uploading,
                requesting, sharing, or distributing CSAM; grooming; or any related harmful conduct
                on SK LIVE voice rooms, chat, profiles, gifts, or any other feature.
              </p>
            </section>

            <section style={{ marginBottom: '40px' }}>
              <h2 style={{ fontSize: '1.8rem', marginBottom: '16px', color: '#fff' }}>2. Age Requirement</h2>
              <p style={{ color: '#b3b3b3' }}>
                SK LIVE is intended for users aged <strong style={{ color: '#fff' }}>18 and older</strong>.
                Accounts believed to belong to underage users may be restricted or permanently removed.
              </p>
            </section>

            <section style={{ marginBottom: '40px' }}>
              <h2 style={{ fontSize: '1.8rem', marginBottom: '16px', color: '#fff' }}>3. In-App Reporting</h2>
              <p style={{ color: '#b3b3b3' }}>
                Users can report child safety concerns and other violations using SK LIVE’s in-app
                report and block tools. We review reports and may remove content, warn users, suspend
                or ban accounts, and preserve relevant information where required by law.
              </p>
            </section>

            <section style={{ marginBottom: '40px' }}>
              <h2 style={{ fontSize: '1.8rem', marginBottom: '16px', color: '#fff' }}>4. Response to CSAM</h2>
              <p style={{ color: '#b3b3b3' }}>
                When we obtain actual knowledge of CSAM or CSAE on our platform, we act promptly to
                remove it and restrict offending accounts in accordance with these standards and
                applicable law. Confirmed CSAM is reported to the relevant national or regional
                authorities as required.
              </p>
            </section>

            <section style={{ marginBottom: '40px' }}>
              <h2 style={{ fontSize: '1.8rem', marginBottom: '16px', color: '#fff' }}>5. Legal Compliance</h2>
              <p style={{ color: '#b3b3b3' }}>
                SK LIVE complies with applicable child safety laws and regulations related to
                preventing and responding to CSAE / CSAM, including cooperation with lawful requests
                from competent authorities.
              </p>
            </section>

            <section>
              <h2 style={{ fontSize: '1.8rem', marginBottom: '16px', color: '#fff' }}>6. Child Safety Contact</h2>
              <p style={{ color: '#b3b3b3' }}>
                Designated point of contact for child safety / CSAE matters related to SK LIVE:
                <br /><br />
                Email:{' '}
                <a href="mailto:contact-us@almohsin-dev.online" style={{ color: 'var(--primary)' }}>
                  contact-us@almohsin-dev.online
                </a>
                <br /><br />
                This contact can discuss SK LIVE’s child safety practices, enforcement procedures,
                and compliance.
              </p>
            </section>
          </div>
        </motion.div>
      </div>
    </main>
  );
}
