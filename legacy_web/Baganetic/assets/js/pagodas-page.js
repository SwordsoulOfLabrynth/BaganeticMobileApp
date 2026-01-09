// Pagodas Page - Handles all pagoda listing and search functionality
// This file contains all the logic that was previously inline in pagodas.html

document.addEventListener("DOMContentLoaded", function () {
  function isMyanmarPage() {
    const p = (window.location.pathname || '').toLowerCase();
    const file = (p.split('/').pop() || '');
    return p.includes('/mmversion/') || /mm\.html$/i.test(file) || /indexmm\.html$/i.test(file);
  }
  const inMM = isMyanmarPage();
  // If a global auth manager is present, defer all auth/dropdown UI to it
  const useGlobalAuth = typeof window.authManager !== "undefined";

  // Login/Signup popup DOM references (used only when no global auth)
  const loginTrigger = document.getElementById("loginTrigger");
  const loginPopup = document.getElementById("loginPopup");
  const closePopup = document.getElementById("closePopup");
  const popupLoginForm = document.getElementById("popupLoginForm");
  const popupSignupForm = document.getElementById("popupSignupForm");
  const popupErrorMessage = document.getElementById("popupErrorMessage");
  const popupSuccessMessage = document.getElementById("popupSuccessMessage");
  const signupErrorMessage = document.getElementById("signupErrorMessage");
  const signupSuccessMessage = document.getElementById("signupSuccessMessage");
  const notificationDropdown = document.getElementById("notificationDropdown");

  // Form toggle functionality
  const toggleBtns = document.querySelectorAll(".toggle-btn");
  const toggleLinks = document.querySelectorAll(".toggle-link");
  const loginForm = document.querySelector(".login-form");
  const signupForm = document.querySelector(".signup-form");

  // When global auth is managing UI, do not attach duplicate handlers
  if (!useGlobalAuth) {
    // Show login popup (guard if trigger exists)
    if (loginTrigger) {
      loginTrigger.addEventListener("click", showLoginPopup);
    }

    // Close login popup
    if (closePopup && loginPopup) {
      closePopup.addEventListener("click", function () {
        loginPopup.style.display = "none";
        document.body.style.overflow = ""; // Restore scrolling
        resetForms();
      });
    }

  // Close popup when clicking outside
    window.addEventListener("click", function (event) {
      if (event.target === loginPopup) {
        loginPopup.style.display = "none";
        document.body.style.overflow = "";
        resetForms();
      }
    });

  // Form toggle functionality
  function toggleForm(formType) {
    if (formType === "login") {
      loginForm.classList.add("active");
      signupForm.classList.remove("active");
      toggleBtns[0].classList.add("active");
      toggleBtns[1].classList.remove("active");
      toggleLinks[0].style.display = "none";
      toggleLinks[1].style.display = "inline";
    } else {
      loginForm.classList.remove("active");
      signupForm.classList.add("active");
      toggleBtns[0].classList.remove("active");
      toggleBtns[1].classList.add("active");
      toggleLinks[0].style.display = "inline";
      toggleLinks[1].style.display = "none";
    }
    resetForms();
  }

    toggleBtns.forEach((btn) => {
      btn.addEventListener("click", () => {
        toggleForm(btn.dataset.form);
      });
    });

    toggleLinks.forEach((link) => {
      link.addEventListener("click", (e) => {
        e.preventDefault();
        toggleForm(link.dataset.form);
      });
    });

  // Reset form states
  function resetForms() {
    popupErrorMessage.style.display = "none";
    popupSuccessMessage.style.display = "none";
    signupErrorMessage.style.display = "none";
    signupSuccessMessage.style.display = "none";
  }

  // Handle login form submission (local auth only)
  if (!useGlobalAuth && popupLoginForm) popupLoginForm.addEventListener("submit", async function (event) {
    event.preventDefault();
    const username = document.getElementById("popupUsername").value.trim();
    const password = document.getElementById("popupPassword").value.trim();

    if (!username || !password) {
      popupErrorMessage.textContent =
        "Please enter both username and password.";
      popupErrorMessage.style.display = "block";
      return;
    }

    try {
      const res = await fetch("/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: 'include',
        body: JSON.stringify({ username, password }),
      });
      const data = await res.json();

      if (data.success) {
        popupSuccessMessage.style.display = "block";
        popupErrorMessage.style.display = "none";
        popupLoginForm.reset();

        // Soft-refresh: update UI via AuthManager and re-init chatbot
        try {
          if (window.authManager && typeof window.authManager.updateUIForAuthenticatedUser === 'function') {
            window.authManager.updateUIForAuthenticatedUser();
          }
          if (typeof window.initializeChatbot === 'function') {
            setTimeout(() => window.initializeChatbot(), 50);
          }
        } catch (e) {
          console.warn('Soft refresh after popup login failed:', e);
        }

        // Store user session and a fallback token for persistence
        localStorage.setItem("userLoggedIn", "true");
        localStorage.setItem("username", username);
        // use backend token if provided, otherwise a local placeholder
        if (data.token) {
          localStorage.setItem("authToken", data.token);
        } else {
          localStorage.setItem("authToken", "local");
        }
        // Optionally store basic profile fields if returned
        if (data.user) {
          if (data.user.fullName) localStorage.setItem("userFullName", data.user.fullName);
          if (data.user.email) localStorage.setItem("userEmail", data.user.email);
        }

        // If global AuthManager exists, let it own the UI update
        if (window.authManager && typeof window.authManager.handleSuccessfulLogin === "function") {
          try {
            window.authManager.handleSuccessfulLogin(
              {
                username: username,
                fullName: localStorage.getItem("userFullName") || username,
                email: localStorage.getItem("userEmail") || "",
                profile: { avatar: localStorage.getItem("userAvatarUrl") || "default" },
              },
              localStorage.getItem("authToken")
            );
          } catch (e) {
            console.warn("AuthManager UI update failed, falling back to local UI", e);
          }
        }

        setTimeout(() => {
          loginPopup.style.display = "none";
          document.body.style.overflow = "";
          updateLoginButton(username);
        }, 1500);
      } else {
        popupErrorMessage.innerText = data.message || "Login failed";
        popupErrorMessage.style.display = "block";
      }
    } catch (err) {
      console.error(err);
      popupErrorMessage.innerText = "An error occurred. Please try again.";
      popupErrorMessage.style.display = "block";
    }
  });

  // Handle signup form submission (local auth only)
  if (!useGlobalAuth && popupSignupForm) popupSignupForm.addEventListener("submit", async function (event) {
    event.preventDefault();
    const fullName = document.getElementById("signupFullName").value.trim();
    const email = document.getElementById("signupEmail").value.trim();
    const username = document.getElementById("signupUsername").value.trim();
    const password = document.getElementById("signupPassword").value;
    const confirmPassword = document.getElementById(
      "signupConfirmPassword"
    ).value;

    // Validation
    if (!fullName || !email || !username || !password || !confirmPassword) {
      signupErrorMessage.textContent = "Please fill in all fields.";
      signupErrorMessage.style.display = "block";
      return;
    }

    if (password.length < 6) {
      signupErrorMessage.textContent =
        "Password must be at least 6 characters.";
      signupErrorMessage.style.display = "block";
      return;
    }

    if (password !== confirmPassword) {
      signupErrorMessage.textContent = "Passwords do not match.";
      signupErrorMessage.style.display = "block";
      return;
    }

    if (!validateEmail(email)) {
      signupErrorMessage.textContent = "Please enter a valid email address.";
      signupErrorMessage.style.display = "block";
      return;
    }

    try {
      const res = await fetch("/signup", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ fullName, email, username, password }),
      });
      const data = await res.json();

      if (data.success) {
        signupSuccessMessage.style.display = "block";
        signupErrorMessage.style.display = "none";
        popupSignupForm.reset();

        // Auto-switch to login form after successful signup
        setTimeout(() => {
          toggleForm("login");
          popupSuccessMessage.textContent = "Account created! Please log in.";
          popupSuccessMessage.style.display = "block";
        }, 2000);
      } else {
        signupErrorMessage.innerText = data.message || "Signup failed";
        signupErrorMessage.style.display = "block";
      }
    } catch (err) {
      console.error(err);
      signupErrorMessage.innerText = "An error occurred. Please try again.";
      signupErrorMessage.style.display = "block";
    }
  });

  }

  // Email validation function
  function validateEmail(email) {
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return re.test(email);
  }

  // Update login button after successful login
  function updateLoginButton(username) {
    if (useGlobalAuth) return; // global auth owns UI
    if (!loginTrigger) return;
    loginTrigger.innerHTML = `
      <div class="user-profile-container">
          <div class="user-avatar-small">
              <span class="user-initial">${username
                .charAt(0)
                .toUpperCase()}</span>
          </div>
          <div class="user-info-small">
              <span class="user-name-display">${username}</span>
              <span class="user-status">Online</span>
          </div>
          <div class="dropdown-arrow">
              <svg width="12" height="8" viewBox="0 0 12 8" fill="none">
                  <path d="M1 1.5L6 6.5L11 1.5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
          </div>
      </div>
    `;
    loginTrigger.style.color = "#aa7739";
    loginTrigger.classList.add("logged-in");

    // Remove the original login popup event listener
    loginTrigger.removeEventListener("click", showLoginPopup);
    // Add dropdown toggle event listener (avoid duplicates)
    loginTrigger.addEventListener("click", toggleUserDropdown, { once: false });
    // Create and show user dropdown
    createUserDropdown();
  }

  // Function to show login popup (extracted for better event handling)
  function showLoginPopup() {
    loginPopup.style.display = "block";
    document.body.style.overflow = "hidden";
  }

  // Create user dropdown menu
  function createUserDropdown() {
    if (useGlobalAuth) return; // global auth owns UI
    // Remove existing dropdown if any
    const existingDropdown = document.getElementById("userDropdown");
    if (existingDropdown) {
      existingDropdown.remove();
    }

    const username = localStorage.getItem("username") || "User";
    const userFullName = localStorage.getItem("userFullName") || "";
    const userEmail = localStorage.getItem("userEmail") || "";

    const dropdown = document.createElement("div");
    dropdown.id = "userDropdown";
    dropdown.className = "user-dropdown";
    dropdown.innerHTML = `
      <div class="dropdown-content">
          <div class="dropdown-header">
              <div class="user-avatar">
                  <span class="user-initial-large">${(
                    userFullName ||
                    username ||
                    "U"
                  )
                    .charAt(0)
                    .toUpperCase()}</span>
              </div>
              <div class="user-info">
                  <div class="user-name">${userFullName || username}</div>
                  <div class="user-email">${userEmail}</div>
                  <div class="user-status-indicator">
                      <span class="status-dot"></span>
                      <span class="status-text">Online</span>
                  </div>
              </div>
          </div>
          <div class="dropdown-divider"></div>
          <a href="#" class="dropdown-item" id="profileBtn">
              <div class="dropdown-icon">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
                      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                      <circle cx="12" cy="7" r="4" stroke="currentColor" stroke-width="2"/>
                  </svg>
              </div>
              <span class="dropdown-text">My Profile</span>
          </a>
          <a href="#" class="dropdown-item" id="favoritesBtn">
              <div class="dropdown-icon">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
                      <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                  </svg>
              </div>
              <span class="dropdown-text">My Favorites</span>
          </a>
          <a href="#" class="dropdown-item" id="settingsBtn">
              <div class="dropdown-icon">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
                      <circle cx="12" cy="12" r="3" stroke="currentColor" stroke-width="2"/>
                      <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1 1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                  </svg>
              </div>
              <span class="dropdown-text">Settings</span>
          </a>
          <div class="dropdown-divider"></div>
          <a href="#" class="dropdown-item logout-item" id="logoutBtn">
              <div class="dropdown-icon">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
                      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                      <polyline points="16,17 21,12 16,7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                      <line x1="21" y1="12" x2="9" y2="12" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                  </svg>
              </div>
              <span class="dropdown-text">Logout</span>
          </a>
      </div>
    `;

    // Attach dropdown to body to avoid clipping/overflow on this page
    document.body.appendChild(dropdown);

    // Set initial state
    dropdown.style.display = "none";

    // Add event listeners
    const logoutBtn = document.getElementById("logoutBtn");
    const profileBtn = document.getElementById("profileBtn");
    const favoritesBtn = document.getElementById("favoritesBtn");
    const settingsBtn = document.getElementById("settingsBtn");

    if (logoutBtn) logoutBtn.addEventListener("click", handleLogout);
    if (profileBtn)
      profileBtn.addEventListener("click", (e) => {
        e.preventDefault();
        if (window.authManager) {
          window.authManager.editProfile();
        }
      });
    if (favoritesBtn)
      favoritesBtn.addEventListener("click", (e) => {
        e.preventDefault();
        if (window.authManager) {
          window.authManager.showFavoritesModal();
        }
      });
    if (settingsBtn)
      settingsBtn.addEventListener("click", (e) => {
        e.preventDefault();
        if (window.authManager) {
          window.authManager.showSettingsModal();
        }
      });
  }

  // Toggle user dropdown visibility
  // Handle outside click to close dropdown cleanly
  let dropdownOutsideHandler = null;

  function toggleUserDropdown(event) {
    if (useGlobalAuth) return; // global auth owns UI
    event.preventDefault();
    event.stopPropagation();
    let dropdown = document.getElementById("userDropdown");
    if (!dropdown) {
      // Create it on-demand if missing
      createUserDropdown();
      dropdown = document.getElementById("userDropdown");
      if (!dropdown) return;
    }

    const isOpen = dropdown.classList.contains("show");
    if (isOpen) {
      dropdown.classList.remove("show");
      dropdown.style.display = "none";
      if (dropdownOutsideHandler) {
        document.removeEventListener("click", dropdownOutsideHandler, true);
        dropdownOutsideHandler = null;
      }
    } else {
      dropdown.classList.add("show");
      // Position near trigger using viewport coords to bypass parent overflow
      const rect = loginTrigger.getBoundingClientRect();
      dropdown.style.position = "fixed";
      dropdown.style.zIndex = "5000";
      dropdown.style.display = "block";
      // compute left to align right edges, clamp within viewport
      const dropdownWidth = dropdown.offsetWidth || 320;
      const left = Math.max(8, Math.min(window.innerWidth - dropdownWidth - 8, rect.right - dropdownWidth));
      dropdown.style.left = left + "px";
      dropdown.style.top = rect.bottom + 8 + "px";
      // Close when clicking outside (defer binding to avoid catching the same click)
      dropdownOutsideHandler = function (e) {
        const isClickInside = dropdown.contains(e.target) || e.target === loginTrigger;
        if (!isClickInside) {
          dropdown.classList.remove("show");
          dropdown.style.display = "none";
          document.removeEventListener("click", dropdownOutsideHandler, true);
          dropdownOutsideHandler = null;
        }
      };
      setTimeout(() => {
        document.addEventListener("click", dropdownOutsideHandler, true);
      }, 0);
      // Prevent clicks inside from bubbling and closing immediately
      dropdown.addEventListener("click", function (e) {
        e.stopPropagation();
      });
    }
  }

  // Handle logout functionality
  async function handleLogout(event) {
    if (useGlobalAuth) return;
    event.preventDefault();

    try {
      // Call backend logout endpoint
      const res = await fetch("/logout", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
      });

      const data = await res.json();

      if (data.success) {
        // Clear localStorage
        localStorage.removeItem("userLoggedIn");
        localStorage.removeItem("username");

        // Reset login button
        resetLoginButton();

        // Remove user dropdown
        const dropdown = document.getElementById("userDropdown");
        if (dropdown) {
          dropdown.remove();
        }

        console.log("Logout successful");
      } else {
        console.error("Logout failed:", data.message);
        // Still clear localStorage and reset UI even if backend fails
        localStorage.removeItem("userLoggedIn");
        localStorage.removeItem("username");
        resetLoginButton();
      }
    } catch (error) {
      console.error("Logout error:", error);
      // Clear localStorage and reset UI even if request fails
      localStorage.removeItem("userLoggedIn");
      localStorage.removeItem("username");
      resetLoginButton();
    }
  }

  // Reset login button to original state
  function resetLoginButton() {
    if (useGlobalAuth) return;
    if (!loginTrigger) return;
    loginTrigger.textContent = "Login";
    loginTrigger.style.color = "";
    loginTrigger.classList.remove("logged-in");

    // Remove dropdown event listener
    loginTrigger.removeEventListener("click", toggleUserDropdown);

    // Add back the original login popup event listener
    loginTrigger.addEventListener("click", showLoginPopup);

    // Remove dropdown if exists
    const dropdown = document.getElementById("userDropdown");
    if (dropdown) {
      dropdown.remove();
    }
  }

  // Check if user is already logged in
  if (!useGlobalAuth) {
    function checkLoginStatus() {
      const isLoggedIn = localStorage.getItem("userLoggedIn");
      const username = localStorage.getItem("username");
      if (isLoggedIn === "true" && username) {
        updateLoginButton(username);
      }
    }
    // Initialize login status for local auth
    checkLoginStatus();
  }

  // === PAGODA DATABASE INTEGRATION ===

  // Initialize pagoda display
  function initializePagodas() {
    if (typeof window.pagodaManager === "undefined") {
      console.error("Pagoda Manager not loaded");
      return;
    }

    // Get all pagodas from database
    const allPagodas = window.pagodaManager.getAllPagodas();
    displayPagodas(allPagodas);

    console.log(`Loaded ${allPagodas.length} pagodas from database`);
  }

  // Display pagodas in the grid
  function displayPagodas(pagodas) {
    const pagodaGrid = document.getElementById("pagodaGrid");

    if (pagodas.length === 0) {
      pagodaGrid.innerHTML =
        '<p style="text-align: center; color: #666; grid-column: 1/-1;">No pagodas available.</p>';
      return;
    }

    // Generate HTML for all pagodas
    const pagodaCards = pagodas
      .map((pagoda) => {
        const img = (pagoda.images && (pagoda.images.main || pagoda.images.thumbnail)) || './assets/images/placeholder-pagoda.jpg';
        const name = pagoda.name || (pagoda.id || '');
        const desc = (pagoda.description && (pagoda.description.short || pagoda.description.long)) || '';
        const city = (pagoda.location && pagoda.location.city) || '';
        const type = pagoda.type || '';
        const built = (pagoda.history && pagoda.history.built) || '';
        const preferred = (pagoda.detailPage && pagoda.detailPage.trim());
        const targetUrl = (function() {
          if (preferred) return preferred;
          if (inMM) return `/mmversion/pagodaDetailsmm.html?id=${pagoda.id}&mm=1`;
          return `pagodaDetils.html?id=${pagoda.id}`;
        })();
        return `
          <div class="pagoda-card" data-pagoda-id="${pagoda.id}">
            <img src="${img}" alt="${name}" loading="lazy" onerror="this.src='./assets/images/placeholder-pagoda.jpg'">
            <div class="pagoda-card-content">
              <h3>${name}</h3>
              <p>${desc}</p>
              <div class="pagoda-meta" style="margin-bottom: 15px; font-size: 0.9rem; color: #888;">
                <span>📍 ${city}</span> • 
                <span>🏛️ ${type}</span> • 
                <span>📅 ${built}</span>
              </div>
              <div class="card-footer">
                <a href="${targetUrl}" class="read-more-btn">Explore Details</a>
              </div>
            </div>
          </div>
        `;
      })
      .join("");

    pagodaGrid.innerHTML = pagodaCards;

    // Add click event listeners to pagoda cards
    const pagodaCardsElements = pagodaGrid.querySelectorAll(".pagoda-card");
    pagodaCardsElements.forEach((card) => {
      card.addEventListener("click", function () {
        const pagodaId = this.getAttribute("data-pagoda-id");
        const p = pagodas.find((x) => x.id === pagodaId) || {};
        const preferred = (p.detailPage && p.detailPage.trim());
        // EN behavior: go to dynamic details; MM behavior: same dynamic details first
        const url = preferred || (inMM ? `mmversion/pagodaDetailsmm.html?id=${pagodaId}` : `pagodaDetils.html?id=${pagodaId}`);
        window.location.href = url;
      });
      card.style.cursor = "pointer";
    });

    // Add favorite buttons after rendering
    setTimeout(() => {
      if (typeof addFavoriteButtonsToPagodaCards === "function") {
        addFavoriteButtonsToPagodaCards();
      }
    }, 100);

    // Update grid class based on number of results
    updateGridLayout(pagodas.length);
  }

  // Update grid layout based on result count
  function updateGridLayout(count) {
    const pagodaGrid = document.getElementById("pagodaGrid");

    if (count === 1) {
      pagodaGrid.className = "pagoda-grid one-result";
    } else if (count === 2) {
      pagodaGrid.className = "pagoda-grid two-results";
    } else if (count === 3) {
      pagodaGrid.className = "pagoda-grid three-results";
    } else {
      pagodaGrid.className = "pagoda-grid";
    }
  }

  // Enhanced search functionality using database
  function searchPagodas(query) {
    if (typeof window.pagodaManager === "undefined") {
      console.error("Pagoda Manager not loaded");
      return;
    }

    const results = window.pagodaManager.search(query);
    const noResults = document.getElementById("noResults");
    const pagodaGrid = document.getElementById("pagodaGrid");

    if (results.length === 0 && query.trim() !== "") {
      noResults.style.display = "block";
      pagodaGrid.style.display = "none";
    } else {
      noResults.style.display = "none";
      pagodaGrid.style.display = "grid";
      displayPagodas(results);
    }
  }

  // Wait for pagoda manager to be ready, then initialize
  function waitForPagodaManager() {
    if (typeof window.pagodaManager !== "undefined") {
      initializePagodas();
      setupSearchFunctionality();
      setupClearSearch();
    } else {
      console.log("Waiting for PagodaManager to load...");
      setTimeout(waitForPagodaManager, 100);
    }
  }

  // Setup search functionality
  function setupSearchFunctionality() {
    const searchInput = document.getElementById("searchInput");
    const searchButton = document.getElementById("searchButton");

    function filterPagodas() {
      const query = searchInput.value.trim();
      searchPagodas(query);
    }

    searchButton.addEventListener("click", filterPagodas);
    searchInput.addEventListener("input", filterPagodas); // instant search
  }

  // Start waiting for pagoda manager
  waitForPagodaManager();

  // Clear search functionality - will be set up after pagoda manager loads
  function setupClearSearch() {
    const clearSearchBtn = document.getElementById("clearSearch");
    if (clearSearchBtn) {
      clearSearchBtn.addEventListener("click", function () {
        const searchInput = document.getElementById("searchInput");
        if (searchInput) {
          searchInput.value = "";
        }

        // Show all pagodas from database
        if (typeof window.pagodaManager !== "undefined") {
          const allPagodas = window.pagodaManager.getAllPagodas();
          displayPagodas(allPagodas);
          document.getElementById("noResults").style.display = "none";
          document.getElementById("pagodaGrid").style.display = "grid";
        }
      });
    }
  }

  // Make functions globally accessible
  window.searchPagodas = searchPagodas;
  window.displayPagodas = displayPagodas;
  window.updateGridLayout = updateGridLayout;
});
