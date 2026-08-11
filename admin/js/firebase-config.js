// Firebase configuration - matches baganetic-mobile project
const firebaseConfig = {
  apiKey: 'AIzaSyBCPoRPdPB6p74PmXqTJrjh4z_BdPDiVhs',
  authDomain: 'baganetic-mobile.firebaseapp.com',
  projectId: 'baganetic-mobile',
  storageBucket: 'baganetic-mobile.firebasestorage.app',
  messagingSenderId: '1076087639842',
  appId: '1:1076087639842:web:1b6a0aa3b4e9497428df7b',
};

const firestoreDatabaseId = 'baganetic-mobile';

window.adminCollections = {
  pagodas: 'pagodas',
  users: 'users',
  trips: 'trips',
  feedbacks: 'feedbacks',
  roadReports: 'roadReports',
  aiChatMessages: 'aiChatMessages',
  communityPosts: 'communityPosts',
  communityComments: 'comments',
  communityVotes: 'votes',
};

function buildCompatDb(firestoreApi, dbInstance) {
  const {
    collection,
    collectionGroup,
    doc,
    getDoc,
    getDocs,
    query,
    where,
    orderBy,
    limit,
    setDoc,
    updateDoc,
    deleteDoc,
  } = firestoreApi;

  function wrapRef(ref, constraints = []) {
    return {
      collection(path) {
        return wrapRef(collection(ref, path));
      },
      doc(id) {
        return wrapDoc(doc(ref, id));
      },
      where(field, op, value) {
        return wrapRef(ref, [...constraints, where(field, op, value)]);
      },
      orderBy(field, direction = 'asc') {
        return wrapRef(ref, [...constraints, orderBy(field, direction)]);
      },
      limit(count) {
        return wrapRef(ref, [...constraints, limit(count)]);
      },
      async get() {
        const target = constraints.length ? query(ref, ...constraints) : ref;
        return getDocs(target);
      },
    };
  }

  function wrapDoc(ref) {
    return {
      id: ref.id,
      collection(path) {
        return wrapRef(collection(ref, path));
      },
      async get() {
        return getDoc(ref);
      },
      async set(data) {
        return setDoc(ref, data);
      },
      async update(data) {
        return updateDoc(ref, data);
      },
      async delete() {
        return deleteDoc(ref);
      },
    };
  }

  return {
    collection(path) {
      return wrapRef(collection(dbInstance, path));
    },
    collectionGroup(path) {
      return wrapRef(collectionGroup(dbInstance, path));
    },
  };
}

const adminBootstrapPromise = (async () => {
  const [appApi, authApi, firestoreApi, storageApi] = await Promise.all([
    import('https://www.gstatic.com/firebasejs/9.23.0/firebase-app.js'),
    import('https://www.gstatic.com/firebasejs/9.23.0/firebase-auth.js'),
    import('https://www.gstatic.com/firebasejs/9.23.0/firebase-firestore.js'),
    import('https://www.gstatic.com/firebasejs/9.23.0/firebase-storage.js'),
  ]);

  const app = appApi.initializeApp(firebaseConfig);
  let firestore;
  try {
    firestore = firestoreApi.getFirestore(app, firestoreDatabaseId);
  } catch (error) {
    console.warn('Falling back to initializeFirestore for named database:', error);
    firestore = firestoreApi.initializeFirestore(
      app,
      {
        ignoreUndefinedProperties: true,
      },
      firestoreDatabaseId,
    );
  }
  const authInstance = authApi.getAuth(app);
  const storage = storageApi.getStorage(app);

  const compatAuth = {
    get currentUser() {
      return authInstance.currentUser;
    },
    onAuthStateChanged(callback) {
      return authApi.onAuthStateChanged(authInstance, callback);
    },
    signInWithEmailAndPassword(email, password) {
      return authApi.signInWithEmailAndPassword(authInstance, email, password);
    },
    sendPasswordResetEmail(email) {
      return authApi.sendPasswordResetEmail(authInstance, email);
    },
    getIdToken(forceRefresh = false) {
      if (!authInstance.currentUser) {
        throw new Error('No authenticated admin user is available.');
      }
      return authInstance.currentUser.getIdToken(forceRefresh);
    },
    getIdTokenResult(forceRefresh = false) {
      if (!authInstance.currentUser) {
        throw new Error('No authenticated admin user is available.');
      }
      return authInstance.currentUser.getIdTokenResult(forceRefresh);
    },
    signOut() {
      return authApi.signOut(authInstance);
    },
  };

  const compatDb = buildCompatDb(firestoreApi, firestore);
  const firestoreRestBase = `https://firestore.googleapis.com/v1/projects/${firebaseConfig.projectId}/databases/${firestoreDatabaseId}/documents`;

  function encodeFirestoreValue(value) {
    if (value === undefined) {
      return { nullValue: null };
    }
    if (value === null) {
      return { nullValue: null };
    }
    if (Array.isArray(value)) {
      return {
        arrayValue: {
          values: value.map((item) => encodeFirestoreValue(item)),
        },
      };
    }
    if (typeof value === 'boolean') {
      return { booleanValue: value };
    }
    if (typeof value === 'number') {
      if (Number.isInteger(value)) {
        return { integerValue: String(value) };
      }
      return { doubleValue: value };
    }
    if (typeof value === 'string') {
      return { stringValue: value };
    }
    if (value instanceof Date) {
      return { timestampValue: value.toISOString() };
    }
    if (typeof value === 'object') {
      const fields = Object.fromEntries(
        Object.entries(value)
          .filter(([, item]) => item !== undefined)
          .map(([key, item]) => [key, encodeFirestoreValue(item)]),
      );
      return {
        mapValue: {
          fields,
        },
      };
    }
    return { stringValue: String(value) };
  }

  function decodeFirestoreValue(value) {
    if (value === null || value === undefined) return null;
    if ('nullValue' in value) return null;
    if ('stringValue' in value) return value.stringValue;
    if ('booleanValue' in value) return value.booleanValue;
    if ('integerValue' in value) return Number(value.integerValue);
    if ('doubleValue' in value) return Number(value.doubleValue);
    if ('timestampValue' in value) return value.timestampValue;
    if ('arrayValue' in value) {
      return (value.arrayValue?.values || []).map((item) => decodeFirestoreValue(item));
    }
    if ('mapValue' in value) {
      return decodeFirestoreFields(value.mapValue?.fields || {});
    }
    return null;
  }

  function decodeFirestoreFields(fields) {
    return Object.fromEntries(
      Object.entries(fields || {}).map(([key, value]) => [key, decodeFirestoreValue(value)]),
    );
  }

  function decodeFirestoreDocument(document) {
    const path = (document.name || '').split('/documents/')[1] || '';
    return {
      id: path.split('/').pop() || '',
      firestoreId: path.split('/').pop() || '',
      __path: path,
      ...decodeFirestoreFields(document.fields || {}),
      createTime: document.createTime,
      updateTime: document.updateTime,
    };
  }

  async function getCurrentIdToken(forceRefresh = false) {
    const user = authInstance.currentUser;
    if (!user) {
      throw new Error('No authenticated admin user is available.');
    }
    return user.getIdToken(forceRefresh);
  }

  async function adminRestFetch(url, options = {}) {
    const token = await getCurrentIdToken(options.forceRefresh === true);
    const response = await fetch(url, {
      ...options,
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
        ...(options.headers || {}),
      },
    });

    if (!response.ok) {
      const body = await response.text();
      throw new Error(`${response.status} ${response.statusText}: ${body}`);
    }

    if (response.status === 204) {
      return null;
    }

    return response.json();
  }

  function buildUpdateMask(keys) {
    const params = new URLSearchParams();
    keys.forEach((key) => {
      params.append('updateMask.fieldPaths', key);
    });
    const serialized = params.toString();
    return serialized ? `?${serialized}` : '';
  }

  const adminFirestoreRest = {
    async listDocuments(collectionPath, pageSize = 100) {
      const documents = [];
      let pageToken = '';

      do {
        const params = new URLSearchParams();
        params.set('pageSize', String(pageSize));
        if (pageToken) {
          params.set('pageToken', pageToken);
        }

        const payload = await adminRestFetch(
          `${firestoreRestBase}/${collectionPath}?${params.toString()}`,
        );
        documents.push(...(payload.documents || []));
        pageToken = payload.nextPageToken || '';
      } while (pageToken);

      return documents.map((doc) => decodeFirestoreDocument(doc));
    },
    async listCollection(collectionId, pageSize = 100) {
      return this.listDocuments(collectionId, pageSize);
    },
    async listCollectionGroup(collectionId) {
      const payload = await adminRestFetch(
        `https://firestore.googleapis.com/v1/projects/${firebaseConfig.projectId}/databases/${firestoreDatabaseId}/documents:runQuery`,
        {
          method: 'POST',
          body: JSON.stringify({
            structuredQuery: {
              from: [{ collectionId, allDescendants: true }],
            },
          }),
        },
      );
      return (payload || [])
        .map((row) => row.document)
        .filter(Boolean)
        .map((doc) => decodeFirestoreDocument(doc));
    },
    async setDocument(documentPath, data) {
      const fields = Object.fromEntries(
        Object.entries(data)
          .filter(([, value]) => value !== undefined)
          .map(([key, value]) => [key, encodeFirestoreValue(value)]),
      );
      const queryString = buildUpdateMask(Object.keys(fields));
      return adminRestFetch(`${firestoreRestBase}/${documentPath}${queryString}`, {
        method: 'PATCH',
        body: JSON.stringify({ fields }),
      });
    },
    async patchDocument(documentPath, partial) {
      const fields = Object.fromEntries(
        Object.entries(partial)
          .filter(([, value]) => value !== undefined)
          .map(([key, value]) => [key, encodeFirestoreValue(value)]),
      );
      const queryString = buildUpdateMask(Object.keys(fields));
      return adminRestFetch(`${firestoreRestBase}/${documentPath}${queryString}`, {
        method: 'PATCH',
        body: JSON.stringify({ fields }),
      });
    },
    async deleteDocument(documentPath) {
      return adminRestFetch(`${firestoreRestBase}/${documentPath}`, {
        method: 'DELETE',
      });
    },
  };
  const compatFirebase = {
    firestore: {
      FieldValue: {
        serverTimestamp: firestoreApi.serverTimestamp,
        increment: firestoreApi.increment,
      },
    },
  };

  window.adminFirebaseApp = app;
  window.adminAuth = compatAuth;
  window.adminDb = compatDb;
  window.adminStorage = storage;
  window.adminStorageApi = storageApi;
  window.adminFirestoreRest = adminFirestoreRest;
  window.getAdminIdToken = getCurrentIdToken;
  window.auth = compatAuth;
  window.db = compatDb;
  window.storage = storage;
  window.firebase = compatFirebase;

  return {
    app,
    auth: compatAuth,
    db: compatDb,
    storage,
    storageApi,
    firestoreApi,
    authApi,
  };
})();

window.waitForAdminApp = () => adminBootstrapPromise;

// ============================================================
// TOAST UTILITY
// ============================================================
function showToast(message, type = 'info') {
  const icons = { success: '✓', error: '✕', info: 'i' };
  const container = document.getElementById('toast-container');
  if (!container) return;
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  const icon = document.createElement('span');
  icon.className = 'toast-icon';
  icon.textContent = icons[type] || icons.info;

  const text = document.createElement('span');
  text.className = 'toast-message';
  text.textContent = String(message || '');

  toast.append(icon, text);
  container.appendChild(toast);
  setTimeout(() => toast.remove(), 3500);
}

// ============================================================
// FORMAT HELPERS
// ============================================================
function formatDate(val) {
  if (!val) return '—';
  let d;
  if (val && val.toDate) d = val.toDate();
  else if (val instanceof Date) d = val;
  else d = new Date(val);
  if (isNaN(d)) return '—';
  return d.toLocaleDateString('en-GB', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  });
}

function formatDateTime(val) {
  if (!val) return '—';
  let d;
  if (val && val.toDate) d = val.toDate();
  else if (val instanceof Date) d = val;
  else d = new Date(val);
  if (isNaN(d)) return '—';
  return d.toLocaleString('en-GB', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function truncate(str, len = 60) {
  if (!str) return '—';
  return str.length > len ? str.slice(0, len) + '…' : str;
}

function renderStars(rating) {
  const full = Math.round(rating || 0);
  return '★'.repeat(full) + '☆'.repeat(Math.max(0, 5 - full));
}

function escapeHtml(str) {
  if (!str) return '';
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function serializeForInlineHandler(value) {
  return escapeHtml(JSON.stringify(value ?? ''));
}

// ============================================================
// MODAL HELPERS
// ============================================================
function openModal(id) {
  document.getElementById(id)?.classList.add('open');
}

function closeModal(id) {
  document.getElementById(id)?.classList.remove('open');
}

document.addEventListener('click', (event) => {
  if (event.target.classList.contains('modal-overlay')) {
    event.target.classList.remove('open');
  }
});
