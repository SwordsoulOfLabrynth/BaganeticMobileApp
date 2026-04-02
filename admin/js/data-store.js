// ============================================================
// SHARED ADMIN DATA STORE
// ============================================================
window.adminState = {
  pagodas: [],
  pagodaMap: {},
  users: [],
  userMap: {},
  posts: [],
  trips: [],
  datasetErrors: [],
  lastLoadedAt: null,
  catalogSeeded: false,
};

let adminStatePromise = null;

function getErrorMessage(error) {
  return error?.message || String(error);
}

function isPermissionDeniedError(error) {
  const code = String(error?.code || '').toLowerCase();
  const message = getErrorMessage(error).toLowerCase();
  return (
    code.includes('permission-denied') ||
    message.includes('missing or insufficient permissions') ||
    message.includes('permission_denied') ||
    message.includes('permission denied') ||
    message.includes('insufficient permissions')
  );
}

async function refreshAdminTokenForFallback() {
  if (typeof auth?.getIdTokenResult !== 'function' || !auth.currentUser) {
    return;
  }

  try {
    await auth.getIdTokenResult(true);
  } catch (tokenError) {
    console.warn('Failed to refresh admin token before REST fallback:', tokenError);
  }
}

async function runAdminWriteOperation({ action, sdkWrite, restWrite }) {
  try {
    return await sdkWrite();
  } catch (error) {
    if (!isPermissionDeniedError(error) || !window.adminFirestoreRest || !restWrite) {
      throw error;
    }

    console.warn(
      `Firestore SDK ${action} failed; retrying with REST fallback.`,
      error,
    );
    await refreshAdminTokenForFallback();
    return restWrite();
  }
}

function buildAdminDocumentPath(collectionId, documentId) {
  return `${collectionId}/${documentId}`;
}

function createAdminRestTimestamp() {
  return new Date().toISOString();
}

function splitAdminFirestorePath(path) {
  return String(path || '')
    .split('/')
    .map((segment) => segment.trim())
    .filter(Boolean);
}

function resolveAdminDocRef(documentPath) {
  const segments = splitAdminFirestorePath(documentPath);
  if (!segments.length || segments.length % 2 !== 0) {
    throw new Error(`Invalid Firestore document path: ${documentPath}`);
  }

  let ref = db.collection(segments[0]).doc(segments[1]);
  for (let index = 2; index < segments.length; index += 2) {
    ref = ref.collection(segments[index]).doc(segments[index + 1]);
  }
  return ref;
}

function resolveAdminCollectionRef(collectionPath) {
  const segments = splitAdminFirestorePath(collectionPath);
  if (!segments.length || segments.length % 2 === 0) {
    throw new Error(`Invalid Firestore collection path: ${collectionPath}`);
  }

  let ref = db.collection(segments[0]);
  for (let index = 1; index < segments.length; index += 2) {
    ref = ref.doc(segments[index]).collection(segments[index + 1]);
  }
  return ref;
}

function getAdminRecordPath(record, fallbackCollectionId = '') {
  const existingPath = String(record?.__path || '').trim();
  if (existingPath) {
    return existingPath;
  }

  const id = String(record?.id || record?.firestoreId || '').trim();
  if (!id || !fallbackCollectionId) {
    return '';
  }

  return buildAdminDocumentPath(fallbackCollectionId, id);
}

async function listAdminDocuments(collectionPath, pageSize = 500) {
  try {
    const snapshot = await resolveAdminCollectionRef(collectionPath).get();
    const key = splitAdminFirestorePath(collectionPath).at(-1) || collectionPath;
    return mapDocs(snapshot, key);
  } catch (error) {
    if (!isPermissionDeniedError(error) || !window.adminFirestoreRest) {
      throw error;
    }

    console.warn(
      `Firestore SDK list failed for ${collectionPath}; retrying with REST fallback.`,
      error,
    );
    await refreshAdminTokenForFallback();
    return window.adminFirestoreRest.listDocuments(collectionPath, pageSize);
  }
}

async function deleteAdminDocumentPath(documentPath, action = 'document delete') {
  return runAdminWriteOperation({
    action,
    sdkWrite: () => resolveAdminDocRef(documentPath).delete(),
    restWrite: () => window.adminFirestoreRest.deleteDocument(documentPath),
  });
}

async function patchAdminDocumentPath(documentPath, partial, action = 'document update') {
  return runAdminWriteOperation({
    action,
    sdkWrite: () => resolveAdminDocRef(documentPath).update(partial),
    restWrite: () => window.adminFirestoreRest.patchDocument(documentPath, partial),
  });
}

function buildRestSeedPagodaPayload(pagoda) {
  const normalized = normalizePagodaRecord(pagoda);
  const now = new Date().toISOString();
  return {
    ...normalized,
    status: 'active',
    createdAt: now,
    updatedAt: now,
  };
}

async function loadCollectionRecords({
  key,
  collectionId,
  isCollectionGroup = false,
}) {
  try {
    const snapshot = isCollectionGroup
      ? await db.collectionGroup(collectionId).get()
      : await db.collection(collectionId).get();
    return mapDocs(snapshot, key);
  } catch (error) {
    if (!isPermissionDeniedError(error) || !window.adminFirestoreRest) {
      throw error;
    }

    console.warn(
      `Firestore SDK read failed for ${collectionId}; retrying with REST fallback.`,
      error,
    );

    await refreshAdminTokenForFallback();

    const records = isCollectionGroup
      ? await window.adminFirestoreRest.listCollectionGroup(collectionId)
      : await window.adminFirestoreRest.listCollection(collectionId, 500);
    return mapDocs(records, key);
  }
}

function normalizePagodaCategory(category) {
  return category === 'Temple' ? 'Temple' : 'Pagoda';
}

function normalizeStringList(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => String(item || '').trim())
    .filter(Boolean);
}

function normalizeUniqueFeatures(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((feature) => ({
      title: String(feature?.title || '').trim(),
      description: String(feature?.description || '').trim(),
      icon: String(feature?.icon || '').trim(),
      imageUrl: String(feature?.imageUrl || '').trim(),
    }))
    .filter((feature) => feature.title || feature.description);
}

function normalizePagodaRecord(pagoda) {
  const latitude = Number(pagoda?.latitude);
  const longitude = Number(pagoda?.longitude);
  const parsedYearBuilt = pagoda?.yearBuilt === null || pagoda?.yearBuilt === undefined || pagoda?.yearBuilt === ''
    ? Number.NaN
    : Number(pagoda.yearBuilt);

  return {
    id: String(pagoda?.id || '').trim(),
    name: String(pagoda?.name || '').trim(),
    description: String(pagoda?.description || '').trim(),
    category: normalizePagodaCategory(pagoda?.category),
    latitude: Number.isFinite(latitude) ? latitude : 0,
    longitude: Number.isFinite(longitude) ? longitude : 0,
    imageUrl: String(pagoda?.imageUrl || '').trim(),
    images: normalizeStringList(pagoda?.images),
    historicalInfo: String(pagoda?.historicalInfo || '').trim(),
    architecturalStyle: String(pagoda?.architecturalStyle || '').trim(),
    yearBuilt: Number.isFinite(parsedYearBuilt) ? parsedYearBuilt : null,
    legends: String(pagoda?.legends || '').trim(),
    religiousImportance: String(pagoda?.religiousImportance || '').trim(),
    preservationInfo: String(pagoda?.preservationInfo || '').trim(),
    bestTimeToVisit: String(pagoda?.bestTimeToVisit || '').trim(),
    visitorLocation: String(pagoda?.visitorLocation || '').trim(),
    openingHours: String(pagoda?.openingHours || '').trim(),
    dressCode: String(pagoda?.dressCode || '').trim(),
    entranceFee: String(pagoda?.entranceFee || '').trim(),
    photographyRules: String(pagoda?.photographyRules || '').trim(),
    height: String(pagoda?.height || '').trim(),
    finalWords: String(pagoda?.finalWords || '').trim(),
    uniqueFeatures: normalizeUniqueFeatures(pagoda?.uniqueFeatures),
    status: pagoda?.status === 'archived' ? 'archived' : 'active',
    createdAt: pagoda?.createdAt || null,
    updatedAt: pagoda?.updatedAt || null,
  };
}

function buildSeedPagodaPayload(pagoda) {
  const normalized = normalizePagodaRecord(pagoda);
  return {
    ...normalized,
    status: 'active',
    createdAt: firebase.firestore.FieldValue.serverTimestamp(),
    updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
  };
}

async function ensurePagodaCatalogSeeded() {
  const seedPagodas = Array.isArray(window.BAGANETIC_PAGODAS)
    ? window.BAGANETIC_PAGODAS
    : [];

  if (!seedPagodas.length) {
    return false;
  }

  try {
    const existingSnapshot = await db
      .collection(window.adminCollections.pagodas)
      .limit(1)
      .get();

    if (!existingSnapshot.empty) {
      return false;
    }

    await Promise.all(
      seedPagodas.map((pagoda) =>
        db
          .collection(window.adminCollections.pagodas)
          .doc(pagoda.id)
          .set(buildSeedPagodaPayload(pagoda))),
    );

    return true;
  } catch (error) {
    if (!isPermissionDeniedError(error) || !window.adminFirestoreRest) {
      throw error;
    }

    console.warn(
      'Firestore SDK seed check failed; retrying pagoda seed with REST fallback.',
      error,
    );

    const existingPagodas = await window.adminFirestoreRest.listCollection(
      window.adminCollections.pagodas,
      1,
    );
    if (existingPagodas.length) {
      return false;
    }

    await Promise.all(
      seedPagodas.map((pagoda) =>
        window.adminFirestoreRest.setDocument(
          `${window.adminCollections.pagodas}/${pagoda.id}`,
          buildRestSeedPagodaPayload(pagoda),
        )),
    );

    return true;
  }
}

function mapDocs(snapshot, key) {
  const records = Array.isArray(snapshot)
    ? snapshot
    : snapshot.docs.map((doc) => ({
        id: doc.id,
        firestoreId: doc.id,
        __path: doc.ref?.path || '',
        ...doc.data(),
      }));

  return records.map((item) => {
    if (key === 'pagodas') {
      return normalizePagodaRecord(item);
    }

    if (key === 'trips' && !item.ownerUserId && item.__path) {
      const segments = item.__path.split('/');
      if (segments.length >= 4 && segments[0] === window.adminCollections.users) {
        item.ownerUserId = segments[1];
      }
    }

    return item;
  });
}

function parseDateSafe(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate();
  if (value instanceof Date) return value;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function sortByRecent(items, field = 'createdAt') {
  return [...items].sort((a, b) => {
    const aDate = parseDateSafe(a[field] || a.updatedAt) || new Date(0);
    const bDate = parseDateSafe(b[field] || b.updatedAt) || new Date(0);
    return bDate - aDate;
  });
}

function getUserId(user) {
  return String(user?.id || user?.uid || user?.firestoreId || '').trim();
}

async function loadAdminState(force = false) {
  if (!force && adminStatePromise) {
    return adminStatePromise;
  }

  adminStatePromise = (async () => {
    const errors = [];
    let catalogSeeded = false;

    try {
      catalogSeeded = await ensurePagodaCatalogSeeded();
    } catch (error) {
      console.error('Failed to seed pagoda catalog:', error);
      errors.push({
        key: 'pagodaSeed',
        label: 'pagoda catalog seed',
        message: error?.message || String(error),
      });
    }

    const datasets = [
      {
        key: 'pagodas',
        label: 'pagoda catalog',
        loader: () =>
          loadCollectionRecords({
            key: 'pagodas',
            collectionId: window.adminCollections.pagodas,
          }),
      },
      {
        key: 'users',
        label: 'users',
        loader: () =>
          loadCollectionRecords({
            key: 'users',
            collectionId: window.adminCollections.users,
          }),
      },
      {
        key: 'posts',
        label: 'community posts',
        loader: () =>
          loadCollectionRecords({
            key: 'posts',
            collectionId: window.adminCollections.communityPosts,
          }),
      },
      {
        key: 'trips',
        label: 'trips',
        loader: () =>
          loadCollectionRecords({
            key: 'trips',
            collectionId: 'trips',
            isCollectionGroup: true,
          }),
      },
    ];

    const results = await Promise.allSettled(
      datasets.map((dataset) => dataset.loader()),
    );

    results.forEach((result, index) => {
      const dataset = datasets[index];
      if (result.status === 'fulfilled') {
        window.adminState[dataset.key] = result.value;
        return;
      }

      console.error(`Failed to load ${dataset.label}:`, result.reason);
      window.adminState[dataset.key] = [];
      errors.push({
        key: dataset.key,
        label: dataset.label,
        message: result.reason?.message || String(result.reason),
      });
    });

    window.adminState.pagodas = [...window.adminState.pagodas].sort((a, b) => {
      if (a.status !== b.status) {
        return a.status === 'active' ? -1 : 1;
      }
      return a.name.localeCompare(b.name);
    });
    window.adminState.pagodaMap = Object.fromEntries(
      window.adminState.pagodas.map((pagoda) => [pagoda.id, pagoda]),
    );

    window.adminState.users = sortByRecent(window.adminState.users, 'createdAt');
    window.adminState.userMap = Object.fromEntries(
      window.adminState.users.map((user) => [getUserId(user), user]),
    );

    window.adminState.posts = sortByRecent(window.adminState.posts, 'createdAt');
    window.adminState.trips = sortByRecent(
      window.adminState.trips.map((trip) => enrichTrip(trip)),
      'updatedAt',
    );
    window.adminState.datasetErrors = errors;
    window.adminState.catalogSeeded = catalogSeeded;
    window.adminState.lastLoadedAt = new Date();
    return window.adminState;
  })();

  return adminStatePromise;
}

function getPagodaName(pagodaId) {
  return window.adminState.pagodaMap[pagodaId]?.name || pagodaId || '—';
}

function getDashboardMetrics() {
  const activePagodas = window.adminState.pagodas.filter(
    (pagoda) => pagoda.status !== 'archived',
  );
  const temples = activePagodas.filter((pagoda) => pagoda.category === 'Temple').length;
  const pagodas = activePagodas.filter((pagoda) => pagoda.category === 'Pagoda').length;
  const activePosts = window.adminState.posts.filter(
    (post) => (post.status || 'active') === 'active',
  ).length;

  return {
    totalPagodas: activePagodas.length,
    totalArchivedPagodas: window.adminState.pagodas.length - activePagodas.length,
    totalTemples: temples,
    totalPagodaType: pagodas,
    totalUsers: window.adminState.users.length,
    totalTrips: window.adminState.trips.length,
    totalPosts: window.adminState.posts.length,
    activePosts,
  };
}

function getPagodaCategorySummary() {
  const activePagodas = window.adminState.pagodas.filter(
    (pagoda) => pagoda.status !== 'archived',
  );
  return [
    {
      label: 'Live Catalog',
      count: activePagodas.length,
      description: 'Pagodas currently visible in the mobile app',
    },
    {
      label: 'Temple',
      count: activePagodas.filter((pagoda) => pagoda.category === 'Temple').length,
      description: 'Active temple entries',
    },
    {
      label: 'Pagoda',
      count: activePagodas.filter((pagoda) => pagoda.category === 'Pagoda').length,
      description: 'Active pagoda entries',
    },
    {
      label: 'Archived',
      count: window.adminState.pagodas.filter((pagoda) => pagoda.status === 'archived').length,
      description: 'Hidden from the mobile app',
    },
  ];
}

function getCommunitySummary() {
  const activePosts = window.adminState.posts.filter(
    (post) => (post.status || 'active') === 'active',
  ).length;
  const tipPosts = window.adminState.posts.filter((post) => post.type === 'tip').length;
  const questionPosts = window.adminState.posts.filter(
    (post) => post.type === 'question',
  ).length;
  return {
    activePosts,
    hiddenPosts: window.adminState.posts.length - activePosts,
    tipPosts,
    questionPosts,
  };
}

function getRecentTrips(limit = 6) {
  return sortByRecent(window.adminState.trips, 'updatedAt').slice(0, limit);
}

function getRecentPosts(limit = 5) {
  return sortByRecent(window.adminState.posts, 'createdAt').slice(0, limit);
}

function getRecentUsers(limit = 5) {
  return sortByRecent(window.adminState.users, 'createdAt').slice(0, limit);
}

function getUserMetrics(userId) {
  const user = window.adminState.userMap[userId] || {};
  const favoriteIds = Array.isArray(user.favoriteIds)
    ? user.favoriteIds
    : Array.isArray(user.favorites)
      ? user.favorites
      : Array.isArray(user.favoritePagodas)
        ? user.favoritePagodas
        : [];
  const tripCount = window.adminState.trips.filter((trip) => trip.ownerUserId === userId).length;
  const postCount = window.adminState.posts.filter((post) => post.authorUserId === userId).length;

  return {
    favoriteCount: favoriteIds.length,
    tripCount,
    postCount,
  };
}

function getUserTrips(userId, limit = 5) {
  return sortByRecent(
    window.adminState.trips.filter((trip) => trip.ownerUserId === userId),
    'updatedAt',
  ).slice(0, limit);
}

function getUserPosts(userId, limit = 5) {
  return sortByRecent(
    window.adminState.posts.filter((post) => post.authorUserId === userId),
    'createdAt',
  ).slice(0, limit);
}

function enrichTrip(trip) {
  return {
    ...trip,
    stopCount: Array.isArray(trip.stops) ? trip.stops.length : 0,
  };
}

function refreshAdminData() {
  return loadAdminState(true).then(() => {
    if (typeof initDashboard === 'function') initDashboard();
    if (typeof initPagodas === 'function') initPagodas();
    if (typeof initUsers === 'function') initUsers();
    if (typeof initTrips === 'function') initTrips();
    if (typeof initCommunity === 'function') initCommunity();
  });
}

window.loadAdminState = loadAdminState;
window.refreshAdminData = refreshAdminData;
window.getDashboardMetrics = getDashboardMetrics;
window.getPagodaCategorySummary = getPagodaCategorySummary;
window.getCommunitySummary = getCommunitySummary;
window.getRecentTrips = getRecentTrips;
window.getRecentPosts = getRecentPosts;
window.getRecentUsers = getRecentUsers;
window.getPagodaName = getPagodaName;
window.getUserId = getUserId;
window.getUserMetrics = getUserMetrics;
window.getUserTrips = getUserTrips;
window.getUserPosts = getUserPosts;
window.enrichTrip = enrichTrip;
window.parseDateSafe = parseDateSafe;
window.normalizePagodaCategory = normalizePagodaCategory;
window.normalizePagodaRecord = normalizePagodaRecord;
window.runAdminWriteOperation = runAdminWriteOperation;
window.buildAdminDocumentPath = buildAdminDocumentPath;
window.createAdminRestTimestamp = createAdminRestTimestamp;
window.splitAdminFirestorePath = splitAdminFirestorePath;
window.resolveAdminDocRef = resolveAdminDocRef;
window.resolveAdminCollectionRef = resolveAdminCollectionRef;
window.getAdminRecordPath = getAdminRecordPath;
window.listAdminDocuments = listAdminDocuments;
window.deleteAdminDocumentPath = deleteAdminDocumentPath;
window.patchAdminDocumentPath = patchAdminDocumentPath;
