// Pagoda Data Manager - Easy-to-use functions for handling pagoda data
// This file provides simple functions to work with pagoda data across your website

class PagodaManager {
  constructor() {
    this.data = window.PAGODA_DATABASE || {};
    this.pagodas = this.data.pagodas || [];
    this.utils = this.data.utils || {};
    this.isLoadedFromApi = false;
  }

  // === BASIC DATA RETRIEVAL ===

  // Get all pagodas
  getAllPagodas() {
    return this.pagodas;
  }

  // Get a specific pagoda by ID
  getPagoda(id) {
    return this.pagodas.find((pagoda) => pagoda.id === id);
  }

  // Get featured pagodas for homepage
  getFeaturedPagodas() {
    return this.pagodas.filter((pagoda) => pagoda.featured);
  }

  // === SEARCH AND FILTER ===

  // Search pagodas by name only (title search from first letter)
  search(query) {
    if (!query) return this.pagodas;

    const searchTerm = query.toLowerCase();
    return this.pagodas.filter((pagoda) => {
      return (
        pagoda.name.toLowerCase().startsWith(searchTerm) ||
        pagoda.shortName.toLowerCase().startsWith(searchTerm)
      );
    });
  }

  // Filter by type (Temple, Pagoda, etc.)
  filterByType(type) {
    return this.pagodas.filter(
      (pagoda) => pagoda.type.toLowerCase() === type.toLowerCase()
    );
  }

  // Filter by location
  filterByLocation(city) {
    return this.pagodas.filter(
      (pagoda) => pagoda.location.city.toLowerCase() === city.toLowerCase()
    );
  }

  // Filter by tags
  filterByTag(tag) {
    return this.pagodas.filter((pagoda) =>
      pagoda.tags.includes(tag.toLowerCase())
    );
  }

  // === DISPLAY HELPERS ===

  // Get pagoda data formatted for cards/lists
  getDisplayData(pagoda) {
    return {
      id: pagoda.id,
      name: pagoda.name,
      shortName: pagoda.shortName,
      description: pagoda.description.short,
      image: pagoda.images.main,
      thumbnail: pagoda.images.thumbnail,
      location: `${pagoda.location.city}, ${pagoda.location.country}`,
      type: pagoda.type,
      built: pagoda.history.built,
      tags: pagoda.tags,
    };
  }

  // Get multiple pagodas formatted for display
  getDisplayDataList(pagodas) {
    return pagodas.map((pagoda) => this.getDisplayData(pagoda));
  }

  // === HTML GENERATION ===

  // Generate HTML for a pagoda card
  generatePagodaCard(pagoda, options = {}) {
    const displayData = this.getDisplayData(pagoda);
    const showDescription = options.showDescription !== false;
    const showLocation = options.showLocation !== false;
    const showType = options.showType !== false;
    const cardClass = options.cardClass || "pagoda-card";
    const linkUrl = options.linkUrl || `pagodaDetils.html?id=${pagoda.id}`;

    return `
            <div class="${cardClass}" data-id="${
      displayData.id
    }" onclick="window.location.href='${linkUrl}'">
                <div class="pagoda-image">
                    <img src="${displayData.image}" alt="${
      pagoda.images.main ? pagoda.name : "Pagoda image"
    }" loading="lazy" />
                    ${
                      showType
                        ? `<span class="pagoda-type">${displayData.type}</span>`
                        : ""
                    }
                </div>
                <div class="pagoda-content">
                    <h3 class="pagoda-name">${displayData.name}</h3>
                    ${
                      showLocation
                        ? `<p class="pagoda-location">📍 ${displayData.location}</p>`
                        : ""
                    }
                    ${
                      showDescription
                        ? `<p class="pagoda-description">${displayData.description}</p>`
                        : ""
                    }
                    <div class="pagoda-meta">
                        <span class="pagoda-built">Built: ${
                          displayData.built
                        }</span>
                    </div>
                    <div class="pagoda-tags">
                        ${displayData.tags
                          .slice(0, 3)
                          .map((tag) => `<span class="tag">${tag}</span>`)
                          .join("")}
                    </div>
                </div>
            </div>
        `;
  }

  // Generate HTML for multiple pagoda cards
  generatePagodaGrid(pagodas, options = {}) {
    const gridClass = options.gridClass || "pagodas-grid";
    const cardsHtml = pagodas
      .map((pagoda) => this.generatePagodaCard(pagoda, options))
      .join("");

    return `
            <div class="${gridClass}">
                ${cardsHtml}
            </div>
        `;
  }

  // Render pagodas to a container with favorite buttons
  renderPagodas(containerId, pagodas = null) {
    const container = document.getElementById(containerId);
    if (!container) {
      console.error(`Container with ID "${containerId}" not found`);
      return;
    }

    const pagodasToRender = pagodas || this.pagodas;

    if (pagodasToRender.length === 0) {
      container.innerHTML = `
        <div class="no-results">
          <div class="no-results-icon">🏛️</div>
          <h3>No pagodas found</h3>
          <p>Try adjusting your search or filter criteria</p>
        </div>
      `;
      return;
    }

    const cardsHTML = pagodasToRender
      .map((pagoda) => this.generatePagodaCard(pagoda))
      .join("");
    container.innerHTML = cardsHTML;

    // Add favorite buttons after rendering
    setTimeout(() => {
      if (typeof addFavoriteButtonsToPagodaCards === "function") {
        addFavoriteButtonsToPagodaCards();
      }
    }, 100);
  }

  // Generate HTML for search suggestions
  generateSearchSuggestion(pagoda) {
    const displayData = this.getDisplayData(pagoda);
    return `
            <li class="search-suggestion" data-id="${displayData.id}">
                <img src="${displayData.thumbnail || displayData.image}" alt="${
      displayData.name
    }" class="suggestion-image" />
                <div class="suggestion-content">
                    <div class="suggestion-name">${displayData.name}</div>
                    <div class="suggestion-location">${
                      displayData.location
                    }</div>
                    <div class="suggestion-type">${displayData.type}</div>
                </div>
            </li>
        `;
  }

  // === UTILITY FUNCTIONS ===

  // Get random pagodas
  getRandomPagodas(count = 3) {
    const shuffled = [...this.pagodas].sort(() => 0.5 - Math.random());
    return shuffled.slice(0, count);
  }

  // Get pagoda statistics
  getStats() {
    const stats = {
      total: this.pagodas.length,
      temples: this.filterByType("Temple").length,
      pagodas: this.filterByType("Pagoda").length,
      featured: this.getFeaturedPagodas().length,
      locations: [...new Set(this.pagodas.map((p) => p.location.city))],
      types: [...new Set(this.pagodas.map((p) => p.type))],
      tags: [...new Set(this.pagodas.flatMap((p) => p.tags))],
    };
    return stats;
  }

  // Check if pagoda exists
  exists(id) {
    return this.pagodas.some((pagoda) => pagoda.id === id);
  }

  // Get pagoda detail URL
  getDetailUrl(id) {
    return `pagodaDetils.html?id=${id}`;
  }

  // === ADVANCED FEATURES ===

  // Get similar pagodas based on tags and type
  getSimilarPagodas(targetPagoda, limit = 3) {
    if (!targetPagoda) return [];

    const similar = this.pagodas
      .filter((pagoda) => pagoda.id !== targetPagoda.id)
      .map((pagoda) => {
        let score = 0;

        // Same type gets higher score
        if (pagoda.type === targetPagoda.type) score += 3;

        // Same location gets higher score
        if (pagoda.location.city === targetPagoda.location.city) score += 2;

        // Shared tags get points
        const sharedTags = pagoda.tags.filter((tag) =>
          targetPagoda.tags.includes(tag)
        );
        score += sharedTags.length;

        return { pagoda, score };
      })
      .sort((a, b) => b.score - a.score)
      .slice(0, limit)
      .map((item) => item.pagoda);

    return similar;
  }

  // Get pagodas by distance (if coordinates are available)
  getNearbyPagodas(targetPagoda, radiusKm = 10) {
    if (!targetPagoda?.location?.coordinates) return [];

    const { lat: targetLat, lng: targetLng } =
      targetPagoda.location.coordinates;

    return this.pagodas
      .filter(
        (pagoda) => pagoda.id !== targetPagoda.id && pagoda.location.coordinates
      )
      .map((pagoda) => {
        const { lat, lng } = pagoda.location.coordinates;
        const distance = this.calculateDistance(targetLat, targetLng, lat, lng);
        return { pagoda, distance };
      })
      .filter((item) => item.distance <= radiusKm)
      .sort((a, b) => a.distance - b.distance)
      .map((item) => item.pagoda);
  }

  // Calculate distance between two coordinates (Haversine formula)
  calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // Radius of the Earth in kilometers
    const dLat = this.deg2rad(lat2 - lat1);
    const dLon = this.deg2rad(lon2 - lon1);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(this.deg2rad(lat1)) *
        Math.cos(this.deg2rad(lat2)) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    const d = R * c; // Distance in kilometers
    return d;
  }

  deg2rad(deg) {
    return deg * (Math.PI / 180);
  }
}

// Create global instance when data is available
async function initializePagodaManager() {
  // Try to load from database first (via Node.js server)
  try {
    const response = await fetch("/api/pagodas", {
      headers: { Accept: "application/json" },
      credentials: "include",
    });

    if (response.ok) {
      const result = await response.json();
      if (
        result.success &&
        Array.isArray(result.data) &&
        result.data.length > 0
      ) {
        // Use database data as primary source
        window.pagodaManager = new PagodaManager();
        // Convert API data to full pagoda objects by merging with static data
        window.pagodaManager.pagodas = result.data.map((apiPagoda) => {
          // Find matching static data for full object
          const staticPagoda = window.PAGODA_DATABASE?.pagodas?.find(
            (p) => p.id === apiPagoda.id
          );
          if (staticPagoda) {
            // Merge API data with static data, but DEEP-MERGE nested objects to avoid overwriting
            // complete structures with partial data from the API.
            const mergedImages = {
              main: apiPagoda.images?.main || staticPagoda.images?.main,
              thumbnail:
                apiPagoda.images?.thumbnail || staticPagoda.images?.thumbnail,
              gallery: staticPagoda.images?.gallery || [],
            };

            const mergedDescription = (function () {
              // API may provide a string or an object; normalize to {short, long}
              if (typeof apiPagoda.description === "string") {
                return {
                  ...staticPagoda.description,
                  short: apiPagoda.description || staticPagoda.description?.short,
                  long: apiPagoda.description || staticPagoda.description?.long,
                };
              }
              return {
                ...staticPagoda.description,
                ...(apiPagoda.description || {}),
              };
            })();

            const mergedHistory = {
              ...staticPagoda.history,
              ...(typeof apiPagoda.history === "object"
                ? apiPagoda.history
                : apiPagoda.history
                ? { built: apiPagoda.history }
                : {}),
            };

            const mergedLocation = {
              ...staticPagoda.location,
              ...(typeof apiPagoda.location === "object"
                ? apiPagoda.location
                : apiPagoda.location
                ? { city: apiPagoda.location }
                : {}),
            };

            return {
              ...staticPagoda,
              // Only copy primitive top-level fields from API to avoid wiping nested structures
              id: apiPagoda.id || staticPagoda.id,
              name: apiPagoda.name || staticPagoda.name,
              shortName: apiPagoda.shortName || staticPagoda.shortName,
              type: apiPagoda.type || staticPagoda.type,
              tags: Array.isArray(apiPagoda.tags)
                ? apiPagoda.tags
                : staticPagoda.tags,
              featured:
                typeof apiPagoda.featured === "boolean"
                  ? apiPagoda.featured
                  : staticPagoda.featured,
              images: mergedImages,
              description: mergedDescription,
              history: mergedHistory,
              location: mergedLocation,
            };
          }
          // If no static data found, use API data as fallback and NORMALIZE fields
          const normalizedDescription = (function () {
            const fallbackShort = "A beautiful temple in Bagan.";
            const fallbackLong =
              "A beautiful temple in Bagan with rich historical significance.";
            if (typeof apiPagoda.description === "string") {
              return { short: apiPagoda.description, long: apiPagoda.description };
            }
            const descObj = apiPagoda.description || {};
            return {
              short: descObj.short || fallbackShort,
              long: descObj.long || fallbackLong,
            };
          })();

          const normalizedImages = (function () {
            const imgs = apiPagoda.images || {};
            const main = imgs.main || "./assets/images/placeholder-pagoda.jpg";
            return {
              main,
              thumbnail: imgs.thumbnail || main,
              gallery: Array.isArray(imgs.gallery) ? imgs.gallery : [],
            };
          })();

          return {
            ...apiPagoda,
            images: normalizedImages,
            description: normalizedDescription,
            history: {
              built: (apiPagoda.history && apiPagoda.history.built) || "Unknown",
              ...(typeof apiPagoda.history === "object" ? apiPagoda.history : {}),
            },
            tags: Array.isArray(apiPagoda.tags)
              ? apiPagoda.tags
              : ["temple", "historic", "bagan"],
            featured:
              typeof apiPagoda.featured === "boolean" ? apiPagoda.featured : false,
          };
        });
        window.pagodaManager.isLoadedFromApi = true;
        console.log(
          "✅ PagodaManager initialized with",
          window.pagodaManager.pagodas.length,
          "pagodas from database"
        );
        return;
      }
    }
  } catch (err) {
    console.warn(
      "⚠️ Failed to load pagodas from database, falling back to static data.",
      err
    );
  }

  // Fallback to static data if database fails
  if (window.PAGODA_DATABASE && window.PAGODA_DATABASE.pagodas) {
    window.pagodaManager = new PagodaManager();
    console.log(
      "✅ PagodaManager initialized with",
      window.pagodaManager.pagodas.length,
      "pagodas (static fallback)"
    );
  } else {
    console.log("⏳ Waiting for PAGODA_DATABASE to load...");
    setTimeout(initializePagodaManager, 100);
  }
}

// Ensure pagoda manager is initialized even if API fails
setTimeout(() => {
  if (
    !window.pagodaManager &&
    window.PAGODA_DATABASE &&
    window.PAGODA_DATABASE.pagodas
  ) {
    console.log("🔄 Fallback initialization of PagodaManager");
    window.pagodaManager = new PagodaManager();
  }
}, 2000);

// Start initialization
initializePagodaManager();

// Export for use in other files
if (typeof module !== "undefined" && module.exports) {
  module.exports = PagodaManager;
}
