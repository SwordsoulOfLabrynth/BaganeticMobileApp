// ============================================================
// FEEDBACKS MODULE
// ============================================================
let allFeedbacks = [];
let filteredFeedbacks = [];
let feedbacksPage = 1;
const FB_PAGE_SIZE = 10;
let feedbackRatingFilter = 'all';
let feedbacksBound = false;

function initFeedbacks() {
  if (!feedbacksBound) {
    document.getElementById('feedbacks-search')?.addEventListener('input', filterFeedbacks);
    document.querySelectorAll('#page-feedbacks .filter-chip').forEach((chip) => {
      chip.addEventListener('click', () => {
        document.querySelectorAll('#page-feedbacks .filter-chip').forEach((item) => {
          item.classList.remove('active');
        });
        chip.classList.add('active');
        feedbackRatingFilter = chip.dataset.filter;
        filterFeedbacks();
      });
    });
    feedbacksBound = true;
  }

  loadFeedbacks();
}

async function loadFeedbacks() {
  await loadAdminState();
  allFeedbacks = window.adminState.feedbacks
    .map((feedback) => enrichFeedback(feedback))
    .sort((a, b) => {
      const aDate = parseDateSafe(a.createdAt) || new Date(0);
      const bDate = parseDateSafe(b.createdAt) || new Date(0);
      return bDate - aDate;
    });

  const avg = allFeedbacks.length
    ? (
        allFeedbacks.reduce((sum, feedback) => sum + (feedback.rating || 0), 0) /
        allFeedbacks.length
      ).toFixed(1)
    : '—';

  const label = document.getElementById('feedbacks-avg');
  if (label) {
    label.textContent = `Average ${avg} ★ · ${allFeedbacks.length} total reviews`;
  }

  filterFeedbacks();
}

function filterFeedbacks() {
  const query = (document.getElementById('feedbacks-search')?.value || '').toLowerCase();
  filteredFeedbacks = allFeedbacks.filter((feedback) => {
    const matchesFilter =
      feedbackRatingFilter === 'all'
        ? true
        : parseInt(feedbackRatingFilter, 10) === (feedback.rating || 0);
    const matchesSearch =
      !query ||
      feedback.userName?.toLowerCase().includes(query) ||
      feedback.comment?.toLowerCase().includes(query) ||
      feedback.pagodaName?.toLowerCase().includes(query) ||
      feedback.pagodaId?.toLowerCase().includes(query);
    return matchesFilter && matchesSearch;
  });

  feedbacksPage = 1;
  renderFeedbacksTable();
}

function renderFeedbacksTable() {
  const tbody = document.getElementById('feedbacks-table-body');
  if (!tbody) return;

  const start = (feedbacksPage - 1) * FB_PAGE_SIZE;
  const slice = filteredFeedbacks.slice(start, start + FB_PAGE_SIZE);
  const totalPages = Math.ceil(filteredFeedbacks.length / FB_PAGE_SIZE) || 1;

  const info = document.getElementById('feedbacks-pagination-info');
  if (info) {
    info.textContent = filteredFeedbacks.length
      ? `${start + 1}–${Math.min(start + FB_PAGE_SIZE, filteredFeedbacks.length)} of ${filteredFeedbacks.length}`
      : '0 results';
  }
  renderFeedbacksPagination(totalPages);

  if (!slice.length) {
    tbody.innerHTML = `
      <tr>
        <td colspan="6">
          <div class="empty-state">
            <div class="empty-icon">⭐</div>
            <p>No feedbacks match the current search or filter.</p>
          </div>
        </td>
      </tr>
    `;
    return;
  }

  tbody.innerHTML = slice.map((feedback) => `
    <tr>
      <td><strong>${escapeHtml(feedback.userName || '—')}</strong></td>
      <td>${escapeHtml(feedback.pagodaName || feedback.pagodaId || '—')}</td>
      <td>
        <span class="badge badge-gold">${feedback.rating || 0} ★</span>
        <span class="cell-muted">${renderStars(feedback.rating)}</span>
      </td>
      <td class="cell-muted">${escapeHtml(truncate(feedback.comment, 78))}</td>
      <td class="cell-nowrap cell-muted">${formatDate(feedback.createdAt)}</td>
      <td><button class="btn-danger" type="button" onclick="deleteFeedback('${escapeHtml(feedback.id)}')">Delete</button></td>
    </tr>
  `).join('');
}

function renderFeedbacksPagination(totalPages) {
  const container = document.getElementById('feedbacks-pagination-controls');
  if (!container) return;

  let html = `<button class="page-btn" onclick="changeFeedbacksPage(${feedbacksPage - 1})" ${feedbacksPage === 1 ? 'disabled' : ''}>‹</button>`;
  for (let index = 1; index <= totalPages; index += 1) {
    if (index === 1 || index === totalPages || Math.abs(index - feedbacksPage) <= 1) {
      html += `<button class="page-btn ${index === feedbacksPage ? 'active' : ''}" onclick="changeFeedbacksPage(${index})">${index}</button>`;
    } else if (Math.abs(index - feedbacksPage) === 2) {
      html += '<span class="pagination-gap">…</span>';
    }
  }
  html += `<button class="page-btn" onclick="changeFeedbacksPage(${feedbacksPage + 1})" ${feedbacksPage === totalPages ? 'disabled' : ''}>›</button>`;
  container.innerHTML = html;
}

function changeFeedbacksPage(page) {
  feedbacksPage = page;
  renderFeedbacksTable();
}

async function deleteFeedback(id) {
  if (!(await confirmPermanentDeletion('Delete this feedback permanently?'))) return;
  try {
    await db.collection(window.adminCollections.feedbacks).doc(id).delete();
    showToast('Feedback deleted.', 'success');
    await refreshAdminData();
  } catch (error) {
    console.error('Failed to delete feedback:', error);
    showToast('Failed to delete feedback.', 'error');
  }
}
