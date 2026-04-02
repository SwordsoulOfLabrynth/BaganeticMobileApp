// ============================================================
// TRIPS MODULE
// ============================================================
let allTrips = [];
let filteredTrips = [];
let tripsPage = 1;
const TRIPS_PAGE_SIZE = 10;
let tripsBound = false;

function initTrips() {
  if (!tripsBound) {
    document.getElementById('trips-search')?.addEventListener('input', filterTrips);
    tripsBound = true;
  }

  loadTrips();
}

async function loadTrips() {
  await loadAdminState();
  allTrips = window.adminState.trips
    .map((trip) => enrichTrip(trip))
    .sort((a, b) => {
      const aDate = parseDateSafe(a.updatedAt) || new Date(0);
      const bDate = parseDateSafe(b.updatedAt) || new Date(0);
      return bDate - aDate;
    });

  const label = document.getElementById('trips-count');
  if (label) {
    label.textContent = `${allTrips.length} synced trips`;
  }

  filterTrips();
}

function filterTrips() {
  const query = (document.getElementById('trips-search')?.value || '').toLowerCase();
  filteredTrips = allTrips.filter((trip) => {
    const stopNames = (trip.stops || [])
      .map((stop) => stop.pagodaName || stop.pagodaId || '')
      .join(' ')
      .toLowerCase();
    return (
      !query ||
      trip.name?.toLowerCase().includes(query) ||
      stopNames.includes(query) ||
      trip.ownerUserId?.toLowerCase().includes(query)
    );
  });

  tripsPage = 1;
  renderTripsTable();
}

function renderTripsTable() {
  const tbody = document.getElementById('trips-table-body');
  if (!tbody) return;

  const start = (tripsPage - 1) * TRIPS_PAGE_SIZE;
  const slice = filteredTrips.slice(start, start + TRIPS_PAGE_SIZE);
  const totalPages = Math.ceil(filteredTrips.length / TRIPS_PAGE_SIZE) || 1;

  const info = document.getElementById('trips-pagination-info');
  if (info) {
    info.textContent = filteredTrips.length
      ? `${start + 1}–${Math.min(start + TRIPS_PAGE_SIZE, filteredTrips.length)} of ${filteredTrips.length}`
      : '0 results';
  }
  renderTripsPagination(totalPages);

  if (!slice.length) {
    tbody.innerHTML = `
      <tr>
        <td colspan="5">
          <div class="empty-state">
            <div class="empty-icon">🗺️</div>
            <p>No trips found for the current search.</p>
          </div>
        </td>
      </tr>
    `;
    return;
  }

  tbody.innerHTML = slice.map((trip) => {
    const stopPreview = (trip.stops || [])
      .slice(0, 3)
      .map((stop) => escapeHtml(stop.pagodaName || getPagodaName(stop.pagodaId)))
      .join(' · ');
    return `
      <tr>
        <td>
          <div class="table-primary">${escapeHtml(trip.name || 'Untitled Trip')}</div>
          <div class="cell-muted">${stopPreview || 'No stops'}${trip.stopCount > 3 ? ` · +${trip.stopCount - 3} more` : ''}</div>
        </td>
        <td><span class="badge badge-blue">${trip.stopCount}</span></td>
        <td class="cell-nowrap cell-muted">${formatDate(trip.date)}</td>
        <td class="cell-nowrap cell-muted">${formatDate(trip.updatedAt || trip.createdAt)}</td>
        <td><button class="btn-warning" type="button" onclick='viewTrip(${serializeForInlineHandler(trip.id)})'>Details</button></td>
      </tr>
    `;
  }).join('');
}

function renderTripsPagination(totalPages) {
  const container = document.getElementById('trips-pagination-controls');
  if (!container) return;

  let html = `<button class="page-btn" onclick="changeTripsPage(${tripsPage - 1})" ${tripsPage === 1 ? 'disabled' : ''}>‹</button>`;
  for (let index = 1; index <= totalPages; index += 1) {
    if (index === 1 || index === totalPages || Math.abs(index - tripsPage) <= 1) {
      html += `<button class="page-btn ${index === tripsPage ? 'active' : ''}" onclick="changeTripsPage(${index})">${index}</button>`;
    } else if (Math.abs(index - tripsPage) === 2) {
      html += '<span class="pagination-gap">…</span>';
    }
  }
  html += `<button class="page-btn" onclick="changeTripsPage(${tripsPage + 1})" ${tripsPage === totalPages ? 'disabled' : ''}>›</button>`;
  container.innerHTML = html;
}

function changeTripsPage(page) {
  tripsPage = page;
  renderTripsTable();
}

function viewTrip(tripId) {
  const trip = allTrips.find((item) => item.id === tripId) || enrichTrip(
    window.adminState.trips.find((item) => item.id === tripId) || {},
  );
  if (!trip || !trip.id) return;

  const body = document.getElementById('trip-detail-body');
  if (!body) return;

  const stops = Array.isArray(trip.stops) ? trip.stops : [];
  const estimatedDistance = stops.reduce((sum, stop) => sum + (stop.distanceToNext || 0), 0);

  body.innerHTML = `
    <div class="detail-grid detail-grid-three">
      <div class="detail-item"><label>Trip Name</label><div class="detail-value">${escapeHtml(trip.name || 'Untitled Trip')}</div></div>
      <div class="detail-item"><label>Stops</label><div class="detail-value">${trip.stopCount || stops.length}</div></div>
      <div class="detail-item"><label>Trip Date</label><div class="detail-value">${formatDateTime(trip.date)}</div></div>
      <div class="detail-item"><label>Created</label><div class="detail-value">${formatDateTime(trip.createdAt)}</div></div>
      <div class="detail-item"><label>Updated</label><div class="detail-value">${formatDateTime(trip.updatedAt)}</div></div>
      <div class="detail-item"><label>Owner ID</label><div class="detail-value">${escapeHtml(trip.ownerUserId || '—')}</div></div>
      <div class="detail-item"><label>Estimated Distance</label><div class="detail-value">${estimatedDistance ? `${estimatedDistance.toFixed(2)} km` : '—'}</div></div>
      <div class="detail-item"><label>Trip ID</label><div class="detail-value">${escapeHtml(trip.id)}</div></div>
    </div>

    ${trip.description ? `
      <div class="detail-section">
        <div class="detail-section-title">Description</div>
        <div class="detail-section-body">${escapeHtml(trip.description)}</div>
      </div>
    ` : ''}

    <div class="detail-section">
      <div class="detail-section-title">Stops</div>
      <div class="timeline-list">
        ${stops.length ? stops.map((stop, index) => `
          <div class="timeline-item">
            <div class="timeline-index">${index + 1}</div>
            <div>
              <div class="table-primary">${escapeHtml(stop.pagodaName || getPagodaName(stop.pagodaId))}</div>
              <div class="cell-muted">${escapeHtml(stop.pagodaId || '—')}${stop.notes ? ` · ${escapeHtml(stop.notes)}` : ''}</div>
            </div>
          </div>
        `).join('') : '<div class="cell-muted">No stops saved for this trip.</div>'}
      </div>
    </div>
  `;

  openModal('modal-trip-detail');
}
