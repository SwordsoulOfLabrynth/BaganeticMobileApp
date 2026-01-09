// Myanmar Pagoda Manager - Handles Myanmar language pagoda data
// This extends the main pagoda manager to work with Myanmar data

(function() {
  // Check if we're on a Myanmar page
  function isMyanmarPage() {
    const pathname = window.location.pathname || '';
    return pathname.includes('/mmversion/') || /mm\.html$/i.test(pathname) || /indexmm\.html$/i.test(pathname);
  }

  // Override pagoda manager for Myanmar pages
  if (isMyanmarPage() && window.PAGODA_DATABASE_MM) {
    // Store original pagoda manager
    const originalPagodaManager = window.pagodaManager;
    
    // Prevent English manager from overriding our Myanmar manager
    const originalPagodaManagerClass = window.PagodaManager;
    
    // Create Myanmar-specific pagoda manager
    class MyanmarPagodaManager {
      constructor() {
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

        this.pagodas = merged;
        this.data = { ...window.PAGODA_DATABASE, pagodas: merged, utils: (window.PAGODA_DATABASE && window.PAGODA_DATABASE.utils) };
        this.isMyanmar = true;
      }

      getAllPagodas() {
        return this.pagodas;
      }

    getPagoda(id) {
      if (!id) return undefined;
      const target = String(id).toLowerCase();
      return this.pagodas.find(p => (p.id || '').toLowerCase() === target);
      }

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
      }

      getFeaturedPagodas() {
        // Filter pagodas that are marked as featured
        const featured = this.pagodas.filter(pagoda => pagoda.featured === true);
        console.log('🏛️ Myanmar Featured Pagodas:', featured.length, 'out of', this.pagodas.length);
        console.log('🏛️ Featured pagodas:', featured.map(p => ({ id: p.id, name: p.name, featured: p.featured })));
        return featured;
      }

      // Add distance calculation methods if needed
      calculateDistance(lat1, lng1, lat2, lng2) {
        const R = 6371; // Earth's radius in km
        const dLat = (lat2 - lat1) * Math.PI / 180;
        const dLng = (lng2 - lng1) * Math.PI / 180;
        const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
                  Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
                  Math.sin(dLng/2) * Math.sin(dLng/2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
        return R * c;
      }
    }

    // Initialize Myanmar pagoda manager (merged dataset with MM overlays)
    window.pagodaManager = new MyanmarPagodaManager();
    
    // Keep global database pointing to merged for consistency on MM pages
    window.PAGODA_DATABASE = window.pagodaManager.data;
    
    // Override the English PagodaManager class to prevent it from overriding our Myanmar manager
    if (originalPagodaManagerClass) {
      window.PagodaManager = function() {
        console.log('🚫 English PagodaManager blocked on Myanmar page');
        return window.pagodaManager; // Return our Myanmar manager instead
      };
    }
    
    console.log('Myanmar Pagoda Manager initialized with', window.pagodaManager.pagodas.length, 'pagodas');
    console.log('Myanmar Pagoda Manager featured count:', window.pagodaManager.getFeaturedPagodas().length);
    
    // Add periodic check to ensure Myanmar manager persists
    const checkMyanmarManager = () => {
      if (window.pagodaManager && !window.pagodaManager.isMyanmar) {
        console.log('🔄 Re-establishing Myanmar Pagoda Manager');
        window.pagodaManager = new MyanmarPagodaManager();
        window.PAGODA_DATABASE = window.pagodaManager.data;
      }
    };
    
    // Check every 100ms for the first 5 seconds
    let checkCount = 0;
    const checkInterval = setInterval(() => {
      checkMyanmarManager();
      checkCount++;
      if (checkCount >= 50) { // 5 seconds
        clearInterval(checkInterval);
      }
    }, 100);
  }

  // Override search functionality for Myanmar pages
  if (isMyanmarPage()) {
    // Override the search function to work with Myanmar data
    const originalSearchPagodas = window.searchPagodas;
    if (originalSearchPagodas) {
      window.searchPagodas = function(query) {
        if (window.pagodaManager && window.pagodaManager.isMyanmar) {
          const results = window.pagodaManager.search(query);
          const noResults = document.getElementById("noResults");
          const pagodaGrid = document.getElementById("pagodaGrid");

          if (results.length === 0 && query.trim() !== "") {
            noResults.style.display = "block";
            pagodaGrid.style.display = "none";
          } else {
            noResults.style.display = "none";
            pagodaGrid.style.display = "grid";
            if (window.displayPagodas) {
              window.displayPagodas(results);
            }
          }
        } else {
          return originalSearchPagodas(query);
        }
      };
    }
  }
})();

