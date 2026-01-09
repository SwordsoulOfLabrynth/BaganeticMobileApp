// Pagoda Loader - Handles loading and displaying pagoda data on the homepage
// This file contains all the logic that was previously inline in index.html

// Build a grid-based Famous Pagodas section with a large featured card
function isMyanmarPage() {
  const p = (window.location.pathname || '').toLowerCase();
  const file = (p.split('/').pop() || '');
  return p.includes('/mmversion/') || /mm\.html$/i.test(file) || /indexmm\.html$/i.test(file);
}

function buildDetailUrlForContext(pagodaId) {
  const inMM = isMyanmarPage();
  if (inMM) {
    // Route to canonical MM details page to ensure consistent breadcrumbs/navigation
    return `/mmversion/pagodaDetailsmm.html?id=${pagodaId}&mm=1`;
  }
  return `pagodaDetils.html?id=${pagodaId}`;
}
function createGridCard(pagoda) {
  const card = document.createElement("div");
  card.className = "pagoda-card";

  const imageUrl =
    pagoda.images && pagoda.images.main
      ? pagoda.images.main
      : "./assets/images/placeholder-pagoda.jpg";

  const pagodaName = pagoda.name || "Unknown Pagoda";
  const pagodaType = pagoda.type || "Temple";
  const pagodaCity =
    pagoda.location && pagoda.location.city ? pagoda.location.city : "Bagan";
  const pagodaCountry =
    pagoda.location && pagoda.location.country
      ? pagoda.location.country
      : "Myanmar";
  const pagodaDescription =
    pagoda.description && pagoda.description.short
      ? pagoda.description.short
      : "A beautiful temple in Bagan with rich historical significance.";
  const pagodaBuilt =
    pagoda.history && pagoda.history.built ? pagoda.history.built : "Unknown";
  const pagodaTags =
    pagoda.tags && Array.isArray(pagoda.tags)
      ? pagoda.tags.slice(0, 3)
      : ["temple", "historic", "bagan"];

  card.innerHTML = `
    <div class="pagoda-image">
      <img src="${imageUrl}" alt="${pagodaName}" loading="lazy" onerror="this.src='./assets/images/placeholder-pagoda.jpg'">
      <span class="pagoda-type">${pagodaType}</span>
    </div>
    <div class="pagoda-content">
      <h3 class="pagoda-name">${pagodaName}</h3>
      <p class="pagoda-location">📍 ${pagodaCity}, ${pagodaCountry}</p>
      <p class="pagoda-description">${pagodaDescription}</p>
      <div class="pagoda-meta">
        <span class="pagoda-built">Built: ${pagodaBuilt}</span>
      </div>
      <div class="pagoda-tags">
        ${pagodaTags.map((tag) => `<span class="tag">${tag}</span>`).join("")}
      </div>
    </div>
  `;

  card.addEventListener("click", function () {
    const pagodaId = pagoda.id || "unknown";
    const target = buildDetailUrlForContext(pagodaId);
    window.location.href = target;
  });

  return card;
}

function renderFeatured(pagoda) {
  const container = document.getElementById("featuredPagoda");
  if (!container) return;

  const imageUrl =
    pagoda.images && pagoda.images.main
      ? pagoda.images.main
      : "./assets/images/placeholder-pagoda.jpg";

  const pagodaName = pagoda.name || "Unknown Pagoda";
  const pagodaCity =
    pagoda.location && pagoda.location.city ? pagoda.location.city : "Bagan";
  const pagodaCountry =
    pagoda.location && pagoda.location.country
      ? pagoda.location.country
      : "Myanmar";
  const pagodaDescription =
    pagoda.description && pagoda.description.long
      ? pagoda.description.long
      : (pagoda.description && pagoda.description.short) ||
        "A beautiful temple in Bagan with rich historical significance.";
  const pagodaBuilt =
    pagoda.history && pagoda.history.built ? pagoda.history.built : "Unknown";

  const inMM = isMyanmarPage();
  container.innerHTML = `
    <div class="featured-card">
      <img src="${imageUrl}" alt="${pagodaName}" loading="lazy" 
           onerror="this.onerror=null; this.src='./assets/images/placeholder-pagoda.jpg';">
      <div class="featured-overlay"></div>
      <div class="featured-content">
        <span class="featured-badge">${inMM ? 'အထူးဖော်ပြချက်' : 'Featured'}</span>
        <h3 class="featured-title">${pagodaName}</h3>
        <div class="featured-meta">📍 ${pagodaCity}, ${pagodaCountry} • ${inMM ? 'တည်ဆောက်သည့်ခုနှစ်' : 'Built'}: ${pagodaBuilt}</div>
        <p class="featured-description">${pagodaDescription}</p>
        <div class="featured-actions">
          <a href="${buildDetailUrlForContext(pagoda.id || 'unknown')}" class="cta-button">${inMM ? 'အသေးစိတ်ကြည့်ရန်' : 'View Details'}</a>
          <a href="${inMM ? 'mmversion/mapmm.html' : 'map.html'}" class="cta-button secondary">${inMM ? 'မြေပုံတွင်ကြည့်ရန်' : 'View on Map'}</a>
        </div>
      </div>
    </div>
  `;
}

async function loadFamousPagodas() {
  console.log("🔄 loadFamousPagodas called");
  console.log("📊 window.pagodaManager:", window.pagodaManager);
  console.log("📊 window.PAGODA_DATABASE:", window.PAGODA_DATABASE);

  // Try to load featured pagodas from API first (dynamic)
  if (window.apiClient) {
    try {
      console.log("🌐 Attempting to load featured pagodas from API...");
      const apiFeaturedPagodas = await window.apiClient.getFeaturedPagodas();
      
      if (apiFeaturedPagodas && apiFeaturedPagodas.length > 0) {
        console.log("✅ Loaded featured pagodas from API:", apiFeaturedPagodas.length);
        
        // If we're on a Myanmar page, apply Myanmar translations
        if (isMyanmarPage() && window.PAGODA_DATABASE_MM) {
          const mm = (window.PAGODA_DATABASE_MM && window.PAGODA_DATABASE_MM.pagodas) || [];
          const mmById = Object.create(null);
          mm.forEach(p => { if (p && p.id) mmById[p.id] = p; });
          
          // Apply Myanmar translations to API data
          const featuredWithTranslations = apiFeaturedPagodas.map(pagoda => {
            const mmTranslation = mmById[pagoda.id];
            if (mmTranslation) {
              return {
                ...pagoda,
                name: mmTranslation.name || pagoda.name,
                description: {
                  short: mmTranslation.description?.short || pagoda.description?.short,
                  long: mmTranslation.description?.long || pagoda.description?.long
                },
                type: mmTranslation.type || pagoda.type,
                location: {
                  ...pagoda.location,
                  city: mmTranslation.location?.city || pagoda.location?.city,
                  country: mmTranslation.location?.country || pagoda.location?.country
                }
              };
            }
            return pagoda;
          });
          
          console.log("🏛️ Myanmar Featured Pagodas from API:", featuredWithTranslations.length);
          renderFeaturedPagodas(featuredWithTranslations);
          return;
        } else {
          // English page - use API data directly
          renderFeaturedPagodas(apiFeaturedPagodas);
          return;
        }
      }
    } catch (error) {
      console.warn("⚠️ Failed to load from API, falling back to static data:", error);
    }
  }

  // Fallback to static data
  console.log("📚 Falling back to static data...");
  
  // Check if we're on a Myanmar page and ensure Myanmar manager is active
  if (isMyanmarPage() && window.PAGODA_DATABASE_MM) {
    if (!window.pagodaManager || !window.pagodaManager.isMyanmar) {
      console.log("🔄 Re-establishing Myanmar Pagoda Manager in loader");
      // Re-create Myanmar manager
      const mm = (window.PAGODA_DATABASE_MM && window.PAGODA_DATABASE_MM.pagodas) || [];
      const en = (window.PAGODA_DATABASE && window.PAGODA_DATABASE.pagodas) || [];
      
      // Build maps for quick lookup
      const enById = Object.create(null);
      en.forEach(p => { if (p && p.id) enById[p.id] = p; });
      const mmById = Object.create(null);
      mm.forEach(p => { if (p && p.id) mmById[p.id] = p; });

      // Merge: union of EN ids; overlay MM fields when available.
      const merged = Object.keys(enById).map((id) => {
        const base = enById[id];
        const overlay = mmById[id] || {};
        const pick = (a, b) => (typeof a !== 'undefined' ? a : b);
        const mergeObj = (a = {}, b = {}) => ({ ...b, ...a }); // prefer a (MM) over b (EN)

        return {
          id,
          name: pick(overlay.name, base.name),
          shortName: pick(overlay.shortName, base.shortName),
          type: pick(overlay.type, base.type),
          location: mergeObj(overlay.location, base.location),
          images: mergeObj(overlay.images, base.images),
          description: mergeObj(overlay.description, base.description),
          history: mergeObj(overlay.history, base.history),
          architecture: mergeObj(overlay.architecture, base.architecture),
          religious: mergeObj(overlay.religious, base.religious),
          visiting: mergeObj(overlay.visiting, base.visiting),
          tags: Array.isArray(overlay.tags) && overlay.tags.length ? overlay.tags : (base.tags || []),
          status: pick(overlay.status, base.status),
          featured: base.featured, // Always use the English featured status
          distances: mergeObj(overlay.distances, base.distances),
          detailPage: pick(overlay.detailPage, base.detailPage)
        };
      });

      // If MM contains any extra ids that aren't in EN, append them
      Object.keys(mmById).forEach((id) => {
        if (!enById[id]) merged.push(mmById[id]);
      });

      // Create Myanmar manager
      window.pagodaManager = {
        pagodas: merged,
        data: { ...window.PAGODA_DATABASE, pagodas: merged, utils: (window.PAGODA_DATABASE && window.PAGODA_DATABASE.utils) },
        isMyanmar: true,
        getAllPagodas() { return this.pagodas; },
        getPagoda(id) {
          if (!id) return undefined;
          const target = String(id).toLowerCase();
          return this.pagodas.find(p => (p.id || '').toLowerCase() === target);
        },
        search(query) {
          if (!query || query.trim() === '') return this.pagodas;
          const searchTerm = query.toLowerCase().trim();
          return this.pagodas.filter(pagoda => {
            return (
              pagoda.name.toLowerCase().includes(searchTerm) ||
              (pagoda.description && pagoda.description.short && pagoda.description.short.toLowerCase().includes(searchTerm)) ||
              (pagoda.description && pagoda.description.long && pagoda.description.long.toLowerCase().includes(searchTerm)) ||
              (pagoda.type && pagoda.type.toLowerCase().includes(searchTerm)) ||
              (pagoda.location && pagoda.location.city && pagoda.location.city.toLowerCase().includes(searchTerm))
            );
          });
        },
        getFeaturedPagodas() {
          const featured = this.pagodas.filter(pagoda => pagoda.featured === true);
          console.log('🏛️ Myanmar Featured Pagodas:', featured.length, 'out of', this.pagodas.length);
          console.log('🏛️ Featured pagodas:', featured.map(p => ({ id: p.id, name: p.name, featured: p.featured })));
          return featured;
        }
      };
      
      window.PAGODA_DATABASE = window.pagodaManager.data;
    }
  }

  if (!window.pagodaManager) {
    console.log("⏳ PagodaManager not ready, retrying...");
    setTimeout(loadFamousPagodas, 100);
    return;
  }

  const featuredPagodas = window.pagodaManager.getFeaturedPagodas();
  console.log("🏛️ Featured pagodas:", featuredPagodas);
  console.log("🏛️ Featured pagodas count:", featuredPagodas.length);
  console.log("🏛️ Is Myanmar page:", isMyanmarPage());
  
  renderFeaturedPagodas(featuredPagodas);
}

function renderFeaturedPagodas(featuredPagodas) {
  const grid = document.getElementById("famousGrid");
  console.log("🎯 Grid element:", grid);

  if (!grid) return;

  if (featuredPagodas && featuredPagodas.length > 0) {
    // Hide the featured section and use full-width grid
    const featuredContainer = document.getElementById("featuredPagoda");
    if (featuredContainer) featuredContainer.style.display = "none";
    const layout = document.querySelector(".famous-layout");
    if (layout) layout.style.gridTemplateColumns = "1fr";

    // Render all featured pagodas instead of a fixed 7
    grid.innerHTML = "";
    featuredPagodas.forEach((pagoda) => {
      grid.appendChild(createGridCard(pagoda));
    });

    if (grid.children.length === 0) {
      const inMM = isMyanmarPage();
      grid.innerHTML = `
        <div class="no-pagodas-message">
          <div class="no-pagodas-icon">🏛️</div>
          <h3>${inMM ? 'အပိုစေတီများ မရှိပါ' : 'No Additional Pagodas'}</h3>
          <p>${inMM ? 'ထူးခြားသော စေတီများကို ရှာဖွေကြည့်ရှုရန် စာရင်းပြည့်စုံကို ကြည့်ပါ။' : 'Explore our full list to discover more remarkable temples.'}</p>
          <a href="${inMM ? 'mmversion/pagodasmm.html' : 'pagodas.html'}" class="cta-button">${inMM ? 'စေတီအားလုံးကြည့်ရန်' : 'View All Pagodas'}</a>
        </div>
      `;
    }
  } else {
    const featuredContainer = document.getElementById("featuredPagoda");
    if (featuredContainer) featuredContainer.style.display = "none";
    const layout = document.querySelector(".famous-layout");
    if (layout) layout.style.gridTemplateColumns = "1fr";
    const inMM2 = isMyanmarPage();
    grid.innerHTML = `
        <div class="no-pagodas-message">
          <div class="no-pagodas-icon">🏛️</div>
          <h3>${inMM2 ? 'ထင်ရှားသော စေတီများ မရှိပါ' : 'No Famous Pagodas Available'}</h3>
          <p>${inMM2 ? 'စေတီအချက်အလက်များကို ပြင်ဆင်နေပါသည်။ နောက်မှ ပြန်လည်စစ်ဆေးပါ။' : "We're currently updating our pagoda database. Please check back soon!"}</p>
          <a href="${inMM2 ? 'mmversion/pagodasmm.html' : 'pagodas.html'}" class="cta-button">${inMM2 ? 'စေတီအားလုံးကြည့်ရန်' : 'View All Pagodas'}</a>
        </div>
      `;
  }
}

// Initialize when DOM is loaded
document.addEventListener("DOMContentLoaded", function () {
  console.log("🎯 DOM Content Loaded");
  console.log("📊 Checking global objects...");
  console.log("📊 window.PAGODA_DATABASE:", window.PAGODA_DATABASE);
  console.log("📊 window.pagodaManager:", window.pagodaManager);

  loadFamousPagodas();
  setTimeout(loadFamousPagodas, 500);
  setTimeout(loadFamousPagodas, 1000);
});
