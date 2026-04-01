// ============================================================
// ROAD REPORTS MODULE
// ============================================================
let allReports = [];
let filteredReports = [];
let reportsPage = 1;
const REPORTS_PAGE_SIZE = 10;
let reportsFilter = 'all';
let selectedReport = null;
let reportsBound = false;

function initReports() {
  if (!reportsBound) {
    document.getElementById('reports-search')?.addEventListener('input', filterReports);
    document.querySelectorAll('#page-reports .filter-chip').forEach((chip) => {
      chip.addEventListener('click', () => {
        document.querySelectorAll('#page-reports .filter-chip').forEach((item) => {
          item.classList.remove('active');
        });
        chip.classList.add('active');
        reportsFilter = chip.dataset.filter;
        filterReports();
      });
    });
    reportsBound = true;
  }

  loadRoadReports();
}

async function loadRoadReports() {
  await loadAdminState();
  allReports = [...window.adminState.reports].sort((a, b) => {
    const aDate = parseDateSafe(a.createdAt) || new Date(0);
    const bDate = parseDateSafe(b.createdAt) || new Date(0);
    return bDate - aDate;
  });
  const countLabel = document.getElementById('reports-count');
  if (countLabel) {
    countLabel.textContent = `${allReports.length} total reports · ${getRoadReportSummary(999).length} still active`;
  }
  filterReports();
}

function filterReports() {
  const query = (document.getElementById('reports-search')?.value || '').toLowerCase();
  filteredReports = allReports.filter((report) => {
    const pagodaName = getPagodaName(report.pagodaId) || report.pagodaName || '';
    const matchesFilter =
      reportsFilter === 'all' ? true :
      reportsFilter === 'active' ? report.status === 'active' :
      reportsFilter === 'resolved' ? report.status === 'resolved' :
      reportsFilter === 'high' ? report.severity === 'high' : true;
    const matchesSearch =
      !query ||
      pagodaName.toLowerCase().includes(query) ||
      (report.category || '').toLowerCase().includes(query) ||
      (report.note || '').toLowerCase().includes(query);
    return matchesFilter && matchesSearch;
  });
  reportsPage = 1;
  renderReportsTable();
}

function renderReportsTable() {
  const tbody = document.getElementById('reports-table-body');
  if (!tbody) return;

  const start = (reportsPage - 1) * REPORTS_PAGE_SIZE;
  const slice = filteredReports.slice(start, start + REPORTS_PAGE_SIZE);
  const totalPages = Math.ceil(filteredReports.length / REPORTS_PAGE_SIZE) || 1;

  const info = document.getElementById('reports-pagination-info');
  if (info) {
    info.textContent = filteredReports.length
      ? `${start + 1}–${Math.min(start + REPORTS_PAGE_SIZE, filteredReports.length)} of ${filteredReports.length}`
      : '0 results';
  }
  renderReportsPagination(totalPages);

  if (!slice.length) {
    tbody.innerHTML = `
      <tr>
        <td colspan="7">
          <div class="empty-state">
            <div class="empty-icon">⚠️</div>
            <p>No reports match the current search or filter.</p>
          </div>
        </td>
      </tr>
    `;
    return;
  }

  tbody.innerHTML = slice.map((report) => {
    const severityBadge =
      report.severity === 'high' ? '<span class="badge badge-red">High</span>' :
      report.severity === 'medium' ? '<span class="badge badge-gold">Medium</span>' :
      '<span class="badge badge-gray">Low</span>';

    const statusBadge = report.status === 'active'
      ? '<span class="badge badge-green">Active</span>'
      : '<span class="badge badge-gray">Resolved</span>';

    const expiresAt = parseDateSafe(report.expiresAt);
    const expired = expiresAt && expiresAt < new Date();

    return `
      <tr>
        <td>
          <div class="table-primary">${escapeHtml(getPagodaName(report.pagodaId) || report.pagodaName || '—')}</div>
          <div class="cell-muted">${escapeHtml(report.pagodaId || '—')}</div>
        </td>
        <td>${escapeHtml(report.category || '—')}</td>
        <td>${severityBadge}</td>
        <td>${statusBadge}${expired ? ' <span class="badge badge-gray">Expired</span>' : ''}</td>
        <td>
          <div class="table-primary">${escapeHtml(getUserName(report.reporterUserId))}</div>
          <div class="cell-muted">${formatDate(report.createdAt)}</div>
        </td>
        <td class="cell-nowrap cell-muted">${formatDate(report.expiresAt)}</td>
        <td>
          <div class="action-row">
            <button class="btn-warning" type="button" onclick="viewReport('${escapeHtml(report.id)}')">View</button>
            ${report.status === 'active' ? `<button class="btn-success" type="button" onclick="resolveReport('${escapeHtml(report.id)}')">Resolve</button>` : ''}
            <button class="btn-danger" type="button" onclick="deleteReport('${escapeHtml(report.id)}')">Delete</button>
          </div>
        </td>
      </tr>
    `;
  }).join('');
}

function renderReportsPagination(totalPages) {
  const container = document.getElementById('reports-pagination-controls');
  if (!container) return;

  let html = `<button class="page-btn" onclick="changeReportsPage(${reportsPage - 1})" ${reportsPage === 1 ? 'disabled' : ''}>‹</button>`;
  for (let index = 1; index <= totalPages; index += 1) {
    if (index === 1 || index === totalPages || Math.abs(index - reportsPage) <= 1) {
      html += `<button class="page-btn ${index === reportsPage ? 'active' : ''}" onclick="changeReportsPage(${index})">${index}</button>`;
    } else if (Math.abs(index - reportsPage) === 2) {
      html += '<span class="pagination-gap">…</span>';
    }
  }
  html += `<button class="page-btn" onclick="changeReportsPage(${reportsPage + 1})" ${reportsPage === totalPages ? 'disabled' : ''}>›</button>`;
  container.innerHTML = html;
}

function changeReportsPage(page) {
  reportsPage = page;
  renderReportsTable();
}

function viewReport(id) {
  selectedReport = allReports.find((report) => report.id === id);
  if (!selectedReport) return;

  const body = document.getElementById('report-detail-body');
  if (!body) return;

  body.innerHTML = `
    <div class="detail-grid detail-grid-three">
      <div class="detail-item"><label>Pagoda</label><div class="detail-value">${escapeHtml(getPagodaName(selectedReport.pagodaId) || selectedReport.pagodaName || '—')}</div></div>
      <div class="detail-item"><label>Category</label><div class="detail-value">${escapeHtml(selectedReport.category || '—')}</div></div>
      <div class="detail-item"><label>Severity</label><div class="detail-value">${escapeHtml(selectedReport.severity || '—')}</div></div>
      <div class="detail-item"><label>Status</label><div class="detail-value">${escapeHtml(selectedReport.status || 'active')}</div></div>
      <div class="detail-item"><label>Reporter</label><div class="detail-value">${escapeHtml(getUserName(selectedReport.reporterUserId))}</div></div>
      <div class="detail-item"><label>Created</label><div class="detail-value">${formatDateTime(selectedReport.createdAt)}</div></div>
      <div class="detail-item"><label>Expires</label><div class="detail-value">${formatDateTime(selectedReport.expiresAt)}</div></div>
      <div class="detail-item"><label>User ID</label><div class="detail-value">${escapeHtml(selectedReport.reporterUserId || '—')}</div></div>
      <div class="detail-item"><label>Pagoda ID</label><div class="detail-value">${escapeHtml(selectedReport.pagodaId || '—')}</div></div>
    </div>

    <div class="detail-section">
      <div class="detail-section-title">Report Note</div>
      <div class="detail-section-body">${escapeHtml(selectedReport.note || '—')}</div>
    </div>
  `;

  openModal('modal-report-detail');
}

async function resolveReport(id) {
  try {
    await db.collection(window.adminCollections.roadReports).doc(id).update({
      status: 'resolved',
      updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
    });
    showToast('Report resolved.', 'success');
    await refreshAdminData();
  } catch (error) {
    console.error('Failed to resolve report:', error);
    showToast('Failed to resolve report.', 'error');
  }
}

async function deleteReport(id) {
  if (!confirm('Delete this road report permanently?')) return;
  try {
    await db.collection(window.adminCollections.roadReports).doc(id).delete();
    showToast('Report deleted.', 'success');
    await refreshAdminData();
  } catch (error) {
    console.error('Failed to delete report:', error);
    showToast('Failed to delete report.', 'error');
  }
}
