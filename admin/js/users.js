// ============================================================
// USERS MODULE
// ============================================================
let allUsers = [];
let filteredUsers = [];
let usersPage = 1;
const USERS_PAGE_SIZE = 10;
let usersBound = false;

function initUsers() {
  if (!usersBound) {
    document.getElementById('users-search')?.addEventListener('input', filterUsers);
    usersBound = true;
  }

  loadUsers();
}

async function loadUsers() {
  await loadAdminState();
  allUsers = [...window.adminState.users];

  const countLabel = document.getElementById('users-count');
  if (countLabel) {
    countLabel.textContent = `${allUsers.length} registered app users`;
  }

  filterUsers();
}

function filterUsers() {
  const query = (document.getElementById('users-search')?.value || '').toLowerCase();
  filteredUsers = allUsers.filter((user) => (
    !query ||
    user.email?.toLowerCase().includes(query) ||
    user.displayName?.toLowerCase().includes(query) ||
    user.name?.toLowerCase().includes(query) ||
    getUserId(user).toLowerCase().includes(query)
  ));

  usersPage = 1;
  renderUsersTable();
}

function renderUsersTable() {
  const tbody = document.getElementById('users-table-body');
  if (!tbody) return;

  const start = (usersPage - 1) * USERS_PAGE_SIZE;
  const slice = filteredUsers.slice(start, start + USERS_PAGE_SIZE);
  const totalPages = Math.ceil(filteredUsers.length / USERS_PAGE_SIZE) || 1;

  const info = document.getElementById('users-pagination-info');
  if (info) {
    info.textContent = filteredUsers.length
      ? `${start + 1}–${Math.min(start + USERS_PAGE_SIZE, filteredUsers.length)} of ${filteredUsers.length}`
      : '0 results';
  }
  renderUsersPagination(totalPages);

  if (!slice.length) {
    tbody.innerHTML = `
      <tr>
        <td colspan="6">
          <div class="empty-state">
            <div class="empty-icon">👥</div>
            <p>No users match the current search.</p>
          </div>
        </td>
      </tr>
    `;
    return;
  }

  tbody.innerHTML = slice.map((user) => {
    const userId = getUserId(user);
    const initial = (user.displayName || user.name || user.email || '?')[0].toUpperCase();
    const metrics = getUserMetrics(userId);
    const isCurrentAdmin = auth.currentUser?.uid === userId;
    const actionButtons = isCurrentAdmin
      ? '<button class="btn-secondary" type="button" disabled>Current</button>'
      : `
          <button class="btn-danger" type="button" onclick='deleteUser(${serializeForInlineHandler(userId)})'>Delete</button>
        `;

    return `
      <tr>
        <td>
          <div class="user-cell">
            <div class="user-avatar">${initial}</div>
            <div>
              <div class="table-primary">${escapeHtml(user.displayName || user.name || '—')}</div>
              <div class="cell-muted">${escapeHtml(user.email || userId || '—')}</div>
            </div>
          </div>
        </td>
        <td><span class="badge ${metrics.favoriteCount ? 'badge-blue' : 'badge-gray'}">${metrics.favoriteCount}</span></td>
        <td><span class="badge ${metrics.tripCount ? 'badge-gold' : 'badge-gray'}">${metrics.tripCount}</span></td>
        <td><span class="badge ${metrics.postCount ? 'badge-green' : 'badge-gray'}">${metrics.postCount}</span></td>
        <td class="cell-nowrap cell-muted">${formatDate(user.createdAt)}</td>
        <td>
          <div class="action-row">
            <button class="btn-warning" type="button" onclick='viewUser(${serializeForInlineHandler(userId)})'>Profile</button>
            ${actionButtons}
          </div>
        </td>
      </tr>
    `;
  }).join('');
}

function renderUsersPagination(totalPages) {
  const container = document.getElementById('users-pagination-controls');
  if (!container) return;

  let html = `<button class="page-btn" onclick="changeUsersPage(${usersPage - 1})" ${usersPage === 1 ? 'disabled' : ''}>‹</button>`;
  for (let index = 1; index <= totalPages; index += 1) {
    if (index === 1 || index === totalPages || Math.abs(index - usersPage) <= 1) {
      html += `<button class="page-btn ${index === usersPage ? 'active' : ''}" onclick="changeUsersPage(${index})">${index}</button>`;
    } else if (Math.abs(index - usersPage) === 2) {
      html += '<span class="pagination-gap">…</span>';
    }
  }
  html += `<button class="page-btn" onclick="changeUsersPage(${usersPage + 1})" ${usersPage === totalPages ? 'disabled' : ''}>›</button>`;
  container.innerHTML = html;
}

function changeUsersPage(page) {
  usersPage = page;
  renderUsersTable();
}

function viewUser(userId) {
  const user = allUsers.find((item) => getUserId(item) === userId);
  if (!user) return;

  const metrics = getUserMetrics(userId);
  const favoriteIds = Array.isArray(user.favoriteIds)
    ? user.favoriteIds
    : Array.isArray(user.favorites)
      ? user.favorites
      : Array.isArray(user.favoritePagodas)
        ? user.favoritePagodas
        : [];
  const favoriteNames = favoriteIds.map((pagodaId) => getPagodaName(pagodaId));
  const recentTrips = getUserTrips(userId, 5);
  const recentPosts = getUserPosts(userId, 5);
  const isCurrentAdmin = auth.currentUser?.uid === userId;

  const body = document.getElementById('user-detail-body');
  const deleteButton = document.getElementById('btn-delete-user-modal');
  if (!body) return;

  body.innerHTML = `
    <div class="detail-grid detail-grid-three">
      <div class="detail-item"><label>Display Name</label><div class="detail-value">${escapeHtml(user.displayName || user.name || '—')}</div></div>
      <div class="detail-item"><label>Email</label><div class="detail-value">${escapeHtml(user.email || '—')}</div></div>
      <div class="detail-item"><label>User ID</label><div class="detail-value">${escapeHtml(userId)}</div></div>
      <div class="detail-item"><label>Joined</label><div class="detail-value">${formatDateTime(user.createdAt)}</div></div>
      <div class="detail-item"><label>Saved Pagodas</label><div class="detail-value">${metrics.favoriteCount}</div></div>
      <div class="detail-item"><label>Trips</label><div class="detail-value">${metrics.tripCount}</div></div>
      <div class="detail-item"><label>Community Posts</label><div class="detail-value">${metrics.postCount}</div></div>
    </div>

    <div class="detail-section">
      <div class="detail-section-title">Favorite Pagodas</div>
      <div class="tag-list">
        ${favoriteNames.length
          ? favoriteNames.map((name) => `<span class="tag-pill">${escapeHtml(name)}</span>`).join('')
          : '<span class="cell-muted">No favorites saved yet.</span>'}
      </div>
    </div>

    <div class="detail-section">
      <div class="detail-section-title">Recent Trips</div>
      <div class="timeline-list">
        ${recentTrips.length ? recentTrips.map((trip) => `
          <div class="timeline-item">
            <div class="timeline-index">🗺️</div>
            <div>
              <div class="table-primary">${escapeHtml(trip.name || 'Untitled Trip')}</div>
              <div class="cell-muted">${trip.stopCount} stops · ${formatDate(trip.date)}</div>
            </div>
          </div>
        `).join('') : '<div class="cell-muted">No trips saved yet.</div>'}
      </div>
    </div>

    <div class="detail-section">
      <div class="detail-section-title">Recent Community Posts</div>
      <div class="timeline-list">
        ${recentPosts.length ? recentPosts.map((post) => `
          <div class="timeline-item">
            <div class="timeline-index">💬</div>
            <div>
              <div class="table-primary">${escapeHtml(post.title || 'Untitled post')}</div>
              <div class="cell-muted">${escapeHtml(post.type || 'post')} · ${formatDate(post.createdAt)}</div>
            </div>
          </div>
        `).join('') : '<div class="cell-muted">No community posts yet.</div>'}
      </div>
    </div>
  `;

  if (deleteButton) {
    deleteButton.disabled = isCurrentAdmin;
    deleteButton.textContent = isCurrentAdmin ? 'Current Admin' : 'Delete User Data';
    deleteButton.onclick = isCurrentAdmin ? null : () => deleteUser(userId);
  }

  openModal('modal-user-detail');
}

async function loadUserScopedDocuments(userId, collectionId) {
  return listAdminDocuments(`${window.adminCollections.users}/${userId}/${collectionId}`);
}

async function collectUserCommunityCleanup(userId, ownedPostIds) {
  const commentDocs = [];
  const voteDocs = [];
  const commentAdjustments = new Map();
  const voteAdjustments = new Map();
  const visiblePosts = window.adminState.posts.filter((post) => !ownedPostIds.has(post.id));

  for (const post of visiblePosts) {
    const [comments, votes] = await Promise.all([
      loadCommunitySubcollectionDocuments(post.id, window.adminCollections.communityComments),
      loadCommunitySubcollectionDocuments(post.id, window.adminCollections.communityVotes),
    ]);

    const userComments = comments.filter((comment) => comment.authorUserId === userId);
    const userVotes = votes.filter((vote) => vote.userId === userId);

    if (userComments.length) {
      commentDocs.push(...userComments);
      commentAdjustments.set(post.id, userComments.length);
    }
    if (userVotes.length) {
      voteDocs.push(...userVotes);
      voteAdjustments.set(post.id, userVotes.length);
    }
  }

  return {
    commentDocs,
    voteDocs,
    commentAdjustments,
    voteAdjustments,
  };
}

async function updatePostEngagementAfterUserCleanup(postId, removedComments, removedVotes) {
  if (!removedComments && !removedVotes) {
    return;
  }

  const post = window.adminState.posts.find((item) => item.id === postId);
  const postPath = getAdminRecordPath(post, window.adminCollections.communityPosts);
  if (!post || !postPath) {
    return;
  }

  await patchAdminDocumentPath(
    postPath,
    {
      commentCount: Math.max(0, Number(post.commentCount || 0) - removedComments),
      upvoteCount: Math.max(0, Number(post.upvoteCount || 0) - removedVotes),
      updatedAt: createAdminRestTimestamp(),
    },
    'community post engagement cleanup',
  );
}

async function deleteUser(userId) {
  const user = allUsers.find((item) => getUserId(item) === userId)
    || window.adminState.users.find((item) => getUserId(item) === userId);
  if (!user) {
    showToast('User record not found.', 'error');
    return;
  }

  if (auth.currentUser?.uid === userId) {
    showToast('Sign in with another admin account before deleting this admin user data.', 'error');
    return;
  }

  const displayName = user.displayName || user.name || user.email || userId;
  if (!(await confirmPermanentDeletion(
    `Delete ${displayName}? This removes the synced user profile, trips, AI chat history, and community activity from Firestore. The Firebase Auth sign-in account itself will remain.`,
  ))) {
    return;
  }

  try {
    const tripDocs = window.adminState.trips.filter((trip) => trip.ownerUserId === userId);
    const ownedPosts = window.adminState.posts.filter((post) => post.authorUserId === userId);
    const ownedPostIds = new Set(ownedPosts.map((post) => post.id));
    const [aiChatDocs, communityCleanup] = await Promise.all([
      loadUserScopedDocuments(userId, window.adminCollections.aiChatMessages),
      collectUserCommunityCleanup(userId, ownedPostIds),
    ]);

    await Promise.all(
      ownedPosts.map((post) => deleteCommunityPostCascade(post.id, { skipRefresh: true, skipToast: true })),
    );

    await Promise.all([
      ...tripDocs
        .map((trip) => getAdminRecordPath(trip, `${window.adminCollections.users}/${userId}/${window.adminCollections.trips}`))
        .filter(Boolean)
        .map((documentPath) => deleteAdminDocumentPath(documentPath, 'user trip delete')),
      ...aiChatDocs
        .map((message) => getAdminRecordPath(message))
        .filter(Boolean)
        .map((documentPath) => deleteAdminDocumentPath(documentPath, 'user ai chat delete')),
      ...communityCleanup.commentDocs
        .map((comment) => getAdminRecordPath(comment))
        .filter(Boolean)
        .map((documentPath) => deleteAdminDocumentPath(documentPath, 'user community comment delete')),
      ...communityCleanup.voteDocs
        .map((vote) => getAdminRecordPath(vote))
        .filter(Boolean)
        .map((documentPath) => deleteAdminDocumentPath(documentPath, 'user community vote delete')),
    ]);

    for (const post of window.adminState.posts) {
      if (ownedPostIds.has(post.id)) {
        continue;
      }
      await updatePostEngagementAfterUserCleanup(
        post.id,
        communityCleanup.commentAdjustments.get(post.id) || 0,
        communityCleanup.voteAdjustments.get(post.id) || 0,
      );
    }

    await deleteAdminDocumentPath(
      buildAdminDocumentPath(window.adminCollections.users, userId),
      'user profile delete',
    );

    closeModal('modal-user-detail');
    showToast(
      `User data deleted: ${tripDocs.length} trip${tripDocs.length === 1 ? '' : 's'}, ${ownedPosts.length} post${ownedPosts.length === 1 ? '' : 's'}, ${communityCleanup.commentDocs.length} comment${communityCleanup.commentDocs.length === 1 ? '' : 's'}, and ${communityCleanup.voteDocs.length} vote${communityCleanup.voteDocs.length === 1 ? '' : 's'} cleaned up.`,
      'success',
    );
    await refreshAdminData();
  } catch (error) {
    console.error('Failed to delete user data:', error);
    showToast(error?.message || 'Failed to delete user data.', 'error');
  }
}
