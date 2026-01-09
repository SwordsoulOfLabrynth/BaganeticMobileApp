// Baganetic Authentication Management System
class AuthManager {
  constructor() {
    this.isAuthenticated = false;
    this.currentUser = null;
    this.authToken = null;
    this.translations = {
      en: {
        // Profile translations
        'My Profile': 'My Profile',
        'Manage your account information': 'Manage your account information',
        'Personal Information': 'Personal Information',
        'Account Statistics': 'Account Statistics',
        'Profile Completion': 'Profile Completion',
        'Favorite Pagodas': 'Favorite Pagodas',
        'Visited Pagodas': 'Visited Pagodas',
        'Profile Complete': 'Profile Complete',
        'Member Since': 'Member Since',
        'Add your full name': 'Add your full name',
        'Write a bio': 'Write a bio',
        'Upload profile picture': 'Upload profile picture',
        'Verify email address': 'Verify email address',
        'Add favorite pagodas': 'Add favorite pagodas',
        'Mark visited pagodas': 'Mark visited pagodas',
        'Edit Profile': 'Edit Profile',
        'Change Password': 'Change Password',
        'Export Data': 'Export Data',
      },
      my: {
        // Profile translations
        'My Profile': 'ကျွန်ုပ်၏ ပရိုဖိုင်',
        'Manage your account information': 'သင့်အကောင့်အချက်အလက်များကို စီမံပါ',
        'Personal Information': 'ကိုယ်ရေးကိုယ်တာ အချက်အလက်များ',
        'Account Statistics': 'အကောင့် စာရင်းအင်းများ',
        'Profile Completion': 'ပရိုဖိုင် ပြီးမြောက်မှု',
        'Favorite Pagodas': 'အကြိုက်ဆုံး စေတီများ',
        'Visited Pagodas': 'သွားရောက်ခဲ့သော စေတီများ',
        'Profile Complete': 'ပရိုဖိုင် ပြီးမြောက်ပါပြီ',
        'Member Since': 'အဖွဲ့ဝင် စတင်သည့်နေ့',
        'Add your full name': 'သင့်အမည်အပြည့်အစုံ ထည့်ပါ',
        'Write a bio': 'ကိုယ်ရေးရာဇဝင် ရေးပါ',
        'Upload profile picture': 'ပရိုဖိုင် ပုံတင်ပါ',
        'Verify email address': 'အီးမေးလ် လိပ်စာ အတည်ပြုပါ',
        'Add favorite pagodas': 'အကြိုက်ဆုံး စေတီများ ထည့်ပါ',
        'Mark visited pagodas': 'သွားရောက်ခဲ့သော စေတီများ မှတ်သားပါ',
        'Edit Profile': 'ပရိုဖိုင် တည်းဖြတ်ပါ',
        'Change Password': 'စကားဝှက် ပြောင်းပါ',
        'Export Data': 'ဒေတာ ထုတ်ယူပါ',
      }
    };
    this.init();
  }

  init() {
    this.checkAuthState();
    // Also attempt to refresh profile from backend if we have a token
    const token = localStorage.getItem("authToken");
    if (token) {
      this.fetchProfileFromServer(token);
    }
    this.setupEventListeners();
    this.startAuthHeartbeat();
  }

  checkAuthState() {
    const storedToken = localStorage.getItem("authToken");
    const userLoggedIn = localStorage.getItem("userLoggedIn");

    // Treat previously logged-in users as authenticated even if token is missing
    if (userLoggedIn === "true") {
      this.authToken = storedToken || "local";
      this.isAuthenticated = true;
      this.currentUser = {
        username: localStorage.getItem("username") || "",
        email: localStorage.getItem("userEmail") || "",
        fullName: localStorage.getItem("userFullName") || "",
        profile: {
          avatar: localStorage.getItem("userAvatarUrl") || "default",
        },
      };
      // Persist the default token if it was missing so future reloads work
      if (!storedToken) {
        try { localStorage.setItem("authToken", this.authToken); } catch (e) {}
      }
      this.updateUIForAuthenticatedUser();
      return;
    }

    this.clearAuthState();
    this.updateUIForUnauthenticatedUser();
  }

  updateUIForAuthenticatedUser() {
    if (this.currentUser) {
      const displayName = this.currentUser.fullName || this.currentUser.username;
      this.updateLoginButton(displayName);
      // Always refresh dropdown to reflect latest profile data
      const existingDropdown = document.getElementById("userDropdown");
      if (existingDropdown) existingDropdown.remove();
      this.createUserDropdown();
    }
  }

  async fetchProfileFromServer(token) {
    try {
      const res = await fetch("/me", {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) return; // silently ignore if backend not available
      const data = await res.json();
      if (data && data.authenticated && data.user) {
        this.currentUser = {
          username: data.user.username,
          email: data.user.email,
          fullName: data.user.fullName,
          profile: { avatar: (data.user.profile && data.user.profile.avatar) || "default" },
        };
        if (data.user.fullName) localStorage.setItem("userFullName", data.user.fullName || "");
        if (data.user.email) localStorage.setItem("userEmail", data.user.email || "");
        if (data.user.username) localStorage.setItem("username", data.user.username || "");
        if (data.user.profile && data.user.profile.avatar) {
          localStorage.setItem("userAvatarUrl", data.user.profile.avatar);
        }
        localStorage.setItem("userLoggedIn", "true");
        this.isAuthenticated = true;
        this.updateUIForAuthenticatedUser();
      }
    } catch (_) {
      // network/server unavailable; keep local state
    }
  }

  updateUIForUnauthenticatedUser() {
    const loginTrigger = document.getElementById("loginTrigger");
    const mobileLoginTrigger = document.getElementById("mobileLoginTrigger");
    
    if (loginTrigger) {
      // Remove all existing event listeners by cloning the element
      const newLoginTrigger = loginTrigger.cloneNode(true);
      loginTrigger.parentNode.replaceChild(newLoginTrigger, loginTrigger);

      // Update the reference
      const updatedLoginTrigger = document.getElementById("loginTrigger");
      const inMM = (function(){
        try {
          const p=(window.location.pathname||'').toLowerCase();
          const f=(p.split('/').pop()||'');
          return p.includes('/mmversion/') || /mm\.html$/i.test(f) || /indexmm\.html$/i.test(f);
        } catch (_) { return false; }
      })();
      updatedLoginTrigger.innerHTML = inMM ? "အကောင့်ဝင်ရန်" : "Login";
      // updatedLoginTrigger.innerHTML = "ဝင်ရောက်ရန်";
      updatedLoginTrigger.style.color = "";
      updatedLoginTrigger.classList.remove("logged-in");

      // Remove existing dropdown
      const existingDropdown = document.getElementById("userDropdown");
      if (existingDropdown) {
        existingDropdown.remove();
      }

      // Add the login popup event listener
      updatedLoginTrigger.addEventListener(
        "click",
        this.showLoginPopup.bind(this)
      );
    }

    // Handle mobile login trigger
    if (mobileLoginTrigger) {
      // Remove all existing event listeners by cloning the element
      const newMobileLoginTrigger = mobileLoginTrigger.cloneNode(true);
      mobileLoginTrigger.parentNode.replaceChild(newMobileLoginTrigger, mobileLoginTrigger);

      // Update the reference
      const updatedMobileLoginTrigger = document.getElementById("mobileLoginTrigger");
      
      // Add the login popup event listener
      updatedMobileLoginTrigger.addEventListener(
        "click",
        this.showLoginPopup.bind(this)
      );
    }
  }

  updateLoginButton(username) {
    const existingLoginTrigger = document.getElementById("loginTrigger");
    if (existingLoginTrigger) {
      // Replace the trigger to remove any previously attached listeners
      const freshTrigger = existingLoginTrigger.cloneNode(false);
      // Preserve classes/attributes and id is already copied
      existingLoginTrigger.parentNode.replaceChild(freshTrigger, existingLoginTrigger);

      const avatarUrl = this.currentUser?.profile?.avatar;
      const hasAvatar = avatarUrl && avatarUrl !== "default";
      freshTrigger.innerHTML = `
                <div class="user-profile-container">
                    <div class="user-avatar-small">
                        ${hasAvatar
                          ? `<img src="${avatarUrl}" alt="avatar" style="width:100%;height:100%;border-radius:50%;object-fit:cover;" />`
                          : `<span class=\"user-initial\">${username
                              .charAt(0)
                              .toUpperCase()}</span>`}
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
      freshTrigger.style.color = "#aa7739";
      freshTrigger.classList.add("logged-in");

      // Attach only the dropdown toggle listener
      freshTrigger.addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        this.toggleUserDropdown(e);
      });

      // Ensure dropdown exists/reflects latest user data
      const existingDropdown = document.getElementById("userDropdown");
      if (existingDropdown) existingDropdown.remove();
      this.createUserDropdown();
    }

    // Also update mobile login button
    this.updateMobileLoginButton(username);
  }

  updateMobileLoginButton(username) {
    const mobileLoginTrigger = document.getElementById("mobileLoginTrigger");
    if (mobileLoginTrigger) {
      // Clone to remove existing listeners
      const freshTrigger = mobileLoginTrigger.cloneNode(false);
      mobileLoginTrigger.parentNode.replaceChild(freshTrigger, mobileLoginTrigger);
      
      const avatarUrl = this.currentUser?.profile?.avatar;
      const hasAvatar = avatarUrl && avatarUrl !== "default";
      
      // Update HTML to show profile similar to desktop
      freshTrigger.innerHTML = `
        <div class="user-profile-container">
          <div class="user-avatar-small">
            ${hasAvatar ? `<img src="${avatarUrl}" alt="avatar" style="width:100%;height:100%;border-radius:50%;object-fit:cover;" />` : `<span class="user-initial">${username.charAt(0).toUpperCase()}</span>`}
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
      
      // Attach dropdown toggle listener
      freshTrigger.addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        this.toggleMobileUserDropdown(e);
      });
      
      // Create mobile dropdown if needed
      this.createMobileUserDropdown();
    }
  }

  createUserDropdown() {
    // Remove existing dropdown if any
    const existingDropdown = document.getElementById("userDropdown");
    if (existingDropdown) {
      existingDropdown.remove();
    }

    const loginTrigger = document.getElementById("loginTrigger");
    if (!loginTrigger) return;

    const dropdown = document.createElement("div");
    dropdown.id = "userDropdown";
    dropdown.className = "user-dropdown";
    dropdown.style.width = "320px"; // Fixed width to prevent expansion

    const userFullName = this.currentUser?.fullName || "";
    const userEmail = this.currentUser?.email || "";

    const avatarUrl = this.currentUser?.profile?.avatar;
    const hasAvatar = avatarUrl && avatarUrl !== "default";
    dropdown.innerHTML = `
            <div class="dropdown-content">
                <div class="dropdown-header">
                    <div class="user-avatar">
                        ${hasAvatar
                          ? `<img id="dropdownAvatarImg" src="${avatarUrl}" alt="avatar" style="width:48px;height:48px;border-radius:50%;object-fit:cover;display:block;" />`
                          : `<span class=\"user-initial-large\">${(userFullName || this.currentUser?.username || "U").charAt(0).toUpperCase()}</span>`}
                    </div>
                    <div class="user-info">
                        <div class="user-name">${
                          userFullName || this.currentUser?.username
                        }</div>
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
                <a href="#" class="dropdown-item" id="visitedBtn">
                    <div class="dropdown-icon">
                        <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
                            <path d="M9 12l2 2 4-4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                            <path d="M21 12c0 4.97-4.03 9-9 9s-9-4.03-9-9 4.03-9 9-9 9 4.03 9 9z" stroke="currentColor" stroke-width="2"/>
                        </svg>
                    </div>
                    <span class="dropdown-text">Visited Pagodas</span>
                </a>
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

    // Attach dropdown to body and position near the trigger to avoid overflow/clipping
    document.body.appendChild(dropdown);
    dropdown.style.display = "none";
    dropdown.style.position = "fixed";
    dropdown.style.zIndex = "2000";

    const positionDropdown = () => {
      const triggerRect = loginTrigger.getBoundingClientRect();
      const dropdownWidth = 320; // Use fixed width instead of offsetWidth
      const gutter = 8;
      // Prefer aligning right edges; fall back to left if overflow
      let left = triggerRect.right - dropdownWidth;
      if (left < gutter) left = gutter;
      let top = triggerRect.bottom + gutter;
      // Prevent going off bottom edge
      const maxTop = window.innerHeight - (dropdown.offsetHeight || 400) - gutter;
      if (top > maxTop) top = Math.max(gutter, maxTop);
      dropdown.style.left = `${left}px`;
      dropdown.style.top = `${top}px`;
    };

    // Initial layout after DOM paints
    requestAnimationFrame(positionDropdown);

    // Add event listeners
    const logoutBtn = document.getElementById("logoutBtn");
    const profileBtn = document.getElementById("profileBtn");
    const favoritesBtn = document.getElementById("favoritesBtn");
    const visitedBtn = document.getElementById("visitedBtn");
    const settingsBtn = document.getElementById("settingsBtn");

    if (logoutBtn)
      logoutBtn.addEventListener("click", this.handleLogout.bind(this));
    if (profileBtn)
      profileBtn.addEventListener("click", this.showUserProfile.bind(this));
    if (favoritesBtn)
      favoritesBtn.addEventListener("click", this.showUserFavorites.bind(this));
    if (visitedBtn)
      visitedBtn.addEventListener("click", this.showUserVisited.bind(this));
    // Reposition on resize/scroll while visible
    const repositionHandler = () => {
      if (dropdown.style.display === "block") positionDropdown();
    };
    window.addEventListener("resize", repositionHandler);
    window.addEventListener("scroll", repositionHandler, true);

    // Store for later use
    this._positionUserDropdown = positionDropdown;
  }

  createMobileUserDropdown() {
    // Remove existing dropdown
    const existingDropdown = document.getElementById("mobileUserDropdown");
    if (existingDropdown) existingDropdown.remove();
    
    const mobileLoginTrigger = document.getElementById("mobileLoginTrigger");
    if (!mobileLoginTrigger) return;
    
    // Create dropdown with same items as desktop but positioned for mobile
    const dropdown = document.createElement("div");
    dropdown.id = "mobileUserDropdown";
    dropdown.className = "mobile-user-dropdown";
    
    const userFullName = this.currentUser?.fullName || "";
    const userEmail = this.currentUser?.email || "";
    const avatarUrl = this.currentUser?.profile?.avatar;
    const hasAvatar = avatarUrl && avatarUrl !== "default";
    
    dropdown.innerHTML = `
      <div class="dropdown-content">
        <div class="dropdown-header">
          <div class="user-avatar">
            ${hasAvatar
              ? `<img id="mobileDropdownAvatarImg" src="${avatarUrl}" alt="avatar" style="width:48px;height:48px;border-radius:50%;object-fit:cover;display:block;" />`
              : `<span class="user-initial-large">${(userFullName || this.currentUser?.username || "U").charAt(0).toUpperCase()}</span>`}
          </div>
          <div class="user-info">
            <div class="user-name">${userFullName || this.currentUser?.username}</div>
            <div class="user-email">${userEmail}</div>
            <div class="user-status-indicator">
              <span class="status-dot"></span>
              <span class="status-text">Online</span>
            </div>
          </div>
        </div>
        <div class="dropdown-divider"></div>
        <a href="#" class="dropdown-item" id="mobileProfileBtn">
          <div class="dropdown-icon">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
              <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              <circle cx="12" cy="7" r="4" stroke="currentColor" stroke-width="2"/>
            </svg>
          </div>
          <span class="dropdown-text">My Profile</span>
        </a>
        <a href="#" class="dropdown-item" id="mobileFavoritesBtn">
          <div class="dropdown-icon">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
              <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </div>
          <span class="dropdown-text">My Favorites</span>
        </a>
        <a href="#" class="dropdown-item" id="mobileVisitedBtn">
          <div class="dropdown-icon">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
              <path d="M9 12l2 2 4-4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              <path d="M21 12c0 4.97-4.03 9-9 9s-9-4.03-9-9 4.03-9 9-9 9 4.03 9 9z" stroke="currentColor" stroke-width="2"/>
            </svg>
          </div>
          <span class="dropdown-text">Visited Pagodas</span>
        </a>
        <a href="#" class="dropdown-item logout-item" id="mobileLogoutBtn">
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
    
    // Append to nav drawer login section
    const navDrawerLoginSection = mobileLoginTrigger.closest('.nav-drawer-section');
    if (navDrawerLoginSection) {
      navDrawerLoginSection.appendChild(dropdown);
    }
    
    // Setup event listeners for mobile dropdown items
    this.setupMobileDropdownEventListeners();
  }

  toggleMobileUserDropdown(event) {
    event.preventDefault();
    event.stopPropagation();
    
    const dropdown = document.getElementById("mobileUserDropdown");
    if (!dropdown) return;
    
    const isVisible = dropdown.classList.contains("show");
    
    // Close any other dropdowns first
    const desktopDropdown = document.getElementById("userDropdown");
    if (desktopDropdown && desktopDropdown.classList.contains("show")) {
      desktopDropdown.classList.remove("show");
    }
    
    // Toggle mobile dropdown
    if (isVisible) {
      dropdown.classList.remove("show");
    } else {
      dropdown.classList.add("show");
    }
  }

  setupMobileDropdownEventListeners() {
    const logoutBtn = document.getElementById("mobileLogoutBtn");
    const profileBtn = document.getElementById("mobileProfileBtn");
    const favoritesBtn = document.getElementById("mobileFavoritesBtn");
    const visitedBtn = document.getElementById("mobileVisitedBtn");

    if (logoutBtn)
      logoutBtn.addEventListener("click", this.handleLogout.bind(this));
    if (profileBtn)
      profileBtn.addEventListener("click", this.showUserProfile.bind(this));
    if (favoritesBtn)
      favoritesBtn.addEventListener("click", this.showUserFavorites.bind(this));
    if (visitedBtn)
      visitedBtn.addEventListener("click", this.showUserVisited.bind(this));
  }

  async handleLogout(event) {
    event.preventDefault();

    // Immediately hide dropdowns and clear UI state to prevent conflicts
    const dropdown = document.getElementById("userDropdown");
    if (dropdown) {
      dropdown.classList.remove("show");
      dropdown.style.display = "none";
    }
    
    const mobileDropdown = document.getElementById("mobileUserDropdown");
    if (mobileDropdown) {
      mobileDropdown.classList.remove("show");
    }

    try {
      const response = await fetch("/logout", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.authToken}`,
        },
        credentials: 'include',
      });

      // Always clear local state regardless of server response
      this.clearAuthState();
      this.updateUIForUnauthenticatedUser();
      // Soft-refresh widgets (e.g., chatbot) without full reload
      try {
        if (typeof window.initializeChatbot === 'function') {
          setTimeout(() => window.initializeChatbot(), 50);
        }
      } catch (e) {
        console.warn('Soft refresh after logout failed:', e);
      }
    } catch (error) {
      console.error("Logout error:", error);
      // Even if server logout fails, clear local state
      this.clearAuthState();
      this.updateUIForUnauthenticatedUser();
      try {
        if (typeof window.initializeChatbot === 'function') {
          setTimeout(() => window.initializeChatbot(), 50);
        }
      } catch (e2) {
        console.warn('Soft refresh after logout error:', e2);
      }
      window.location.reload();
    }
  }

  startAuthHeartbeat() {
    // Avoid multiple timers
    if (this._authHeartbeatInterval) return;
    // Poll every 60 seconds to validate token and refresh profile
    this._authHeartbeatInterval = setInterval(async () => {
      try {
        if (!this.isAuthenticated) return;
        const token = localStorage.getItem("authToken");
        if (!token) {
          // Lost token => logout
          this.clearAuthState();
          this.updateUIForUnauthenticatedUser();
          return;
        }
        const res = await fetch("/me", { headers: { Authorization: `Bearer ${token}` }, cache: 'no-store' });
        if (!res.ok) {
          // Token invalid/expired or server says unauthenticated
          this.clearAuthState();
          this.updateUIForUnauthenticatedUser();
          return;
        }
        const data = await res.json();
        if (!data || !data.authenticated) {
          this.clearAuthState();
          this.updateUIForUnauthenticatedUser();
          return;
        }
        // Optionally refresh displayed profile details
        if (data.user) {
          this.currentUser = {
            username: data.user.username,
            email: data.user.email,
            fullName: data.user.fullName,
            profile: { avatar: (data.user.profile && data.user.profile.avatar) || "default" },
          };
          this.updateUIForAuthenticatedUser();
        }
      } catch (e) {
        // Network issue: do not logout immediately; keep local state
      }
    }, 60000);
  }

  clearAuthState() {
    this.isAuthenticated = false;
    this.currentUser = null;
    this.authToken = null;
    localStorage.removeItem("authToken");
    localStorage.removeItem("userLoggedIn");
    localStorage.removeItem("username");
    localStorage.removeItem("userEmail");
    localStorage.removeItem("userFullName");
  }

  showLoginPopup() {
    // Prevent showing login popup if user is still authenticated
    if (this.isAuthenticated) {
      return;
    }

    // Close navigation drawer if it's open (for mobile)
    const navDrawer = document.getElementById("navDrawer");
    if (navDrawer && navDrawer.getAttribute("aria-hidden") === "false") {
      // Close the navigation drawer
      navDrawer.setAttribute("aria-hidden", "true");
      navDrawer.classList.remove("open");
      document.body.classList.remove("nav-open");
      
      // Close hamburger menu
      const hamburger = document.getElementById("hamburger");
      if (hamburger) {
        hamburger.classList.remove("active");
      }
    }

    const loginPopup = document.getElementById("loginPopup");
    if (loginPopup) {
      // Move popup to body if it's not already there to ensure proper positioning
      if (loginPopup.parentNode !== document.body) {
        document.body.appendChild(loginPopup);
      }

      loginPopup.style.display = "flex";
      document.body.classList.add("modal-open");
      this.resetForms();
      this.toggleForm("login");
    }
  }

  toggleUserDropdown(event) {
    event.preventDefault();
    // Ensure any leftover modal overlay doesn't block interactions
    const loginPopupEl = document.getElementById("loginPopup");
    if (loginPopupEl) {
      loginPopupEl.style.display = "none";
    }
    document.body.classList.remove("modal-open");
    const dropdown = document.getElementById("userDropdown");
    if (dropdown) {
      const isVisible = dropdown.style.display === "block";

      if (isVisible) {
        // Hide dropdown
        dropdown.classList.remove("show");
        setTimeout(() => {
          dropdown.style.display = "none";
        }, 200); // Match CSS transition duration
      } else {
        // Show dropdown
        dropdown.style.display = "block";
        // Force a reflow to ensure the transition works
        dropdown.offsetHeight;
        dropdown.classList.add("show");
        // Ensure it's placed correctly relative to trigger
        if (typeof this._positionUserDropdown === "function") {
          this._positionUserDropdown();
        }
      }
    }
  }

  showUserProfile(event) {
    event.preventDefault();
    this.hideUserDropdown();
    this.createProfileModal();
  }

  showUserFavorites(event) {
    event.preventDefault();
    this.hideUserDropdown();
    this.createFavoritesModal();
  }


  showUserVisited(event) {
    event.preventDefault();
    this.hideUserDropdown();
    this.createVisitedModal();
  }

  hideUserDropdown() {
    const dropdown = document.getElementById("userDropdown");
    if (dropdown) {
      dropdown.classList.remove("show");
      dropdown.style.display = "none";
    }
  }

  createProfileModal() {
    // Remove existing modal if any
    const existingModal = document.getElementById("profileModal");
    if (existingModal) {
      existingModal.remove();
    }

    const modal = document.createElement("div");
    modal.id = "profileModal";
    modal.className = "modal";
    modal.innerHTML = `
      <div class="modal-content profile-modal-content">
        <div class="modal-header">
          <div class="header-content">
            <div class="profile-avatar-large" id="profileAvatar">
              <img id="profileAvatarImg" src="${this.getDefaultAvatar()}" alt="Profile Picture" style="width: 60px; height: 60px; border-radius: 50%; object-fit: cover; display: none;">
              <span class="user-initial-large" id="profileInitial">${(
                this.currentUser?.fullName ||
                this.currentUser?.username ||
                "U"
              )
                .charAt(0)
                .toUpperCase()}</span>
            </div>
            <div class="header-text">
              <h2>${this.translate('My Profile')}</h2>
              <p class="profile-subtitle">${this.translate('Manage your account information')}</p>
            </div>
          </div>
          <span class="close">&times;</span>
        </div>
        <div class="modal-body">
          <div class="profile-section">
            <h3>${this.translate('Personal Information')}</h3>
            <div class="info-grid">
              <div class="info-item">
                <label>Username</label>
                <div class="info-value">${
                  this.currentUser?.username || "N/A"
                }</div>
              </div>
              <div class="info-item">
                <label>Full Name</label>
                <div class="info-value">${
                  this.currentUser?.fullName || "Not provided"
                }</div>
              </div>
              <div class="info-item">
                <label>Email Address</label>
                <div class="info-value">${
                  this.currentUser?.email || "N/A"
                }</div>
              </div>
              <div class="info-item">
                <label>Account Status</label>
                <div class="info-value status-online">
                  <span class="status-dot"></span>
                  Online
                </div>
              </div>
            </div>
          </div>
          
          <div class="profile-section">
            <h3>${this.translate('Account Statistics')}</h3>
            <div class="stats-grid">
              <div class="stat-item">
                <div class="stat-number" id="favoritesCount">0</div>
                <div class="stat-label">${this.translate('Favorite Pagodas')}</div>
              </div>
              <div class="stat-item">
                <div class="stat-number" id="visitedCount">0</div>
                <div class="stat-label">${this.translate('Visited Pagodas')}</div>
              </div>
              <div class="stat-item">
                <div class="stat-number" id="profileCompletion">0%</div>
                <div class="stat-label">${this.translate('Profile Complete')}</div>
              </div>
              <div class="stat-item">
                <div class="stat-number" id="memberSince">Today</div>
                <div class="stat-label">${this.translate('Member Since')}</div>
              </div>
            </div>
          </div>

          <div class="profile-section">
            <h3>${this.translate('Profile Completion')}</h3>
            <div class="completion-progress">
              <div class="progress-bar">
                <div class="progress-fill" id="progressFill" style="width: 0%"></div>
              </div>
              <div class="completion-tasks">
                <div class="completion-task" id="task-fullname">
                  <span class="task-icon">○</span>
                  <span class="task-text">${this.translate('Add your full name')}</span>
                </div>
                <div class="completion-task" id="task-bio">
                  <span class="task-icon">○</span>
                  <span class="task-text">${this.translate('Write a bio')}</span>
                </div>
                <div class="completion-task" id="task-avatar">
                  <span class="task-icon">○</span>
                  <span class="task-text">${this.translate('Upload profile picture')}</span>
                </div>
                <div class="completion-task" id="task-email">
                  <span class="task-icon">○</span>
                  <span class="task-text">${this.translate('Verify email address')}</span>
                </div>
                <div class="completion-task" id="task-favorites">
                  <span class="task-icon">○</span>
                  <span class="task-text">${this.translate('Add favorite pagodas')}</span>
                </div>
                <div class="completion-task" id="task-visited">
                  <span class="task-icon">○</span>
                  <span class="task-text">${this.translate('Mark visited pagodas')}</span>
                </div>
              </div>
            </div>
          </div>

          <div class="profile-actions">
            <button class="btn btn-primary" onclick="authManager.editProfile()">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
              ${this.translate('Edit Profile')}
            </button>
            <button class="btn btn-secondary" onclick="authManager.changePassword()">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                <rect x="3" y="11" width="18" height="11" rx="2" ry="2" stroke="currentColor" stroke-width="2"/>
                <circle cx="12" cy="16" r="1" stroke="currentColor" stroke-width="2"/>
                <path d="M7 11V7a5 5 0 0 1 10 0v4" stroke="currentColor" stroke-width="2"/>
              </svg>
              ${this.translate('Change Password')}
            </button>
            <button class="btn btn-secondary" onclick="authManager.exportData()">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                <polyline points="7,10 12,15 17,10" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                <line x1="12" y1="15" x2="12" y2="3" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
              ${this.translate('Export Data')}
            </button>
          </div>
        </div>
      </div>
    `;

    document.body.appendChild(modal);
    modal.style.display = "block";

    // Load user statistics and profile data
    this.loadUserStatistics();
    this.loadProfileData();

    // Close modal functionality
    const closeBtn = modal.querySelector(".close");
    closeBtn.onclick = () => modal.remove();

    window.onclick = (event) => {
      if (event.target === modal) {
        modal.remove();
      }
    };
  }

  createFavoritesModal() {
    // Remove existing modal if any
    const existingModal = document.getElementById("favoritesModal");
    if (existingModal) {
      existingModal.remove();
    }

    const modal = document.createElement("div");
    modal.id = "favoritesModal";
    modal.className = "modal";
    modal.innerHTML = `
      <div class="modal-content favorites-modal">
        <div class="modal-header">
          <div class="header-content">
            <div class="favorites-icon">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </div>
            <div class="header-text">
              <h2>My Favorites</h2>
              <p class="favorites-subtitle">Your saved pagodas and temples</p>
            </div>
          </div>
          <span class="close">&times;</span>
        </div>
        <div class="modal-body">
          <div class="favorites-content" id="favoritesContent">
            <div class="loading-state">
              <div class="loading-spinner"></div>
              <p>Loading your favorites...</p>
            </div>
          </div>
        </div>
      </div>
    `;

    document.body.appendChild(modal);
    modal.style.display = "block";

    // Load user favorites
    this.loadUserFavorites();

    // Close modal functionality
    const closeBtn = modal.querySelector(".close");
    closeBtn.onclick = () => modal.remove();

    window.onclick = (event) => {
      if (event.target === modal) {
        modal.remove();
      }
    };
  }

  createVisitedModal() {
    // Remove existing modal if any
    const existingModal = document.getElementById("visitedModal");
    if (existingModal) {
      existingModal.remove();
    }

    const modal = document.createElement("div");
    modal.id = "visitedModal";
    modal.className = "modal";
    modal.innerHTML = `
      <div class="modal-content visited-modal">
        <div class="modal-header">
          <div class="header-content">
            <div class="visited-icon">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                <path d="M9 12l2 2 4-4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                <path d="M21 12c0 4.97-4.03 9-9 9s-9-4.03-9-9 4.03-9 9-9 9 4.03 9 9z" stroke="currentColor" stroke-width="2"/>
              </svg>
            </div>
            <div class="header-text">
              <h2>Visited Pagodas</h2>
              <p class="visited-subtitle">Your journey through Bagan's temples</p>
            </div>
          </div>
          <span class="close">&times;</span>
        </div>
        <div class="modal-body">
          <div class="visited-content" id="visitedContent">
            <div class="loading-state">
              <div class="loading-spinner"></div>
              <p>Loading your visited pagodas...</p>
            </div>
          </div>
        </div>
      </div>
    `;

    document.body.appendChild(modal);
    modal.style.display = "block";

    // Load user visited pagodas
    this.loadUserVisited();

    // Close modal functionality
    const closeBtn = modal.querySelector(".close");
    closeBtn.onclick = () => modal.remove();

    window.onclick = (event) => {
      if (event.target === modal) {
        modal.remove();
      }
    };
  }


  async loadUserStatistics() {
    try {
      // Fetch real counts from the backend
      const [favoritesRes, visitedRes, profileRes] = await Promise.all([
        fetch("/api/user/favorites", { headers: { Authorization: `Bearer ${this.authToken}` } }),
        fetch("/api/user/visited", { headers: { Authorization: `Bearer ${this.authToken}` } }),
        fetch("/profile", { headers: { Authorization: `Bearer ${this.authToken}` } }),
      ]);

      const favorites = favoritesRes.ok ? await favoritesRes.json() : [];
      const visited = visitedRes.ok ? await visitedRes.json() : [];
      const profileData = profileRes.ok ? await profileRes.json() : { success: false };

      // Update counts
      const favoritesCountEl = document.getElementById("favoritesCount");
      if (favoritesCountEl) favoritesCountEl.textContent = String(favorites.length || 0);

      const visitedCountEl = document.getElementById("visitedCount");
      if (visitedCountEl) visitedCountEl.textContent = String(visited.length || 0);

      // Member since from server timestamps
      const memberSinceEl = document.getElementById("memberSince");
      const createdAt = profileData?.user?.createdAt;
      if (memberSinceEl) {
        memberSinceEl.textContent = createdAt
          ? new Date(createdAt).toLocaleDateString()
          : "Today";
      }

      // Calculate profile completion using server data
      const user = profileData?.user || this.currentUser || {};
      let completionScore = 0;
      const totalFields = 6;
      if (user.fullName && user.fullName.trim()) completionScore++;
      if (user.profile?.bio && user.profile.bio.trim()) completionScore++;
      if (user.profile?.avatar && user.profile.avatar !== "default") completionScore++;
      if (user.isEmailVerified) completionScore++;
      if ((favorites?.length || 0) > 0) completionScore++;
      if ((visited?.length || 0) > 0) completionScore++;

      const completionPercentage = Math.round((completionScore / totalFields) * 100);

      const profileCompletionEl = document.getElementById("profileCompletion");
      if (profileCompletionEl) profileCompletionEl.textContent = `${completionPercentage}%`;

      const progressFillEl = document.getElementById("progressFill");
      if (progressFillEl) progressFillEl.style.width = `${completionPercentage}%`;

      this.updateCompletionTasks(user, completionScore);
    } catch (error) {
      console.error("Error loading user statistics:", error);
      const favoritesCountEl = document.getElementById("favoritesCount");
      const visitedCountEl = document.getElementById("visitedCount");
      const memberSinceEl = document.getElementById("memberSince");
      const profileCompletionEl = document.getElementById("profileCompletion");
      const progressFillEl = document.getElementById("progressFill");
      if (favoritesCountEl) favoritesCountEl.textContent = "0";
      if (visitedCountEl) visitedCountEl.textContent = "0";
      if (memberSinceEl) memberSinceEl.textContent = "Today";
      if (profileCompletionEl) profileCompletionEl.textContent = "0%";
      if (progressFillEl) progressFillEl.style.width = "0%";
    }
  }

  async loadUserFavorites() {
    const favoritesContent = document.getElementById("favoritesContent");
    if (!favoritesContent) return;

    try {
      const response = await fetch("/api/user/favorites", {
        headers: {
          Authorization: `Bearer ${this.authToken}`,
        },
      });

      if (response.ok) {
        const favorites = await response.json();

        if (favorites.length === 0) {
          favoritesContent.innerHTML = `
            <div class="empty-state">
              <div class="empty-icon">
                <svg width="48" height="48" viewBox="0 0 24 24" fill="none">
                  <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
              </div>
              <h3>No favorites yet</h3>
              <p>Start exploring pagodas and add them to your favorites!</p>
              <button class="btn btn-primary" onclick="window.location.href=(window.location.pathname.includes('/mmversion/') ? 'mmversion/pagodasmm.html' : 'pagodas.html')">
                Explore Pagodas
              </button>
            </div>
          `;
        } else {
          // Load visited status for all favorites
          const visitedStatus = await Promise.all(
            favorites.map(pagoda => this.isVisited(pagoda.id))
          );

          favoritesContent.innerHTML = `
            <div class="favorites-grid">
              ${favorites
                .map(
                  (pagoda, index) => {
                    // Enhanced image handling with multiple fallbacks
                    const getImageUrl = (pagoda) => {
                      // Try different image sources in order of preference
                      if (pagoda.images?.main) return pagoda.images.main;
                      if (pagoda.images?.thumbnail) return pagoda.images.thumbnail;
                      if (pagoda.images?.gallery && pagoda.images.gallery.length > 0) return pagoda.images.gallery[0];
                      if (pagoda.image) return pagoda.image;
                      
                      // Fallback to placeholder
                      return "assets/images/placeholder-pagoda.jpg";
                    };

                    const imageUrl = getImageUrl(pagoda);
                    const pagodaType = pagoda.type || pagoda.category || "Temple";
                    const pagodaDescription = pagoda.description?.short || pagoda.description || pagoda.summary || "";
                    const isVisited = visitedStatus[index];

                    return `
                <div class="favorite-item" data-pagoda-id="${pagoda.id}">
                  <div class="favorite-image">
                    <img 
                      src="${imageUrl}" 
                      alt="${pagoda.name}"
                      onerror="this.src='assets/images/placeholder-pagoda.jpg'; this.onerror=null;"
                      loading="lazy"
                    >
                    <div class="favorite-overlay">
                      <button class="favorite-remove-btn" onclick="authManager.removeFavorite('${pagoda.id}')" title="Remove from favorites">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                          <path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                      </button>
                    </div>
                  </div>
                  <div class="favorite-info">
                    <h4>${pagoda.name}</h4>
                    <p class="favorite-type">${pagodaType}</p>
                    ${pagodaDescription ? `<p class="favorite-description">${pagodaDescription.substring(0, 100)}${pagodaDescription.length > 100 ? '...' : ''}</p>` : ''}
                    <div class="favorite-actions">
                      <button class="btn btn-small btn-primary" onclick="window.location.href=(window.location.pathname.includes('/mmversion/') ? 'mmversion/${pagoda.id}mm.html' : 'pagodaDetils.html?id=${pagoda.id}')">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
                          <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" stroke="currentColor" stroke-width="2"/>
                          <circle cx="12" cy="12" r="3" stroke="currentColor" stroke-width="2"/>
                        </svg>
                        View Details
                      </button>
                      <button class="btn btn-small btn-secondary visited-btn ${isVisited ? 'visited' : ''}" onclick="authManager.${isVisited ? 'unmarkAsVisited' : 'markAsVisited'}('${pagoda.id}')" title="${isVisited ? 'Remove from visited' : 'Mark as visited'}" data-pagoda-id="${pagoda.id}">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
                          <path d="M9 12l2 2 4-4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                        ${isVisited ? 'Visited' : 'Mark Visited'}
                      </button>
                    </div>
                  </div>
                </div>
              `;
                  }
                )
                .join("")}
            </div>
          `;
        }
      } else {
        favoritesContent.innerHTML = `
          <div class="error-state">
            <div class="error-icon">
              <svg width="48" height="48" viewBox="0 0 24 24" fill="none">
                <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2"/>
                <line x1="15" y1="9" x2="9" y2="15" stroke="currentColor" stroke-width="2"/>
                <line x1="9" y1="9" x2="15" y2="15" stroke="currentColor" stroke-width="2"/>
              </svg>
            </div>
            <h3>Error loading favorites</h3>
            <p>There was a problem loading your favorites. Please try again.</p>
            <button class="btn btn-primary" onclick="authManager.loadUserFavorites()">
              Try Again
            </button>
          </div>
        `;
      }
    } catch (error) {
      console.error("Error loading favorites:", error);
      favoritesContent.innerHTML = `
        <div class="error-state">
          <div class="error-icon">
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none">
              <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2"/>
              <line x1="15" y1="9" x2="9" y2="15" stroke="currentColor" stroke-width="2"/>
              <line x1="9" y1="9" x2="15" y2="15" stroke="currentColor" stroke-width="2"/>
            </svg>
          </div>
          <h3>Connection Error</h3>
          <p>Unable to connect to the server. Please check your internet connection and try again.</p>
          <button class="btn btn-primary" onclick="authManager.loadUserFavorites()">
            Retry
          </button>
        </div>
      `;
    }
  }

  async loadUserVisited() {
    const visitedContent = document.getElementById("visitedContent");
    if (!visitedContent) return;

    try {
      const response = await fetch("/api/user/visited", {
        headers: {
          Authorization: `Bearer ${this.authToken}`,
        },
      });

      if (response.ok) {
        const visited = await response.json();

        if (visited.length === 0) {
          visitedContent.innerHTML = `
            <div class="empty-state">
              <div class="empty-icon">
                <svg width="48" height="48" viewBox="0 0 24 24" fill="none">
                  <path d="M9 12l2 2 4-4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                  <path d="M21 12c0 4.97-4.03 9-9 9s-9-4.03-9-9 4.03-9 9-9 9 4.03 9 9z" stroke="currentColor" stroke-width="2"/>
                </svg>
              </div>
              <h3>No visited pagodas yet</h3>
              <p>Start your journey through Bagan's temples and mark them as visited!</p>
              <button class="btn btn-primary" onclick="window.location.href=(window.location.pathname.includes('/mmversion/') ? 'mmversion/pagodasmm.html' : 'pagodas.html')">
                Explore Pagodas
              </button>
            </div>
          `;
        } else {
          visitedContent.innerHTML = `
            <div class="favorites-grid">
              ${visited
                .map(
                  (pagoda) => {
                    // Enhanced image handling with multiple fallbacks
                    const getImageUrl = (pagoda) => {
                      if (pagoda.images?.main) return pagoda.images.main;
                      if (pagoda.images?.thumbnail) return pagoda.images.thumbnail;
                      if (pagoda.images?.gallery && pagoda.images.gallery.length > 0) return pagoda.images.gallery[0];
                      if (pagoda.image) return pagoda.image;
                      return "assets/images/placeholder-pagoda.jpg";
                    };

                    const imageUrl = getImageUrl(pagoda);
                    const pagodaType = pagoda.type || pagoda.category || "Temple";
                    const pagodaDescription = pagoda.description?.short || pagoda.description || pagoda.summary || "";

                    return `
                <div class="favorite-item visited-item" data-pagoda-id="${pagoda.id}">
                  <div class="favorite-image">
                    <img 
                      src="${imageUrl}" 
                      alt="${pagoda.name}"
                      onerror="this.src='assets/images/placeholder-pagoda.jpg'; this.onerror=null;"
                      loading="lazy"
                    >
                    <div class="visited-badge">
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                        <path d="M9 12l2 2 4-4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                      </svg>
                      Visited
                    </div>
                  </div>
                  <div class="favorite-info">
                    <h4>${pagoda.name}</h4>
                    <p class="favorite-type">${pagodaType}</p>
                    ${pagodaDescription ? `<p class="favorite-description">${pagodaDescription.substring(0, 100)}${pagodaDescription.length > 100 ? '...' : ''}</p>` : ''}
                    <div class="favorite-actions">
                      <button class="btn btn-small btn-primary" onclick="window.location.href=(window.location.pathname.includes('/mmversion/') ? 'mmversion/${pagoda.id}mm.html' : 'pagodaDetils.html?id=${pagoda.id}')">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
                          <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" stroke="currentColor" stroke-width="2"/>
                          <circle cx="12" cy="12" r="3" stroke="currentColor" stroke-width="2"/>
                        </svg>
                        View Details
                      </button>
                      <button class="btn btn-small btn-danger" onclick="authManager.unmarkAsVisited('${pagoda.id}')" title="Remove from visited">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
                          <path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                        Remove
                      </button>
                    </div>
                  </div>
                </div>
              `;
                  }
                )
                .join("")}
            </div>
          `;
        }
      } else {
        visitedContent.innerHTML = `
          <div class="error-state">
            <div class="error-icon">
              <svg width="48" height="48" viewBox="0 0 24 24" fill="none">
                <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2"/>
                <line x1="15" y1="9" x2="9" y2="15" stroke="currentColor" stroke-width="2"/>
                <line x1="9" y1="9" x2="15" y2="15" stroke="currentColor" stroke-width="2"/>
              </svg>
            </div>
            <h3>Error loading visited pagodas</h3>
            <p>There was a problem loading your visited pagodas. Please try again.</p>
            <button class="btn btn-primary" onclick="authManager.loadUserVisited()">
              Try Again
            </button>
          </div>
        `;
      }
    } catch (error) {
      console.error("Error loading visited pagodas:", error);
      visitedContent.innerHTML = `
        <div class="error-state">
          <div class="error-icon">
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none">
              <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2"/>
              <line x1="15" y1="9" x2="9" y2="15" stroke="currentColor" stroke-width="2"/>
              <line x1="9" y1="9" x2="15" y2="15" stroke="currentColor" stroke-width="2"/>
            </svg>
          </div>
          <h3>Connection Error</h3>
          <p>Unable to connect to the server. Please check your internet connection and try again.</p>
          <button class="btn btn-primary" onclick="authManager.loadUserVisited()">
            Retry
          </button>
        </div>
      `;
    }
  }


  editProfile() {
    this.showEditProfileModal();
  }

  changePassword() {
    this.showChangePasswordModal();
  }

  showEditProfileModal() {
    // Remove existing modal if any
    const existingModal = document.getElementById("editProfileModal");
    if (existingModal) {
      existingModal.remove();
    }

    const modal = document.createElement("div");
    modal.id = "editProfileModal";
    modal.className = "modal";
    modal.innerHTML = `
      <div class="modal-content edit-profile-modal">
        <div class="modal-header">
          <div class="header-content">
            <div class="profile-avatar-large">
              <img id="currentAvatar" src="${
                this.currentUser?.profile?.avatar || this.getDefaultAvatar()
              }" alt="Profile Picture" style="width: 60px; height: 60px; border-radius: 50%; object-fit: cover;">
            </div>
            <div class="header-text">
              <h2>Edit Profile</h2>
              <p class="profile-subtitle">Update your account information</p>
            </div>
          </div>
          <span class="close">&times;</span>
        </div>
        <div class="modal-body">
          <form id="editProfileForm">
            <div class="form-group">
              <label for="editFullName">Full Name</label>
              <input type="text" id="editFullName" name="fullName" value="${
                this.currentUser?.fullName || ""
              }" required>
            </div>
            <div class="form-group">
              <label for="editBio">Bio</label>
              <textarea id="editBio" name="bio" rows="3" placeholder="Tell us about yourself...">${
                this.currentUser?.profile?.bio || ""
              }</textarea>
            </div>
            <div class="form-group">
              <label for="avatarUpload">Profile Picture</label>
              <input type="file" id="avatarUpload" name="avatar" accept="image/*">
              <small>Max file size: 5MB. Supported formats: JPG, PNG, GIF, WebP</small>
            </div>
            <div class="form-actions">
              <button type="button" class="btn btn-secondary" onclick="this.closest('.modal').remove()">Cancel</button>
              <button type="submit" class="btn btn-primary">Save Changes</button>
            </div>
          </form>
        </div>
      </div>
    `;

    document.body.appendChild(modal);
    modal.style.display = "block";

    // Close modal functionality
    const closeBtn = modal.querySelector(".close");
    closeBtn.onclick = () => modal.remove();

    window.onclick = (event) => {
      if (event.target === modal) {
        modal.remove();
      }
    };

    // Handle form submission
    const form = document.getElementById("editProfileForm");
    form.addEventListener("submit", this.handleEditProfileSubmit.bind(this));
  }

  showChangePasswordModal() {
    // Remove existing modal if any
    const existingModal = document.getElementById("changePasswordModal");
    if (existingModal) {
      existingModal.remove();
    }

    const modal = document.createElement("div");
    modal.id = "changePasswordModal";
    modal.className = "modal";
    modal.innerHTML = `
      <div class="modal-content change-password-modal">
        <div class="modal-header">
          <div class="header-content">
            <div class="password-icon">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                <rect x="3" y="11" width="18" height="11" rx="2" ry="2" stroke="currentColor" stroke-width="2"/>
                <circle cx="12" cy="16" r="1" stroke="currentColor" stroke-width="2"/>
                <path d="M7 11V7a5 5 0 0 1 10 0v4" stroke="currentColor" stroke-width="2"/>
              </svg>
            </div>
            <div class="header-text">
              <h2>Change Password</h2>
              <p class="password-subtitle">Update your account password</p>
            </div>
          </div>
          <span class="close">&times;</span>
        </div>
        <div class="modal-body">
          <form id="changePasswordForm">
            <div class="form-group">
              <label for="currentPassword">Current Password</label>
              <input type="password" id="currentPassword" name="currentPassword" required>
            </div>
            <div class="form-group">
              <label for="newPassword">New Password</label>
              <input type="password" id="newPassword" name="newPassword" required minlength="8">
              <div id="passwordStrength" class="password-strength-container"></div>
              <div class="password-requirements">
                <small>Password must contain:</small>
                <ul>
                  <li id="req-length">• At least 8 characters</li>
                  <li id="req-uppercase">• One uppercase letter</li>
                  <li id="req-lowercase">• One lowercase letter</li>
                  <li id="req-number">• One number</li>
                  <li id="req-special">• One special character</li>
                </ul>
              </div>
            </div>
            <div class="form-group">
              <label for="confirmNewPassword">Confirm New Password</label>
              <input type="password" id="confirmNewPassword" name="confirmNewPassword" required>
              <div id="passwordMatch" class="password-match-indicator"></div>
            </div>
            <div class="form-actions">
              <button type="button" class="btn btn-secondary" onclick="this.closest('.modal').remove()">Cancel</button>
              <button type="submit" class="btn btn-primary">Change Password</button>
            </div>
          </form>
        </div>
      </div>
    `;

    document.body.appendChild(modal);
    modal.style.display = "block";

    // Close modal functionality
    const closeBtn = modal.querySelector(".close");
    closeBtn.onclick = () => modal.remove();

    window.onclick = (event) => {
      if (event.target === modal) {
        modal.remove();
      }
    };

    // Handle form submission
    const form = document.getElementById("changePasswordForm");
    form.addEventListener("submit", this.handleChangePasswordSubmit.bind(this));

    // Add password strength validation
    this.setupPasswordValidation();
  }

  async handleEditProfileSubmit(event) {
    event.preventDefault();

    const formData = new FormData();
    const fullName = document.getElementById("editFullName").value.trim();
    const bio = document.getElementById("editBio").value.trim();
    const avatarFile = document.getElementById("avatarUpload").files[0];

    if (!fullName) {
      this.showNotification("Full name is required", "error");
      return;
    }

    try {
      // Update profile data
      const response = await fetch("/profile", {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.authToken}`,
        },
        body: JSON.stringify({
          fullName,
          bio,
        }),
      });

      const data = await response.json();

      if (data.success) {
        // Update local user data
        this.currentUser.fullName = data.user.fullName;
        this.currentUser.profile = data.user.profile;

        // Update localStorage
        localStorage.setItem("userFullName", data.user.fullName);

        // Upload avatar if provided
        if (avatarFile) {
          await this.uploadAvatar(avatarFile);
        }

        this.showNotification("Profile updated successfully!", "success");
        this.updateUIForAuthenticatedUser();
        document.getElementById("editProfileModal").remove();
      } else {
        this.showNotification(
          data.message || "Failed to update profile",
          "error"
        );
      }
    } catch (error) {
      console.error("Edit profile error:", error);
      this.showNotification("Error updating profile", "error");
    }
  }

  async handleChangePasswordSubmit(event) {
    event.preventDefault();

    const currentPassword = document.getElementById("currentPassword").value;
    const newPassword = document.getElementById("newPassword").value;
    const confirmPassword = document.getElementById("confirmNewPassword").value;

    if (newPassword !== confirmPassword) {
      this.showNotification("New passwords do not match", "error");
      return;
    }

    try {
      const response = await fetch("/profile/password", {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.authToken}`,
        },
        body: JSON.stringify({
          currentPassword,
          newPassword,
        }),
      });

      const data = await response.json();

      if (data.success) {
        this.showNotification("Password changed successfully!", "success");
        document.getElementById("changePasswordModal").remove();
      } else {
        this.showNotification(
          data.message || "Failed to change password",
          "error"
        );
      }
    } catch (error) {
      console.error("Change password error:", error);
      this.showNotification("Error changing password", "error");
    }
  }

  async uploadAvatar(file) {
    const formData = new FormData();
    formData.append("avatar", file);

    try {
      const response = await fetch("/profile/avatar", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${this.authToken}`,
        },
        body: formData,
      });

      const data = await response.json();

      if (data.success) {
        // Update local user data
        this.currentUser.profile.avatar = data.avatar;
        try { localStorage.setItem("userAvatarUrl", data.avatar); } catch (e) {}
        this.showNotification("Profile picture updated!", "success");
        this.updateUIForAuthenticatedUser();
        // Also refresh any visible profile modal avatar
        const avatarImg = document.getElementById("profileAvatarImg");
        const profileInitial = document.getElementById("profileInitial");
        if (avatarImg) {
          avatarImg.src = data.avatar;
          avatarImg.style.display = "block";
          if (profileInitial) profileInitial.style.display = "none";
        }
      } else {
        this.showNotification(
          data.message || "Failed to upload avatar",
          "error"
        );
      }
    } catch (error) {
      console.error("Avatar upload error:", error);
      this.showNotification("Error uploading profile picture", "error");
    }
  }

  getDefaultAvatar() {
    const initial = (
      this.currentUser?.fullName ||
      this.currentUser?.username ||
      "U"
    )
      .charAt(0)
      .toUpperCase();
    return `data:image/svg+xml,${encodeURIComponent(`
      <svg width="60" height="60" viewBox="0 0 60 60" xmlns="http://www.w3.org/2000/svg">
        <circle cx="30" cy="30" r="30" fill="#aa7739"/>
        <text x="30" y="38" text-anchor="middle" fill="white" font-family="Arial, sans-serif" font-size="24" font-weight="bold">${initial}</text>
      </svg>
    `)}`;
  }

  // Load profile data and update avatar
  async loadProfileData() {
    try {
      // Update avatar if exists
      const avatarImg = document.getElementById("profileAvatarImg");
      const profileInitial = document.getElementById("profileInitial");
      
      if (this.currentUser?.profile?.avatar && this.currentUser.profile.avatar !== "default") {
        if (avatarImg) {
          avatarImg.src = this.currentUser.profile.avatar;
          avatarImg.style.display = "block";
          if (profileInitial) profileInitial.style.display = "none";
        }
      } else {
        if (avatarImg) avatarImg.style.display = "none";
        if (profileInitial) profileInitial.style.display = "block";
      }

      // Update profile completion
      this.updateProfileCompletion(this.currentUser);
    } catch (error) {
      console.error("Error loading profile data:", error);
    }
  }

  // Update profile completion progress
  updateProfileCompletion(user) {
    let completionScore = 0;
    const totalFields = 6;
    
    if (user.fullName && user.fullName.trim()) completionScore++;
    if (user.profile?.bio && user.profile.bio.trim()) completionScore++;
    if (user.profile?.avatar && user.profile.avatar !== "default") completionScore++;
    if (user.isEmailVerified) completionScore++;
    if (user.profile?.favoritePagodas && user.profile.favoritePagodas.length > 0) completionScore++;
    if (user.profile?.visitedPagodas && user.profile.visitedPagodas.length > 0) completionScore++;
    
    const completionPercentage = Math.round((completionScore / totalFields) * 100);
    
    // Update progress bar
    const progressFill = document.getElementById("progressFill");
    if (progressFill) {
      progressFill.style.width = `${completionPercentage}%`;
    }

    // Update completion percentage
    const profileCompletion = document.getElementById("profileCompletion");
    if (profileCompletion) {
      profileCompletion.textContent = `${completionPercentage}%`;
    }

    // Update completion tasks
    this.updateCompletionTasks(user, completionScore);
  }

  // Export user data
  async exportData() {
    try {
      const response = await fetch("/api/user/export", {
        headers: {
          Authorization: `Bearer ${this.authToken}`,
        },
      });

      if (response.ok) {
        const data = await response.json();
        const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `baganetic-data-${new Date().toISOString().split('T')[0]}.json`;
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
        document.body.removeChild(a);
        this.showNotification("Data exported successfully!", "success");
      } else {
        this.showNotification("Error exporting data", "error");
      }
    } catch (error) {
      console.error("Error exporting data:", error);
      this.showNotification("Error exporting data", "error");
    }
  }

  // Edit profile functionality
  editProfile() {
    const modal = document.getElementById("profileModal");
    if (modal) modal.remove();

    const editModal = document.createElement("div");
    editModal.id = "editProfileModal";
    editModal.className = "modal";
    editModal.innerHTML = `
      <div class="modal-content edit-profile-modal">
        <div class="modal-header">
          <div class="header-content">
            <div class="settings-icon">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </div>
            <div class="header-text">
              <h2>Edit Profile</h2>
              <p class="profile-subtitle">Update your personal information</p>
            </div>
          </div>
          <span class="close">&times;</span>
        </div>
        <div class="modal-body">
          <form id="editProfileForm" class="profile-form">
            <div class="form-group">
              <label for="editFullName">Full Name</label>
              <input type="text" id="editFullName" name="fullName" value="${this.currentUser?.fullName || ''}" placeholder="Enter your full name">
            </div>

            <div class="form-group">
              <label for="editAvatar">Profile Picture</label>
              <input type="file" id="editAvatar" name="avatar" accept="image/*">
              <small>Max 5MB. JPG, PNG, GIF, WebP</small>
            </div>
            
            <div class="form-group">
              <label for="editBio">Bio</label>
              <textarea id="editBio" name="bio" rows="3" placeholder="Tell us about yourself...">${this.currentUser?.profile?.bio || ''}</textarea>
            </div>
            
            <div class="form-group">
              <label for="editLocation">Location</label>
              <input type="text" id="editLocation" name="location" value="${this.currentUser?.profile?.location || ''}" placeholder="Where are you from?">
            </div>
            
            <div class="form-group">
              <label for="editWebsite">Website</label>
              <input type="url" id="editWebsite" name="website" value="${this.currentUser?.profile?.website || ''}" placeholder="https://yourwebsite.com">
            </div>
            
            <div class="form-group">
              <label for="editInterests">Interests</label>
              <input type="text" id="editInterests" name="interests" value="${this.currentUser?.profile?.interests?.join(', ') || ''}" placeholder="Travel, Photography, History...">
              <small>Separate interests with commas</small>
            </div>
            
            <div class="form-actions">
              <button type="button" class="btn btn-secondary" onclick="authManager.cancelEditProfile()">Cancel</button>
              <button type="submit" class="btn btn-primary">Save Changes</button>
            </div>
          </form>
        </div>
      </div>
    `;

    document.body.appendChild(editModal);
    editModal.style.display = "block";

    // Form submission
    const form = document.getElementById("editProfileForm");
    form.addEventListener("submit", (e) => {
      e.preventDefault();
      this.saveProfileChanges();
    });

    // Close modal functionality
    const closeBtn = editModal.querySelector(".close");
    closeBtn.onclick = () => editModal.remove();

    window.onclick = (event) => {
      if (event.target === editModal) {
        editModal.remove();
      }
    };
  }

  // Save profile changes
  async saveProfileChanges() {
    const form = document.getElementById("editProfileForm");
    const formData = new FormData(form);
    
    const profileData = {
      fullName: formData.get("fullName"),
      bio: formData.get("bio"),
      location: formData.get("location"),
      website: formData.get("website"),
      interests: (formData.get("interests") || "")
        .split(',')
        .map(i => i.trim())
        .filter(i => i)
    };

    try {
      const response = await fetch("/profile", {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.authToken}`,
        },
        body: JSON.stringify(profileData),
      });

      if (response.ok) {
        const data = await response.json();
        if (data.success) {
          // Update current user data
          this.currentUser = { ...this.currentUser, ...data.user };
          // Upload avatar if provided
          const avatarFile = form.querySelector('#editAvatar')?.files?.[0];
          if (avatarFile) {
            await this.uploadAvatar(avatarFile);
          }
          this.showNotification("Profile updated successfully!", "success");
          // Refresh header/dropdown widgets
          this.updateUIForAuthenticatedUser();
          
          // Close edit modal and reopen profile modal
          const editModal = document.getElementById("editProfileModal");
          if (editModal) editModal.remove();
          
          this.createProfileModal();
        } else {
          this.showNotification(data.message || "Error updating profile", "error");
        }
      } else {
        this.showNotification("Error updating profile", "error");
      }
    } catch (error) {
      console.error("Error updating profile:", error);
      this.showNotification("Error updating profile", "error");
    }
  }

  // Cancel edit profile
  cancelEditProfile() {
    const editModal = document.getElementById("editProfileModal");
    if (editModal) editModal.remove();
    this.createProfileModal();
  }

  // Change password functionality
  changePassword() {
    const modal = document.getElementById("profileModal");
    if (modal) modal.remove();

    const changePasswordModal = document.createElement("div");
    changePasswordModal.id = "changePasswordModal";
    changePasswordModal.className = "modal";
    changePasswordModal.innerHTML = `
      <div class="modal-content change-password-modal">
        <div class="modal-header">
          <div class="header-content">
            <div class="settings-icon">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                <rect x="3" y="11" width="18" height="11" rx="2" ry="2" stroke="currentColor" stroke-width="2"/>
                <circle cx="12" cy="16" r="1" stroke="currentColor" stroke-width="2"/>
                <path d="M7 11V7a5 5 0 0 1 10 0v4" stroke="currentColor" stroke-width="2"/>
              </svg>
            </div>
            <div class="header-text">
              <h2>Change Password</h2>
              <p class="profile-subtitle">Update your account password</p>
            </div>
          </div>
          <span class="close">&times;</span>
        </div>
        <div class="modal-body">
          <form id="changePasswordForm" class="password-form">
            <div class="form-group">
              <label for="currentPassword">Current Password</label>
              <input type="password" id="currentPassword" name="currentPassword" required placeholder="Enter current password">
            </div>
            
            <div class="form-group">
              <label for="newPassword">New Password</label>
              <input type="password" id="newPassword" name="newPassword" required placeholder="Enter new password" minlength="6">
              <small>Password must be at least 6 characters long</small>
            </div>
            
            <div class="form-group">
              <label for="confirmPassword">Confirm New Password</label>
              <input type="password" id="confirmPassword" name="confirmPassword" required placeholder="Confirm new password">
            </div>
            
            <div class="form-actions">
              <button type="button" class="btn btn-secondary" onclick="authManager.cancelChangePassword()">Cancel</button>
              <button type="submit" class="btn btn-primary">Change Password</button>
            </div>
          </form>
        </div>
      </div>
    `;

    document.body.appendChild(changePasswordModal);
    changePasswordModal.style.display = "block";

    // Form submission
    const form = document.getElementById("changePasswordForm");
    form.addEventListener("submit", (e) => {
      e.preventDefault();
      this.savePasswordChange();
    });

    // Close modal functionality
    const closeBtn = changePasswordModal.querySelector(".close");
    closeBtn.onclick = () => changePasswordModal.remove();

    window.onclick = (event) => {
      if (event.target === changePasswordModal) {
        changePasswordModal.remove();
      }
    };
  }

  // Save password change
  async savePasswordChange() {
    const form = document.getElementById("changePasswordForm");
    const formData = new FormData(form);
    
    const currentPassword = formData.get("currentPassword");
    const newPassword = formData.get("newPassword");
    const confirmPassword = formData.get("confirmPassword");

    // Validate passwords match
    if (newPassword !== confirmPassword) {
      this.showNotification("New passwords do not match", "error");
      return;
    }

    // Validate password length
    if (newPassword.length < 6) {
      this.showNotification("Password must be at least 6 characters long", "error");
      return;
    }

    try {
      const response = await fetch("/api/user/change-password", {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.authToken}`,
        },
        body: JSON.stringify({
          currentPassword,
          newPassword
        }),
      });

      if (response.ok) {
        const data = await response.json();
        if (data.success) {
          this.showNotification("Password changed successfully!", "success");
          
          // Close change password modal and reopen profile modal
          const changePasswordModal = document.getElementById("changePasswordModal");
          if (changePasswordModal) changePasswordModal.remove();
          
          this.createProfileModal();
        } else {
          this.showNotification(data.message || "Error changing password", "error");
        }
      } else {
        this.showNotification("Error changing password", "error");
      }
    } catch (error) {
      console.error("Error changing password:", error);
      this.showNotification("Error changing password", "error");
    }
  }

  // Cancel change password
  cancelChangePassword() {
    const changePasswordModal = document.getElementById("changePasswordModal");
    if (changePasswordModal) changePasswordModal.remove();
    this.createProfileModal();
  }


  // Apply theme
  applyTheme(theme) {
    const body = document.body;
    body.classList.remove('theme-light', 'theme-dark', 'dark-theme');
    
    if (theme === 'auto') {
      const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
      body.classList.add(prefersDark ? 'theme-dark' : 'theme-light');
    } else if (theme === 'dark') {
      body.classList.add('theme-dark');
    } else {
      body.classList.add('theme-light');
    }
  }

  // Apply language
  applyLanguage(language) {
    const body = document.body;
    body.classList.remove('language-en', 'language-my', 'language-zh', 'language-ja');
    
    if (language === 'my') {
      body.classList.add('language-my');
    } else if (language === 'zh') {
      body.classList.add('language-zh');
    } else if (language === 'ja') {
      body.classList.add('language-ja');
    } else {
      body.classList.add('language-en');
    }
  }

  // Translate text based on current language
  translate(key) {
    const currentLanguage = localStorage.getItem('baganeticSettings') ? 
      JSON.parse(localStorage.getItem('baganeticSettings')).language || 'en' : 'en';
    
    if (this.translations[currentLanguage] && this.translations[currentLanguage][key]) {
      return this.translations[currentLanguage][key];
    }
    
    // Fallback to English
    return this.translations.en[key] || key;
  }

  // Clear cache
  async clearCache() {
    try {
      // Clear localStorage cache
      const keys = Object.keys(localStorage);
      keys.forEach(key => {
        if (key.startsWith('cache_') || key.startsWith('image_')) {
          localStorage.removeItem(key);
        }
      });

      // Clear service worker cache if available
      if ('caches' in window) {
        const cacheNames = await caches.keys();
        await Promise.all(
          cacheNames.map(cacheName => caches.delete(cacheName))
        );
      }

      this.showNotification('Cache cleared successfully!', 'success');
    } catch (error) {
      console.error('Error clearing cache:', error);
      this.showNotification('Error clearing cache', 'error');
    }
  }

  // Update completion tasks
  updateCompletionTasks(user, completionScore) {
    const tasks = [
      { id: 'task-fullname', completed: user.fullName && user.fullName.trim() },
      { id: 'task-bio', completed: user.profile?.bio && user.profile.bio.trim() },
      { id: 'task-avatar', completed: user.profile?.avatar && user.profile.avatar !== 'default' },
      { id: 'task-email', completed: user.isEmailVerified },
      { id: 'task-favorites', completed: user.profile?.favoritePagodas && user.profile.favoritePagodas.length > 0 },
      { id: 'task-visited', completed: user.profile?.visitedPagodas && user.profile.visitedPagodas.length > 0 }
    ];

    tasks.forEach(task => {
      const taskElement = document.getElementById(task.id);
      if (taskElement) {
        const icon = taskElement.querySelector('.task-icon');
        if (icon) {
          icon.textContent = task.completed ? '✓' : '○';
          icon.style.color = task.completed ? '#10b981' : '#6b7280';
        }
      }
    });
  }

  // Update completion tasks from stats
  updateCompletionTasksFromStats(completionScore, favoritesCount, visitedCount) {
    const tasks = [
      { id: 'task-fullname', completed: this.currentUser?.fullName && this.currentUser.fullName.trim() },
      { id: 'task-bio', completed: this.currentUser?.profile?.bio && this.currentUser.profile.bio.trim() },
      { id: 'task-avatar', completed: this.currentUser?.profile?.avatar && this.currentUser.profile.avatar !== 'default' },
      { id: 'task-email', completed: this.currentUser?.isEmailVerified },
      { id: 'task-favorites', completed: favoritesCount > 0 },
      { id: 'task-visited', completed: visitedCount > 0 }
    ];

    tasks.forEach(task => {
      const taskElement = document.getElementById(task.id);
      if (taskElement) {
        const icon = taskElement.querySelector('.task-icon');
        if (icon) {
          icon.textContent = task.completed ? '✓' : '○';
          icon.style.color = task.completed ? '#10b981' : '#6b7280';
        }
      }
    });
  }

  showDeleteAccountModal() {
    // Remove existing modal if any
    const existingModal = document.getElementById("deleteAccountModal");
    if (existingModal) {
      existingModal.remove();
    }

    const modal = document.createElement("div");
    modal.id = "deleteAccountModal";
    modal.className = "modal";
    modal.innerHTML = `
      <div class="modal-content delete-account-modal">
        <div class="modal-header">
          <div class="header-content">
            <div class="danger-icon">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                <path d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </div>
            <div class="header-text">
              <h2>Delete Account</h2>
              <p class="danger-subtitle">This action cannot be undone</p>
            </div>
          </div>
          <span class="close">&times;</span>
        </div>
        <div class="modal-body">
          <div class="warning-message">
            <p><strong>Are you sure you want to delete your account?</strong></p>
            <p>This will permanently delete:</p>
            <ul>
              <li>Your profile and personal information</li>
              <li>Your favorite pagodas</li>
              <li>Your account settings and preferences</li>
              <li>All associated data</li>
            </ul>
            <p class="warning-text">This action cannot be undone!</p>
          </div>
          <form id="deleteAccountForm">
            <div class="form-group">
              <label for="deletePassword">Enter your password to confirm:</label>
              <input type="password" id="deletePassword" name="password" required>
            </div>
            <div class="form-group">
              <label class="checkbox-label">
                <input type="checkbox" id="confirmDelete" required>
                <span class="checkmark"></span>
                I understand that this action cannot be undone
              </label>
            </div>
            <div class="form-actions">
              <button type="button" class="btn btn-secondary" onclick="this.closest('.modal').remove()">Cancel</button>
              <button type="submit" class="btn btn-danger">Delete Account</button>
            </div>
          </form>
        </div>
      </div>
    `;

    document.body.appendChild(modal);
    modal.style.display = "block";

    // Close modal functionality
    const closeBtn = modal.querySelector(".close");
    closeBtn.onclick = () => modal.remove();

    window.onclick = (event) => {
      if (event.target === modal) {
        modal.remove();
      }
    };

    // Handle form submission
    const form = document.getElementById("deleteAccountForm");
    form.addEventListener("submit", this.handleDeleteAccountSubmit.bind(this));
  }

  async handleDeleteAccountSubmit(event) {
    event.preventDefault();

    const password = document.getElementById("deletePassword").value;
    const confirmDelete = document.getElementById("confirmDelete").checked;

    if (!password) {
      this.showNotification("Password is required", "error");
      return;
    }

    if (!confirmDelete) {
      this.showNotification(
        "Please confirm that you understand this action cannot be undone",
        "error"
      );
      return;
    }

    try {
      const response = await fetch("/profile", {
        method: "DELETE",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.authToken}`,
        },
        body: JSON.stringify({
          password,
        }),
      });

      const data = await response.json();

      if (data.success) {
        this.showNotification("Account deleted successfully", "success");

        // Clear local state and redirect
        this.clearAuthState();
        this.updateUIForUnauthenticatedUser();

        // Close modal
        document.getElementById("deleteAccountModal").remove();

        // Redirect to home page after a short delay
        setTimeout(() => {
          window.location.href = "/";
        }, 2000);
      } else {
        this.showNotification(
          data.message || "Failed to delete account",
          "error"
        );
      }
    } catch (error) {
      console.error("Delete account error:", error);
      this.showNotification("Error deleting account", "error");
    }
  }

  async addToFavorites(pagodaId) {
    try {
      const response = await fetch(`/api/user/favorites/${pagodaId}`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${this.authToken}`,
        },
      });

      if (response.ok) {
        this.showNotification("Added to favorites!", "success");
        // Update favorite button state
        this.updateFavoriteButton(pagodaId, true);
      } else {
        this.showNotification("Error adding to favorites", "error");
      }
    } catch (error) {
      console.error("Error adding to favorites:", error);
      this.showNotification("Error adding to favorites", "error");
    }
  }

  async removeFavorite(pagodaId) {
    try {
      const response = await fetch(`/api/user/favorites/${pagodaId}`, {
        method: "DELETE",
        headers: {
          Authorization: `Bearer ${this.authToken}`,
        },
      });

      if (response.ok) {
        this.showNotification("Removed from favorites!", "success");
        // Update favorite button state
        this.updateFavoriteButton(pagodaId, false);
        // Reload favorites if in favorites modal
        if (document.getElementById("favoritesContent")) {
          this.loadUserFavorites();
        }
        // Update statistics
        this.loadUserStatistics();
      } else {
        this.showNotification("Error removing favorite", "error");
      }
    } catch (error) {
      console.error("Error removing favorite:", error);
      this.showNotification("Error removing favorite", "error");
    }
  }

  async markAsVisited(pagodaId) {
    try {
      const response = await fetch(`/api/user/visited/${pagodaId}`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${this.authToken}`,
        },
      });

      if (response.ok) {
        this.showNotification("Marked as visited!", "success");
        // Update statistics
        this.loadUserStatistics();
        // Update the button state
        this.updateVisitedButton(pagodaId, true);
        // Reload favorites if in favorites modal to show updated button
        if (document.getElementById("favoritesContent")) {
          this.loadUserFavorites();
        }
      } else {
        this.showNotification("Error marking as visited", "error");
      }
    } catch (error) {
      console.error("Error marking as visited:", error);
      this.showNotification("Error marking as visited", "error");
    }
  }

  async unmarkAsVisited(pagodaId) {
    try {
      const response = await fetch(`/api/user/visited/${pagodaId}`, {
        method: "DELETE",
        headers: {
          Authorization: `Bearer ${this.authToken}`,
        },
      });

      if (response.ok) {
        this.showNotification("Removed from visited list!", "success");
        // Update statistics
        this.loadUserStatistics();
        // Update the button state
        this.updateVisitedButton(pagodaId, false);
        // Reload visited modal if it's open
        if (document.getElementById("visitedContent")) {
          this.loadUserVisited();
        }
        // Reload favorites if in favorites modal to update button state
        if (document.getElementById("favoritesContent")) {
          this.loadUserFavorites();
        }
      } else {
        this.showNotification("Error removing from visited list", "error");
      }
    } catch (error) {
      console.error("Error removing from visited list:", error);
      this.showNotification("Error removing from visited list", "error");
    }
  }

  updateVisitedButton(pagodaId, isVisited) {
    const visitedBtn = document.querySelector(`[data-pagoda-id="${pagodaId}"] .visited-btn`);
    if (visitedBtn) {
      if (isVisited) {
        visitedBtn.innerHTML = `
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
            <path d="M9 12l2 2 4-4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
          Visited
        `;
        visitedBtn.classList.add("visited");
        visitedBtn.onclick = () => this.unmarkAsVisited(pagodaId);
      } else {
        visitedBtn.innerHTML = `
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
            <path d="M9 12l2 2 4-4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
          Mark Visited
        `;
        visitedBtn.classList.remove("visited");
        visitedBtn.onclick = () => this.markAsVisited(pagodaId);
      }
    }
  }

  updateCompletionTasks(user, completionScore) {
    const tasks = [
      { id: 'task-fullname', completed: user.fullName && user.fullName.trim() },
      { id: 'task-bio', completed: user.profile?.bio && user.profile.bio.trim() },
      { id: 'task-avatar', completed: user.profile?.avatar && user.profile.avatar !== "default" },
      { id: 'task-email', completed: user.isEmailVerified },
      { id: 'task-favorites', completed: user.profile?.favoritePagodas && user.profile.favoritePagodas.length > 0 },
      { id: 'task-visited', completed: user.profile?.visitedPagodas && user.profile.visitedPagodas.length > 0 }
    ];

    tasks.forEach((task, index) => {
      const taskElement = document.getElementById(task.id);
      if (taskElement) {
        const icon = taskElement.querySelector('.task-icon');
        const text = taskElement.querySelector('.task-text');
        
        if (task.completed) {
          taskElement.classList.add('completed');
          if (icon) icon.textContent = '✓';
          if (text) text.style.textDecoration = 'line-through';
        } else {
          taskElement.classList.remove('completed');
          if (icon) icon.textContent = '○';
          if (text) text.style.textDecoration = 'none';
        }
      }
    });
  }

  updateFavoriteButton(pagodaId, isFavorite) {
    // Prefer the new star button if present; fall back to old footer button
    const favoriteBtn = document.querySelector(
      `.pagoda-card[data-pagoda-id="${pagodaId}"] .favorite-star, .recommend-card[data-pagoda-id="${pagodaId}"] .favorite-star`
    ) || document.querySelector(`[data-pagoda-id="${pagodaId}"] .favorite-btn`);
    if (favoriteBtn) {
      if (isFavorite) {
        if (favoriteBtn.classList.contains("favorite-star")) {
          favoriteBtn.classList.add("favorited");
        } else {
          favoriteBtn.innerHTML = `
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
              <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
            </svg>
            Remove from Favorites
          `;
          favoriteBtn.classList.add("favorited");
        }
        favoriteBtn.onclick = () => this.removeFavorite(pagodaId);
      } else {
        if (favoriteBtn.classList.contains("favorite-star")) {
          favoriteBtn.classList.remove("favorited");
        } else {
          favoriteBtn.innerHTML = `
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
            </svg>
            Add to Favorites
          `;
          favoriteBtn.classList.remove("favorited");
        }
        favoriteBtn.onclick = () => this.addToFavorites(pagodaId);
      }
    }
  }

  // Check if a pagoda is in favorites
  async isFavorite(pagodaId) {
    try {
      const response = await fetch("/api/user/favorites", {
        headers: {
          Authorization: `Bearer ${this.authToken}`,
        },
      });

      if (response.ok) {
        const favorites = await response.json();
        return favorites.some((pagoda) => pagoda.id === pagodaId);
      }
      return false;
    } catch (error) {
      console.error("Error checking favorites:", error);
      return false;
    }
  }

  // Check if a pagoda is visited
  async isVisited(pagodaId) {
    try {
      const response = await fetch("/api/user/visited", {
        headers: {
          Authorization: `Bearer ${this.authToken}`,
        },
      });

      if (response.ok) {
        const visited = await response.json();
        return visited.some((pagoda) => pagoda.id === pagodaId);
      }
      return false;
    } catch (error) {
      console.error("Error checking visited status:", error);
      return false;
    }
  }

  setupPasswordValidation() {
    const newPasswordInput = document.getElementById("newPassword");
    const confirmPasswordInput = document.getElementById("confirmNewPassword");

    if (newPasswordInput) {
      newPasswordInput.addEventListener(
        "input",
        this.validatePassword.bind(this)
      );
    }

    if (confirmPasswordInput) {
      confirmPasswordInput.addEventListener(
        "input",
        this.validatePasswordMatch.bind(this)
      );
    }
  }

  validatePassword() {
    const password = document.getElementById("newPassword").value;
    const strengthContainer = document.getElementById("passwordStrength");
    const requirements = {
      length: document.getElementById("req-length"),
      uppercase: document.getElementById("req-uppercase"),
      lowercase: document.getElementById("req-lowercase"),
      number: document.getElementById("req-number"),
      special: document.getElementById("req-special"),
    };

    // Check requirements
    const checks = {
      length: password.length >= 8,
      uppercase: /[A-Z]/.test(password),
      lowercase: /[a-z]/.test(password),
      number: /\d/.test(password),
      special: /[!@#$%^&*(),.?":{}|<>]/.test(password),
    };

    // Update requirement indicators
    Object.keys(checks).forEach((key) => {
      if (requirements[key]) {
        requirements[key].classList.toggle("valid", checks[key]);
        requirements[key].classList.toggle("invalid", !checks[key]);
      }
    });

    // Update strength bar
    if (strengthContainer) {
      const validCount = Object.values(checks).filter(Boolean).length;
      let strength = "weak";
      let width = "25%";

      if (validCount >= 4) {
        strength = "strong";
        width = "100%";
      } else if (validCount >= 2) {
        strength = "medium";
        width = "50%";
      }

      strengthContainer.innerHTML = `<div class="password-strength-bar password-strength-${strength}" style="width: ${width}"></div>`;
    }
  }

  validatePasswordMatch() {
    const password = document.getElementById("newPassword").value;
    const confirmPassword = document.getElementById("confirmNewPassword").value;
    const matchIndicator = document.getElementById("passwordMatch");

    if (matchIndicator) {
      if (confirmPassword && password === confirmPassword) {
        matchIndicator.textContent = "✓ Passwords match";
        matchIndicator.className = "password-match-indicator match";
      } else if (confirmPassword) {
        matchIndicator.textContent = "✗ Passwords do not match";
        matchIndicator.className = "password-match-indicator no-match";
      } else {
        matchIndicator.textContent = "";
        matchIndicator.className = "password-match-indicator";
      }
    }
  }

  showNotification(message, type = "info") {
    // Remove existing notification
    const existingNotification = document.getElementById("notification");
    if (existingNotification) {
      existingNotification.remove();
    }

    const notification = document.createElement("div");
    notification.id = "notification";
    notification.className = `notification notification-${type}`;
    notification.innerHTML = `
      <div class="notification-content">
        <span class="notification-message">${message}</span>
        <button class="notification-close">&times;</button>
      </div>
    `;

    document.body.appendChild(notification);

    // Show notification
    setTimeout(() => {
      notification.classList.add("show");
    }, 100);

    // Auto hide after 3 seconds
    setTimeout(() => {
      notification.classList.remove("show");
      setTimeout(() => {
        if (notification.parentNode) {
          notification.remove();
        }
      }, 300);
    }, 3000);

    // Close button functionality
    const closeBtn = notification.querySelector(".notification-close");
    closeBtn.onclick = () => {
      notification.classList.remove("show");
      setTimeout(() => {
        if (notification.parentNode) {
          notification.remove();
        }
      }, 300);
    };
  }

  resetForms() {
    const loginForm = document.querySelector(".login-form");
    const signupForm = document.querySelector(".signup-form");
    if (loginForm) loginForm.classList.remove("active");
    if (signupForm) signupForm.classList.remove("active");
  }

  toggleForm(formType) {
    const loginForm = document.querySelector(".login-form");
    const signupForm = document.querySelector(".signup-form");

    if (formType === "login") {
      loginForm.classList.add("active");
      signupForm.classList.remove("active");
    } else if (formType === "signup") {
      loginForm.classList.remove("active");
      signupForm.classList.add("active");
    }
  }

  setupEventListeners() {
    // Close dropdown when clicking outside
    document.addEventListener("click", (event) => {
      const dropdown = document.getElementById("userDropdown");
      const loginTrigger = document.getElementById("loginTrigger");

      if (
        dropdown &&
        loginTrigger &&
        !loginTrigger.contains(event.target) &&
        !dropdown.contains(event.target)
      ) {
        dropdown.classList.remove("show");
        setTimeout(() => {
          dropdown.style.display = "none";
        }, 200); // Match CSS transition duration
      }
    });

    // Setup close popup functionality
    this.setupClosePopupHandlers();

    // Setup form submission handlers
    this.setupFormHandlers();
  }

  setupClosePopupHandlers() {
    const closePopup = document.getElementById("closePopup");
    const loginPopup = document.getElementById("loginPopup");

    if (closePopup) {
      closePopup.addEventListener("click", () => {
        this.closeLoginPopup();
      });
    }

    // Close popup when clicking outside
    if (loginPopup) {
      loginPopup.addEventListener("click", (event) => {
        if (event.target === loginPopup) {
          this.closeLoginPopup();
        }
      });
    }

    // Close popup when Escape key is pressed
    document.addEventListener("keydown", (event) => {
      if (
        event.key === "Escape" &&
        loginPopup &&
        loginPopup.style.display === "flex"
      ) {
        this.closeLoginPopup();
      }
    });
  }

  closeLoginPopup() {
    const loginPopup = document.getElementById("loginPopup");
    if (loginPopup) {
      loginPopup.style.display = "none";
      document.body.classList.remove("modal-open");

      // Move popup back to its original container if it was moved to body
      const originalContainer = document.querySelector(
        ".login-popup-container"
      );
      if (originalContainer && loginPopup.parentNode === document.body) {
        originalContainer.appendChild(loginPopup);
      }
    }
  }

  setupFormHandlers() {
    const loginForm = document.getElementById("popupLoginForm");
    const signupForm = document.getElementById("popupSignupForm");

    if (loginForm) {
      loginForm.addEventListener("submit", this.handleLoginSubmit.bind(this));
    }

    if (signupForm) {
      signupForm.addEventListener("submit", this.handleSignupSubmit.bind(this));
    }
  }

  async handleLoginSubmit(event) {
    event.preventDefault();
    const username = document.getElementById("popupUsername").value.trim();
    const password = document.getElementById("popupPassword").value.trim();
    const popupErrorMessage = document.getElementById("popupErrorMessage");
    const popupSuccessMessage = document.getElementById("popupSuccessMessage");
    const loginPopup = document.getElementById("loginPopup");

    // Reset error messages
    if (popupErrorMessage) popupErrorMessage.style.display = "none";
    if (popupSuccessMessage) popupSuccessMessage.style.display = "none";

    if (!username || !password) {
      if (popupErrorMessage) {
        popupErrorMessage.textContent =
          "Please enter both username and password.";
        popupErrorMessage.style.display = "block";
      }
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
        // Handle successful login
        this.handleSuccessfulLogin(data.user, data.token);

        // Soft-refresh: update UI and re-init chatbot without full reload
        try {
          this.updateUIForAuthenticatedUser();
          if (typeof window.initializeChatbot === 'function') {
            setTimeout(() => window.initializeChatbot(), 50);
          }
        } catch (e) {
          console.warn('Soft refresh after login failed:', e);
        }

        if (popupSuccessMessage) {
          popupSuccessMessage.innerHTML = `
            <strong>Login successful!</strong><br>
            Welcome back, ${data.user.fullName || data.user.username}!
          `;
          popupSuccessMessage.style.display = "block";
        }

        // Reset form
        event.target.reset();

        // Close popup after delay
        setTimeout(() => {
          this.closeLoginPopup();
        }, 1500);
      } else {
        if (popupErrorMessage) {
          popupErrorMessage.innerHTML = data.message || "Login failed";
          popupErrorMessage.style.display = "block";
        }
      }
    } catch (err) {
      console.error(err);
      if (popupErrorMessage) {
        popupErrorMessage.textContent =
          "Network error. Please check your connection and try again.";
        popupErrorMessage.style.display = "block";
      }
    }
  }

  async handleSignupSubmit(event) {
    event.preventDefault();
    const fullName = document.getElementById("signupFullName").value.trim();
    const email = document.getElementById("signupEmail").value.trim();
    const username = document.getElementById("signupUsername").value.trim();
    const password = document.getElementById("signupPassword").value;
    const confirmPassword = document.getElementById(
      "signupConfirmPassword"
    )?.value;
    const signupErrorMessage = document.getElementById("signupErrorMessage");
    const signupSuccessMessage = document.getElementById(
      "signupSuccessMessage"
    );
    const loginPopup = document.getElementById("loginPopup");

    // Reset error messages
    if (signupErrorMessage) signupErrorMessage.style.display = "none";
    if (signupSuccessMessage) signupSuccessMessage.style.display = "none";

    // Validation
    if (!fullName || !email || !username || !password || !confirmPassword) {
      if (signupErrorMessage) {
        signupErrorMessage.textContent = "Please fill in all fields.";
        signupErrorMessage.style.display = "block";
      }
      return;
    }

    if (password !== confirmPassword) {
      if (signupErrorMessage) {
        signupErrorMessage.textContent = "Passwords do not match.";
        signupErrorMessage.style.display = "block";
      }
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
        // Handle successful signup
        this.handleSuccessfulSignup(data.user, data.token);

        if (signupSuccessMessage) {
          signupSuccessMessage.innerHTML = `
            <strong>Account created successfully!</strong><br>
            ${
              data.user.isAdminVerified
                ? "Your account is verified and ready to use!"
                : "Your account is pending admin verification. You'll be notified once verified."
            }
          `;
          signupSuccessMessage.style.display = "block";
        }

        // Reset form
        event.target.reset();

        // Close popup after delay
        setTimeout(() => {
          this.closeLoginPopup();
        }, 2000);
      } else {
        if (signupErrorMessage) {
          if (data.errors && Array.isArray(data.errors)) {
            signupErrorMessage.innerHTML = `
              <strong>${data.message}</strong><br>
              ${data.errors.map((error) => `• ${error}`).join("<br>")}
            `;
          } else {
            signupErrorMessage.textContent = data.message || "Signup failed";
          }
          signupErrorMessage.style.display = "block";
        }
      }
    } catch (err) {
      console.error(err);
      if (signupErrorMessage) {
        signupErrorMessage.textContent =
          "Network error. Please check your connection and try again.";
        signupErrorMessage.style.display = "block";
      }
    }
  }

  // Method to handle successful login
  handleSuccessfulLogin(userData, token) {
    this.authToken = token;
    this.isAuthenticated = true;
    this.currentUser = userData;

    // Store in localStorage
    localStorage.setItem("authToken", token);
    localStorage.setItem("userLoggedIn", "true");
    localStorage.setItem("username", userData.username);
    localStorage.setItem("userEmail", userData.email);
    localStorage.setItem("userFullName", userData.fullName);
    if (userData && userData.profile && userData.profile.avatar) {
      localStorage.setItem("userAvatarUrl", userData.profile.avatar);
    }

    // Update UI
    this.updateUIForAuthenticatedUser();
  }

  // Method to handle successful signup
  handleSuccessfulSignup(userData, token) {
    this.handleSuccessfulLogin(userData, token);
  }
}

// Initialize authentication manager when DOM is loaded
document.addEventListener("DOMContentLoaded", function () {
  window.authManager = new AuthManager();
});

// Utility function to add favorite buttons to pagoda cards
function addFavoriteButtonsToPagodaCards() {
  if (!window.authManager || !window.authManager.isAuthenticated) {
    return;
  }

  // Inject minimal styles (once) for the star button
  if (!document.getElementById("favorite-star-styles")) {
    const style = document.createElement("style");
    style.id = "favorite-star-styles";
    style.textContent = `
      .pagoda-card, .recommend-card { position: relative; }
      .favorite-star {
        position: absolute;
        top: 10px;
        right: 10px;
        width: 36px;
        height: 36px;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        background: rgba(255,255,255,0.9);
        border: 1px solid rgba(0,0,0,0.08);
        box-shadow: 0 4px 10px rgba(0,0,0,0.12);
        cursor: pointer;
        z-index: 2;
        transition: transform .15s ease, box-shadow .15s ease;
      }
      .favorite-star:hover { transform: scale(1.05); box-shadow: 0 6px 14px rgba(0,0,0,0.16); }
      .favorite-star svg { width: 20px; height: 20px; }
      .favorite-star svg path { fill: none; stroke: #aa7739; stroke-width: 2; }
      .favorite-star.favorited { background: #fff7e9; border-color: #ffe0a6; }
      .favorite-star.favorited svg path { fill: #ffbf00; stroke: #ffbf00; }
    `;
    document.head.appendChild(style);
  }

  // Find all pagoda cards and add favorite star buttons
  const pagodaCards = document.querySelectorAll(
    ".pagoda-card, .recommend-card"
  );

  pagodaCards.forEach((card) => {
    const pagodaId =
      card.getAttribute("data-pagoda-id") ||
      card.querySelector("[data-pagoda-id]")?.getAttribute("data-pagoda-id");

    if (pagodaId && !card.querySelector(".favorite-star")) {
      const favoriteBtn = document.createElement("button");
      favoriteBtn.className = "favorite-star";
      favoriteBtn.setAttribute("aria-label", "Toggle favorite");
      favoriteBtn.setAttribute("data-pagoda-id", pagodaId);
      favoriteBtn.innerHTML = `
        <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21 12 17.27z" />
        </svg>
      `;

      // Prevent navigation when clicking the star
      favoriteBtn.addEventListener("click", (e) => e.stopPropagation());

      // Set initial state
      favoriteBtn.onclick = () => window.authManager.addToFavorites(pagodaId);

      // Check if already in favorites
      window.authManager.isFavorite(pagodaId).then((isFav) => {
        if (isFav) {
          window.authManager.updateFavoriteButton(pagodaId, true);
        }
      });

      // Append in the top-right corner of the card
      card.appendChild(favoriteBtn);
    }
  });
}

// Function to initialize theme on page load
function initializeTheme() {
  const savedTheme = localStorage.getItem("theme") || "light";
  if (window.authManager) {
    window.authManager.applyTheme(savedTheme);
  }
}

// Initialize theme when DOM is loaded
document.addEventListener("DOMContentLoaded", initializeTheme);

// Export for use in other files
if (typeof module !== "undefined" && module.exports) {
  module.exports = AuthManager;
}
