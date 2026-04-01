// ============================================================
// PAGODAS MODULE
// ============================================================
let allPagodas = [];
let filteredPagodas = [];
let pagodasPage = 1;
const PAGODAS_PAGE_SIZE = 12;
let pagodaCategory = 'all';
let pagodaStatus = 'active';
let pagodasBound = false;
let currentPagodaEditId = null;
let originalPagodaCoordinates = null;

function initPagodas() {
  if (!pagodasBound) {
    document.getElementById('pagodas-search')?.addEventListener('input', filterPagodas);
    document.getElementById('pagodas-status-filter')?.addEventListener('change', (event) => {
      pagodaStatus = event.target.value;
      filterPagodas();
    });
    document.getElementById('btn-new-pagoda')?.addEventListener('click', openCreatePagodaModal);
    document.getElementById('pagoda-form')?.addEventListener('submit', submitPagodaForm);

    document.querySelectorAll('#page-pagodas .filter-chip').forEach((chip) => {
      chip.addEventListener('click', () => {
        if (chip.classList.contains('active')) {
          chip.classList.remove('active');
          pagodaCategory = 'all';
          filterPagodas();
          return;
        }

        document.querySelectorAll('#page-pagodas .filter-chip').forEach((item) => {
          item.classList.remove('active');
        });
        chip.classList.add('active');
        pagodaCategory = chip.dataset.filter;
        filterPagodas();
      });
    });

    pagodasBound = true;
  }

  loadPagodas();
}

async function loadPagodas() {
  await loadAdminState();
  allPagodas = [...window.adminState.pagodas];

  const activeCount = allPagodas.filter((pagoda) => pagoda.status !== 'archived').length;
  const archivedCount = allPagodas.filter((pagoda) => pagoda.status === 'archived').length;
  const countLabel = document.getElementById('pagodas-count');
  if (countLabel) {
    countLabel.textContent = `${activeCount} live pagodas · ${archivedCount} archived · Firestore-backed catalog`;
  }

  const statusFilter = document.getElementById('pagodas-status-filter');
  if (statusFilter) {
    statusFilter.value = pagodaStatus;
  }

  filterPagodas();
}

function filterPagodas() {
  const query = (document.getElementById('pagodas-search')?.value || '').toLowerCase();
  filteredPagodas = allPagodas.filter((pagoda) => {
    const matchesCategory =
      pagodaCategory === 'all' ||
      (pagoda.category || '').toLowerCase() === pagodaCategory.toLowerCase();
    const matchesStatus =
      pagodaStatus === 'all' ||
      (pagodaStatus === 'archived'
        ? pagoda.status === 'archived'
        : pagoda.status !== 'archived');
    const matchesSearch =
      !query ||
      pagoda.name?.toLowerCase().includes(query) ||
      pagoda.description?.toLowerCase().includes(query) ||
      pagoda.id?.toLowerCase().includes(query);

    return matchesCategory && matchesStatus && matchesSearch;
  });

  pagodasPage = 1;
  renderPagodasTable();
}

function renderPagodasTable() {
  const tbody = document.getElementById('pagodas-table-body');
  if (!tbody) return;

  const start = (pagodasPage - 1) * PAGODAS_PAGE_SIZE;
  const slice = filteredPagodas.slice(start, start + PAGODAS_PAGE_SIZE);
  const totalPages = Math.ceil(filteredPagodas.length / PAGODAS_PAGE_SIZE) || 1;

  const info = document.getElementById('pagodas-pagination-info');
  if (info) {
    info.textContent = filteredPagodas.length
      ? `${start + 1}–${Math.min(start + PAGODAS_PAGE_SIZE, filteredPagodas.length)} of ${filteredPagodas.length}`
      : '0 results';
  }
  renderPagodasPagination(totalPages);

  if (!filteredPagodas.length) {
    tbody.innerHTML = `
      <tr>
        <td colspan="5">
          <div class="empty-state">
            <div class="empty-icon">🏛️</div>
            <p>No pagodas match the current search or filter.</p>
          </div>
        </td>
      </tr>
    `;
    return;
  }

  tbody.innerHTML = slice.map((pagoda) => {
    const archiveLabel = pagoda.status === 'archived' ? 'Restore' : 'Archive';
    const nextStatus = pagoda.status === 'archived' ? 'active' : 'archived';

    return `
      <tr>
        <td>
          <div class="table-primary">${escapeHtml(pagoda.name || pagoda.id)}</div>
          <div class="cell-muted">${escapeHtml(pagoda.id || '—')}</div>
        </td>
        <td>${renderPagodaCategoryBadge(pagoda.category)}</td>
        <td>${renderPagodaStatusBadge(pagoda.status)}</td>
        <td class="cell-nowrap cell-muted">${formatDate(pagoda.updatedAt || pagoda.createdAt)}</td>
        <td>
          <div class="action-row">
            <button class="btn-warning" type="button" onclick="openEditPagodaModal(${JSON.stringify(pagoda.id)})">Edit</button>
            <button class="btn-secondary" type="button" onclick="togglePagodaArchive(${JSON.stringify(pagoda.id)}, ${JSON.stringify(nextStatus)})">${archiveLabel}</button>
          </div>
        </td>
      </tr>
    `;
  }).join('');
}

function renderPagodaCategoryBadge(category) {
  if (category === 'Temple') return '<span class="badge badge-purple">Temple</span>';
  return '<span class="badge badge-gold">Pagoda</span>';
}

function renderPagodaStatusBadge(status) {
  if (status === 'archived') return '<span class="badge badge-gray">Archived</span>';
  return '<span class="badge badge-green">Active</span>';
}

function renderPagodasPagination(totalPages) {
  const container = document.getElementById('pagodas-pagination-controls');
  if (!container) return;

  let html = `<button class="page-btn" onclick="changePagodasPage(${pagodasPage - 1})" ${pagodasPage === 1 ? 'disabled' : ''}>‹</button>`;
  for (let index = 1; index <= totalPages; index += 1) {
    if (index === 1 || index === totalPages || Math.abs(index - pagodasPage) <= 1) {
      html += `<button class="page-btn ${index === pagodasPage ? 'active' : ''}" onclick="changePagodasPage(${index})">${index}</button>`;
    } else if (Math.abs(index - pagodasPage) === 2) {
      html += '<span class="pagination-gap">…</span>';
    }
  }
  html += `<button class="page-btn" onclick="changePagodasPage(${pagodasPage + 1})" ${pagodasPage === totalPages ? 'disabled' : ''}>›</button>`;
  container.innerHTML = html;
}

function changePagodasPage(page) {
  pagodasPage = page;
  renderPagodasTable();
}

function resetPagodaForm() {
  document.getElementById('pagoda-form')?.reset();
  document.getElementById('pagoda-form-id').disabled = false;
  document.getElementById('pagoda-form-category').value = 'Pagoda';
  currentPagodaEditId = null;
  originalPagodaCoordinates = null;
}

function openCreatePagodaModal() {
  resetPagodaForm();
  document.getElementById('pagoda-modal-title').textContent = 'New Pagoda';
  document.getElementById('pagoda-modal-subtitle').textContent =
    'Create a new live catalog entry. It will sync to the mobile app through Firestore.';
  document.getElementById('pagoda-form-submit').textContent = 'Create Pagoda';
  openModal('modal-pagoda-editor');
}

function openEditPagodaModal(id) {
  const pagoda = allPagodas.find((item) => item.id === id);
  if (!pagoda) return;

  resetPagodaForm();
  currentPagodaEditId = pagoda.id;
  originalPagodaCoordinates = {
    latitude: Number(pagoda.latitude || 0),
    longitude: Number(pagoda.longitude || 0),
  };

  document.getElementById('pagoda-modal-title').textContent = `Edit ${pagoda.name || 'Pagoda'}`;
  document.getElementById('pagoda-modal-subtitle').textContent =
    'Update the shared catalog entry. ID is locked after creation to protect trips and routing.';
  document.getElementById('pagoda-form-submit').textContent = 'Save Changes';

  document.getElementById('pagoda-form-id').value = pagoda.id || '';
  document.getElementById('pagoda-form-id').disabled = true;
  document.getElementById('pagoda-form-name').value = pagoda.name || '';
  document.getElementById('pagoda-form-category').value = normalizePagodaCategory(pagoda.category);
  document.getElementById('pagoda-form-year-built').value = pagoda.yearBuilt || '';
  document.getElementById('pagoda-form-latitude').value = pagoda.latitude ?? '';
  document.getElementById('pagoda-form-longitude').value = pagoda.longitude ?? '';
  document.getElementById('pagoda-form-image-url').value = pagoda.imageUrl || '';
  document.getElementById('pagoda-form-height').value = pagoda.height || '';
  document.getElementById('pagoda-form-description').value = pagoda.description || '';
  document.getElementById('pagoda-form-images').value = serializeStringList(pagoda.images);
  document.getElementById('pagoda-form-historical-info').value = pagoda.historicalInfo || '';
  document.getElementById('pagoda-form-architectural-style').value = pagoda.architecturalStyle || '';
  document.getElementById('pagoda-form-legends').value = pagoda.legends || '';
  document.getElementById('pagoda-form-religious-importance').value = pagoda.religiousImportance || '';
  document.getElementById('pagoda-form-preservation-info').value = pagoda.preservationInfo || '';
  document.getElementById('pagoda-form-best-time').value = pagoda.bestTimeToVisit || '';
  document.getElementById('pagoda-form-visitor-location').value = pagoda.visitorLocation || '';
  document.getElementById('pagoda-form-opening-hours').value = pagoda.openingHours || '';
  document.getElementById('pagoda-form-dress-code').value = pagoda.dressCode || '';
  document.getElementById('pagoda-form-entrance-fee').value = pagoda.entranceFee || '';
  document.getElementById('pagoda-form-photography-rules').value = pagoda.photographyRules || '';
  document.getElementById('pagoda-form-final-words').value = pagoda.finalWords || '';
  document.getElementById('pagoda-form-unique-features').value = serializeUniqueFeatures(pagoda.uniqueFeatures);

  openModal('modal-pagoda-editor');
}

function serializeStringList(items) {
  return Array.isArray(items) ? items.join('\n') : '';
}

function serializeUniqueFeatures(features) {
  if (!Array.isArray(features) || !features.length) return '';
  return features.map((feature) => [
    feature.title || '',
    feature.description || '',
    feature.icon || '',
    feature.imageUrl || '',
  ].join(' || ')).join('\n');
}

function parseLineListInput(raw) {
  return String(raw || '')
    .split('\n')
    .map((item) => item.trim())
    .filter(Boolean);
}

function parseUniqueFeaturesInput(raw) {
  return String(raw || '')
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const [title = '', description = '', icon = '', imageUrl = ''] = line
        .split('||')
        .map((part) => part.trim());
      return {
        title,
        description,
        icon,
        imageUrl,
      };
    })
    .filter((feature) => feature.title || feature.description);
}

function buildPagodaPayloadFromForm() {
  const id = String(document.getElementById('pagoda-form-id').value || '').trim();
  const name = String(document.getElementById('pagoda-form-name').value || '').trim();
  const category = normalizePagodaCategory(
    document.getElementById('pagoda-form-category').value,
  );
  const description = String(document.getElementById('pagoda-form-description').value || '').trim();
  const imageUrl = String(document.getElementById('pagoda-form-image-url').value || '').trim();
  const latitude = Number(document.getElementById('pagoda-form-latitude').value);
  const longitude = Number(document.getElementById('pagoda-form-longitude').value);
  const yearBuiltRaw = String(document.getElementById('pagoda-form-year-built').value || '').trim();
  const yearBuilt = yearBuiltRaw ? parseInt(yearBuiltRaw, 10) : null;

  if (!id) {
    throw new Error('Pagoda ID is required.');
  }
  if (!/^[a-z0-9_-]+$/.test(id)) {
    throw new Error('Pagoda ID may only use lowercase letters, numbers, hyphens, and underscores.');
  }
  if (!name) {
    throw new Error('Pagoda name is required.');
  }
  if (!description) {
    throw new Error('Description is required.');
  }
  if (!imageUrl) {
    throw new Error('Image URL is required.');
  }
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    throw new Error('Valid latitude and longitude are required.');
  }
  if (yearBuiltRaw && Number.isNaN(yearBuilt)) {
    throw new Error('Year built must be a valid number.');
  }

  return {
    id,
    name,
    category,
    description,
    latitude,
    longitude,
    imageUrl,
    images: parseLineListInput(document.getElementById('pagoda-form-images').value),
    historicalInfo: String(document.getElementById('pagoda-form-historical-info').value || '').trim(),
    architecturalStyle: String(document.getElementById('pagoda-form-architectural-style').value || '').trim(),
    yearBuilt,
    legends: String(document.getElementById('pagoda-form-legends').value || '').trim(),
    religiousImportance: String(document.getElementById('pagoda-form-religious-importance').value || '').trim(),
    preservationInfo: String(document.getElementById('pagoda-form-preservation-info').value || '').trim(),
    bestTimeToVisit: String(document.getElementById('pagoda-form-best-time').value || '').trim(),
    visitorLocation: String(document.getElementById('pagoda-form-visitor-location').value || '').trim(),
    openingHours: String(document.getElementById('pagoda-form-opening-hours').value || '').trim(),
    dressCode: String(document.getElementById('pagoda-form-dress-code').value || '').trim(),
    entranceFee: String(document.getElementById('pagoda-form-entrance-fee').value || '').trim(),
    photographyRules: String(document.getElementById('pagoda-form-photography-rules').value || '').trim(),
    height: String(document.getElementById('pagoda-form-height').value || '').trim(),
    finalWords: String(document.getElementById('pagoda-form-final-words').value || '').trim(),
    uniqueFeatures: parseUniqueFeaturesInput(document.getElementById('pagoda-form-unique-features').value),
  };
}

async function submitPagodaForm(event) {
  event.preventDefault();

  const submitButton = document.getElementById('pagoda-form-submit');
  if (submitButton) {
    submitButton.disabled = true;
  }

  try {
    const payload = buildPagodaPayloadFromForm();
    const docRef = db.collection(window.adminCollections.pagodas).doc(
      currentPagodaEditId || payload.id,
    );

    const coordinatesChanged = currentPagodaEditId
      ? Number(payload.latitude) !== Number(originalPagodaCoordinates?.latitude || 0) ||
        Number(payload.longitude) !== Number(originalPagodaCoordinates?.longitude || 0)
      : true;

    if (currentPagodaEditId) {
      await docRef.update({
        ...payload,
        id: currentPagodaEditId,
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
      });
      showToast('Pagoda updated successfully.', 'success');
    } else {
      await docRef.set({
        ...payload,
        status: 'active',
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
      });
      showToast('Pagoda created successfully.', 'success');
    }

    if (coordinatesChanged) {
      showToast(
        'If coordinates changed, regenerate assets/data/pagoda_route_graph.json for optimal shortest-path routing.',
        'info',
      );
    }

    closeModal('modal-pagoda-editor');
    await refreshAdminData();
  } catch (error) {
    console.error('Failed to save pagoda:', error);
    showToast(error?.message || 'Failed to save pagoda.', 'error');
  } finally {
    if (submitButton) {
      submitButton.disabled = false;
    }
  }
}

async function togglePagodaArchive(id, nextStatus) {
  const pagoda = allPagodas.find((item) => item.id === id);
  if (!pagoda) return;

  const verb = nextStatus === 'archived' ? 'archive' : 'restore';
  if (!confirm(`Do you want to ${verb} ${pagoda.name || id}?`)) return;

  try {
    await db.collection(window.adminCollections.pagodas).doc(id).update({
      status: nextStatus,
      updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
    });

    showToast(
      nextStatus === 'archived'
        ? 'Pagoda archived. It will disappear from the mobile app catalog after refresh.'
        : 'Pagoda restored to the live catalog.',
      'success',
    );
    await refreshAdminData();
  } catch (error) {
    console.error('Failed to update pagoda status:', error);
    showToast('Failed to update pagoda status.', 'error');
  }
}
