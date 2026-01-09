// Map Page - Handles interactive map functionality
// This file contains all the logic that was previously inline in map.html

// Global map variable for updates
let globalMap = null;
let globalMarkers = null;

// Initialize map when everything is loaded
window.addEventListener("load", function () {
  console.log("Initializing map..."); // Debug log

  // Check if map container exists
  const mapContainer = document.getElementById("map");
  if (!mapContainer) {
    console.error("Map container not found!");
    return;
  }

  // Check if pagoda data is loaded
  if (!window.pagodaManager) {
    console.error("PagodaManager not loaded! Retrying in 1 second...");
    setTimeout(() => {
      window.location.reload();
    }, 1000);
    return;
  }

  initializeMap();
});

// Listen for pagoda data updates
window.addEventListener("pagodas-updated", function() {
  console.log("Pagoda data updated, refreshing map...");
  if (globalMap && globalMarkers) {
    globalMap.removeLayer(globalMarkers);
    addMarkersToMap(globalMap);
  }
});

function initializeMap() {

  try {
    const inMM = (function(){ const p=(window.location.pathname||'').toLowerCase(); const f=(p.split('/').pop()||''); return p.includes('/mmversion/') || /mm\.html$/i.test(f) || /indexmm\.html$/i.test(f); })();
    // Get pagoda data from the database first
    const pagodas = window.pagodaManager
      ? window.pagodaManager.getAllPagodas().map((pagoda) => {
          // Safely access coordinates with fallback
          const coords = pagoda.location?.coordinates || pagoda.location || {};
          const lat = coords.lat;
          const lng = coords.lng;
          
          // Skip pagodas without valid coordinates
          if (!lat || !lng) {
            console.warn(`Skipping ${pagoda.name}: missing coordinates`);
            return null;
          }
          
          const mmOverlay = (function(){
            if (!inMM || !window.PAGODA_DATABASE_MM || !Array.isArray(window.PAGODA_DATABASE_MM.pagodas)) return null;
            return window.PAGODA_DATABASE_MM.pagodas.find((p) => p.id === pagoda.id) || null;
          })();
          return {
            id: pagoda.id,
            name: inMM && mmOverlay && mmOverlay.name ? mmOverlay.name : pagoda.name,
            lat: lat,
            lng: lng,
            // Link to the details page for both languages
            link: inMM ? `/mmversion/pagodaDetailsmm.html?id=${pagoda.id}&mm=1` : `pagodaDetils.html?id=${pagoda.id}`,
            img: (pagoda.images && (pagoda.images.main || pagoda.images.thumbnail)) || './assets/images/placeholder-pagoda.jpg',
            description: (function(){
              const baseDesc = (pagoda.description && (pagoda.description.short || pagoda.description.long)) || '';
              if (inMM) {
                const mmDesc = mmOverlay && mmOverlay.description && (mmOverlay.description.short || mmOverlay.description.long);
                return mmDesc || baseDesc || 'အသေးစိတ်အချက်အလက် မရှိသေးပါ';
              }
              return baseDesc || 'No description available';
            })(),
          };
        }).filter(p => p !== null) // Remove null entries
      : [];

    // Debug: Log pagoda coordinates
    console.log("Pagoda coordinates loaded:", pagodas.length, "pagodas");
    pagodas.forEach((p) => {
      console.log(`${p.name}: ${p.lat}, ${p.lng}`);
    });

    // Calculate center point from all pagoda coordinates
    let centerLat = 21.1717;
    let centerLng = 94.8585;

    if (pagodas.length > 0) {
      const lats = pagodas.map((p) => p.lat);
      const lngs = pagodas.map((p) => p.lng);
      centerLat = (Math.min(...lats) + Math.max(...lats)) / 2;
      centerLng = (Math.min(...lngs) + Math.max(...lngs)) / 2;
    }

    globalMap = L.map("map", {
      zoomControl: true,
      attributionControl: true,
    }).setView([centerLat, centerLng], 12);
    
    // Make map globally accessible for pathfinding
    window.globalMap = globalMap;

    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution:
        '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      maxZoom: 18,
    }).addTo(globalMap);

    // Multiple attempts to fix size
    setTimeout(() => {
      globalMap.invalidateSize();
      console.log("Map size invalidated");
    }, 100);

    setTimeout(() => {
      globalMap.invalidateSize();
    }, 500);

    // Add markers to map
    addMarkersToMap(globalMap);

    // Ensure map is interactive
    globalMap.dragging.enable();
    globalMap.touchZoom.enable();
    globalMap.doubleClickZoom.enable();
    globalMap.scrollWheelZoom.enable();
    globalMap.boxZoom.enable();
    globalMap.keyboard.enable();

    console.log("Map initialized successfully");
    console.log("Map is now available for pathfinding as window.globalMap");
    
    // Notify that map is ready for pathfinding
    window.dispatchEvent(new CustomEvent('map-ready'));
  } catch (error) {
    console.error("Error initializing map:", error);
  }
}

function addMarkersToMap(map) {
  // Get current pagoda data
  const inMM = (function(){ const p=(window.location.pathname||'').toLowerCase(); const f=(p.split('/').pop()||''); return p.includes('/mmversion/') || /mm\.html$/i.test(f) || /indexmm\.html$/i.test(f); })();
  const pagodas = window.pagodaManager
    ? window.pagodaManager.getAllPagodas().map((pagoda) => {
        // Safely access coordinates with fallback
        const coords = pagoda.location?.coordinates || pagoda.location || {};
        const lat = coords.lat;
        const lng = coords.lng;
        
        // Skip pagodas without valid coordinates
        if (!lat || !lng) {
          console.warn(`Skipping ${pagoda.name}: missing coordinates`);
          return null;
        }
        
        const mmOverlay = (function(){
          if (!inMM || !window.PAGODA_DATABASE_MM || !Array.isArray(window.PAGODA_DATABASE_MM.pagodas)) return null;
          return window.PAGODA_DATABASE_MM.pagodas.find((p) => p.id === pagoda.id) || null;
        })();
        return {
          id: pagoda.id,
          name: inMM && mmOverlay && mmOverlay.name ? mmOverlay.name : pagoda.name,
          lat: lat,
          lng: lng,
          // Link to the details page for both languages
          link: inMM ? `/mmversion/pagodaDetailsmm.html?id=${pagoda.id}&mm=1` : `pagodaDetils.html?id=${pagoda.id}`,
          img: (pagoda.images && (pagoda.images.main || pagoda.images.thumbnail)) || './assets/images/placeholder-pagoda.jpg',
          description: (function(){
            const baseDesc = pagoda.description && (pagoda.description.short || pagoda.description.long);
            if (inMM) {
              const mmDesc = mmOverlay && mmOverlay.description && (mmOverlay.description.short || mmOverlay.description.long);
              return mmDesc || baseDesc || 'အသေးစိတ်အချက်အလက် မရှိသေးပါ';
            }
            return baseDesc || 'No description available';
          })(),
        };
      }).filter(p => p !== null) // Remove null entries
    : [];

  // Initialize MarkerClusterGroup
  globalMarkers = L.markerClusterGroup();

  // Add markers with image-enhanced popups
  if (pagodas.length > 0) {
    pagodas.forEach((p) => {
      const popupContent = `
        <div style="text-align:center; padding: 5px;">
          <img src="${p.img}" alt="${p.name}" style="width:120px; height:auto; border-radius:8px; box-shadow:0 0 6px rgba(0,0,0,0.2); margin-bottom: 8px; object-fit: cover;"><br>
          <strong style="font-size: 1.1em; color: #aa7739;">${p.name}</strong><br>
          <p style="font-size: 0.9em; color: #555; margin: 5px 0;">${p.description}</p>
          <a href="${p.link}" style="color:#8d5e2f; font-weight:bold; text-decoration: none; display: inline-block; margin-top: 5px; padding: 5px 10px; border: 1px solid #aa7739; border-radius: 5px; transition: background-color 0.3s, color: 0.3s;">${inMM ? 'အသေးစိတ်ကြည့်ရန်' : 'View Details'}</a>
        </div>
      `;
      const marker = L.marker([p.lat, p.lng]).bindPopup(popupContent);
      globalMarkers.addLayer(marker);
    });
  }

  map.addLayer(globalMarkers);

  // Fit map bounds to all markers for better view
  if (pagodas.length > 0) {
    const bounds = L.latLngBounds(pagodas.map((p) => [p.lat, p.lng]));
    map.fitBounds(bounds, { padding: [20, 20] });
  }
}
