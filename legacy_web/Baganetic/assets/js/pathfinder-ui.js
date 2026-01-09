/**
 * Pathfinder UI Module for Baganetic
 * Handles the shortest path finding interface and map visualization
 */

class PathfinderUI {
  constructor() {
    this.map = null;
    this.pathMarkers = [];
    this.pathPolyline = null;
    this.startPagoda = null;
    this.endPagoda = null;
    this.availablePagodas = [];
    this.isMM = (function() {
      const p = (window.location && window.location.pathname || '').toLowerCase();
      const file = (p.split('/').pop() || '');
      return p.includes('/mmversion/') || /mm\.html$/i.test(file) || /indexmm\.html$/i.test(file);
    })();

    this.init();
  }

  async init() {
    console.log("🗺️ Initializing Pathfinder UI...");

    // Load available pagodas
    await this.loadAvailablePagodas();

    // Setup UI elements
    this.setupUI();

    // Ensure clean initial state
    this.clearPath();

    console.log("✅ Pathfinder UI initialized");
  }

  async loadAvailablePagodas() {
    try {
      const response = await fetch("/api/pathfinder/pagodas");
      const result = await response.json();

      if (result.success) {
        // Normalize with EN name (API key) and localized label (MM when available)
        const enDb = (window.PAGODA_DATABASE && window.PAGODA_DATABASE.pagodas) || [];
        const mmDb = (window.PAGODA_DATABASE_MM && window.PAGODA_DATABASE_MM.pagodas) || [];
        this.availablePagodas = (result.data || []).map((item) => {
          const enName = item && item.name ? String(item.name) : '';
          const enMatch = enDb.find(p => (p.name || '').toLowerCase() === enName.toLowerCase());
          const id = enMatch ? enMatch.id : null;
          const mmName = this.isMM && id ? (mmDb.find(p => (p.id || '') === id)?.name || enName) : enName;
          return { ...item, id, name: enName, label: mmName };
        });
        console.log(
          `📚 Loaded ${this.availablePagodas.length} pagodas for pathfinding`
        );
      } else {
        console.error("Failed to load pagodas:", result.message);
      }
    } catch (error) {
      console.error("Error loading pagodas:", error);
    }
  }

  setupUI() {
    // Create pathfinder controls
    this.createPathfinderControls();

    // Add event listeners
    this.setupEventListeners();
  }

  createPathfinderControls() {
    // Find the map container
    const mapContainer = document.querySelector("#map");
    if (!mapContainer) {
      console.error("Map container not found");
      return;
    }

    // Create pathfinder panel
    const pathfinderPanel = document.createElement("div");
    pathfinderPanel.id = "pathfinder-panel";
    pathfinderPanel.className = "pathfinder-panel";
    const t = (key) => {
      if (!this.isMM) return {
        title: '🗺️ Shortest Path Finder', start: '📍 Start Pagoda:', dest: '🎯 Destination:', chooseStart: 'Choose starting point...', chooseEnd: 'Choose destination...', find: '🔍 Find Route', finding: '🔄 Finding...', clear: '🗑️ Clear', routeFound: '✅ Route Found!', distance: 'Distance', stops: 'Stops', yourRoute: '🗺️ Your Route:', nearby: '📍 Nearby Pagodas:', startingPoint: 'Starting Point', destination: 'Destination', waypoint: 'Waypoint', stepOf: (i, n) => `Step ${i} of ${n}`, kmAway: (d) => `${d.toFixed(2)} km away`
      };
      return {
        title: '🗺️ အတိုဆုံးလမ်းကြောင်း ရှာဖွေရေး', start: '📍 စတင်ရာ စေတီ:', dest: '🎯 သွားရောက်မည့်နေရာ:', chooseStart: 'စတင်ရာကို ရွေးချယ်ပါ...', chooseEnd: 'သွားရောက်မည့်နေရာကို ရွေးချယ်ပါ...', find: '🔍 လမ်းကြောင်းရှာမည်', finding: '🔄 ရှာဖွေနေပါသည်...', clear: '🗑️ ဖျက်လှပ်', routeFound: '✅ လမ်းကြောင်း ရှာဖွေတွေ့ရှိပြီး!', distance: 'အကွာအဝေး', stops: 'ရပ်နားချက်များ', yourRoute: '🗺️ သင့်လမ်းကြောင်း:', nearby: '📍အနီးအနားရှိ စေတီများ:', startingPoint: 'စတင်ရာနေရာ', destination: 'သွားရောက်မည့်နေရာ', waypoint: 'အလယ်နေရာ', stepOf: (i, n) => `အဆင့် ${i} / ${n}`, kmAway: (d) => `${d.toFixed(2)} ကီလိုမီတာ အကွာ`
      };
    };

    const L10N = t();

    pathfinderPanel.innerHTML = `
            <div class="pathfinder-header">
                <h3>${L10N.title}</h3>
                <button id="close-pathfinder" class="close-btn">&times;</button>
            </div>
            <div class="pathfinder-content">
                <div class="pathfinder-form">
                    <div class="form-group">
                        <label for="start-pagoda">${L10N.start}</label>
                        <select id="start-pagoda" class="pagoda-select">
                            <option value="">${L10N.chooseStart}</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label for="end-pagoda">${L10N.dest}</label>
                        <select id="end-pagoda" class="pagoda-select">
                            <option value="">${L10N.chooseEnd}</option>
                        </select>
                    </div>
                    <div class="form-actions">
                        <button id="find-path-btn" class="find-path-btn" disabled>
                            <span class="btn-text">${L10N.find}</span>
                            <span class="btn-loading" style="display: none;">${L10N.finding}</span>
                        </button>
                        <button id="clear-path-btn" class="clear-path-btn" disabled>
                            ${L10N.clear}
                        </button>
                    </div>
                </div>
                <div id="path-results" class="path-results" style="display: none;">
                    <div class="path-info">
                        <div class="path-header">
                            <h4>${L10N.routeFound}</h4>
                            <div class="path-summary">
                                <div class="summary-item">
                                    <span class="icon">📏</span>
                                    <span class="label">${L10N.distance}</span>
                                    <span id="path-distance" class="value">-</span>
                                </div>
                                <div class="summary-item">
                                    <span class="icon">🏛️</span>
                                    <span class="label">${L10N.stops}</span>
                                    <span id="path-stops" class="value">-</span>
                                </div>
                            </div>
                        </div>
                        <div class="path-list">
                            <h5>${L10N.yourRoute}</h5>
                            <div id="path-list" class="route-steps"></div>
                        </div>
                        <div class="nearby-pagodas" id="nearby-pagodas" style="display: none;">
                            <h5>${L10N.nearby}</h5>
                            <div id="nearby-list" class="nearby-list"></div>
                        </div>
                    </div>
                </div>
            </div>
        `;

    // Insert before map
    mapContainer.parentNode.insertBefore(pathfinderPanel, mapContainer);

    // Start hidden
    pathfinderPanel.style.display = "none";

    // Populate pagoda selects
    this.populatePagodaSelects();

    // Add CSS styles
    this.addPathfinderStyles();
  }

  populatePagodaSelects() {
    const startSelect = document.getElementById("start-pagoda");
    const endSelect = document.getElementById("end-pagoda");

    // Sort alphabetically by name before populating
    const sorted = [...this.availablePagodas].sort((a, b) =>
      (a.label || a.name).localeCompare(b.label || b.name)
    );

    sorted.forEach((pagoda) => {
      const option = document.createElement("option");
      // Keep value as EN name (API expects this), show label in MM when available
      option.value = pagoda.name;
      option.textContent = pagoda.label || pagoda.name;

      startSelect.appendChild(option.cloneNode(true));
      endSelect.appendChild(option);
    });
  }

  setupEventListeners() {
    // Find path button
    document.getElementById("find-path-btn").addEventListener("click", () => {
      this.findPath();
    });

    // Clear path button
    document.getElementById("clear-path-btn").addEventListener("click", () => {
      this.clearPath();
    });

    // Close pathfinder panel
    document
      .getElementById("close-pathfinder")
      .addEventListener("click", () => {
        this.hidePathfinderPanel();
      });

    // Enable/disable find button based on selections
    const startSelect = document.getElementById("start-pagoda");
    const endSelect = document.getElementById("end-pagoda");
    const findBtn = document.getElementById("find-path-btn");

    [startSelect, endSelect].forEach((select) => {
      select.addEventListener("change", () => {
        const canFind =
          startSelect.value &&
          endSelect.value &&
          startSelect.value !== endSelect.value;
        findBtn.disabled = !canFind;
      });
    });
  }

  async findPath() {
    const startPagoda = document.getElementById("start-pagoda").value;
    const endPagoda = document.getElementById("end-pagoda").value;

    if (!startPagoda || !endPagoda) {
      this.showError("Please select both start and end pagodas");
      return;
    }

    if (startPagoda === endPagoda) {
      this.showError("Start and end pagodas must be different");
      return;
    }

    // Show loading state
    const findBtn = document.getElementById("find-path-btn");
    const btnText = findBtn.querySelector(".btn-text");
    const btnLoading = findBtn.querySelector(".btn-loading");

    btnText.style.display = "none";
    btnLoading.style.display = "inline";
    findBtn.disabled = true;

    try {
      const response = await fetch("/api/pathfinder/find-path", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          start: startPagoda,
          end: endPagoda,
        }),
      });

      const result = await response.json();

      if (result.success) {
        this.displayPathResult(result.data);
        this.visualizePathOnMap(result.data);
        this.hideError(); // Hide any previous errors
      } else {
        this.showError(result.message || "Failed to find path");
      }
    } catch (error) {
      console.error("Error finding path:", error);
      this.showError("Network error occurred while finding path");
    } finally {
      // Restore button state
      btnText.style.display = "inline";
      btnLoading.style.display = "none";
      findBtn.disabled = false;
    }
  }

  displayPathResult(data) {
    const resultsDiv = document.getElementById("path-results");
    const distanceSpan = document.getElementById("path-distance");
    const stopsSpan = document.getElementById("path-stops");
    const pathList = document.getElementById("path-list");
    const nearbyDiv = document.getElementById("nearby-pagodas");
    const nearbyList = document.getElementById("nearby-list");

    // Update path information - use distanceKm if available, otherwise distance
    const distance = data.distanceKm || data.distance;
    distanceSpan.textContent = `${distance.toFixed(1)} km`;
    stopsSpan.textContent = data.pathLength;

    // Update path list with better styling
    pathList.innerHTML = "";
    data.path.forEach((pagoda, index) => {
      const stepDiv = document.createElement("div");
      stepDiv.className = "route-step";

      const isStart = index === 0;
      const isEnd = index === data.path.length - 1;
      const isWaypoint = !isStart && !isEnd;

      let icon = "🟢";
      let stepClass = "start";
      if (isEnd) {
        icon = "🔴";
        stepClass = "end";
      } else if (isWaypoint) {
        icon = "🔵";
        stepClass = "waypoint";
      }

      stepDiv.innerHTML = `
        <div class="step-number">${index + 1}</div>
        <div class="step-icon ${stepClass}">${icon}</div>
        <div class="step-content">
          <div class="step-name">${pagoda}</div>
          <div class="step-type">${
            isStart ? "Starting Point" : isEnd ? "Destination" : "Waypoint"
          }</div>
        </div>
      `;

      pathList.appendChild(stepDiv);
    });

    // Update nearby pagodas
    if (data.nearbyPagodas && data.nearbyPagodas.length > 0) {
      nearbyList.innerHTML = "";
      data.nearbyPagodas.forEach((pagoda) => {
        const nearbyDiv = document.createElement("div");
        nearbyDiv.className = "nearby-item";
        nearbyDiv.innerHTML = `
          <div class="nearby-name">${pagoda.name}</div>
          <div class="nearby-distance">${pagoda.distance.toFixed(
            2
          )} km away</div>
        `;
        nearbyList.appendChild(nearbyDiv);
      });
      nearbyDiv.style.display = "block";
    } else {
      nearbyDiv.style.display = "none";
    }

    // Show results
    resultsDiv.style.display = "block";

    // Enable clear button
    document.getElementById("clear-path-btn").disabled = false;
  }

  visualizePathOnMap(data) {
    if (!this.map) {
      console.error("Map not initialized");
      return;
    }

    // Clear existing path visualization
    this.clearPathVisualization();

    // Add markers only for the main pagodas in the path (not road waypoints)
    data.path.forEach((pagodaName, index) => {
      const isStart = index === 0;
      const isEnd = index === data.path.length - 1;

      // Find the coordinate for this pagoda
      const coord = data.coordinates.find(c => c.name === pagodaName);
      if (!coord) return;

      const icon = isStart ? "🟢" : isEnd ? "🔴" : "🔵";
      const marker = L.marker([coord.lat, coord.lng], {
        icon: L.divIcon({
          html: `<div class="path-marker ${
            isStart ? "start" : isEnd ? "end" : "waypoint"
          }">${icon}</div>`,
          className: "path-marker-container",
          iconSize: [30, 30],
        }),
      }).addTo(this.map);

      // Add popup with pagoda info
      const stepLabel = this.isMM ? (idx => idx === 0 ? 'စတင်ရာနေရာ' : (idx === data.path.length - 1 ? 'သွားရောက်မည့်နေရာ' : 'အလယ်နေရာ')) : (idx => idx === 0 ? 'Starting Point' : (idx === data.path.length - 1 ? 'Destination' : 'Waypoint'));
      const stepText = (i) => this.isMM ? `အဆင့် ${i} / ${data.path.length}` : `Step ${i} of ${data.path.length}`;
      marker.bindPopup(`
                <div class="path-marker-popup">
                    <h4>${pagodaName}</h4>
                    <p>${stepText(index + 1)}</p>
                    ${isStart ? `<p><strong>${stepLabel(0)}</strong></p>` : ""}
                    ${isEnd ? `<p><strong>${stepLabel(data.path.length - 1)}</strong></p>` : ""}
                </div>
            `);

      this.pathMarkers.push(marker);
    });

    // Build a smooth polyline for the path (no dotted segments)
    const allCoords = data.coordinates.map(coord => [coord.lat, coord.lng]);
    const pathCoords = this.sampleCoordinates(allCoords, 200);

    // Soft glow outline under the main path
    const outline = L.polyline(pathCoords, {
      color: "#000000",
      weight: 10,
      opacity: 0.15,
      lineJoin: "round",
      lineCap: "round",
      smoothFactor: 1.2,
    }).addTo(this.map);

    // Main path stroke
    this.pathPolyline = L.polyline(pathCoords, {
      color: "#ff7f11",
      weight: 6,
      opacity: 0.95,
      lineJoin: "round",
      lineCap: "round",
      smoothFactor: 1.2,
    }).addTo(this.map);
    
    // Keep outline in the markers list for bounds fitting and later cleanup
    this.pathMarkers.push(outline);

    // Fit map to show the entire path
    if (pathCoords.length > 0) {
      const group = new L.featureGroup(
        this.pathMarkers.concat([this.pathPolyline])
      );
      this.map.fitBounds(group.getBounds().pad(0.1));
    }
  }

  clearPath() {
    // Clear path visualization first
    this.clearPathVisualization();

    // Clear results display
    const resultsDiv = document.getElementById("path-results");
    resultsDiv.style.display = "none";

    // Clear form selections
    document.getElementById("start-pagoda").value = "";
    document.getElementById("end-pagoda").value = "";

    // Disable buttons
    document.getElementById("find-path-btn").disabled = true;
    document.getElementById("clear-path-btn").disabled = true;

    // Hide any errors
    this.hideError();

    // Reset button text to ensure it's not stuck in loading state
    const findBtn = document.getElementById("find-path-btn");
    const btnText = findBtn.querySelector(".btn-text");
    const btnLoading = findBtn.querySelector(".btn-loading");

    if (btnText && btnLoading) {
      btnText.style.display = "inline";
      btnLoading.style.display = "none";
    }

    findBtn.disabled = true;
  }

  clearPathVisualization() {
    // Remove markers
    this.pathMarkers.forEach((marker) => {
      this.map.removeLayer(marker);
    });
    this.pathMarkers = [];

    // Remove polyline
    if (this.pathPolyline) {
      this.map.removeLayer(this.pathPolyline);
      this.pathPolyline = null;
    }
  }

  hideError() {
    const errorDiv = document.querySelector(".pathfinder-error");
    if (errorDiv) {
      errorDiv.remove();
    }
  }

  showError(message) {
    // Create or update error message
    let errorDiv = document.getElementById("pathfinder-error");
    if (!errorDiv) {
      errorDiv = document.createElement("div");
      errorDiv.id = "pathfinder-error";
      errorDiv.className = "pathfinder-error";
      document.querySelector(".pathfinder-content").appendChild(errorDiv);
    }

    errorDiv.innerHTML = `
            <div class="error-message">
                <span class="error-icon">⚠️</span>
                <span class="error-text">${message}</span>
                <button class="error-close" onclick="this.parentElement.parentElement.style.display='none'">&times;</button>
            </div>
        `;
    errorDiv.style.display = "block";

    // Auto-hide after 5 seconds
    setTimeout(() => {
      errorDiv.style.display = "none";
    }, 5000);
  }

  hidePathfinderPanel() {
    const panel = document.getElementById("pathfinder-panel");
    if (panel) {
      panel.style.display = "none";
      // Clear everything when hiding
      this.clearPath();
    }
  }

  showPathfinderPanel() {
    document.getElementById("pathfinder-panel").style.display = "block";
  }

  addPathfinderStyles() {
    const style = document.createElement("style");
    style.textContent = `
            .pathfinder-panel {
                position: fixed;
                top: 20px;
                right: 20px;
                width: 380px;
                background: white;
                border-radius: 15px;
                box-shadow: 0 8px 32px rgba(0,0,0,0.12);
                z-index: 1000;
                max-height: 85vh;
                overflow-y: auto;
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                border: 1px solid rgba(170, 119, 57, 0.1);
            }

            .pathfinder-header {
                background: linear-gradient(135deg, #aa7739, #8b5a2b);
                color: white;
                padding: 20px;
                border-radius: 15px 15px 0 0;
                display: flex;
                justify-content: space-between;
                align-items: center;
                position: relative;
                overflow: hidden;
            }

            .pathfinder-header::before {
                content: '';
                position: absolute;
                top: -50%;
                right: -50%;
                width: 100%;
                height: 100%;
                background: radial-gradient(circle, rgba(255,255,255,0.1) 0%, transparent 70%);
                pointer-events: none;
            }

            .pathfinder-header h3 {
                margin: 0;
                font-size: 1.3em;
                font-weight: 600;
                position: relative;
                z-index: 1;
            }

            .close-btn {
                background: rgba(255,255,255,0.2);
                border: none;
                color: white;
                font-size: 1.2em;
                cursor: pointer;
                padding: 8px;
                width: 32px;
                height: 32px;
                border-radius: 50%;
                display: flex;
                align-items: center;
                justify-content: center;
                transition: all 0.3s ease;
                position: relative;
                z-index: 1;
            }

            .close-btn:hover {
                background: rgba(255,255,255,0.3);
                transform: scale(1.1);
            }

            .pathfinder-content {
                padding: 25px;
            }

            .form-group {
                margin-bottom: 20px;
            }

            .form-group label {
                display: block;
                margin-bottom: 8px;
                font-weight: 600;
                color: #333;
                font-size: 14px;
            }

            .pagoda-select {
                width: 100%;
                padding: 12px 15px;
                border: 2px solid #e1e5e9;
                border-radius: 10px;
                font-size: 14px;
                background: white;
                transition: all 0.3s ease;
                box-sizing: border-box;
            }

            .pagoda-select:focus {
                outline: none;
                border-color: #aa7739;
                box-shadow: 0 0 0 3px rgba(170, 119, 57, 0.1);
            }

            .form-actions {
                display: flex;
                gap: 12px;
                margin-top: 25px;
            }

            .find-path-btn, .clear-path-btn {
                flex: 1;
                padding: 14px 20px;
                border: none;
                border-radius: 10px;
                font-size: 14px;
                font-weight: 600;
                cursor: pointer;
                transition: all 0.3s ease;
                position: relative;
                overflow: hidden;
            }

            .find-path-btn {
                background: linear-gradient(135deg, #27ae60, #2ecc71);
                color: white;
                box-shadow: 0 4px 15px rgba(39, 174, 96, 0.3);
            }

            .find-path-btn:hover:not(:disabled) {
                background: linear-gradient(135deg, #229954, #27ae60);
                transform: translateY(-2px);
                box-shadow: 0 6px 20px rgba(39, 174, 96, 0.4);
            }

            .find-path-btn:disabled {
                background: #bdc3c7;
                cursor: not-allowed;
                transform: none;
                box-shadow: none;
            }

            .clear-path-btn {
                background: linear-gradient(135deg, #e74c3c, #c0392b);
                color: white;
                box-shadow: 0 4px 15px rgba(231, 76, 60, 0.3);
            }

            .clear-path-btn:hover:not(:disabled) {
                background: linear-gradient(135deg, #c0392b, #a93226);
                transform: translateY(-2px);
                box-shadow: 0 6px 20px rgba(231, 76, 60, 0.4);
            }

            .clear-path-btn:disabled {
                background: #bdc3c7;
                cursor: not-allowed;
                transform: none;
                box-shadow: none;
            }

            .path-results {
                margin-top: 25px;
                padding: 20px;
                background: linear-gradient(135deg, #f8f9fa, #e9ecef);
                border-radius: 12px;
                border: 1px solid rgba(170, 119, 57, 0.1);
            }

            .path-header {
                margin-bottom: 20px;
            }

            .path-header h4 {
                margin: 0 0 15px 0;
                color: #aa7739;
                font-size: 1.2em;
                font-weight: 600;
            }

            .path-summary {
                display: flex;
                gap: 15px;
                margin-bottom: 20px;
            }

            .summary-item {
                flex: 1;
                background: white;
                padding: 15px;
                border-radius: 10px;
                text-align: center;
                box-shadow: 0 2px 8px rgba(0,0,0,0.05);
                border: 1px solid rgba(170, 119, 57, 0.1);
            }

            .summary-item .icon {
                font-size: 20px;
                display: block;
                margin-bottom: 8px;
            }

            .summary-item .label {
                font-size: 12px;
                color: #666;
                margin-bottom: 5px;
                display: block;
            }

            .summary-item .value {
                font-size: 18px;
                font-weight: bold;
                color: #aa7739;
                display: block;
            }

            .path-list h5 {
                margin: 0 0 15px 0;
                color: #333;
                font-size: 1.1em;
                font-weight: 600;
            }

            .route-steps {
                display: flex;
                flex-direction: column;
                gap: 12px;
            }

            .route-step {
                display: flex;
                align-items: center;
                gap: 15px;
                padding: 15px;
                background: white;
                border-radius: 10px;
                box-shadow: 0 2px 8px rgba(0,0,0,0.05);
                border: 1px solid rgba(170, 119, 57, 0.1);
                transition: all 0.3s ease;
            }

            .route-step:hover {
                transform: translateX(5px);
                box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            }

            .step-number {
                background: #aa7739;
                color: white;
                width: 28px;
                height: 28px;
                border-radius: 50%;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 12px;
                font-weight: bold;
                flex-shrink: 0;
            }

            .step-icon {
                font-size: 20px;
                flex-shrink: 0;
            }

            .step-content {
                flex: 1;
            }

            .step-name {
                font-weight: 600;
                color: #333;
                margin-bottom: 2px;
            }

            .step-type {
                font-size: 12px;
                color: #666;
            }

            .nearby-pagodas {
                margin-top: 20px;
                padding-top: 20px;
                border-top: 1px solid rgba(170, 119, 57, 0.2);
            }

            .nearby-pagodas h5 {
                margin: 0 0 15px 0;
                color: #333;
                font-size: 1.1em;
                font-weight: 600;
            }

            .nearby-list {
                display: flex;
                flex-direction: column;
                gap: 8px;
            }

            .nearby-item {
                display: flex;
                justify-content: space-between;
                align-items: center;
                padding: 10px 15px;
                background: white;
                border-radius: 8px;
                border: 1px solid rgba(170, 119, 57, 0.1);
                transition: all 0.3s ease;
            }

            .nearby-item:hover {
                background: rgba(170, 119, 57, 0.05);
                transform: translateX(3px);
            }

            .nearby-name {
                font-weight: 500;
                color: #333;
            }

            .nearby-distance {
                color: #666;
                font-size: 12px;
                background: rgba(170, 119, 57, 0.1);
                padding: 4px 8px;
                border-radius: 12px;
            }

            .pathfinder-error {
                margin-top: 15px;
            }

            .error-message {
                background: #f8d7da;
                color: #721c24;
                padding: 15px;
                border-radius: 10px;
                border: 1px solid #f5c6cb;
                display: flex;
                align-items: center;
                gap: 12px;
            }

            .error-icon {
                font-size: 18px;
            }

            .error-text {
                flex: 1;
                font-weight: 500;
            }

            .error-close {
                background: none;
                border: none;
                color: #721c24;
                cursor: pointer;
                font-size: 18px;
                padding: 0;
                width: 24px;
                height: 24px;
                border-radius: 50%;
                transition: all 0.3s ease;
            }

            .error-close:hover {
                background: rgba(114, 28, 36, 0.1);
            }

            .path-marker-container {
                background: none !important;
                border: none !important;
            }

            .path-marker {
                width: 32px;
                height: 32px;
                border-radius: 50%;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 16px;
                box-shadow: 0 4px 12px rgba(0,0,0,0.3);
                border: 3px solid white;
                transition: all 0.3s ease;
            }

            .path-marker:hover {
                transform: scale(1.2);
            }

            .path-marker.start {
                background: #27ae60;
            }

            .path-marker.end {
                background: #e74c3c;
            }

            .path-marker.waypoint {
                background: #3498db;
            }

            .path-marker-popup h4 {
                margin: 0 0 8px 0;
                color: #aa7739;
                font-weight: 600;
            }

            .path-marker-popup p {
                margin: 5px 0;
                font-size: 12px;
                color: #666;
            }

            @media (max-width: 768px) {
                .pathfinder-panel {
                    position: fixed;
                    top: 0;
                    right: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    border-radius: 0;
                    max-height: 100vh;
                }
                
                .path-summary {
                    flex-direction: column;
                }
            }
        `;
    document.head.appendChild(style);
  }

  // Method to be called when map is initialized
  setMap(mapInstance) {
    this.map = mapInstance;
  }

  /**
   * Generate road-based path coordinates instead of straight lines
   * This creates waypoints that follow realistic road patterns
   */
  generateRoadPath(coordinates) {
    if (coordinates.length < 2) {
      return coordinates.map(coord => [coord.lat, coord.lng]);
    }

    const roadPath = [];
    
    for (let i = 0; i < coordinates.length - 1; i++) {
      const start = coordinates[i];
      const end = coordinates[i + 1];
      
      // Add start point
      roadPath.push([start.lat, start.lng]);
      
      // Generate intermediate waypoints that follow road patterns
      const intermediatePoints = this.generateIntermediateWaypoints(start, end);
      roadPath.push(...intermediatePoints);
    }
    
    // Add the final point
    const lastPoint = coordinates[coordinates.length - 1];
    roadPath.push([lastPoint.lat, lastPoint.lng]);
    
    return roadPath;
  }

  /**
   * Generate intermediate waypoints between two pagodas
   * This simulates following actual roads instead of straight lines
   */
  generateIntermediateWaypoints(start, end) {
    const waypoints = [];
    
    // Calculate distance between points
    const distance = this.calculateDistance(start.lat, start.lng, end.lat, end.lng);
    
    // If distance is small (< 1km), no intermediate points needed
    if (distance < 1.0) {
      return waypoints;
    }
    
    // Generate 2-4 intermediate points based on distance
    const numPoints = Math.min(Math.max(2, Math.floor(distance / 0.5)), 4);
    
    for (let i = 1; i < numPoints; i++) {
      const ratio = i / numPoints;
      
      // Add some randomness to simulate road curves
      const latOffset = (Math.random() - 0.5) * 0.001; // Small random offset
      const lngOffset = (Math.random() - 0.5) * 0.001;
      
      const lat = start.lat + (end.lat - start.lat) * ratio + latOffset;
      const lng = start.lng + (end.lng - start.lng) * ratio + lngOffset;
      
      waypoints.push([lat, lng]);
    }
    
    return waypoints;
  }

  /**
   * Calculate distance between two coordinates using Haversine formula
   */
  calculateDistance(lat1, lng1, lat2, lng2) {
    const R = 6371; // Earth radius in km
    const dLat = this.toRadians(lat2 - lat1);
    const dLng = this.toRadians(lng2 - lng1);
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
              Math.cos(this.toRadians(lat1)) * Math.cos(this.toRadians(lat2)) *
              Math.sin(dLng / 2) * Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  toRadians(degrees) {
    return degrees * (Math.PI / 180);
  }

  /**
   * Sample coordinates to reduce the number of points for smoother visualization
   */
  sampleCoordinates(coordinates, maxPoints) {
    if (coordinates.length <= maxPoints) {
      return coordinates;
    }
    
    const sampled = [];
    const step = coordinates.length / maxPoints;
    
    // Always include the first and last points
    sampled.push(coordinates[0]);
    
    for (let i = 1; i < maxPoints - 1; i++) {
      const index = Math.floor(i * step);
      sampled.push(coordinates[index]);
    }
    
    // Always include the last point
    sampled.push(coordinates[coordinates.length - 1]);
    
    return sampled;
  }
}

// Export for use in other modules
if (typeof module !== "undefined" && module.exports) {
  module.exports = PathfinderUI;
} else {
  window.PathfinderUI = PathfinderUI;
}
