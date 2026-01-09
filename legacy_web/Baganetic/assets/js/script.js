// Baganetic Enhanced Login/Signup Popup JavaScript
// Authentication is now handled by auth.js

// Login/Signup popup functionality

document.addEventListener("DOMContentLoaded", function () {
  // Login/Signup popup functionality
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
  const forgotPasswordForm = document.querySelector(".forgot-password-form");
  const forgotPasswordLink = document.getElementById("forgotPasswordLink");
  const backToLoginLink = document.getElementById("backToLoginLink");
  const forgotErrorMessage = document.getElementById("forgotErrorMessage");
  const forgotSuccessMessage = document.getElementById("forgotSuccessMessage");

  // Note: Login popup functionality is now handled entirely by auth.js
  // No need to add event listeners here as they conflict with auth.js

  // Close login popup
  closePopup.addEventListener("click", function () {
    loginPopup.style.display = "none";
    document.body.classList.remove("modal-open"); // Restore scrolling
    resetForms();
  });

  // Close popup when clicking outside
  window.addEventListener("click", function (event) {
    if (event.target === loginPopup) {
      loginPopup.style.display = "none";
      document.body.classList.remove("modal-open");
      resetForms();
    }
  });

  // Password visibility toggle functionality
  document.addEventListener("click", function (event) {
    if (event.target.classList.contains("password-toggle")) {
      const targetId = event.target.getAttribute("data-target");
      const passwordField = document.getElementById(targetId);
      const toggleButton = event.target;

      if (passwordField.type === "password") {
        passwordField.type = "text";
        toggleButton.textContent = "🙈";
        toggleButton.setAttribute("aria-label", "Hide password");
      } else {
        passwordField.type = "password";
        toggleButton.textContent = "👁️";
        toggleButton.setAttribute("aria-label", "Show password");
      }
    }
  });

  // Form toggle functionality
  function toggleForm(formType) {
    // Hide all forms first
    loginForm.classList.remove("active");
    signupForm.classList.remove("active");
    if (forgotPasswordForm) forgotPasswordForm.classList.remove("active");

    // Reset all toggle buttons
    toggleBtns.forEach((btn) => btn.classList.remove("active"));

    if (formType === "login") {
      loginForm.classList.add("active");
      if (toggleBtns[0]) toggleBtns[0].classList.add("active");
    } else if (formType === "signup") {
      signupForm.classList.add("active");
      if (toggleBtns[1]) toggleBtns[1].classList.add("active");
    } else if (formType === "forgot-password") {
      if (forgotPasswordForm) forgotPasswordForm.classList.add("active");
      // Hide toggle buttons for forgot password form
      toggleBtns.forEach((btn) => btn.classList.remove("active"));
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

  // Add event listeners for forgot password and back to login links
  if (forgotPasswordLink) {
    forgotPasswordLink.addEventListener("click", (e) => {
      e.preventDefault();
      toggleForm("forgot-password");
    });
  }

  if (backToLoginLink) {
    backToLoginLink.addEventListener("click", (e) => {
      e.preventDefault();
      toggleForm("login");
    });
  }

  // Reset form states
  function resetForms() {
    popupErrorMessage.style.display = "none";
    popupSuccessMessage.style.display = "none";
    signupErrorMessage.style.display = "none";
    signupSuccessMessage.style.display = "none";
    if (forgotErrorMessage) forgotErrorMessage.style.display = "none";
    if (forgotSuccessMessage) forgotSuccessMessage.style.display = "none";
  }

  // Handle forgot password form submission
  if (document.getElementById("popupForgotPasswordForm")) {
    document
      .getElementById("popupForgotPasswordForm")
      .addEventListener("submit", async function (event) {
        event.preventDefault();
        const email = document.getElementById("forgotEmail").value.trim();

        const submitButton = event.target.querySelector(".auth-button");
        if (!submitButton.dataset.originalText) {
          submitButton.dataset.originalText = submitButton.textContent;
        }

        // Reset messages
        forgotErrorMessage.style.display = "none";
        forgotSuccessMessage.style.display = "none";

        if (!email) {
          forgotErrorMessage.textContent = "Please enter your email address.";
          forgotErrorMessage.style.display = "block";
          return;
        }

        if (!validateEmail(email)) {
          forgotErrorMessage.textContent =
            "Please enter a valid email address.";
          forgotErrorMessage.style.display = "block";
          return;
        }

        showLoadingState(submitButton, true);

        try {
          const res = await fetch("/forgot-password", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ email }),
          });
          const data = await res.json();

          if (data.success) {
            forgotSuccessMessage.innerHTML = `
            <strong>Reset link sent!</strong><br>
            ${data.message}
            ${
              data.resetToken
                ? `<br><small>Debug token: ${data.resetToken}</small>`
                : ""
            }
          `;
            forgotSuccessMessage.style.display = "block";
            forgotErrorMessage.style.display = "none";
            document.getElementById("popupForgotPasswordForm").reset();
          } else {
            forgotErrorMessage.textContent =
              data.message || "Failed to send reset link";
            forgotErrorMessage.style.display = "block";
          }
        } catch (err) {
          console.error(err);
          forgotErrorMessage.textContent =
            "Network error. Please check your connection and try again.";
          forgotErrorMessage.style.display = "block";
        } finally {
          showLoadingState(submitButton, false);
        }
      });
  }

  // Note: Login form submission is now handled entirely by auth.js
  // No need to add event listeners here as they conflict with auth.js

  // Password strength validation
  function validatePasswordStrength(password) {
    const minLength = 8;
    const hasUpperCase = /[A-Z]/.test(password);
    const hasLowerCase = /[a-z]/.test(password);
    const hasNumbers = /\d/.test(password);
    const hasSpecialChar = /[!@#$%^&*(),.?":{}|<>]/.test(password);

    const errors = [];

    if (password.length < minLength) {
      errors.push(`Password must be at least ${minLength} characters long`);
    }
    if (!hasUpperCase) {
      errors.push("Password must contain at least one uppercase letter");
    }
    if (!hasLowerCase) {
      errors.push("Password must contain at least one lowercase letter");
    }
    if (!hasNumbers) {
      errors.push("Password must contain at least one number");
    }
    if (!hasSpecialChar) {
      errors.push("Password must contain at least one special character");
    }

    return {
      isValid: errors.length === 0,
      errors: errors,
      strength: calculatePasswordStrength(password),
    };
  }

  function calculatePasswordStrength(password) {
    let score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (/[A-Z]/.test(password)) score++;
    if (/[a-z]/.test(password)) score++;
    if (/\d/.test(password)) score++;
    if (/[!@#$%^&*(),.?":{}|<>]/.test(password)) score++;
    if (password.length >= 16) score++;

    if (score <= 2) return "weak";
    if (score <= 4) return "medium";
    return "strong";
  }

  function updatePasswordStrengthIndicator(password, strengthElement) {
    if (!strengthElement) return;

    const validation = validatePasswordStrength(password);
    const strength = validation.strength;

    strengthElement.className = `password-strength ${strength}`;

    let strengthText = "";
    let strengthColor = "";

    switch (strength) {
      case "weak":
        strengthText = "Weak";
        strengthColor = "#dc3545";
        break;
      case "medium":
        strengthText = "Medium";
        strengthColor = "#ffc107";
        break;
      case "strong":
        strengthText = "Strong";
        strengthColor = "#28a745";
        break;
    }

    strengthElement.innerHTML = `
      <div class="strength-bar">
        <div class="strength-fill ${strength}"></div>
      </div>
      <span class="strength-text" style="color: ${strengthColor}">${strengthText}</span>
    `;

    return validation;
  }

  function showLoadingState(button, isLoading) {
    if (isLoading) {
      button.disabled = true;
      button.innerHTML = '<span class="loading-spinner"></span> Processing...';
    } else {
      button.disabled = false;
      button.innerHTML = button.dataset.originalText || button.textContent;
    }
  }

  // Note: Signup form submission is now handled entirely by auth.js
  // No need to add event listeners here as they conflict with auth.js

  // Email validation function
  function validateEmail(email) {
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return re.test(email);
  }

  // Update login button after successful login - now handled by AuthManager
  function updateLoginButton(username) {
    // This function is now handled by AuthManager
    // Keeping for backward compatibility but it's deprecated
    console.warn("updateLoginButton is deprecated. Use AuthManager instead.");
  }

  // Function to show login popup (extracted for better event handling)
  function showLoginPopup() {
    // If the popup is inside the header (sticky/backdrop-filter), move it to body
    if (
      loginPopup &&
      loginPopup.parentNode &&
      loginPopup.parentNode.tagName !== "BODY"
    ) {
      document.body.appendChild(loginPopup);
    }
    loginPopup.style.display = "flex";
    document.body.classList.add("modal-open"); // Prevent scrolling
    resetForms();
    toggleForm("login");
  }

  // Create user dropdown menu - now handled by AuthManager
  function createUserDropdown() {
    // This function is now handled by AuthManager
    // Keeping for backward compatibility but it's deprecated
    console.warn("createUserDropdown is deprecated. Use AuthManager instead.");
  }

  // Show user profile modal
  function showUserProfile(event) {
    event.preventDefault();
    createProfileModal();
  }

  // Show user favorites
  function showUserFavorites(event) {
    event.preventDefault();
    // Redirect to pagodas page with favorites filter
    window.location.href = (window.location.pathname.includes('/mmversion/') ? "mmversion/pagodasmm.html?filter=favorites" : "pagodas.html?filter=favorites");
  }


  // Create profile modal
  function createProfileModal() {
    // Remove existing modal if any
    const existingModal = document.getElementById("profileModal");
    if (existingModal) {
      existingModal.remove();
    }

    const modal = document.createElement("div");
    modal.id = "profileModal";
    modal.className = "profile-modal";

    const userFullName = localStorage.getItem("userFullName") || "";
    const userEmail = localStorage.getItem("userEmail") || "";
    const username = localStorage.getItem("username") || "";

    modal.innerHTML = `
      <div class="modal-content">
        <div class="modal-header">
          <h3>My Profile</h3>
          <span class="close-modal" id="closeProfileModal">&times;</span>
        </div>
        <div class="modal-body">
          <form id="profileForm">
            <div class="profile-avatar-section">
              <div class="avatar-display">👤</div>
              <button type="button" class="change-avatar-btn">Change Avatar</button>
            </div>
            <div class="form-group">
              <label for="profileFullName">Full Name</label>
              <input type="text" id="profileFullName" value="${userFullName}" maxlength="100">
            </div>
            <div class="form-group">
              <label for="profileUsername">Username</label>
              <input type="text" id="profileUsername" value="${username}" readonly>
              <small>Username cannot be changed</small>
            </div>
            <div class="form-group">
              <label for="profileEmail">Email</label>
              <input type="email" id="profileEmail" value="${userEmail}" readonly>
              <small>Email cannot be changed</small>
            </div>
            <div class="form-group">
              <label for="profileBio">Bio</label>
              <textarea id="profileBio" maxlength="500" placeholder="Tell us about yourself..."></textarea>
              <small class="char-count">0/500 characters</small>
            </div>
            <div class="form-actions">
              <button type="submit" class="auth-button">Save Changes</button>
              <button type="button" class="auth-button secondary" id="cancelProfile">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    `;

    document.body.appendChild(modal);
    modal.style.display = "block";
    document.body.style.overflow = "hidden";

    // Add event listeners
    const closeBtn = document.getElementById("closeProfileModal");
    const cancelBtn = document.getElementById("cancelProfile");
    const profileForm = document.getElementById("profileForm");
    const bioTextarea = document.getElementById("profileBio");
    const charCount = modal.querySelector(".char-count");

    closeBtn.addEventListener("click", closeProfileModal);
    cancelBtn.addEventListener("click", closeProfileModal);
    profileForm.addEventListener("submit", handleProfileUpdate);

    // Character count for bio
    bioTextarea.addEventListener("input", function () {
      const count = this.value.length;
      charCount.textContent = `${count}/500 characters`;
      charCount.style.color = count > 450 ? "#dc3545" : "#6c757d";
    });

    // Close modal when clicking outside
    modal.addEventListener("click", function (event) {
      if (event.target === modal) {
        closeProfileModal();
      }
    });

    // Load existing profile data
    loadUserProfile();
  }

  // Close profile modal
  function closeProfileModal() {
    const modal = document.getElementById("profileModal");
    if (modal) {
      modal.remove();
      document.body.style.overflow = "";
    }
  }

  // Load user profile data
  async function loadUserProfile() {
    const token = localStorage.getItem("authToken");
    if (!token) return;

    try {
      const res = await fetch("/profile", {
        method: "GET",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
      });

      if (res.ok) {
        const data = await res.json();
        if (data.success && data.user) {
          const bioTextarea = document.getElementById("profileBio");
          if (bioTextarea && data.user.profile && data.user.profile.bio) {
            bioTextarea.value = data.user.profile.bio;
            bioTextarea.dispatchEvent(new Event("input")); // Trigger character count update
          }
        }
      }
    } catch (error) {
      console.error("Failed to load profile:", error);
    }
  }

  // Handle profile update
  async function handleProfileUpdate(event) {
    event.preventDefault();

    const token = localStorage.getItem("authToken");
    if (!token) {
      alert("Please log in again to update your profile.");
      return;
    }

    const fullName = document.getElementById("profileFullName").value.trim();
    const bio = document.getElementById("profileBio").value.trim();

    const submitButton = event.target.querySelector(".auth-button");
    showLoadingState(submitButton, true);

    try {
      const res = await fetch("/profile", {
        method: "PUT",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ fullName, bio }),
      });

      const data = await res.json();

      if (data.success) {
        // Update localStorage
        localStorage.setItem("userFullName", fullName);

        // Update UI
        updateLoginButton(localStorage.getItem("username"));

        alert("Profile updated successfully!");
        closeProfileModal();
      } else {
        alert(data.message || "Failed to update profile");
      }
    } catch (error) {
      console.error("Profile update error:", error);
      alert("Network error. Please try again.");
    } finally {
      showLoadingState(submitButton, false);
    }
  }


  // Toggle user dropdown visibility - now handled by AuthManager
  function toggleUserDropdown(event) {
    // This function is now handled by AuthManager
    // Keeping for backward compatibility but it's deprecated
    console.warn("toggleUserDropdown is deprecated. Use AuthManager instead.");
  }

  // Handle logout functionality - now handled by AuthManager
  async function handleLogout(event) {
    // This function is now handled by AuthManager
    // Keeping for backward compatibility but it's deprecated
    console.warn("handleLogout is deprecated. Use AuthManager instead.");
  }

  // Reset login button to original state - now handled by AuthManager
  function resetLoginButton() {
    // This function is now handled by AuthManager
    // Keeping for backward compatibility but it's deprecated
    console.warn("resetLoginButton is deprecated. Use AuthManager instead.");
  }

  // Check if user is already logged in - now handled by AuthManager
  function checkLoginStatus() {
    // This function is now handled by AuthManager
    // Keeping for backward compatibility but it's deprecated
    console.warn("checkLoginStatus is deprecated. Use AuthManager instead.");
  }

  // Initialize login status - now handled by AuthManager
  // checkLoginStatus();

  // Real-time password validation
  const signupPasswordInput = document.getElementById("signupPassword");
  const confirmPasswordInput = document.getElementById("signupConfirmPassword");
  const passwordStrengthContainer = document.getElementById("passwordStrength");
  const passwordMatchIndicator = document.getElementById("passwordMatch");

  if (signupPasswordInput) {
    signupPasswordInput.addEventListener("input", function () {
      const password = this.value;

      // Update password strength indicator
      if (passwordStrengthContainer) {
        updatePasswordStrengthIndicator(password, passwordStrengthContainer);
      }

      // Update password requirements
      updatePasswordRequirements(password);

      // Check password match if confirm password has value
      if (confirmPasswordInput && confirmPasswordInput.value) {
        updatePasswordMatch(password, confirmPasswordInput.value);
      }
    });
  }

  if (confirmPasswordInput) {
    confirmPasswordInput.addEventListener("input", function () {
      const confirmPassword = this.value;
      const password = signupPasswordInput ? signupPasswordInput.value : "";

      updatePasswordMatch(password, confirmPassword);
    });
  }

  function updatePasswordRequirements(password) {
    const requirements = [
      { id: "req-length", test: password.length >= 8 },
      { id: "req-uppercase", test: /[A-Z]/.test(password) },
      { id: "req-lowercase", test: /[a-z]/.test(password) },
      { id: "req-number", test: /\d/.test(password) },
      { id: "req-special", test: /[!@#$%^&*(),.?":{}|<>]/.test(password) },
    ];

    requirements.forEach((req) => {
      const element = document.getElementById(req.id);
      if (element) {
        element.className = req.test
          ? "valid"
          : password.length > 0
          ? "invalid"
          : "";
      }
    });
  }

  function updatePasswordMatch(password, confirmPassword) {
    if (!passwordMatchIndicator) return;

    if (confirmPassword.length === 0) {
      passwordMatchIndicator.innerHTML = "";
      passwordMatchIndicator.className = "password-match-indicator";
      return;
    }

    if (password === confirmPassword) {
      passwordMatchIndicator.innerHTML = "✓ Passwords match";
      passwordMatchIndicator.className = "password-match-indicator match";
    } else {
      passwordMatchIndicator.innerHTML = "✗ Passwords do not match";
      passwordMatchIndicator.className = "password-match-indicator no-match";
    }
  }

  // Close user dropdown when clicking outside - now handled by AuthManager
  // This functionality is now handled by AuthManager's setupEventListeners method
});
// Enhanced Mobile-First Hamburger menu functionality
const hamburger = document.getElementById("hamburger");
const navDrawer = document.getElementById("navDrawer");
const closeNav = document.getElementById("closeNav");
const body = document.body;

// Mobile navigation state management
let isNavOpen = false;

// Touch handling for mobile devices
let touchStartX = 0;
let touchStartY = 0;
let touchEndX = 0;
let touchEndY = 0;

function isMobileDevice() {
  return (
    window.innerWidth <= 768 ||
    /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
      navigator.userAgent
    )
  );
}

function openNavigation() {
  body.classList.add("nav-open");
  isNavOpen = true;

  // Prevent body scroll on mobile when nav is open
  if (isMobileDevice()) {
    body.style.overflow = "hidden";
  }

  // Set focus to first nav item for accessibility
  const firstNavItem = navDrawer?.querySelector("a");
  if (firstNavItem) {
    setTimeout(() => firstNavItem.focus(), 100);
  }
}

function closeNavigation() {
  body.classList.remove("nav-open");
  isNavOpen = false;

  // Restore body scroll
  body.style.overflow = "";

  // Return focus to hamburger button
  if (hamburger) {
    hamburger.focus();
  }
}

// Enhanced hamburger menu with better mobile support
if (hamburger && navDrawer) {
  // Main hamburger click handler
  hamburger.addEventListener("click", function (e) {
    e.preventDefault();
    e.stopPropagation();

    if (isNavOpen) {
      closeNavigation();
    } else {
      openNavigation();
    }
  });

  // Touch events for swipe gestures on mobile
  if (isMobileDevice()) {
    // Swipe to open navigation from left edge
    document.addEventListener(
      "touchstart",
      function (e) {
        touchStartX = e.changedTouches[0].screenX;
        touchStartY = e.changedTouches[0].screenY;
      },
      { passive: true }
    );

    document.addEventListener(
      "touchend",
      function (e) {
        touchEndX = e.changedTouches[0].screenX;
        touchEndY = e.changedTouches[0].screenY;
        handleSwipeGesture();
      },
      { passive: true }
    );
  }

  // Close drawer when clicking close button
  if (closeNav) {
    closeNav.addEventListener("click", function (e) {
      e.preventDefault();
      closeNavigation();
    });
  }

  // Enhanced outside click detection
  document.addEventListener("click", function (event) {
    if (
      isNavOpen &&
      !hamburger.contains(event.target) &&
      !navDrawer.contains(event.target)
    ) {
      closeNavigation();
    }
  });

  // Close drawer when clicking on a link
  const navLinks = navDrawer.querySelectorAll("a");
  navLinks.forEach((link) => {
    link.addEventListener("click", function () {
      // Delay closing to allow navigation to complete
      setTimeout(() => closeNavigation(), 100);
    });
  });

  // Handle mobile login trigger - now handled by AuthManager
  // The AuthManager will handle both desktop and mobile login triggers
  // This ensures consistent behavior across all login entry points

  // Keyboard navigation support
  document.addEventListener("keydown", function (e) {
    if (isNavOpen) {
      if (e.key === "Escape") {
        e.preventDefault();
        closeNavigation();
      }

      // Tab trapping within navigation
      if (e.key === "Tab") {
        const focusableElements = navDrawer.querySelectorAll(
          'a, button, [tabindex]:not([tabindex="-1"])'
        );
        const firstElement = focusableElements[0];
        const lastElement = focusableElements[focusableElements.length - 1];

        if (e.shiftKey && document.activeElement === firstElement) {
          e.preventDefault();
          lastElement.focus();
        } else if (!e.shiftKey && document.activeElement === lastElement) {
          e.preventDefault();
          firstElement.focus();
        }
      }
    }
  });

  // Handle window resize to close nav on desktop
  window.addEventListener("resize", function () {
    if (window.innerWidth > 768 && isNavOpen) {
      closeNavigation();
    }
  });
} else {
  console.error("Hamburger or nav drawer element not found!");
}

// Swipe gesture handler for mobile
function handleSwipeGesture() {
  const swipeThreshold = 50;
  const swipeDistance = touchEndX - touchStartX;
  const verticalDistance = Math.abs(touchEndY - touchStartY);

  // Only handle horizontal swipes
  if (verticalDistance < swipeThreshold) {
    // Swipe right from left edge to open
    if (touchStartX < 50 && swipeDistance > swipeThreshold && !isNavOpen) {
      openNavigation();
    }
    // Swipe left to close
    else if (swipeDistance < -swipeThreshold && isNavOpen) {
      closeNavigation();
    }
  }
}

// --- Search functionality for non-pagoda pages with suggestions ---

// Get pagoda data from the centralized database
function getAllPagodas() {
  // Use the pagoda manager if available, otherwise fallback to basic data
  if (window.pagodaManager) {
    return window.pagodaManager.getAllPagodas().map((pagoda) => ({
      name: pagoda.name,
      image: pagoda.images.main,
      alt: `${pagoda.name} - ${pagoda.description.short}`,
      location: `${pagoda.location.city}, ${pagoda.location.country}`,
      id: pagoda.id,
    }));
  }

  // Fallback data if pagoda manager is not loaded
  return [
    {
      name: "Ananda Temple",
      image:
        "./assets/images/pagodas/Ananda Temple/ananda-temple-4899166_1280.jpg",
      alt: "Ancient golden Ananda Temple with intricate Burmese architecture and multiple spires against blue sky in Bagan",
      location: "Bagan, Myanmar",
      id: "ananda",
    },
    {
      name: "Dhammayangyi Temple",
      image:
        "./assets/images/pagodas/Dhammayangyi Temple/Dhammayangyi_Temple_at_Bagan,Myanmar.jpg",
      alt: "Massive red brick Dhammayangyi Temple with pyramid-like structure and arched doorways in Old Bagan",
      location: "Bagan, Myanmar",
      id: "dhammayangyi",
    },
    {
      name: "Shwezigon Pagoda",
      image:
        "./assets/images/pagodas/Shwezigon Pagoda/1a1afe376333f59c9bb72dbf35c2e9c9.jpg",
      alt: "Golden bell-shaped Shwezigon Pagoda with traditional Burmese design and surrounding smaller stupas",
      location: "Bagan, Myanmar",
      id: "shwezigon",
    },
    {
      name: "Sulamani Temple",
      image:
        "./assets/images/pagodas/Sulamani Temple/7e5692c46b129496fc9c5a5e966b4621.jpg",
      alt: "Elegant red brick Sulamani Temple with intricate carvings and multiple terraces in Old Bagan",
      location: "Bagan, Myanmar",
      id: "sulamani",
    },
    {
      name: "Thatbyinnyu Temple",
      image:
        "./assets/images/pagodas/Thatbyinnyu Temple/1f1ce06e7352fa7895d920c25aa69217.jpg",
      alt: "Tall white Thatbyinnyu Temple with distinctive tiered architecture rising above Bagan temple plains",
      location: "Bagan, Myanmar",
      id: "thatbinnyu",
    },
    {
      name: "Gawdawpalin Temple",
      image:
        "./assets/images/pagodas/Gawdawpalin Temple/31922c378893074a240e3f07913b4d18.jpg",
      alt: "Majestic Gawdawpalin Temple with white walls and golden spires rising above Bagan landscape",
      location: "Bagan, Myanmar",
      id: "gawdawpalin",
    },
  ];
}

const navSearchInput = document.getElementById("navSearch");
const navSearchButton = document.getElementById("navSearchButton");
const mobileLoginTrigger = document.getElementById("mobileLoginTrigger");

// Mobile elements
const mobileLangToggle = document.getElementById("mobileLangToggle");

let currentActiveSuggestion = -1; // For keyboard navigation

// Function to display suggestions with images
function showSuggestions(inputElement, suggestionsContainer) {
  const searchValue = inputElement.value.toLowerCase().trim();
  suggestionsContainer.innerHTML = "";
  currentActiveSuggestion = -1;

  // Show suggestions from the first character typed
  if (searchValue.length === 0) {
    suggestionsContainer.style.display = "none";
    return;
  }

  // Get fresh pagoda data each time to ensure it's loaded
  const allPagodas = getAllPagodas();
  console.log("All pagodas:", allPagodas); // Debug log
  // First get pagodas that start with the search term
  const startsWithResults = allPagodas.filter((pagoda) =>
    pagoda.name.toLowerCase().startsWith(searchValue)
  );

  // Then get pagodas that contain the search term but don't start with it
  const containsResults = allPagodas.filter(
    (pagoda) =>
      pagoda.name.toLowerCase().includes(searchValue) &&
      !pagoda.name.toLowerCase().startsWith(searchValue)
  );

  // Combine results with "starts with" first, then "contains"
  const filteredPagodas = [...startsWithResults, ...containsResults].sort(
    (a, b) => a.name.localeCompare(b.name)
  );

  console.log("Filtered pagodas:", filteredPagodas); // Debug log

  if (filteredPagodas.length > 0) {
    suggestionsContainer.style.display = "block";
    filteredPagodas.forEach((pagoda, index) => {
      const li = document.createElement("li");

      // Create image element
      const img = document.createElement("img");
      img.src = pagoda.image;
      img.alt = pagoda.alt;
      img.className = "suggestion-image";
      img.onerror = function () {
        this.style.display = "none";
      };

      // Create text container
      const textContainer = document.createElement("div");
      textContainer.className = "suggestion-text";

      const nameDiv = document.createElement("div");
      nameDiv.textContent = pagoda.name;
      nameDiv.style.fontWeight = "500";

      const locationDiv = document.createElement("div");
      locationDiv.textContent = pagoda.location;
      locationDiv.className = "suggestion-location";

      textContainer.appendChild(nameDiv);
      textContainer.appendChild(locationDiv);

      li.appendChild(img);
      li.appendChild(textContainer);

      li.addEventListener("click", () => {
        inputElement.value = pagoda.name;
        suggestionsContainer.style.display = "none";
        // Redirect to specific pagoda detail page
        window.location.href = (window.location.pathname.includes('/mmversion/') ? `mmversion/${pagoda.id}mm.html` : `pagodaDetils.html?id=${pagoda.id}`);
      });

      suggestionsContainer.appendChild(li);
    });
    suggestionsContainer.style.display = "block";
  } else {
    suggestionsContainer.style.display = "none";
  }
}

// Function to navigate suggestions with keyboard
function navigateSuggestions(inputElement, suggestionsContainer, event) {
  const items = suggestionsContainer.querySelectorAll("li");
  if (items.length === 0) return;

  if (event.key === "ArrowDown") {
    event.preventDefault();
    currentActiveSuggestion = (currentActiveSuggestion + 1) % items.length;
    highlightSuggestion(items);
  } else if (event.key === "ArrowUp") {
    event.preventDefault();
    currentActiveSuggestion =
      (currentActiveSuggestion - 1 + items.length) % items.length;
    highlightSuggestion(items);
  } else if (event.key === "Enter") {
    event.preventDefault();
    if (currentActiveSuggestion > -1) {
      items[currentActiveSuggestion].click();
    } else {
      // If no suggestion highlighted, search for the first matching pagoda
      const searchValue = inputElement.value.toLowerCase().trim();
      const matchingPagoda = allPagodas.find((pagoda) =>
        pagoda.name.toLowerCase().includes(searchValue)
      );
      if (matchingPagoda) {
        window.location.href = (window.location.pathname.includes('/mmversion/') ? `mmversion/${matchingPagoda.id}mm.html` : `pagodaDetils.html?id=${matchingPagoda.id}`);
      }
    }
  } else if (event.key === "Escape") {
    suggestionsContainer.style.display = "none";
    currentActiveSuggestion = -1;
  }
}

// Function to highlight active suggestion
function highlightSuggestion(items) {
  items.forEach((item, index) => {
    if (index === currentActiveSuggestion) {
      item.classList.add("active");
      item.scrollIntoView({ block: "nearest" });
    } else {
      item.classList.remove("active");
    }
  });
}

// Function to handle search button click (redirect to pagodas.html)
function handleSearchButton(sourceInput) {
  const searchValue = sourceInput.value.trim();
  if (searchValue) {
    // For button clicks, redirect to pagodas.html for general search
    window.location.href = (window.location.pathname.includes('/mmversion/') ? `mmversion/pagodasmm.html?search=${encodeURIComponent(searchValue)}` : `pagodas.html?search=${encodeURIComponent(searchValue)}`);
  }
}

// Function to sync search inputs (desktop navbar only)
function syncSearchInputs(value) {
  if (navSearchInput && navSearchInput.value !== value)
    navSearchInput.value = value;
}

// Enhanced search functionality with mobile optimization
if (navSearchInput) {
  const navSuggestions = document.createElement("ul");
  navSuggestions.className = "search-suggestions";
  navSearchInput.parentNode.insertBefore(
    navSuggestions,
    navSearchInput.nextSibling
  );

  // Enhanced input handling with debouncing for mobile performance
  let searchTimeout;
  navSearchInput.addEventListener("input", () => {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
      syncSearchInputs(navSearchInput.value);
      console.log("Showing suggestions for:", navSearchInput.value); // Debug log
      showSuggestions(navSearchInput, navSuggestions);
    }, 50); // Reduced debounce for faster response
  });

  navSearchInput.addEventListener("keydown", (e) =>
    navigateSuggestions(navSearchInput, navSuggestions, e)
  );

  navSearchInput.addEventListener("focus", () => {
    if (navSearchInput.value.trim()) {
      showSuggestions(navSearchInput, navSuggestions);
    }
  });

  navSearchInput.addEventListener("blur", () => {
    // Delay hiding to allow click event on suggestion to fire
    setTimeout(() => {
      navSuggestions.style.display = "none";
      currentActiveSuggestion = -1;
    }, 200); // Slightly longer delay for mobile touch events
  });

  // Mobile-specific touch handling for search
  if (isMobileDevice()) {
    navSearchInput.addEventListener("touchstart", function () {
      this.focus();
    });
  }
}

// Mobile search functionality removed - search only available in desktop navbar

// Button event listeners (these will redirect to pagodas.html for general search)
if (navSearchButton) {
  navSearchButton.addEventListener("click", () =>
    handleSearchButton(navSearchInput)
  );
}

// Enhanced outside click handling for mobile
document.addEventListener("click", function (event) {
  const suggestions = document.querySelectorAll(".search-suggestions");
  suggestions.forEach((suggestionBox) => {
    if (!suggestionBox.parentNode.contains(event.target)) {
      suggestionBox.style.display = "none";
      currentActiveSuggestion = -1;
    }
  });
});

// Add touch event handling for mobile devices
if (isMobileDevice()) {
  document.addEventListener(
    "touchstart",
    function (event) {
      const suggestions = document.querySelectorAll(".search-suggestions");
      suggestions.forEach((suggestionBox) => {
        if (!suggestionBox.parentNode.contains(event.target)) {
          suggestionBox.style.display = "none";
          currentActiveSuggestion = -1;
        }
      });
    },
    { passive: true }
  );
}

// Smooth scrolling for navigation links
document.addEventListener("DOMContentLoaded", function () {
  document.querySelectorAll('a[href^="#"]').forEach((anchor) => {
    anchor.addEventListener("click", function (e) {
      e.preventDefault();
      const href = this.getAttribute("href");
      // Only process if href is not just "#"
      if (href && href !== "#" && href.length > 1) {
        const target = document.querySelector(href);
        if (target) {
          target.scrollIntoView({
            behavior: "smooth",
            block: "start",
          });
        }
      }
    });
  });
});
