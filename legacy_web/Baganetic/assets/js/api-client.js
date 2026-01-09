// API Client - Handles communication between frontend and backend servers
// Node.js server (port 3000) serves the frontend
// Flask server (port 5000) provides A* pathfinding API

class APIClient {
  constructor() {
    this.baseURL = ""; // Same origin (Node.js server)
    this.flaskAPI = "http://localhost:5000"; // Flask A* API
  }

  // === PAGODA DATA (via Node.js server) ===

  async getPagodas() {
    try {
      const response = await fetch(`${this.baseURL}/api/pagodas`);
      const data = await response.json();
      return data.success ? data.data : [];
    } catch (error) {
      console.error("Error fetching pagodas:", error);
      return [];
    }
  }

  async getPagoda(id) {
    try {
      const response = await fetch(`${this.baseURL}/api/pagodas/${id}`);
      const data = await response.json();
      return data.success ? data.data : null;
    } catch (error) {
      console.error("Error fetching pagoda:", error);
      return null;
    }
  }

  async getFeaturedPagodas() {
    try {
      const response = await fetch(`${this.baseURL}/api/pagodas/featured`);
      const data = await response.json();
      return data.success ? data.data : [];
    } catch (error) {
      console.error("Error fetching featured pagodas:", error);
      return [];
    }
  }

  // === PATHFINDING (via Flask A* API) ===

  async findPath(start, end) {
    try {
      // Get authentication token
      const token = localStorage.getItem('authToken');
      if (!token) {
        return { success: false, error: 'Authentication required. Please log in to use the pathfinding feature.' };
      }

      const response = await fetch(
        `${this.flaskAPI}/api/pathfinder/find-path`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${token}`,
          },
          body: JSON.stringify({ start, end }),
        }
      );
      const data = await response.json();
      return data;
    } catch (error) {
      console.error("Error finding path:", error);
      return { success: false, error: "Pathfinding service unavailable" };
    }
  }

  async getPathfinderPagodas() {
    try {
      const response = await fetch(`${this.flaskAPI}/api/pathfinder/pagodas`);
      const data = await response.json();
      return data.success ? data.data : [];
    } catch (error) {
      console.error("Error fetching pathfinder pagodas:", error);
      return [];
    }
  }

  async getNearbyPagodas(pagodaName, distance = 1.0) {
    try {
      const response = await fetch(
        `${this.flaskAPI}/api/pathfinder/nearby/${pagodaName}?distance=${distance}`
      );
      const data = await response.json();
      return data.success ? data.data : [];
    } catch (error) {
      console.error("Error fetching nearby pagodas:", error);
      return [];
    }
  }

  // === HEALTH CHECKS ===

  async checkFlaskHealth() {
    try {
      const response = await fetch(`${this.flaskAPI}/api/health`);
      const data = await response.json();
      return data.status === "healthy";
    } catch (error) {
      console.error("Flask API health check failed:", error);
      return false;
    }
  }

  async checkNodeHealth() {
    try {
      // First try the health endpoint
      const healthResponse = await fetch(`${this.baseURL}/api/health`);
      if (healthResponse.ok) {
        const data = await healthResponse.json();
        return data.status === "healthy";
      }
      
      // Fallback: check if main page loads (indicates server is running)
      const mainResponse = await fetch(`${this.baseURL}/`);
      return mainResponse.ok;
    } catch (error) {
      console.error("Node.js API health check failed:", error);
      return false;
    }
  }

  // === UTILITY METHODS ===

  async initialize() {
    console.log("🔧 Initializing API Client...");

    // Check both servers
    const flaskHealthy = await this.checkFlaskHealth();
    const nodeHealthy = await this.checkNodeHealth();

    console.log(
      `Flask A* API: ${flaskHealthy ? "✅ Healthy" : "❌ Unavailable"}`
    );
    console.log(
      `Node.js Server: ${nodeHealthy ? "✅ Healthy" : "❌ Unavailable"}`
    );

    if (!flaskHealthy) {
      console.warn(
        "⚠️ Flask A* API is not available. Pathfinding features will be disabled."
      );
    }

    if (!nodeHealthy) {
      console.warn(
        "⚠️ Node.js server is not available. Some features may not work."
      );
    }

    return { flaskHealthy, nodeHealthy };
  }
}

// Create global API client instance
window.apiClient = new APIClient();

// Initialize when DOM is loaded
document.addEventListener("DOMContentLoaded", () => {
  window.apiClient.initialize();
});

// Export for use in other files
if (typeof module !== "undefined" && module.exports) {
  module.exports = APIClient;
}
