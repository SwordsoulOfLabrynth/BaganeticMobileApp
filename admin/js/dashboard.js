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
  document.getElementById('stat-featured-pagodas').textContent = metrics.totalFeaturedPagodas;
  document.getElementById('stat-myanmar-ready').textContent = metrics.totalMyanmarReady;
  document.getElementById('stat-archived').textContent = metrics.totalArchivedPagodas;
  document.getElementById('stat-card-myanmar-ready').hidden = metrics.totalMyanmarReady === 0;
  document.getElementById('stat-card-archived').hidden = metrics.totalArchivedPagodas === 0;
  document.getElementById('stat-users').textContent = metrics.totalUsers;
  document.getElementById('stat-trips').textContent = metrics.totalTrips;
  document.getElementById('stat-posts').textContent = metrics.totalPosts;

  const community = getCommunitySummary();
  const dataStatus = document.getElementById('dashboard-data-status');
  if (dataStatus) {
    const snapshotItems = [
      community.activePosts > 0 ? `${community.activePosts} active posts` : null,
      community.tipPosts > 0 ? `${community.tipPosts} tips` : null,
      metrics.totalFeaturedPagodas > 0 ? `${metrics.totalFeaturedPagodas} featured on Home` : null,
      metrics.totalArchivedPagodas > 0 ? `${metrics.totalArchivedPagodas} archived sites` : null,
    ].filter(Boolean);
    dataStatus.textContent = snapshotItems.join(' · ') || 'No additional live activity yet';
  }

  renderDashboardWarning();
  renderSyncStatus();
  renderDashboardFeaturedPagodas(getHomeFeaturedPagodas());
  renderRecentUsersPanel(getRecentUsers(3));
  renderRecentTripsPanel(getRecentTrips(3));
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
    messages.push(`These sections may be incomplete: ${failedLabels}.`);
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
      <span>${escapeHtml(messages.join(' '))}</span>
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

function renderDashboardFeaturedPagodas(items) {
  const container = document.getElementById('dashboard-featured-pagodas');
  if (!container) return;

  if (!items.length) {
    container.innerHTML = `
      <div class="home-feature-empty">
        <div class="home-feature-empty-icon" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none"><path d="m12 3 2.78 5.63 6.22.9-4.5 4.39 1.06 6.2L12 17.2l-5.56 2.92 1.06-6.2L3 9.53l6.22-.9L12 3Z"/></svg></div>
        <div><strong>No pagodas featured yet</strong><span>Choose sites from the Pagodas table to show them on Home.</span></div>
      </div>
    `;
    return;
  }

  container.innerHTML = items.map((pagoda, index) => `
    <div class="home-feature-row">
      <span class="home-feature-order" aria-label="Home position ${index + 1}">${index + 1}</span>
      <div class="home-feature-copy">
        <strong>${escapeHtml(pagoda.name || pagoda.id)}</strong>
        <span>${escapeHtml(pagoda.category || 'Heritage site')} · ${escapeHtml(pagoda.era || 'Ready for Home')}</span>
      </div>
      <span class="home-feature-state"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m12 3 2.78 5.63 6.22.9-4.5 4.39 1.06 6.2L12 17.2l-5.56 2.92 1.06-6.2L3 9.53l6.22-.9L12 3Z"/></svg>Featured</span>
    </div>
  `).join('');
}

function getHomeFeaturedPagodas() {
  return window.adminState.pagodas
    .filter((pagoda) => pagoda.status !== 'archived' && pagoda.isHomeFeatured)
    .sort((a, b) => {
      const aOrder = Number(a.homeFeaturedOrder) || Number.MAX_SAFE_INTEGER;
      const bOrder = Number(b.homeFeaturedOrder) || Number.MAX_SAFE_INTEGER;
      return aOrder - bOrder || String(a.name || a.id).localeCompare(String(b.name || b.id));
    });
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
        <button class="btn-secondary" type="button" onclick='viewUser(${serializeForInlineHandler(userId)})'>View</button>
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
      <button class="btn-secondary" type="button" onclick='viewTrip(${serializeForInlineHandler(trip.id)})'>View</button>
    </div>
  `).join('');
}

function renderRecentPostsTable(items) {
  const tbody = document.getElementById('recent-posts-body');
  if (!tbody) return;

  if (!items.length) {
    tbody.innerHTML = `
      <tr>
        <td colspan="6">
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
        <td class="post-type-cell">${typeBadge}</td>
        <td class="post-status-cell">${statusBadge}</td>
        <td class="cell-muted">${post.upvoteCount ?? 0} upvotes · ${post.commentCount ?? 0} comments</td>
        <td class="cell-nowrap cell-muted">${formatDate(post.createdAt)}</td>
      </tr>
    `;
  }).join('');
}
