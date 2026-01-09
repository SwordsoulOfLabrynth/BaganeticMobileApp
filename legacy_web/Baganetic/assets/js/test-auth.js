// Test Auth Page - Handles authentication testing functionality
// This file contains all the logic that was previously inline in test-auth.html

document.addEventListener("DOMContentLoaded", function () {
  console.log("Auth test page loaded");
  checkAuthStatus();
  checkLocalStorage();
  testServerConnection();
});

function checkAuthStatus() {
  const authStatus = document.getElementById("authStatus");
  const authInfo = document.getElementById("authInfo");

  if (window.authManager) {
    if (window.authManager.isAuthenticated) {
      authStatus.className = "status success";
      authStatus.textContent = "✅ User is authenticated";

      authInfo.style.display = "block";
      authInfo.innerHTML = `
        <strong>User Information:</strong><br>
        Username: ${window.authManager.currentUser?.username}<br>
        Full Name: ${window.authManager.currentUser?.fullName}<br>
        Email: ${window.authManager.currentUser?.email}<br>
        Token: ${window.authManager.authToken ? "Present" : "Missing"}
      `;
    } else {
      authStatus.className = "status error";
      authStatus.textContent = "❌ User is not authenticated";
      authInfo.style.display = "none";
    }
  } else {
    authStatus.className = "status error";
    authStatus.textContent = "❌ AuthManager not found";
    authInfo.style.display = "none";
  }
}

function checkLocalStorage() {
  const localStorageInfo = document.getElementById("localStorageInfo");
  const token = localStorage.getItem("authToken");
  const userLoggedIn = localStorage.getItem("userLoggedIn");
  const username = localStorage.getItem("username");

  localStorageInfo.innerHTML = `
    <strong>Local Storage Status:</strong><br>
    authToken: ${token ? "Present" : "Missing"}<br>
    userLoggedIn: ${userLoggedIn || "Not set"}<br>
    username: ${username || "Not set"}<br>
    userEmail: ${localStorage.getItem("userEmail") || "Not set"}<br>
    userFullName: ${localStorage.getItem("userFullName") || "Not set"}
  `;
}

function clearLocalStorage() {
  localStorage.clear();
  checkLocalStorage();
  checkAuthStatus();
  alert("Local storage cleared!");
}

async function testServerConnection() {
  const serverStatus = document.getElementById("serverStatus");
  serverStatus.className = "status info";
  serverStatus.textContent = "Testing server connection...";

  try {
    const response = await fetch("/api/pagodas");
    if (response.ok) {
      serverStatus.className = "status success";
      serverStatus.textContent = "✅ Server connection successful";
    } else {
      serverStatus.className = "status error";
      serverStatus.textContent =
        "❌ Server responded with error: " + response.status;
    }
  } catch (error) {
    serverStatus.className = "status error";
    serverStatus.textContent =
      "❌ Server connection failed: " + error.message;
  }
}

function testLogin() {
  if (window.authManager) {
    window.authManager.showLoginPopup();
  } else {
    alert("AuthManager not available");
  }
}

function testSignup() {
  if (window.authManager) {
    window.authManager.showLoginPopup();
    window.authManager.toggleForm("signup");
  } else {
    alert("AuthManager not available");
  }
}

function testLogout() {
  if (window.authManager && window.authManager.isAuthenticated) {
    window.authManager.handleLogout({ preventDefault: () => {} });
    setTimeout(() => {
      checkAuthStatus();
      checkLocalStorage();
    }, 100);
  } else {
    alert("User not logged in");
  }
}

// Add event listeners to buttons
document.addEventListener("DOMContentLoaded", function() {
  // Test buttons
  document.getElementById("testLoginBtn")?.addEventListener("click", testLogin);
  document.getElementById("testSignupBtn")?.addEventListener("click", testSignup);
  document.getElementById("testLogoutBtn")?.addEventListener("click", testLogout);
  
  // Local storage buttons
  document.getElementById("checkLocalStorageBtn")?.addEventListener("click", checkLocalStorage);
  document.getElementById("clearLocalStorageBtn")?.addEventListener("click", clearLocalStorage);
  
  // Server test button
  document.getElementById("testServerBtn")?.addEventListener("click", testServerConnection);
});

// Listen for authentication state changes
if (window.authManager) {
  // Override the handleSuccessfulLogin method to update our test display
  const originalHandleLogin = window.authManager.handleSuccessfulLogin;
  window.authManager.handleSuccessfulLogin = function (userData, token) {
    originalHandleLogin.call(this, userData, token);
    setTimeout(() => {
      checkAuthStatus();
      checkLocalStorage();
    }, 100);
  };
}
