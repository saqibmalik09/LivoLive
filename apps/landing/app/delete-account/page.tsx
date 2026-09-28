"use client";

import { motion } from "framer-motion";
import Link from "next/link";
import { useState } from "react";

export default function DataDeletion() {
  const [submitted, setSubmitted] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitted(true);
  };

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
          
          <h1 style={{ fontSize: '3.5rem', marginBottom: '24px', fontFamily: 'var(--font-outfit)' }}>Data Deletion Request</h1>
          <p style={{ color: '#b3b3b3', marginBottom: '40px', fontSize: '1.2rem' }}>
            We value your privacy. Use this form to request the permanent deletion of your account and associated data from SK LIVE.
          </p>

          <div className="glass-card" style={{ padding: '60px', border: '1px solid rgba(255, 179, 0, 0.3)' }}>
            {!submitted ? (
              <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  <label style={{ fontWeight: 600, color: '#fff' }}>User ID / Unique ID</label>
                  <input 
                    type="text" 
                    required 
                    placeholder="Enter your SK LIVE ID" 
                    style={{ 
                      background: 'rgba(255,255,255,0.05)', 
                      border: '1px solid rgba(255,255,255,0.1)', 
                      padding: '16px', 
                      borderRadius: '12px', 
                      color: '#fff',
                      outline: 'none'
                    }} 
                  />
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  <label style={{ fontWeight: 600, color: '#fff' }}>Registered Email / Phone</label>
                  <input 
                    type="text" 
                    required 
                    placeholder="Enter your registered email or phone" 
                    style={{ 
                      background: 'rgba(255,255,255,0.05)', 
                      border: '1px solid rgba(255,255,255,0.1)', 
                      padding: '16px', 
                      borderRadius: '12px', 
                      color: '#fff',
                      outline: 'none'
                    }} 
                  />
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  <label style={{ fontWeight: 600, color: '#fff' }}>Reason for Deletion (Optional)</label>
                  <textarea 
                    placeholder="Tell us why you're leaving..." 
                    rows={4}
                    style={{ 
                      background: 'rgba(255,255,255,0.05)', 
                      border: '1px solid rgba(255,255,255,0.1)', 
                      padding: '16px', 
                      borderRadius: '12px', 
                      color: '#fff',
                      outline: 'none',
                      resize: 'none'
                    }} 
                  />
                </div>

                <div style={{ display: 'flex', alignItems: 'flex-start', gap: '12px', margin: '10px 0' }}>
                  <input type="checkbox" required style={{ marginTop: '5px' }} />
                  <p style={{ fontSize: '0.9rem', color: '#b3b3b3' }}>
                    I understand that this action is permanent. All my coins, levels, and CP status will be permanently erased and cannot be recovered.
                  </p>
                </div>

                <motion.button 
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  className="btn-primary" 
                  type="submit" 
                  style={{ width: '100%', marginTop: '20px', padding: '18px' }}
                >
                  Submit Deletion Request
                </motion.button>
              </form>
            ) : (
              <motion.div 
                initial={{ scale: 0.9, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                style={{ textAlign: 'center', padding: '40px 0' }}
              >
                <div style={{ fontSize: '5rem', marginBottom: '24px' }}>✅</div>
                <h2 style={{ fontSize: '2rem', marginBottom: '16px' }}>Request Submitted</h2>
                <p style={{ color: '#b3b3b3', fontSize: '1.1rem', lineHeight: 1.6 }}>
                  We have received your deletion request. Our team will verify your identity and process the deletion within 7-14 business days. You will receive a confirmation email once complete.
                </p>
                <Link href="/" className="btn-primary" style={{ display: 'inline-block', marginTop: '40px', textDecoration: 'none' }}>
                  Return Home
                </Link>
              </motion.div>
            )}
          </div>

          <div style={{ marginTop: '60px', padding: '30px', background: 'rgba(255, 100, 100, 0.05)', borderRadius: '16px', border: '1px solid rgba(255, 100, 100, 0.1)' }}>
            <h3 style={{ color: '#ff6b6b', marginBottom: '10px' }}>Important Note</h3>
            <p style={{ color: '#b3b3b3', fontSize: '0.95rem' }}>
              Data deletion is irreversible. Once your account is deleted, you will lose access to all your virtual assets, including Coins, VIP status, and Family memberships.
            </p>
          </div>
        </motion.div>
      </div>
    </main>
  );
}
