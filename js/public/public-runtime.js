import { MARKETS_CONFIG } from '../../config/markets.js';
import { TRANSPORT_MODES } from '../../config/transport-modes.js';

class KRIMPublicRuntime {
  constructor() {
    this.currentLocale = localStorage.getItem('krim_locale') || 'en';
    this.currentCurrency = localStorage.getItem('krim_currency') || 'USD';
    this.initialized = false;
  }

  async init() {
    if (this.initialized) return;
    
    this.setupAccessibilityListeners();
    this.setupConsentEngine();
    this.bindNavigationEvents();
    
    this.initialized = true;
    console.log(`[KRIM OS] Public Runtime Initialized (${this.currentLocale.toUpperCase()})`);
  }

  setupAccessibilityListeners() {
    // High-contrast and reduced motion detection
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      document.documentElement.classList.add('reduce-motion');
    }
  }

  setupConsentEngine() {
    const consent = localStorage.getItem('krim_consent_v1');
    if (!consent) {
      this.renderConsentBanner();
    }
  }

  renderConsentBanner() {
    // Dynamic non-intrusive cookie/consent banner
    const banner = document.createElement('div');
    banner.id = 'krim-consent-banner';
    banner.className = 'fixed bottom-4 right-4 max-w-md bg-slate-900 border border-slate-800 text-slate-300 p-4 rounded-xl shadow-2xl z-50 text-xs flex flex-col gap-3';
    banner.innerHTML = `
      <p>We use essential cookies to maintain operational security and regional routing performance.</p>
      <div class="flex justify-end gap-2">
        <a href="/legal/privacy.html" class="px-3 py-1.5 text-slate-400 hover:text-white">Privacy Policy</a>
        <button id="accept-consent" class="px-3 py-1.5 bg-cyan-500 text-slate-950 font-semibold rounded-lg">Acknowledge</button>
      </div>
    `;
    document.body.appendChild(banner);

    document.getElementById('accept-consent').addEventListener('click', () => {
      localStorage.setItem('krim_consent_v1', JSON.stringify({ acceptedAt: new Date().toISOString(), version: '1.0' }));
      banner.remove();
    });
  }

  bindNavigationEvents() {
    const mobileMenuBtn = document.getElementById('mobile-menu-btn');
    const mobileNav = document.getElementById('mobile-nav');
    
    if (mobileMenuBtn && mobileNav) {
      mobileMenuBtn.addEventListener('click', () => {
        const isOpen = mobileNav.classList.toggle('hidden');
        mobileMenuBtn.setAttribute('aria-expanded', (!isOpen).toString());
      });
    }
  }
}

export const runtime = new KRIMPublicRuntime();
document.addEventListener('DOMContentLoaded', () => runtime.init());
