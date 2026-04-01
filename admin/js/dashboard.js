// ============================================================
// DASHBOARD MODULE
// ============================================================
async function initDashboard() {
  await loadDashboard();
}

async function loadDashboard() {
  await loadAdminState();

  const metrics = getDashboardMetrics();
  document.getElementById('stat-pagodas').textContent = metrics.totalPagodas;
  document.getElementById('stat-temples').textContent = metrics.totalTemples;
  document.getElementById('stat-pagoda-type').textContent = metrics.totalPagodaType;
  document.getElementById('stat-users').textContent = metrics.totalUsers;
  document.getElementById('stat-trips').textContent = metrics.totalTrips;
  document.getElementById('stat-posts').textContent = metrics.totalPosts;

  const community = getCommunitySummary();
  const dataStatus = document.getElementById('dashboard-data-status');
  if (dataStatus) {
    dataStatus.textContent = `${community.activePosts} active posts · ${metrics.totalArchivedPagodas} archived pagodas · ${community.tipPosts} tips`;
  }

  renderDashboardWarning();
  renderSyncStatus();
  renderCatalogSummary(getPagodaCategorySummary());
  renderRecentUsersPanel(getRecentUsers(5));
  renderRecentTripsPanel(getRecentTrips(6));
  renderRecentPostsTable(getRecentPosts(6));
}

function renderDashboardWarning() {
  const banner = document.getElementById('dashboard-warning');
  if (!banner) return;

  if (!window.adminState.datasetErrors.length && !window.adminState.catalogSeeded) {
    banner.style.display = 'none';
    banner.innerHTML = '';
    return;
  }

  const messages = [];
  if (window.adminState.catalogSeeded) {
    messages.push('The shared pagoda catalog was seeded from the bundled sample dataset.');
  }
  if (window.adminState.datasetErrors.length) {
    const failedLabels = window.adminState.datasetErrors
      .map((error) => error.label)
      .join(', ');
    messages.push(`These sections may be incomplete: ${escapeHtml(failedLabels)}.`);
    messages.push(
      window.adminState.datasetErrors
        .map((error) => `${error.label}: ${error.message || 'Unknown error'}`)
        .join(' | '),
    );
  }

  banner.style.display = 'flex';
  banner.classList.add('data-banner-info');
  banner.innerHTML = `
    <div>
      <strong>Admin sync notice</strong>
      <span>${messages.join(' ')}</span>
    </div>
    <button class="btn-secondary" type="button" onclick="handleAdminRefresh(false)">Retry</button>
  `;
}

function renderSyncStatus() {
  const syncStatus = document.getElementById('sync-status');
  if (!syncStatus) return;

  const lastLoaded = window.adminState.lastLoadedAt;
  const statusText = lastLoaded
    ? `Last sync ${formatDateTime(lastLoaded)}`
    : 'Waiting for data';
  syncStatus.textContent = window.adminState.datasetErrors.length
    ? `${statusText} · partial data`
    : statusText;
}

function renderCatalogSummary(items) {
  const container = document.getElementById('catalog-summary-list');
  if (!container) return;

  container.innerHTML = items.map((item) => `
    <div class="insight-row">
      <div>
        <div class="insight-title">${escapeHtml(item.label)}</div>
        <div class="insight-meta">${escapeHtml(item.description)}</div>
      </div>
      <span class="pill">${item.count}</span>
    </div>
  `).join('');
}

function renderRecentUsersPanel(items) {
  const container = document.getElementById('recent-users-list');
  if (!container) return;

  if (!items.length) {
    container.innerHTML = `
      <div class="empty-state compact">
        <div class="empty-icon">👥</div>
        <p>No user profiles have been synced yet.</p>
      </div>
    `;
    return;
  }

  container.innerHTML = items.map((user) => {
    const userId = getUserId(user);
    const metrics = getUserMetrics(userId);
    return `
      <div class="insight-row">
        <div>
          <div class="insight-title">${escapeHtml(user.displayName || user.name || user.email || 'Unknown user')}</div>
          <div class="insight-meta">${metrics.favoriteCount} saved · ${metrics.tripCount} trips · ${metrics.postCount} posts</div>
        </div>
        <button class="btn-secondary" type="button" onclick="viewUser(${JSON.stringify(userId)})">View</button>
      </div>
    `;
  }).join('');
}

function renderRecentTripsPanel(items) {
  const container = document.getElementById('recent-trips-list');
  if (!container) return;

  if (!items.length) {
    container.innerHTML = `
      <div class="empty-state compact">
        <div class="empty-icon">🗺️</div>
        <p>No trips synced from the app yet.</p>
      </div>
    `;
    return;
  }

  container.innerHTML = items.map((trip) => `
    <div class="insight-row">
      <div>
        <div class="insight-title">${escapeHtml(trip.name || 'Untitled Trip')}</div>
        <div class="insight-meta">${trip.stopCount} stops · ${formatDate(trip.date)}</div>
      </div>
      <button class="btn-secondary" type="button" onclick="viewTrip(${JSON.stringify(trip.id)})">View</button>
    </div>
  `).join('');
}

function renderRecentPostsTable(items) {
  const tbody = document.getElementById('recent-posts-body');
  if (!tbody) return;

  if (!items.length) {
    tbody.innerHTML = `
      <tr>
        <td colspan="5">
          <div class="empty-state compact">
            <div class="empty-icon">💬</div>
            <p>No community posts yet.</p>
          </div>
        </td>
      </tr>
    `;
    return;
  }

  tbody.innerHTML = items.map((post) => {
    const typeBadge = post.type === 'tip'
      ? '<span class="badge badge-green">Tip</span>'
      : '<span class="badge badge-blue">Question</span>';
    const statusBadge = post.status === 'active'
      ? '<span class="badge badge-green">Active</span>'
      : '<span class="badge badge-red">Hidden</span>';

    return `
      <tr>
        <td>
          <div class="table-primary">${escapeHtml(truncate(post.title, 60))}</div>
          <div class="cell-muted">${escapeHtml(truncate(post.body, 78))}</div>
        </td>
        <td>${escapeHtml(post.authorName || '—')}</td>
        <td>${typeBadge} ${statusBadge}</td>
        <td class="cell-muted">${post.upvoteCount ?? 0} upvotes · ${post.commentCount ?? 0} comments</td>
        <td class="cell-nowrap cell-muted">${formatDate(post.createdAt)}</td>
      </tr>
    `;
  }).join('');
}
