"use client";

import Image from "next/image";
import { motion } from "framer-motion";
import Link from "next/link";

export default function HomeClient({
  androidDownloadUrl,
}: {
  androidDownloadUrl: string;
}) {
  const fadeInUp = {
    initial: { opacity: 0, y: 60 },
    whileInView: { opacity: 1, y: 0 },
    viewport: { once: true },
    transition: { duration: 0.6, ease: "easeOut" as const }
  };

  const staggerContainer = {
    initial: {},
    whileInView: {
      transition: {
        staggerChildren: 0.2
      }
    }
  };

  return (
    <main style={{ overflowX: 'hidden', width: '100%' }}>
      <div className="brand-glow top-left"></div>
      <div className="brand-glow bottom-right"></div>

      {/* Navigation */}
      <motion.nav 
        initial={{ y: -100, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 1, ease: "circOut" }}
        className="glass-nav"
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div style={{ borderRadius: '12px', overflow: 'hidden', width: '40px', height: '40px', background: 'rgba(255,179,0,0.12)' }}>
            <Image src="/assets/sk-live-logo.png" alt="SK LIVE Logo" width={40} height={40} />
          </div>
          <span style={{ fontWeight: 800, fontSize: '1.4rem', fontFamily: 'var(--font-outfit)', letterSpacing: '1px', background: 'linear-gradient(135deg, #fff, #ffe082, #ffb300)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent' }}>
            SK LIVE
          </span>
        </div>
        <div style={{ display: 'flex', gap: '40px' }} className="nav-links">
          <a href="#features" className="nav-link">Features</a>
          <a href="#showcase" className="nav-link">Showcase</a>
          <a href="#download" className="nav-link">Download</a>
        </div>
        <a href="#download" style={{ textDecoration: 'none' }}>
          <motion.button 
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            className="btn-primary" 
            style={{ padding: '10px 28px', fontSize: '0.95rem' }}
          >
            Get Started
          </motion.button>
        </a>
      </motion.nav>

      {/* Hero Section */}
      <header className="hero">
        <motion.div
          initial={{ scale: 0.8, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ duration: 1, ease: "backOut" }}
          style={{ borderRadius: '24px', overflow: 'hidden', marginBottom: '24px', boxShadow: '0 20px 50px rgba(255,179,0,0.25)', background: 'rgba(255,179,0,0.08)', padding: '10px', border: '1px solid rgba(255,179,0,0.2)' }}
        >
          <Image src="/assets/sk-live-logo.png" alt="SK LIVE" width={120} height={120} style={{ borderRadius: '20px' }} priority />
        </motion.div>
        
        <motion.h1 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2, duration: 0.8 }}
          className="hero-title"
        >
          Your World,<br />Your Voice,<br />Your Stars.
        </motion.h1>

        <motion.p 
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.5, duration: 1 }}
          className="hero-subtitle"
        >
          Experience the next level of social audio. Connect in premium voice rooms, exchange virtual gifts, and build lasting communities.
        </motion.p>

        <motion.div 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.8, duration: 0.5 }}
          style={{ display: 'flex', gap: '20px' }}
        >
          <a 
            href={androidDownloadUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="btn-primary"
            style={{ textDecoration: 'none', display: 'inline-block' }}
          >
            Download for Android
          </a>
          <button className="btn-outline">iOS Coming Soon</button>
        </motion.div>
      </header>

      {/* Features Section */}
      <section id="features" className="section">
        <motion.h2 
          {...fadeInUp}
          className="section-title"
        >
          Why Choose SK LIVE?
        </motion.h2>
        
        <motion.div 
          variants={staggerContainer}
          initial="initial"
          whileInView="whileInView"
          viewport={{ once: true }}
          className="feature-grid"
        >
          {[
            { icon: "🎙️", title: "Premium Voice Rooms", text: "Interactive audio spaces with 8-20 mic slots. Crystal clear sound and real-time engagement." },
            { icon: "🎁", title: "Virtual Economy", text: "Exchange stunning 3D animated gifts like Rockets, Castles, and Wings to show your appreciation." },
            { icon: "💖", title: "CP & Family Systems", text: "Build special bonds with the CP Space and compete with your Family in global events." },
            { icon: "🎮", title: "Mini-Games", text: "Play Ludo, Lucky Spin, and Greed directly inside your voice rooms with friends." }
          ].map((feature, i) => (
            <motion.div 
              key={i}
              variants={fadeInUp}
              className="feature-card glass-card"
            >
              <div className="feature-icon-wrapper">{feature.icon}</div>
              <h3>{feature.title}</h3>
              <p>{feature.text}</p>
            </motion.div>
          ))}
        </motion.div>
      </section>

      {/* Showcase Section */}
      <section id="showcase" className="section">
        {[
          { 
            title: "Immersive Audio Experience", 
            text: "Step into futuristic voice rooms designed for the best social experience. High-quality audio, seamless interactions, and a community that never sleeps.",
            img: "/assets/hero_visual.png"
          },
          { 
            title: "Luxury Virtual Gifting", 
            text: "Stand out with premium animated gifts. Our virtual economy is built for creators and fans to celebrate moments in style.",
            img: "/assets/gifting_visual.png"
          },
          { 
            title: "Community & Connection", 
            text: "Whether it's finding your Partner in the CP Space or leading your Family to victory, SK LIVE is where real connections happen.",
            img: "/assets/community_visual.png"
          }
        ].map((item, i) => (
          <div key={i} className="showcase-item">
            <motion.div 
              initial={{ opacity: 0, x: i % 2 === 0 ? -100 : 100 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true, margin: "-100px" }}
              transition={{ duration: 0.8, ease: "easeOut" }}
              className="showcase-content"
            >
              <h2 style={{ fontSize: '3.5rem', marginBottom: '24px', fontWeight: 800 }}>{item.title}</h2>
              <p style={{ fontSize: '1.25rem', color: 'var(--text-secondary)', lineHeight: 1.8 }}>{item.text}</p>
            </motion.div>
            <motion.div 
              initial={{ opacity: 0, scale: 0.8, rotate: i % 2 === 0 ? 5 : -5 }}
              whileInView={{ opacity: 1, scale: 1, rotate: 0 }}
              viewport={{ once: true, margin: "-100px" }}
              transition={{ duration: 1, ease: "backOut" }}
              className="showcase-visual"
            >
              <Image src={item.img} alt={item.title} width={600} height={400} style={{ borderRadius: '40px', border: '1px solid rgba(255, 179, 0, 0.25)' }} />
            </motion.div>
          </div>
        ))}
      </section>

      {/* CTA Section */}
      <section id="download" className="section" style={{ textAlign: 'center' }}>
        <motion.div 
          initial={{ opacity: 0, scale: 0.9 }}
          whileInView={{ opacity: 1, scale: 1 }}
          viewport={{ once: true }}
          transition={{ duration: 0.8 }}
          className="glass-card" 
          style={{ padding: '100px 40px', background: 'linear-gradient(135deg, rgba(255, 179, 0, 0.12), rgba(217, 70, 239, 0.18), rgba(78, 52, 46, 0.4))', border: '1px solid rgba(255, 179, 0, 0.3)' }}
        >
          <h2 style={{ fontSize: '4rem', marginBottom: '24px', fontWeight: 900 }}>Ready to Shine?</h2>
          <p style={{ fontSize: '1.4rem', color: 'var(--text-secondary)', marginBottom: '48px', maxWidth: '800px', margin: '0 auto 48px' }}>
            Join thousands of stars on SK LIVE today. The ultimate stage for social audio awaits you.
          </p>
          <motion.div 
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            style={{ display: 'flex', gap: '20px', justifyContent: 'center' }}
          >
            <a 
              href={androidDownloadUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="btn-primary" 
              style={{ padding: '18px 48px', fontSize: '1.2rem', textDecoration: 'none', display: 'inline-block' }}
            >
              Download SK LIVE Now
            </a>
          </motion.div>
        </motion.div>
      </section>

      {/* Footer */}
      <footer>
        <div className="footer-container">
          <div className="footer-brand">
            <div style={{ display: 'flex', alignItems: 'center', gap: '15px', marginBottom: '24px' }}>
              <div style={{ borderRadius: '15px', overflow: 'hidden', width: '50px', height: '50px', background: 'rgba(255,255,255,0.05)', padding: '5px' }}>
                <Image src="/assets/sk-live-logo.png" alt="SK LIVE" width={40} height={40} />
              </div>
              <span style={{ fontWeight: 800, fontSize: '1.8rem', letterSpacing: '1px', color: '#fff' }}>SK LIVE</span>
            </div>
            <p style={{ color: 'var(--text-secondary)', maxWidth: '400px', lineHeight: 1.7, marginBottom: '32px' }}>
              The world's premium social audio platform. Connecting communities through voice, entertainment, and virtual gifting.
            </p>
            <div style={{ display: 'flex', gap: '20px' }}>
              {['Twitter', 'Instagram', 'Discord', 'Facebook'].map(social => (
                <a key={social} href="#" style={{ color: 'var(--text-secondary)', fontSize: '1.2rem' }}>{social[0]}</a>
              ))}
            </div>
          </div>

          <div>
            <h4 className="footer-title">Product</h4>
            <ul className="footer-links">
              <li><a href="#features">Features</a></li>
              <li><a href="#showcase">Showcase</a></li>
              <li><a href="#">Virtual Shop</a></li>
              <li><a href="#">Mini-Games</a></li>
            </ul>
          </div>

          <div>
            <h4 className="footer-title">Company</h4>
            <ul className="footer-links">
              <li><a href="#">About Us</a></li>
              <li><a href="#">Careers</a></li>
              <li><a href="#">Brand Assets</a></li>
              <li><a href="#">Contact</a></li>
            </ul>
          </div>

          <div>
            <h4 className="footer-title">Legal</h4>
            <ul className="footer-links">
              <li><Link href="/privacy">Privacy Policy</Link></li>
              <li><Link href="/terms">Terms of Service</Link></li>
              <li><Link href="/child-safety">Child Safety Standards</Link></li>
              <li><Link href="/delete-account">Data Deletion</Link></li>
              <li><a href="#">Cookie Policy</a></li>
            </ul>
          </div>
        </div>

        <div className="footer-bottom">
          <p>&copy; {new Date().getFullYear()} SK LIVE. All rights reserved.</p>
          <div style={{ display: 'flex', gap: '30px' }}>
            <span>Built with Premium Aesthetics</span>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: 'var(--success)' }}></div>
              <span>System Online</span>
            </div>
          </div>
        </div>
      </footer>

      <style jsx>{`
        @media (max-width: 992px) {
          .nav-links {
            display: none !important;
          }
        }
      `}</style>
    </main>
  );
}
