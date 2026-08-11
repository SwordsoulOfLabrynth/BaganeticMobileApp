// ============================================================
// COMMUNITY MODULE
// ============================================================
let allPosts = [];
let filteredPosts = [];
let communityPage = 1;
const COMM_PAGE_SIZE = 10;
let communityFilter = 'all';
let selectedPost = null;
let communityBound = false;

function initCommunity() {
  if (!communityBound) {
    document.getElementById('community-search')?.addEventListener('input', filterCommunityPosts);
    document.querySelectorAll('#page-community .filter-chip').forEach((chip) => {
      chip.addEventListener('click', () => {
        document.querySelectorAll('#page-community .filter-chip').forEach((item) => {
          item.classList.remove('active');
        });
        chip.classList.add('active');
        communityFilter = chip.dataset.filter;
        filterCommunityPosts();
      });
    });
    communityBound = true;
  }

  loadCommunityPosts();
}

async function loadCommunityPosts() {
  await loadAdminState();
  allPosts = [...window.adminState.posts].sort((a, b) => {
    const aDate = parseDateSafe(a.createdAt) || new Date(0);
    const bDate = parseDateSafe(b.createdAt) || new Date(0);
    return bDate - aDate;
  });
  const countLabel = document.getElementById('community-count');
  if (countLabel) {
    countLabel.textContent = `${allPosts.length} synced community posts`;
  }
  filterCommunityPosts();
}

function filterCommunityPosts() {
  const query = (document.getElementById('community-search')?.value || '').toLowerCase();
  filteredPosts = allPosts.filter((post) => {
    const matchesFilter =
      communityFilter === 'all' ? true :
      communityFilter === 'active' ? post.status === 'active' :
      communityFilter === 'hidden' ? post.status !== 'active' :
      communityFilter === 'tip' ? post.type === 'tip' :
      communityFilter === 'question' ? post.type === 'question' : true;

    const matchesSearch =
      !query ||
      post.title?.toLowerCase().includes(query) ||
      post.body?.toLowerCase().includes(query) ||
      post.authorName?.toLowerCase().includes(query);

    return matchesFilter && matchesSearch;
  });
  communityPage = 1;
  renderCommunityTable();
}

function renderCommunityTable() {
  const tbody = document.getElementById('community-table-body');
  if (!tbody) return;

  const start = (communityPage - 1) * COMM_PAGE_SIZE;
  const slice = filteredPosts.slice(start, start + COMM_PAGE_SIZE);
  const totalPages = Math.ceil(filteredPosts.length / COMM_PAGE_SIZE) || 1;

  const info = document.getElementById('comm-pagination-info');
  if (info) {
    info.textContent = filteredPosts.length
      ? `${start + 1}–${Math.min(start + COMM_PAGE_SIZE, filteredPosts.length)} of ${filteredPosts.length}`
      : '0 results';
  }
  renderCommunityPagination(totalPages);

  if (!slice.length) {
    tbody.innerHTML = `
      <tr>
        <td colspan="7">
          <div class="empty-state">
            <div class="empty-icon">💬</div>
            <p>No posts match the current search or filter.</p>
          </div>
        </td>
      </tr>
    `;
    return;
  }

  tbody.innerHTML = slice.map((post) => {
    const typeBadge = post.type === 'tip'
      ? '<span class="badge badge-green">Tip</span>'
      : '<span class="badge badge-blue">Question</span>';
    const statusBadge = post.status === 'active'
      ? '<span class="badge badge-green">Active</span>'
      : '<span class="badge badge-red">Hidden</span>';
    return `
      <tr>
        <td>
          <div class="table-primary">${escapeHtml(truncate(post.title, 58))}</div>
          <div class="cell-muted">${escapeHtml(truncate(post.body, 88))}</div>
        </td>
        <td>${escapeHtml(post.authorName || '—')}</td>
        <td>${typeBadge}</td>
        <td>${statusBadge}</td>
        <td>${post.upvoteCount ?? 0} upvotes · ${post.commentCount ?? 0} comments</td>
        <td class="cell-nowrap cell-muted">${formatDate(post.createdAt)}</td>
        <td>
          <div class="action-row">
            <button class="btn-warning" type="button" onclick='viewPost(${serializeForInlineHandler(post.id)})'>Manage</button>
          </div>
        </td>
      </tr>
    `;
  }).join('');
}

function renderCommunityPagination(totalPages) {
  const container = document.getElementById('comm-pagination-controls');
  if (!container) return;

  let html = `<button class="page-btn" onclick="changeCommunityPage(${communityPage - 1})" ${communityPage === 1 ? 'disabled' : ''}>‹</button>`;
  for (let index = 1; index <= totalPages; index += 1) {
    if (index === 1 || index === totalPages || Math.abs(index - communityPage) <= 1) {
      html += `<button class="page-btn ${index === communityPage ? 'active' : ''}" onclick="changeCommunityPage(${index})">${index}</button>`;
    } else if (Math.abs(index - communityPage) === 2) {
      html += '<span class="pagination-gap">…</span>';
    }
  }
  html += `<button class="page-btn" onclick="changeCommunityPage(${communityPage + 1})" ${communityPage === totalPages ? 'disabled' : ''}>›</button>`;
  container.innerHTML = html;
}

function changeCommunityPage(page) {
  communityPage = page;
  renderCommunityTable();
}

function viewPost(postId) {
  selectedPost = allPosts.find((post) => post.id === postId);
  if (!selectedPost) return;

  const body = document.getElementById('post-detail-body');
  const actions = document.getElementById('post-detail-actions');
  if (!body || !actions) return;

  const tags = Array.isArray(selectedPost.tags) ? selectedPost.tags : [];
  body.innerHTML = `
    <div class="detail-grid detail-grid-three">
      <div class="detail-item"><label>Author</label><div class="detail-value">${escapeHtml(selectedPost.authorName || '—')}</div></div>
      <div class="detail-item"><label>Type</label><div class="detail-value">${escapeHtml(selectedPost.type || '—')}</div></div>
      <div class="detail-item"><label>Status</label><div class="detail-value">${escapeHtml(selectedPost.status || 'active')}</div></div>
      <div class="detail-item"><label>Upvotes</label><div class="detail-value">${selectedPost.upvoteCount ?? 0}</div></div>
      <div class="detail-item"><label>Comments</label><div class="detail-value">${selectedPost.commentCount ?? 0}</div></div>
      <div class="detail-item"><label>Created</label><div class="detail-value">${formatDateTime(selectedPost.createdAt)}</div></div>
    </div>

    <div class="detail-section">
      <div class="detail-section-title">${escapeHtml(selectedPost.title || 'Untitled post')}</div>
      <div class="detail-section-body">${escapeHtml(selectedPost.body || '—')}</div>
    </div>

    ${tags.length ? `
      <div class="detail-section">
        <div class="detail-section-title">Tags</div>
        <div class="tag-list">
          ${tags.map((tag) => `<span class="tag-pill">${escapeHtml(tag)}</span>`).join('')}
        </div>
      </div>
    ` : ''}
  `;

  const toggleLabel = selectedPost.status === 'active' ? 'Hide post' : 'Restore post';
  actions.innerHTML = `
    <button class="btn-secondary" type="button" onclick='togglePostStatus(${serializeForInlineHandler(selectedPost.id)}, ${serializeForInlineHandler(selectedPost.status || 'active')})'>${toggleLabel}</button>
    <button class="btn-danger" type="button" onclick='deletePost(${serializeForInlineHandler(selectedPost.id)})'>Delete post</button>
  `;

  openModal('modal-post-detail');
}

async function loadCommunitySubcollectionDocuments(postId, collectionId) {
  return listAdminDocuments(
    `${window.adminCollections.communityPosts}/${postId}/${collectionId}`,
  );
}

async function deleteCommunityPostCascade(postId, options = {}) {
  const { skipRefresh = false, skipToast = false } = options;
  const post = allPosts.find((item) => item.id === postId)
    || window.adminState.posts.find((item) => item.id === postId);
  const postPath = getAdminRecordPath(post, window.adminCollections.communityPosts);

  if (!postPath) {
    throw new Error('Community post path could not be resolved.');
  }

  const [commentDocs, voteDocs] = await Promise.all([
    loadCommunitySubcollectionDocuments(postId, window.adminCollections.communityComments),
    loadCommunitySubcollectionDocuments(postId, window.adminCollections.communityVotes),
  ]);

  await Promise.all([
    ...commentDocs
      .map((comment) => getAdminRecordPath(comment))
      .filter(Boolean)
      .map((documentPath) => deleteAdminDocumentPath(documentPath, 'community comment delete')),
    ...voteDocs
      .map((vote) => getAdminRecordPath(vote))
      .filter(Boolean)
      .map((documentPath) => deleteAdminDocumentPath(documentPath, 'community vote delete')),
  ]);

  await deleteAdminDocumentPath(postPath, 'community post delete');

  if (!skipToast) {
    const removedChildren = commentDocs.length + voteDocs.length;
    showToast(
      removedChildren
        ? `Post deleted with ${commentDocs.length} comment${commentDocs.length === 1 ? '' : 's'} and ${voteDocs.length} vote${voteDocs.length === 1 ? '' : 's'}.`
        : 'Post deleted.',
      'success',
    );
  }

  if (!skipRefresh) {
    await refreshAdminData();
  }
}

async function togglePostStatus(postId, currentStatus) {
  const newStatus = currentStatus === 'active' ? 'hidden' : 'active';
  try {
    const documentPath = buildAdminDocumentPath(window.adminCollections.communityPosts, postId);
    const now = createAdminRestTimestamp();
    await runAdminWriteOperation({
      action: 'community post status update',
      sdkWrite: () =>
        db.collection(window.adminCollections.communityPosts).doc(postId).update({
          status: newStatus,
          updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }),
      restWrite: () =>
        window.adminFirestoreRest.patchDocument(documentPath, {
          status: newStatus,
          updatedAt: now,
        }),
    });
    showToast(`Post ${newStatus === 'active' ? 'restored' : 'hidden'} successfully.`, 'success');
    closeModal('modal-post-detail');
    await refreshAdminData();
  } catch (error) {
    console.error('Failed to update post status:', error);
    showToast('Failed to update post status.', 'error');
  }
}

async function deletePost(postId) {
  if (!(await confirmPermanentDeletion('Delete this community post permanently? Related comments and votes will also be removed.'))) return;
  try {
    await deleteCommunityPostCascade(postId);
    closeModal('modal-post-detail');
  } catch (error) {
    console.error('Failed to delete post:', error);
    showToast('Failed to delete post.', 'error');
  }
}
