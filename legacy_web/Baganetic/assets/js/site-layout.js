// Site-wide layout and shared UI bootstrapping
// - Injects consistent header and nav drawer
// - Wires up hamburger, search, and auth placeholders
// - Ensures chatbot initializes once per page

(function () {
  if (window.__baganeticLayoutBootstrapped) return;
  window.__baganeticLayoutBootstrapped = true;

  function isMyanmarPage(pathname) {
    const file = (pathname.split('/').pop() || '').toLowerCase();
    return pathname.includes('/mmversion/') || /mm\.html$/i.test(file) || /indexmm\.html$/i.test(file);
  }

  function ensureHeaderAndDrawer() {
    const hasHeader = document.querySelector('body > header');
    const hasDrawer = document.getElementById('navDrawer');
    const inMM = isMyanmarPage(window.location.pathname);

    if (!hasHeader) {
      const header = document.createElement('header');
      header.innerHTML = `
        <button id="hamburger" class="hamburger" aria-label="${inMM ? 'မီနူးဖွင့်ရန်' : 'Open menu'}">
          <span></span><span></span><span></span>
        </button>
        <div class="logo"><h1>Baganetic</h1></div>
        <div class="nav-search">
          <input type="text" id="navSearch" placeholder="${inMM ? 'စေတီများ ရှာဖွေရန်...' : 'Search pagodas...'}" />
          <button id="navSearchButton" aria-label="${inMM ? 'ရှာဖွေရန်' : 'Search'}">🔍</button>
        </div>
        <nav class="nav-inline" aria-label="Primary">
          <a href="${inMM ? '/mmversion/indexmm.html' : '/index.html'}">${inMM ? 'ပင်မစာမျက်နှာ' : 'Home'}</a>
          <a href="${inMM ? '/mmversion/mapmm.html' : '/map.html'}">${inMM ? 'မြေပုံ' : 'Map'}</a>
          <a href="${inMM ? '/mmversion/pagodasmm.html' : '/pagodas.html'}">${inMM ? 'စေတီများ' : 'Pagodas'}</a>
          <div class="login-popup-container">
            <button class="login-trigger" id="loginTrigger">${inMM ? 'အကောင့်ဝင်ရန်' : 'Login'}</button>
            <div class="login-popup" id="loginPopup" style="display:none"></div>
            <div class="notification-dropdown" id="notificationDropdown"><div class="notification-content"></div></div>
          </div>
        </nav>
      `;
      document.body.insertBefore(header, document.body.firstChild);
    }

    if (!hasDrawer) {
      const drawer = document.createElement('aside');
      drawer.className = 'nav-drawer';
      drawer.id = 'navDrawer';
      drawer.setAttribute('aria-hidden', 'true');
      drawer.innerHTML = `
        <button class="close-nav" id="closeNav" aria-label="${inMM ? 'လမ်းညွှန်မှုပိတ်ရန်' : 'Close navigation'}">×</button>
        <a href="${inMM ? '/mmversion/indexmm.html' : '/index.html'}">${inMM ? 'ပင်မစာမျက်နှာ' : 'Home'}</a>
        <a href="${inMM ? '/mmversion/mapmm.html' : '/map.html'}">${inMM ? 'မြေပုံ' : 'Map'}</a>
        <a href="${inMM ? '/mmversion/pagodasmm.html' : '/pagodas.html'}">${inMM ? 'စေတီများ' : 'Pagodas'}</a>
      `;
      document.body.insertBefore(drawer, document.body.firstChild.nextSibling);
    }
  }

  function wireHamburger() {
    const hamburger = document.getElementById('hamburger');
    const navDrawer = document.getElementById('navDrawer');
    if (!hamburger || !navDrawer) return;

    let isOpen = false;
    function open() {
      document.body.classList.add('nav-open');
      isOpen = true;
    }
    function close() {
      document.body.classList.remove('nav-open');
      isOpen = false;
    }

    hamburger.addEventListener('click', (e) => {
      e.preventDefault();
      isOpen ? close() : open();
    });
    const closeBtn = document.getElementById('closeNav');
    if (closeBtn) closeBtn.addEventListener('click', (e) => { e.preventDefault(); close(); });
    document.addEventListener('click', (e) => {
      if (!isOpen) return;
      if (hamburger.contains(e.target)) return;
      if (navDrawer.contains(e.target)) return;
      close();
    });
  }

  function wireSearch() {
    const input = document.getElementById('navSearch');
    const btn = document.getElementById('navSearchButton');
    if (btn && input) {
      btn.addEventListener('click', () => {
        const v = input.value.trim();
        if (!v) return;
        const inMM = isMyanmarPage(window.location.pathname);
        const target = inMM ? '/mmversion/pagodasmm.html' : '/pagodas.html';
        window.location.href = `${target}?search=${encodeURIComponent(v)}`;
      });
      
      // Also handle Enter key
      input.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
          const v = input.value.trim();
          if (!v) return;
          const inMM = isMyanmarPage(window.location.pathname);
          const target = inMM ? '/mmversion/pagodasmm.html' : '/pagodas.html';
          window.location.href = `${target}?search=${encodeURIComponent(v)}`;
        }
      });
    }
  }

  function initChatbotOnce() {
    console.log('initChatbotOnce called');
    // If chatbot script already loaded, just initialize
    if (window.initializeChatbot) {
      console.log('Chatbot script already loaded, initializing...');
      try { window.initializeChatbot(); } catch (e) { console.error('Error initializing chatbot:', e); }
      return;
    }
    // If not, but widget exists from previous include, skip
    if (document.querySelector('.baganetic-chatbot-widget')) {
      console.log('Chatbot widget already exists, skipping');
      return;
    }
    // Load chatbot script dynamically at the end of body, then init
    console.log('Loading chatbot script...');
    const s = document.createElement('script');
    s.src = '/assets/js/floating-chatbot.js';
    s.defer = true;
    s.onload = function() {
      console.log('Chatbot script loaded, initializing...');
      // Wait for other scripts to finish loading
      setTimeout(() => {
        if (window.initializeChatbot) {
          try { window.initializeChatbot(); } catch (e) { console.error('Error initializing chatbot:', e); }
        }
      }, 500); // Reduced delay for faster appearance
    };
    // Append to body instead of head to avoid conflicts
    document.body.appendChild(s);
  }

  function boot() {
    ensureHeaderAndDrawer();
    wireHamburger();
    wireSearch();
    addLanguageToggle();
    initChatbotOnce();
    ensureBreadcrumbShell();
    normalizeExistingNavLinks();
    // Re-normalize when breadcrumb content is created/changed after load
    try {
      const bc = document.getElementById('breadcrumb');
      if (bc && window.MutationObserver) {
        const obs = new MutationObserver(() => {
          try { normalizeExistingNavLinks(); } catch (_) {}
        });
        obs.observe(bc, { childList: true, subtree: true, attributes: true });
      }
      // Also schedule a delayed re-run for pages that inject late
      setTimeout(() => { try { normalizeExistingNavLinks(); } catch (_) {} }, 300);
      setTimeout(() => { try { normalizeExistingNavLinks(); } catch (_) {} }, 1000);
    } catch (_) {}

    // Intercept anchor clicks to enforce correct language routing
    document.addEventListener('click', function(e) {
      try {
        const a = e.target.closest && e.target.closest('a');
        if (!a) return;
        let href = a.getAttribute('href') || '';
        if (!href || /^https?:\/\//i.test(href) || href.startsWith('#') ) return;
        const inMM = isMyanmarPage(window.location.pathname);
        // Normalize common routes
        function toMM(u){
          if (/^(\.\.\/)?index\.html$/i.test(u)) return '/mmversion/indexmm.html';
          if (/^(\.\.\/)?map\.html$/i.test(u)) return '/mmversion/mapmm.html';
          if (/^(\.\.\/)?pagodas\.html$/i.test(u)) return '/mmversion/pagodasmm.html';
          if (/^(\.\.\/)?pagodaDetils\.html\?id=/.test(u)) {
            const id = (u.match(/id=([^&]+)/) || [])[1];
            if (id) return `/mmversion/pagodaDetailsmm.html?id=${id}&mm=1`;
          }
          if (/^mmversion\/[a-z0-9-]+mm\.html$/i.test(u)) {
            const id = (u.match(/^mmversion\/([a-z0-9-]+)mm\.html/i) || [])[1];
            if (id) return `/mmversion/pagodaDetailsmm.html?id=${id}&mm=1`;
          }
          return u;
        }
        function toEN(u){
          if (/^(\.\.\/)?mmversion\/indexmm\.html$/i.test(u)) return '/index.html';
          if (/^(\.\.\/)?mmversion\/mapmm\.html$/i.test(u)) return '/map.html';
          if (/^(\.\.\/)?mmversion\/pagodasmm\.html$/i.test(u)) return '/pagodas.html';
          if (/^(\.\.\/)?mmversion\/pagodaDetailsmm\.html\?id=/.test(u)) {
            const id = (u.match(/id=([^&]+)/) || [])[1];
            if (id) return `/pagodaDetils.html?id=${id}`;
          }
          return u;
        }
        const newHref = inMM ? toMM(href) : toEN(href);
        if (newHref !== href) {
          e.preventDefault();
          window.location.href = newHref;
        }
      } catch (_) {}
    }, true);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();


// Language toggle (EN/MM) — injected into header nav on every page
(function () {
  function isMyanmarPage(pathname) {
    const file = pathname.split('/').pop() || '';
    return pathname.includes('/mmversion/') || /mm\.html$/i.test(file);
  }

  function buildTargetUrl(pathname) {
    const parts = pathname.split('/').filter(Boolean);
    const file = parts.pop() || 'index.html';
    const inMM = isMyanmarPage(pathname);

    if (inMM) {
      // MM -> EN mapping
      if (file.toLowerCase() === 'indexmm.html') {
        return '/index.html';
      }
      // Handle filename typos/legacy names
      let enFile = file.replace(/mm\.html$/i, '.html');
      if (enFile.toLowerCase() === 'pagodadetails.html') {
        // English file is spelled 'pagodaDetils.html' in this project
        enFile = 'pagodaDetils.html';
      }
      const withoutMMDir = parts.filter(p => p.toLowerCase() !== 'mmversion');
      return '/' + withoutMMDir.join('/') + (withoutMMDir.length ? '/' : '') + enFile;
    } else {
      // EN -> MM mapping
      if (file.toLowerCase() === 'index.html' || file === '') {
        return '/mmversion/indexmm.html';
      }
      // Handle legacy typo: 'pagodaDetils.html' -> 'pagodaDetailsmm.html'
      let mmFile = file.replace(/\.html$/i, 'mm.html');
      if (file.toLowerCase() === 'pagodadetils.html') {
        mmFile = 'pagodaDetailsmm.html';
      }
      return '/mmversion/' + mmFile;
    }
  }

  function addLanguageToggle() {
    const headerNav = document.querySelector('header nav.nav-inline');
    if (!headerNav) return;

    // Avoid duplicates
    if (headerNav.querySelector('.lang-toggle')) return;

    const btn = document.createElement('button');
    btn.className = 'lang-toggle';
    btn.style.marginLeft = '12px';
    btn.style.padding = '8px 12px';
    btn.style.borderRadius = '999px';
    btn.style.border = '1px solid #aa7739';
    btn.style.background = 'white';
    btn.style.color = '#5a3d1f';
    btn.style.cursor = 'pointer';

    const pathname = window.location.pathname;
    const inMM = isMyanmarPage(pathname);
    btn.textContent = inMM ? 'EN' : 'MM';
    btn.setAttribute('aria-label', inMM ? 'Switch to English' : 'မြန်မာဘာသာသို့ ပြောင်းရန်');

    btn.addEventListener('click', function (e) {
      e.preventDefault();
      try { localStorage.setItem('preferredLanguage', inMM ? 'en' : 'my'); } catch (_) {}
      const target = buildTargetUrl(pathname);
      const current = new URL(window.location.href);
      // Adjust query params: remove mm when going to EN; add when going to MM
      if (inMM) {
        current.searchParams.delete('mm');
      } else {
        current.searchParams.set('mm', '1');
      }
      const q = current.searchParams.toString();
      const h = current.hash || '';
      window.location.href = target + (q ? ('?' + q) : '') + h;
    });

    headerNav.appendChild(btn);
  }

  function addMobileLanguageToggle() {
    const mobileLangToggle = document.getElementById('mobileLangToggle');
    if (!mobileLangToggle) return;

    const pathname = window.location.pathname;
    const inMM = isMyanmarPage(pathname);
    const langText = mobileLangToggle.querySelector('.lang-text');
    
    if (langText) {
      langText.textContent = inMM ? 'EN' : 'MM';
    }
    mobileLangToggle.setAttribute('aria-label', inMM ? 'Switch to English' : 'မြန်မာဘာသာသို့ ပြောင်းရန်');

    mobileLangToggle.addEventListener('click', function (e) {
      e.preventDefault();
      try { localStorage.setItem('preferredLanguage', inMM ? 'en' : 'my'); } catch (_) {}
      const target = buildTargetUrl(pathname);
      const current = new URL(window.location.href);
      // Adjust query params: remove mm when going to EN; add when going to MM
      if (inMM) {
        current.searchParams.delete('mm');
      } else {
        current.searchParams.set('mm', '1');
      }
      const q = current.searchParams.toString();
      const h = current.hash || '';
      window.location.href = target + (q ? ('?' + q) : '') + h;
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', addLanguageToggle);
    document.addEventListener('DOMContentLoaded', addMobileLanguageToggle);
  } else {
    addLanguageToggle();
    addMobileLanguageToggle();
  }
})();

// Normalize existing hard-coded nav links inside headers/nav-drawers on pages
// that already contain markup (e.g., localized MM pages), so they route to the
// correct language variants.
(function () {
  function isMyanmarPage(pathname) {
    const file = (pathname.split('/').pop() || '').toLowerCase();
    return pathname.includes('/mmversion/') || /mm\.html$/i.test(file) || /indexmm\.html$/i.test(file);
  }

  window.normalizeExistingNavLinks = function normalizeExistingNavLinks() {
    const inMM = isMyanmarPage(window.location.pathname);
    const headerNav = document.querySelector('header nav.nav-inline');
    const drawer = document.getElementById('navDrawer');
    const breadcrumb = document.getElementById('breadcrumb');
    const targets = inMM
      ? {
          home: '/mmversion/indexmm.html',
          map: '/mmversion/mapmm.html',
          pagodas: '/mmversion/pagodasmm.html',
          searchPlaceholder: 'စေတီများ ရှာဖွေရန်...'
        }
      : {
          home: '/index.html',
          map: '/map.html',
          pagodas: '/pagodas.html',
          searchPlaceholder: 'Search pagodas...'
        };

    function updateAnchors(container) {
      if (!container) return;
      const anchors = container.querySelectorAll('a');
      anchors.forEach((a) => {
        const text = (a.textContent || '').trim();
        let href = (a.getAttribute('href') || '').trim();
        // Match by known English/MM labels and update hrefs
        if (/^Home$|ပင်မစာမျက်နှာ/.test(text)) a.setAttribute('href', targets.home);
        if (/^Map$|မြေပုံး|မြေပုံ/.test(text)) a.setAttribute('href', targets.map);
        if (/^Pagodas$|စေတီများ|ဘုရားများ|စေတီပုထိုးများ/.test(text)) a.setAttribute('href', targets.pagodas);
        // Also rewrite legacy relative links and details/info deep-links
        if (!/^https?:\/\//i.test(href)) {
          if (inMM) {
            if (/^(\.\.\/)?index\.html$/i.test(href)) a.setAttribute('href', targets.home);
            if (/^(\.\.\/)?map\.html$/i.test(href)) a.setAttribute('href', targets.map);
            if (/^(\.\.\/)?pagodas\.html$/i.test(href)) a.setAttribute('href', targets.pagodas);
            // English details -> MM details
            if (/^(\.\.\/)?pagodaDetils\.html\?id=/.test(href)) {
              const id = (href.match(/id=([^&]+)/) || [])[1];
              if (id) a.setAttribute('href', `/mmversion/pagodaDetailsmm.html?id=${id}&mm=1`);
            }
            // MM standalone articles -> prefer MM details when available
            if (/^mmversion\/[a-z0-9-]+mm\.html$/i.test(href)) {
              const id = (href.match(/^mmversion\/([a-z0-9-]+)mm\.html/i) || [])[1];
              if (id) a.setAttribute('href', `/mmversion/pagodaDetailsmm.html?id=${id}&mm=1`);
            }
          } else {
            if (/^(\.\.\/)?mmversion\/indexmm\.html$/i.test(href)) a.setAttribute('href', targets.home);
            if (/^(\.\.\/)?mmversion\/mapmm\.html$/i.test(href)) a.setAttribute('href', targets.map);
            if (/^(\.\.\/)?mmversion\/pagodasmm\.html$/i.test(href)) a.setAttribute('href', targets.pagodas);
            // MM details -> English details
            if (/^(\.\.\/)?mmversion\/pagodaDetailsmm\.html\?id=/.test(href)) {
              const id = (href.match(/id=([^&]+)/) || [])[1];
              if (id) a.setAttribute('href', `/pagodaDetils.html?id=${id}`);
            }
          }
        }
      });
    }

    updateAnchors(headerNav);
    updateAnchors(drawer);
    updateAnchors(breadcrumb);

    const searchInput = document.getElementById('navSearch');
    if (searchInput && !searchInput.getAttribute('data-i18n-fixed')) {
      searchInput.placeholder = targets.searchPlaceholder;
      searchInput.setAttribute('data-i18n-fixed', 'true');
    }
    
    // Force language toggle to show correct state
    const langToggle = document.querySelector('.lang-toggle');
    if (langToggle) {
      langToggle.textContent = inMM ? 'EN' : 'MM';
      langToggle.setAttribute('aria-label', inMM ? 'Switch to English' : 'မြန်မာဘာသာသို့ ပြောင်းရန်');
    }
  };
})();

// Ensure a consistent breadcrumb shell and styles across pages (especially MM pages)
(function () {
  function isMyanmarPage(pathname) {
    const file = (pathname.split('/').pop() || '').toLowerCase();
    return pathname.includes('/mmversion/') || /mm\.html$/i.test(file) || /indexmm\.html$/i.test(file);
  }

  window.ensureBreadcrumbShell = function ensureBreadcrumbShell() {
    const inMM = isMyanmarPage(window.location.pathname);
    // If a breadcrumb exists, ensure it has the expected id/class
    let bc = document.getElementById('breadcrumb');
    if (!bc) {
      bc = document.querySelector('.breadcrumb');
      if (bc) bc.id = 'breadcrumb';
    }
    if (!bc) {
      // Create a minimal breadcrumb just under the header
      const el = document.createElement('div');
      el.className = 'breadcrumb';
      el.id = 'breadcrumb';
      el.innerHTML = `
        <a href="${inMM ? '/mmversion/indexmm.html' : '/index.html'}">${inMM ? 'ပင်မစာမျက်နှာ' : 'Home'}</a>
        <span> / </span>
        <a href="${inMM ? '/mmversion/pagodasmm.html' : '/pagodas.html'}">${inMM ? 'စေတီများ' : 'Pagodas'}</a>
      `;
      const anchor = document.querySelector('main, .container, body');
      if (anchor && anchor.parentNode) {
        anchor.parentNode.insertBefore(el, anchor);
      } else {
        document.body.insertBefore(el, document.body.children[1] || null);
      }
    }
  };
})();

