// Pagoda Details Page - Handles individual pagoda detail display
// This file contains all the logic that was previously inline in pagodaDetils.html

let pagodaMap = null;

// Determine if this details page should render Myanmar content
function isMyanmarContext() {
  try {
    const p = (window.location.pathname || '').toLowerCase();
    const file = (p.split('/').pop() || '');
    const q = new URLSearchParams(window.location.search);
    return p.includes('/mmversion/') || /mm\.html$/i.test(file) || /indexmm\.html$/i.test(file) || q.get('mm') === '1';
  } catch (_) { return false; }
}

// Normalize asset paths when the current page lives under `mmversion/`
// Some datasets use "./assets/..." which is correct for EN pages at the root,
// but MM pages are one level deeper, so we need to prefix with "../".
function normalizeAssetUrl(url) {
  try {
    if (!url) return url;
    const inMM = isMyanmarContext();
    // Already absolute root or already corrected
    if (!inMM || url.startsWith('/') || url.startsWith('../')) return url;
    if (url.startsWith('./assets/')) return url.replace('./', '../');
    return url;
  } catch (_) {
    return url;
  }
}

// Dynamically load a script if needed
function loadScriptOnce(src) {
  return new Promise((resolve, reject) => {
    try {
      // Already loaded?
      const existing = Array.from(document.getElementsByTagName('script')).some((s) => (s.getAttribute('src') || '').includes(src));
      if (existing) { resolve(); return; }
      const el = document.createElement('script');
      el.src = src;
      el.async = true;
      el.onload = () => resolve();
      el.onerror = (e) => reject(e);
      document.head.appendChild(el);
    } catch (e) { reject(e); }
  });
}

// Get pagoda ID from URL parameter
function getPagodaIdFromUrl() {
  const urlParams = new URLSearchParams(window.location.search);
  const raw = urlParams.get("id");
  return raw ? String(raw).trim() : null;
}

// Fast path: fetch a single pagoda directly from API and normalize result
async function fetchPagodaById(id) {
  try {
    const res = await fetch(`/api/pagodas/${encodeURIComponent(id)}`, {
      headers: { Accept: 'application/json' },
      credentials: 'include'
    });
    if (!res.ok) return null;
    const json = await res.json();
    if (!json || !json.success || !json.data) return null;
    const p = json.data;
    // Normalize critical fields the same way the manager does
    const images = (function() {
      const imgs = p.images || {};
      const main = imgs.main || './assets/images/placeholder-pagoda.jpg';
      return {
        main,
        thumbnail: imgs.thumbnail || main,
        gallery: Array.isArray(imgs.gallery) ? imgs.gallery : []
      };
    })();
    const description = (function() {
      if (typeof p.description === 'string') {
        return { short: p.description, long: p.description };
      }
      const d = p.description || {};
      return {
        short: d.short || 'A beautiful temple in Bagan.',
        long:
          d.long ||
          'A beautiful temple in Bagan with rich historical significance.'
      };
    })();
    const normalized = { ...p, images, description };
    // Cache by id for local use on details pages without mutating manager
    if (!window.__apiPagodaById) window.__apiPagodaById = {};
    window.__apiPagodaById[id] = normalized;
    return normalized;
  } catch (_) {
    return null;
  }
}

// Fetch all pagodas quickly (for nearest computation) and normalize minimal fields
async function fetchAllPagodas() {
  try {
    const res = await fetch('/api/pagodas', { headers: { Accept: 'application/json' }, credentials: 'include' });
    if (!res.ok) return [];
    const json = await res.json();
    if (!json || !json.success || !Array.isArray(json.data)) return [];
    return json.data.map((p) => {
      const imgs = p.images || {};
      const main = imgs.main || './assets/images/placeholder-pagoda.jpg';
      const desc = typeof p.description === 'string' ? { short: p.description, long: p.description } : (p.description || {});
      return {
        ...p,
        images: { main, thumbnail: imgs.thumbnail || main, gallery: Array.isArray(imgs.gallery) ? imgs.gallery : [] },
        description: { short: desc.short || '', long: desc.long || '' }
      };
    });
  } catch (_) {
    return [];
  }
}

// Initialize map for pagoda location
function initializePagodaMap(pagoda) {
  // Default to Bagan if coordinates are missing entirely
  if (!pagoda) pagoda = {};
  if (!pagoda.location) pagoda.location = {};
  if (!pagoda.location.coordinates) pagoda.location.coordinates = {};

  let { lat, lng } = pagoda.location.coordinates;
  // Coerce string coordinates to numbers to avoid using fallback
  if (typeof lat === 'string') lat = parseFloat(lat);
  if (typeof lng === 'string') lng = parseFloat(lng);
  const hasValidCoords =
    typeof lat === "number" && isFinite(lat) && typeof lng === "number" && isFinite(lng);
  if (!hasValidCoords) {
    console.warn("Invalid coordinates for pagoda", pagoda.id, lat, lng);
    // Fallback: center on Bagan
    lat = 21.171; // Bagan approximate
    lng = 94.86;
  }

  // Initialize the map
  // Ensure container has a height (in case CSS failed)
  const mapEl = document.getElementById('pagodaMap');
  if (mapEl && (!mapEl.style.height || mapEl.clientHeight === 0)) {
    mapEl.style.height = '400px';
  }
  // If a map instance already exists on this container, remove it to avoid
  // "Map container is already initialized" errors when re-rendering details
  if (pagodaMap && typeof pagodaMap.remove === 'function') {
    try { pagodaMap.remove(); } catch (_) {}
    pagodaMap = null;
  }
  // Leaflet may have attached an internal id to the container; clear it
  if (mapEl && mapEl._leaflet_id) {
    try { delete mapEl._leaflet_id; } catch (_) {}
  }
  pagodaMap = L.map("pagodaMap", { zoomControl: true, attributionControl: true }).setView([lat, lng], 15);

  // Add tile layer
  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    attribution:
      '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    maxZoom: 18,
  }).addTo(pagodaMap);

  // Add marker for the current pagoda
  const marker = L.marker([lat, lng]).addTo(pagodaMap);

  // Add popup with pagoda information
  const popupContent = `
    <div style="text-align:center; padding: 5px;">
      <img src="${pagoda.images.main}" alt="${pagoda.name}" style="width:120px; height:auto; border-radius:8px; box-shadow:0 0 6px rgba(0,0,0,0.2); margin-bottom: 8px; object-fit: cover;"><br>
      <strong style="font-size: 1.1em; color: #aa7739;">${pagoda.name}</strong><br>
      <p style="font-size: 0.9em; color: #555; margin: 5px 0;">${pagoda.description.short}</p>
    </div>
  `;

  marker.bindPopup(popupContent).openPopup();

  // Invalidate map size to ensure proper rendering
  setTimeout(() => {
    try { pagodaMap.invalidateSize(); } catch (_) {}
  }, 150);
}

// Load and display pagoda details
function loadPagodaDetails() {
  const pagodaId = getPagodaIdFromUrl();

  if (!pagodaId || !window.pagodaManager) {
    showError("Pagoda not found");
    return;
  }

  // Prefer manager data on MM pages; otherwise allow API fast-path
  const inMMFlag = isMyanmarContext();
  const managerFirst = inMMFlag && window.pagodaManager && typeof window.pagodaManager.getPagoda === 'function';
  let pagoda = managerFirst ? window.pagodaManager.getPagoda(pagodaId) : null;
  if (!pagoda) {
    pagoda = (window.__apiPagodaById && window.__apiPagodaById[pagodaId])
      ? window.__apiPagodaById[pagodaId]
      : (window.pagodaManager && window.pagodaManager.getPagoda ? window.pagodaManager.getPagoda(pagodaId) : null);
  }
  if (!pagoda && window.pagodaManager && Array.isArray(window.pagodaManager.pagodas)) {
    const idLower = pagodaId.toLowerCase();
    pagoda = window.pagodaManager.pagodas.find((p) => (p.id || '').toLowerCase() === idLower);
  }

  if (!pagoda) {
    // Create a minimal placeholder so the page still functions
    pagoda = {
      id: pagodaId,
      name: pagodaId,
      description: { short: '', long: '' },
      images: { main: './assets/images/placeholder-pagoda.jpg', thumbnail: './assets/images/placeholder-pagoda.jpg' },
      location: { city: 'Bagan', country: 'Myanmar', coordinates: { lat: 21.171, lng: 94.86 } },
      distances: {}
    };
  }


  // On MM pages, overlay MM fields from manager onto API object if present
  if (inMMFlag && window.pagodaManager && typeof window.pagodaManager.getPagoda === 'function') {
    const mm = window.pagodaManager.getPagoda(pagodaId);
    if (mm) {
      if (mm.name) pagoda.name = mm.name;
      if (mm.description) {
        const dApi = typeof pagoda.description === 'string' ? { short: pagoda.description, long: pagoda.description } : (pagoda.description || {});
        const dMm = typeof mm.description === 'string' ? { short: mm.description, long: mm.description } : (mm.description || {});
        pagoda.description = { short: dMm.short || dApi.short || '', long: dMm.long || dApi.long || '' };
      }
    }
  }
  // Also overlay directly from MM dataset if available (in case manager is EN only)
  if (inMMFlag && window.PAGODA_DATABASE_MM && Array.isArray(window.PAGODA_DATABASE_MM.pagodas)) {
    const mm2 = window.PAGODA_DATABASE_MM.pagodas.find((p) => (p.id || '') === pagodaId);
    if (mm2) {
      if (mm2.name) pagoda.name = mm2.name;
      if (mm2.description) {
        const dApi = typeof pagoda.description === 'string' ? { short: pagoda.description, long: pagoda.description } : (pagoda.description || {});
        const dMm = typeof mm2.description === 'string' ? { short: mm2.description, long: mm2.description } : (mm2.description || {});
        pagoda.description = { short: dMm.short || dApi.short || '', long: dMm.long || dApi.long || '' };
      }
    }
  }

  // Update page title
  document.title = inMMFlag ? `Baganetic - ${pagoda.name}` : `Baganetic - ${pagoda.name} Details`;

  // Update breadcrumb
  document.getElementById("breadcrumbPagoda").textContent = pagoda.name;
  // Normalize breadcrumb links for correct language routing
  (function normalizeBreadcrumb() {
    try {
      const bc = document.getElementById('breadcrumb');
      if (!bc) return;
      const anchors = bc.querySelectorAll('a');
      const inMM = isMyanmarContext();
      anchors.forEach((a) => {
        const txt = (a.textContent || '').trim();
        if (inMM) {
          if (/ပင်မစာမျက်နှာ/.test(txt)) a.setAttribute('href', '/mmversion/indexmm.html');
          if (/စေတီများ|ဘုရားများ|စေတီပုထိုးများ/.test(txt)) a.setAttribute('href', '/mmversion/pagodasmm.html');
        } else {
          if (/^Home$/.test(txt)) a.setAttribute('href', '/index.html');
          if (/^Pagodas$/.test(txt)) a.setAttribute('href', '/pagodas.html');
        }
      });
    } catch (_) {}
  })();

  // Update main title
  document.getElementById("pagodaTitle").textContent = pagoda.name;

  // Update image with fallback
  const pagodaImage = document.getElementById("pagodaImage");
  const mainImg = (pagoda.images && (pagoda.images.main || pagoda.images.thumbnail)) || "./assets/images/placeholder-pagoda.jpg";
  const normalizedMainImg = normalizeAssetUrl(mainImg);
  // Also normalize on the object so downstream users (map popup) get a valid path
  if (pagoda.images) pagoda.images.main = normalizedMainImg;
  pagodaImage.src = normalizedMainImg;
  pagodaImage.alt = `${pagoda.name} photo`;
  pagodaImage.onerror = function () {
    this.onerror = null;
    this.src = normalizeAssetUrl("./assets/images/placeholder-pagoda.jpg");
  };

  // Set description and configure Explore Detail link
  const descriptionEl = document.getElementById("pagodaDescription");
  // Handle description stored as object or as plain string
  let descText = '';
  if (pagoda.description) {
    if (typeof pagoda.description === 'string') {
      descText = pagoda.description;
    } else {
      descText = pagoda.description.long || pagoda.description.short || '';
    }
  }
  if (!descText || descText.trim() === '') {
    descText = inMMFlag ? 'ဤစေတီအား အသေးစိတ်အချက်အလက် မရှိသေးပါ။' : 'No detailed description available for this pagoda yet.';
  }
  descriptionEl.textContent = descText;

  const exploreBtn = document.getElementById("exploreDetailBtn");
  // On the details page, we may want to deep-link to a richer standalone article
  // without affecting how the list cards navigate. Provide per-id overrides here.
  // Check if we're on a Myanmar page and prefer MM detail pages
  const isMyanmarPage = () => {
    const p = (window.location.pathname || '').toLowerCase();
    const file = (p.split('/').pop() || '');
    return p.includes('/mmversion/') || /mm\.html$/i.test(file) || /indexmm\.html$/i.test(file);
  };
  
  const detailsPageOverrides = { thatbinnyu: inMMFlag ? '/mmversion/thatbinnyumm.html' : 'thatbinnyu.html' };
  const preferred = (pagoda.detailPage && pagoda.detailPage.trim());
  let detailUrl = detailsPageOverrides[pagoda.id] || preferred || (inMMFlag ? `/mmversion/pagodaDetailsmm.html?id=${pagoda.id}&mm=1` : `pagodaDetils.html?id=${pagoda.id}`);
  
  async function resolveDetailUrl() {
    const inMM = isMyanmarPage();
    
    if (inMM) {
      // Prefer a richer standalone MM article when available; otherwise fall back to canonical MM details
      const mmArticle = `/mmversion/${pagoda.id}mm.html`;
      try {
        const res = await fetch(mmArticle, { method: 'HEAD' });
        if (res.ok) {
          detailUrl = mmArticle;
          setExploreTarget(detailUrl);
          return;
        }
      } catch (_) { /* ignore and fall back */ }
      detailUrl = `/mmversion/pagodaDetailsmm.html?id=${pagoda.id}&mm=1`;
      setExploreTarget(detailUrl);
      return;
    }
    
    if (!preferred && !detailsPageOverrides[pagoda.id]) {
      try {
        const candidate = `${pagoda.id}.html`;
        const res = await fetch(candidate, { method: 'HEAD' });
        if (res.ok) {
          detailUrl = candidate;
        }
      } catch (_) {
        // ignore, keep fallback
      }
    }
    setExploreTarget(detailUrl);
  }
  
  let targetUrl = detailUrl;
  
  function setExploreTarget(url) {
    // Set the href for display purposes
    exploreBtn.href = url;
    // Remove any existing event listeners that might interfere
    exploreBtn.onclick = null;
    // Add a click handler to ensure navigation works
    exploreBtn.addEventListener('click', function(e) {
      e.preventDefault();
      window.location.href = url;
    });
  }
  // Apply now and also attempt to upgrade via HEAD check
  setExploreTarget(targetUrl);
  resolveDetailUrl();
  
  exploreBtn.style.display = "";

  // Initialize map with pagoda location (now safe with fallbacks)
  initializePagodaMap(pagoda);

  // Load nearest pagodas
  renderNearestPagodas(pagoda);
}

// Render nearest pagodas
async function renderNearestPagodas(currentPagoda) {
  const container = document.getElementById("nearest-pagodas");
  container.innerHTML = "";

  if (!currentPagoda || !window.pagodaManager) {
    // Try fetching from API directly if manager isn't ready
    if (currentPagoda) {
      fetchAllPagodas().then((list) => {
        if (Array.isArray(list) && list.length > 1) {
          const origin = currentPagoda.location?.coordinates;
          const nearest = list
            .filter((p) => p.id !== currentPagoda.id && p.location && p.location.coordinates && typeof p.location.coordinates.lat === 'number' && typeof p.location.coordinates.lng === 'number')
            .map((p) => ({
              id: p.id,
              name: p.name,
              thumbnail: (p.images && (p.images.thumbnail || p.images.main)) || './assets/images/placeholder-pagoda.jpg',
              distance: haversineKm(origin.lat, origin.lng, p.location.coordinates.lat, p.location.coordinates.lng)
            }))
            .sort((a, b) => a.distance - b.distance)
            .slice(0, 8);
          if (nearest.length) {
            container.innerHTML = '';
            const overrides = { ananda: '/ananda.html', mahazedi: '/mahazedi.html', shwegugyi: '/shwegugyi.html' };
            nearest.forEach((p) => {
              const url = `/pagodaDetils.html?id=${p.id}`;
              const thumb = normalizeAssetUrl(p.thumbnail);
              const card = document.createElement('article');
              card.className = 'recommend-card';
              card.innerHTML = `
                <a href="${overrides[p.id] || url}" aria-label="Open ${p.name} details" style="text-decoration:none;color:inherit;display:block">
                  <img src="${thumb}" alt="${p.name} photo" loading="lazy">
                  <h3>${p.name}</h3>
                  <p>${(p.distance ?? 0).toFixed(1)} km away</p>
                </a>
                <div style=\"margin-top:8px\">
                  <a href="${overrides[p.id] || url}" class="read-more" id="readMoreBtn_${p.id}">${isMyanmarContext() ? 'ပိုမိုဖတ်ရှုရန်' : 'Read more'}</a>
                </div>`;
              container.appendChild(card);
            });
            return;
          }
        }
        container.innerHTML = "<p>No nearby pagodas found.</p>";
      });
      return;
    } else {
      container.innerHTML = "<p>No nearby pagodas found.</p>";
      return;
    }
  }

  try {
    const inMM = isMyanmarContext();
    const usePrecomputed =
      window.pagodaManager &&
      window.pagodaManager.data &&
      window.pagodaManager.data.utils &&
      typeof window.pagodaManager.data.utils.getNearestPagodas === "function" &&
      currentPagoda &&
      currentPagoda.distances &&
      Object.keys(currentPagoda.distances).length > 0;

    let nearestPagodas = [];
    if (usePrecomputed) {
      nearestPagodas = window.pagodaManager.data.utils.getNearestPagodas(
        currentPagoda.id,
        8
      );
    } else {
      // Compute using Haversine distance on the fly; if manager has only this pagoda, augment from API
      let list = (
        window.pagodaManager && typeof window.pagodaManager.getAllPagodas === 'function'
          ? window.pagodaManager.getAllPagodas()
          : window.pagodaManager && Array.isArray(window.pagodaManager.pagodas)
            ? window.pagodaManager.pagodas
            : (window.PAGODA_DATABASE && Array.isArray(window.PAGODA_DATABASE.pagodas) ? window.PAGODA_DATABASE.pagodas : [])
      );
      if (!list || list.length <= 1) {
        list = await fetchAllPagodas();
      }
      // Normalize coordinate helpers
      const toNum = (v) => (typeof v === 'string' ? parseFloat(v) : v);
      const isValidNum = (n) => typeof n === 'number' && isFinite(n);
      const originRaw = currentPagoda.location?.coordinates || {};
      const origin = { lat: toNum(originRaw.lat), lng: toNum(originRaw.lng) };
      if (!isValidNum(origin.lat) || !isValidNum(origin.lng)) {
        container.innerHTML = "<p>No nearby pagodas found.</p>";
        return;
      }
      nearestPagodas = list
        .filter((p) => p && p.id !== currentPagoda.id && p.location && p.location.coordinates)
        .map((p) => {
          const c = p.location.coordinates;
          const lat = toNum(c.lat);
          const lng = toNum(c.lng);
          if (!isValidNum(lat) || !isValidNum(lng)) return null;
          return {
            id: p.id,
            name: p.name,
            thumbnail: (p.images && (p.images.thumbnail || p.images.main)) || './assets/images/placeholder-pagoda.jpg',
            distance: haversineKm(origin.lat, origin.lng, lat, lng)
          };
        })
        .filter(Boolean)
        .sort((a, b) => a.distance - b.distance)
        .slice(0, 8);
    }

    if (!nearestPagodas || nearestPagodas.length === 0) {
      container.innerHTML = "<p>No nearby pagodas found.</p>";
      return;
    }

    const overrides = inMM ? {} : { ananda: '/ananda.html', mahazedi: '/mahazedi.html', shwegugyi: '/shwegugyi.html' };
    const getMMName = (id, fallback) => {
      if (!inMM || !window.PAGODA_DATABASE_MM) return fallback;
      const rec = (window.PAGODA_DATABASE_MM.pagodas || []).find(p => p.id === id);
      return (rec && rec.name) || fallback;
    };
    nearestPagodas.forEach((p) => {
      const nearestData = (window.pagodaManager && window.pagodaManager.getPagoda(p.id)) || { id: p.id };
      const preferred = (nearestData.detailPage && nearestData.detailPage.trim()) || overrides[p.id];
      const url = preferred || `${inMM ? '/mmversion/pagodaDetailsmm.html?id=' : '/pagodaDetils.html?id='}${p.id}${inMM ? '&mm=1' : ''}`;
      const card = document.createElement("article");
      card.className = "recommend-card";
      card.innerHTML = `
        <a href="${url}" aria-label="Open ${p.name} details" style="text-decoration:none;color:inherit;display:block">
          <img src="${normalizeAssetUrl(p.thumbnail)}" alt="${p.name} photo" loading="lazy">
          <h3>${getMMName(p.id, p.name)}</h3>
          <p>${(p.distance ?? 0).toFixed(1)} ${inMM ? 'ကီလိုမီတာ အကွာ' : 'km away'}</p>
        </a>
        <div style=\"margin-top:8px\">
          <a href="${url}" class="read-more" id="readMoreBtn_${p.id}">${inMM ? 'ပိုမိုဖတ်ရှုရန်' : 'Read more'}</a>
        </div>
      `;

      container.appendChild(card);
    });
  } catch (error) {
    console.error("Error loading nearest pagodas:", error);
    container.innerHTML = "<p>Error loading nearby pagodas.</p>";
  }
}

// Haversine distance calculator (km)
function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371; // km
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// Show error message
function showError(message) {
  document.getElementById("pagodaTitle").textContent = "Error";
  document.getElementById("pagodaDescription").textContent = message;
  document.getElementById("breadcrumbPagoda").textContent = "Error";
}

// Initialize when DOM is ready
document.addEventListener("DOMContentLoaded", () => {
  let timeoutId;
  let retryCount = 0;
  const maxRetries = 50; // 5 seconds max

  // Wait for PagodaManager to be ready to avoid "Pagoda not found" race conditions
  const tryLoad = () => {
    const pagodaId = getPagodaIdFromUrl();
    const managerReady =
      typeof window.pagodaManager !== "undefined" &&
      Array.isArray(window.pagodaManager.pagodas) &&
      window.pagodaManager.pagodas.length > 0;

    if (pagodaId) {
      // Kick off a fast single-record fetch in parallel. If it returns, render immediately.
      fetchPagodaById(pagodaId).then((p) => {
        if (p) {
          // Ensure a minimal manager exists, but don't override its methods
          if (!window.pagodaManager) {
            window.pagodaManager = { getPagoda: (id) => (window.__apiPagodaById ? window.__apiPagodaById[id] : null), pagodas: [p], data: {} };
          }
          // Render or re-render immediately with authoritative API data for this id
          clearTimeout(timeoutId);
          if (!window.__pagodaRendered) {
            window.__pagodaRendered = true;
            loadPagodaDetails();
          } else {
            // If already rendered, update description/image quickly
            loadPagodaDetails();
          }
        }
      });
    }

    if (managerReady && pagodaId && !window.__pagodaRendered) {
      clearTimeout(timeoutId);
      window.__pagodaRendered = true;
      loadPagodaDetails();
    } else if (retryCount < maxRetries && !window.__pagodaRendered) {
      // As a fallback, if database manager isn't ready yet but static data exists, set up a lightweight manager
      if (
        !window.pagodaManager &&
        window.PAGODA_DATABASE &&
        Array.isArray(window.PAGODA_DATABASE.pagodas)
      ) {
        window.pagodaManager = {
          pagodas: window.PAGODA_DATABASE.pagodas,
          getPagoda: (id) =>
            window.PAGODA_DATABASE.pagodas.find((p) => p.id === id),
          data: window.PAGODA_DATABASE,
        };
      }
      retryCount++;
      timeoutId = setTimeout(tryLoad, 100);
    } else {
      console.warn("PagodaManager loading timeout - trying to load anyway");
      // Ensure a minimal manager exists so map fallback can still render
      if (!window.pagodaManager && window.PAGODA_DATABASE) {
        window.pagodaManager = {
          pagodas: window.PAGODA_DATABASE.pagodas || [],
          getPagoda: (id) =>
            (window.PAGODA_DATABASE.pagodas || []).find((p) => p.id === id),
          data: window.PAGODA_DATABASE,
        };
      }
      if (!window.__pagodaRendered) {
        window.__pagodaRendered = true;
        loadPagodaDetails();
      }
    }
  };

  tryLoad();
});
