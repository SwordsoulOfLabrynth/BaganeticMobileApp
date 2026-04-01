// ============================================================
// AUTH MODULE
// ============================================================
const ADMIN_EMAILS = [
  'admin@baganetic.com',
  'kyawzayyahein.mdy@gmail.com',
  'phyuhninaung2005@gmail.com',
];
const ADMIN_LOCAL_URL = 'http://127.0.0.1:4173/admin/index.html';

let refreshBound = false;

async function prepareAdminSession(user, forceRefresh = true) {
  if (!user || typeof auth?.getIdTokenResult !== 'function') {
    return null;
  }

  try {
    const tokenResult = await auth.getIdTokenResult(forceRefresh);
    window.adminSessionInfo = {
      uid: user.uid || '',
      email: user.email || '',
      tokenIssuedAt: tokenResult?.issuedAtTime || null,
      authTime: tokenResult?.authTime || null,
      claims: tokenResult?.claims || {},
    };

    // Give Firestore auth state a moment to observe the refreshed token.
    await new Promise((resolve) => setTimeout(resolve, 200));
    return window.adminSessionInfo;
  } catch (error) {
    console.warn('Failed to prepare admin session:', error);
    window.adminSessionInfo = {
      uid: user.uid || '',
      email: user.email || '',
      tokenIssuedAt: null,
      authTime: null,
      claims: {},
    };
    return window.adminSessionInfo;
  }
}

function initAuth() {
  auth.onAuthStateChanged((user) => {
    if (user) {
      if (!ADMIN_EMAILS.includes(user.email)) {
        auth.signOut();
        showLoginError('Access denied. This account is not an admin.');
        return;
      }
      onAdminAuthenticated(user);
      return;
    }

    showLoginPage();
  });
}

function showLoginPage() {
  document.getElementById('login-section').style.display = 'flex';
  document.getElementById('admin-section').style.display = 'none';
}

function showAdminPage() {
  document.getElementById('login-section').style.display = 'none';
  document.getElementById('admin-section').style.display = 'flex';
}

async function onAdminAuthenticated(user) {
  showAdminPage();

  const initial = (user.displayName || user.email || 'A')[0].toUpperCase();
  document.getElementById('user-avatar-text').textContent = initial;
  document.getElementById('header-user-name').textContent =
    user.displayName || user.email.split('@')[0];
  document.getElementById('header-user-email').textContent = user.email;

  await prepareAdminSession(user, true);
  navigateTo('dashboard');
  await handleAdminRefresh(false);
}

function showLoginError(message) {
  const element = document.getElementById('login-error');
  if (element) {
    element.textContent = message;
    element.classList.add('show');
  }
}

function hideLoginError() {
  const element = document.getElementById('login-error');
  if (element) {
    element.classList.remove('show');
  }
}

document.addEventListener('DOMContentLoaded', () => {
  bootAdminAuth();
});

function showFileModeInstructions() {
  const loginButton = document.getElementById('login-btn');
  const subtitle = document.querySelector('.login-subtitle');
  if (subtitle) {
    subtitle.textContent =
      'Open the admin over HTTP for live Firebase sync. Run admin/start_admin.bat, then use http://127.0.0.1:4173/admin/index.html.';
  }
  showLoginError(
    'Live sync is disabled on file:// pages. Start admin/start_admin.bat and open ' +
      ADMIN_LOCAL_URL +
      ' instead.',
  );
  if (loginButton) {
    loginButton.disabled = true;
    loginButton.textContent = 'Use Local Server';
  }
}

async function bootAdminAuth() {
  const loginButton = document.getElementById('login-btn');
  if (loginButton) {
    loginButton.disabled = true;
    loginButton.textContent = 'Connecting…';
  }

  if (window.location.protocol === 'file:') {
    showFileModeInstructions();
    return;
  }

  try {
    await window.waitForAdminApp();
  } catch (error) {
    console.error('Admin bootstrap failed:', error);
    showLoginError('Failed to connect to Firebase. Check your network and config.');
    if (loginButton) {
      loginButton.disabled = false;
      loginButton.textContent = 'Sign In';
    }
    return;
  }

  const form = document.getElementById('login-form');
  if (form) {
    form.addEventListener('submit', async (event) => {
      event.preventDefault();
      hideLoginError();

      const email = document.getElementById('login-email').value.trim();
      const password = document.getElementById('login-password').value;
      const submitButton = document.getElementById('login-btn');
      submitButton.disabled = true;
      submitButton.innerHTML = '<span class="loading-spinner"></span>';

      try {
        await auth.signInWithEmailAndPassword(email, password);
      } catch (error) {
        let message = 'Login failed. Please check your credentials.';
        if (
          error.code === 'auth/user-not-found' ||
          error.code === 'auth/wrong-password' ||
          error.code === 'auth/invalid-credential'
        ) {
          message = 'Invalid email or password.';
        } else if (error.code === 'auth/too-many-requests') {
          message = 'Too many attempts. Please wait and try again.';
        }
        showLoginError(message);
        submitButton.disabled = false;
        submitButton.textContent = 'Sign In';
      }
    });
  }

  document.getElementById('btn-logout')?.addEventListener('click', () => {
    auth.signOut();
    showToast('Signed out successfully.', 'info');
  });

  if (!refreshBound) {
    document.getElementById('btn-refresh-data')?.addEventListener('click', () => {
      handleAdminRefresh(true);
    });
    refreshBound = true;
  }

  if (loginButton) {
    loginButton.disabled = false;
    loginButton.textContent = 'Sign In';
  }

  initAuth();
}

async function handleAdminRefresh(showSuccessToast = true) {
  const refreshButton = document.getElementById('btn-refresh-data');
  const syncStatus = document.getElementById('sync-status');

  if (refreshButton) {
    refreshButton.disabled = true;
    refreshButton.textContent = '…';
  }
  if (syncStatus) {
    syncStatus.textContent = 'Refreshing app data…';
  }

  try {
    if (auth.currentUser) {
      await prepareAdminSession(auth.currentUser, true);
    }
    await refreshAdminData();
    if (showSuccessToast) {
      showToast('Admin data refreshed.', 'success');
    }
  } catch (error) {
    console.error('Failed to refresh admin data:', error);
    showToast('Failed to refresh admin data.', 'error');
  } finally {
    if (refreshButton) {
      refreshButton.disabled = false;
      refreshButton.textContent = '↺';
    }
  }
}

window.handleAdminRefresh = handleAdminRefresh;
