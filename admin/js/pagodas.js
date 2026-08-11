// ============================================================
// PAGODAS MODULE
// ============================================================
let allPagodas = [];
let filteredPagodas = [];
let pagodasPage = 1;
const PAGODAS_PAGE_SIZE = 12;
let pagodaStatus = 'active';
let pagodaQuality = 'all';
let pagodasBound = false;
let currentPagodaEditId = null;
let pendingPagodaUploads = 0;
const PAGODA_ALLOWED_IMAGE_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.webp'];
const PAGODA_MAX_UPLOAD_BYTES = 8 * 1024 * 1024;
const PAGODA_UPLOAD_TIMEOUT_MS = 45000;

function initPagodas() {
  if (!pagodasBound) {
    document.getElementById('pagodas-search')?.addEventListener('input', filterPagodas);
    document.getElementById('pagodas-status-filter')?.addEventListener('change', (event) => {
      pagodaStatus = event.target.value;
      filterPagodas();
    });
    document.getElementById('pagodas-quality-filter')?.addEventListener('change', (event) => {
      pagodaQuality = event.target.value;
      filterPagodas();
    });
    document.getElementById('btn-new-pagoda')?.addEventListener('click', () => openCreatePagodaModal());
    document.getElementById('btn-download-pagoda-json')?.addEventListener('click', downloadPagodaJsonTemplate);
    document.getElementById('btn-import-pagoda-json')?.addEventListener('click', openPagodaJsonPicker);
    document.getElementById('pagoda-json-file-input')?.addEventListener('change', handlePagodaJsonImport);
    document.getElementById('btn-open-pagoda-editor')?.addEventListener('click', () => openCreatePagodaModal());
    document.getElementById('btn-export-current-pagoda-json')?.addEventListener('click', downloadCurrentPagodaJson);
    document.getElementById('pagoda-form')?.addEventListener('submit', submitPagodaForm);
    document.getElementById('pagoda-form-primary-image-file')?.addEventListener('change', handlePrimaryImageFileChange);
    document.getElementById('pagoda-form-gallery-image-files')?.addEventListener('change', handleGalleryImageFilesChange);

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

  const qualityFilter = document.getElementById('pagodas-quality-filter');
  if (qualityFilter) {
    qualityFilter.value = pagodaQuality;
  }

  renderPagodaContentHealth(allPagodas);
  filterPagodas();
}

function filterPagodas() {
  const query = (document.getElementById('pagodas-search')?.value || '').toLowerCase();
  filteredPagodas = allPagodas.filter((pagoda) => {
    const matchesStatus =
      pagodaStatus === 'all' ||
      (pagodaStatus === 'archived'
        ? pagoda.status === 'archived'
        : pagoda.status !== 'archived');
    const issues = getPagodaContentIssues(pagoda);
    const matchesQuality =
      pagodaQuality === 'all' ||
      (pagodaQuality === 'ready' && issues.length === 0) ||
      (pagodaQuality === 'missing-myanmar' && issues.includes('Myanmar copy')) ||
      (pagodaQuality === 'missing-history' && issues.includes('History')) ||
      (pagodaQuality === 'missing-gallery' && issues.includes('Gallery'));
    const matchesSearch =
      !query ||
      pagoda.name?.toLowerCase().includes(query) ||
      pagoda.description?.toLowerCase().includes(query) ||
      pagoda.id?.toLowerCase().includes(query);

    return matchesStatus && matchesQuality && matchesSearch;
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
        <td colspan="4">
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
          ${renderPagodaContentReadiness(pagoda)}
        </td>
        <td>${renderPagodaStatusBadge(pagoda.status)}</td>
        <td class="cell-nowrap cell-muted">${formatDate(pagoda.updatedAt || pagoda.createdAt)}</td>
        <td>
          <div class="action-row">
            <button class="btn-warning" type="button" onclick='openEditPagodaModal(${serializeForInlineHandler(pagoda.id)})'>Edit</button>
            <button class="btn-secondary" type="button" onclick='togglePagodaArchive(${serializeForInlineHandler(pagoda.id)}, ${serializeForInlineHandler(nextStatus)})'>${archiveLabel}</button>
          </div>
        </td>
      </tr>
    `;
  }).join('');
}

function getPagodaContentIssues(pagoda) {
  const issues = [];
  if (!String(pagoda?.nameMyanmar || '').trim() || !String(pagoda?.descriptionMyanmar || '').trim()) {
    issues.push('Myanmar copy');
  }
  if (!String(pagoda?.historicalInfo || '').trim()) issues.push('History');
  if (!Array.isArray(pagoda?.images) || pagoda.images.length === 0) issues.push('Gallery');
  return issues;
}

function renderPagodaContentReadiness(pagoda) {
  const issues = getPagodaContentIssues(pagoda);
  if (!issues.length) {
    return '<span class="content-readiness">Content ready</span>';
  }
  return `<span class="content-readiness needs-review">Needs: ${escapeHtml(issues.join(', '))}</span>`;
}

function renderPagodaContentHealth(pagodas) {
  const card = document.getElementById('pagoda-health-card');
  if (!card) return;

  const active = pagodas.filter((pagoda) => pagoda.status !== 'archived');
  const missingMyanmar = active.filter((pagoda) => getPagodaContentIssues(pagoda).includes('Myanmar copy')).length;
  const missingHistory = active.filter((pagoda) => getPagodaContentIssues(pagoda).includes('History')).length;
  const missingGallery = active.filter((pagoda) => getPagodaContentIssues(pagoda).includes('Gallery')).length;
  const ready = active.filter((pagoda) => getPagodaContentIssues(pagoda).length === 0).length;

  card.innerHTML = `
    <div>
      <div class="content-health-title">Content readiness</div>
      <div class="content-health-copy">Review live catalog overrides before publishing. When these Myanmar fields are blank, the app continues using its bundled reviewed translation.</div>
    </div>
    <div class="content-health-stats">
      <span class="content-health-stat"><strong>${ready}</strong> ready</span>
      <span class="content-health-stat"><strong>${missingMyanmar}</strong> need Myanmar</span>
      <span class="content-health-stat"><strong>${missingHistory}</strong> need history</span>
      <span class="content-health-stat"><strong>${missingGallery}</strong> need gallery</span>
    </div>
  `;
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
  currentPagodaEditId = null;
  pendingPagodaUploads = 0;
  resetPagodaUploadInputs();
  syncCurrentFormImagesToPreview();
  syncPagodaSubmitState();
}

function openCreatePagodaModal(initialValues = null) {
  resetPagodaForm();
  document.getElementById('pagoda-modal-title').textContent = 'New Pagoda';
  document.getElementById('pagoda-modal-subtitle').textContent =
    initialValues
      ? 'Review the imported JSON, choose image files if needed, then save the pagoda.'
      : 'Create a new catalog entry directly here, or start from the JSON template above.';
  document.getElementById('pagoda-form-submit').textContent = 'Create Pagoda';
  document.getElementById('pagoda-form-submit').dataset.defaultLabel = 'Create Pagoda';

  if (initialValues) {
    populatePagodaForm(initialValues);
  }

  syncPagodaSubmitState();
  openModal('modal-pagoda-editor');
}

function openEditPagodaModal(id) {
  const pagoda = allPagodas.find((item) => item.id === id);
  if (!pagoda) return;

  resetPagodaForm();
  currentPagodaEditId = pagoda.id;

  document.getElementById('pagoda-modal-title').textContent = `Edit ${pagoda.name || 'Pagoda'}`;
  document.getElementById('pagoda-modal-subtitle').textContent =
    'Update the shared catalog entry. The ID stays locked after creation, but text and images can be changed here.';
  document.getElementById('pagoda-form-submit').textContent = 'Save Changes';
  document.getElementById('pagoda-form-submit').dataset.defaultLabel = 'Save Changes';

  populatePagodaForm(pagoda);
  document.getElementById('pagoda-form-id').disabled = true;

  syncPagodaSubmitState();
  openModal('modal-pagoda-editor');
}

function populatePagodaForm(pagoda = {}) {
  document.getElementById('pagoda-form-id').value = pagoda.id || '';
  document.getElementById('pagoda-form-name').value = pagoda.name || '';
  document.getElementById('pagoda-form-name-myanmar').value = pagoda.nameMyanmar || '';
  document.getElementById('pagoda-form-year-built').value = pagoda.yearBuilt ?? '';
  document.getElementById('pagoda-form-latitude').value = pagoda.latitude ?? '';
  document.getElementById('pagoda-form-longitude').value = pagoda.longitude ?? '';
  document.getElementById('pagoda-form-image-url').value = pagoda.imageUrl || '';
  document.getElementById('pagoda-form-height').value = pagoda.height || '';
  document.getElementById('pagoda-form-description').value = pagoda.description || '';
  document.getElementById('pagoda-form-description-myanmar').value = pagoda.descriptionMyanmar || '';
  document.getElementById('pagoda-form-images').value = serializeStringList(normalizeStringArray(pagoda.images));
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
  document.getElementById('pagoda-form-unique-features').value = serializeUniqueFeatures(
    normalizeUniqueFeaturesList(pagoda.uniqueFeatures),
  );
  resetPagodaUploadInputs();
  syncCurrentFormImagesToPreview();
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
  ].join(' | ')).join('\n');
}

function parseLineListInput(raw) {
  return String(raw || '')
    .split('\n')
    .map((item) => item.trim())
    .filter(Boolean);
}

function parseUniqueFeatureLine(line) {
  const separator = line.includes('||') ? '||' : '|';
  const [title = '', description = '', icon = '', imageUrl = ''] = line
    .split(separator)
    .map((part) => part.trim());
  return {
    title,
    description,
    icon,
    imageUrl,
  };
}

function parseUniqueFeaturesInput(raw) {
  return String(raw || '')
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => parseUniqueFeatureLine(line))
    .filter((feature) => feature.title || feature.description);
}

function normalizeStringArray(value) {
  if (Array.isArray(value)) {
    return value
      .map((item) => String(item || '').trim())
      .filter(Boolean);
  }
  return parseLineListInput(value);
}

function normalizeUniqueFeaturesList(value) {
  if (Array.isArray(value)) {
    return value
      .map((feature) => ({
        title: String(feature?.title || '').trim(),
        description: String(feature?.description || '').trim(),
        icon: String(feature?.icon || '').trim(),
        imageUrl: String(feature?.imageUrl || '').trim(),
      }))
      .filter((feature) => feature.title || feature.description || feature.icon || feature.imageUrl);
  }
  return parseUniqueFeaturesInput(value);
}

function buildPagodaPayloadFromForm() {
  const id = String(document.getElementById('pagoda-form-id').value || '').trim();
  const name = String(document.getElementById('pagoda-form-name').value || '').trim();
  const nameMyanmar = String(document.getElementById('pagoda-form-name-myanmar').value || '').trim();
  const existingPagoda = currentPagodaEditId
    ? allPagodas.find((pagoda) => pagoda.id === currentPagodaEditId)
    : null;
  // The mobile app presents one shared site list. Keep old category data only
  // for compatibility with already-synced records; new entries use Pagoda.
  const category = existingPagoda?.category || 'Pagoda';
  const description = String(document.getElementById('pagoda-form-description').value || '').trim();
  const descriptionMyanmar = String(document.getElementById('pagoda-form-description-myanmar').value || '').trim();
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
  if ((nameMyanmar || descriptionMyanmar) && !/[\u1000-\u109f]/.test(`${nameMyanmar} ${descriptionMyanmar}`)) {
    throw new Error('Myanmar content must contain Burmese script, or be left blank for the reviewed fallback translation.');
  }
  if (!imageUrl) {
    throw new Error('Primary image is required.');
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
    nameMyanmar,
    category,
    description,
    descriptionMyanmar,
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

function slugifyPagodaValue(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function resetPagodaUploadInputs() {
  const primaryInput = document.getElementById('pagoda-form-primary-image-file');
  const galleryInput = document.getElementById('pagoda-form-gallery-image-files');
  if (primaryInput) primaryInput.value = '';
  if (galleryInput) galleryInput.value = '';
}

function getPagodaFieldValue(fieldId) {
  return String(document.getElementById(fieldId)?.value || '').trim();
}

function syncPagodaSubmitState() {
  const submitButton = document.getElementById('pagoda-form-submit');
  if (!submitButton) return;

  const defaultLabel = submitButton.dataset.defaultLabel || submitButton.textContent || 'Save';
  if (pendingPagodaUploads > 0) {
    submitButton.disabled = true;
    submitButton.textContent = pendingPagodaUploads === 1
      ? 'Uploading Image...'
      : 'Uploading Images...';
    return;
  }

  submitButton.disabled = false;
  submitButton.textContent = defaultLabel;
}

function beginPagodaUpload() {
  pendingPagodaUploads += 1;
  syncPagodaSubmitState();
}

function finishPagodaUpload() {
  pendingPagodaUploads = Math.max(0, pendingPagodaUploads - 1);
  syncPagodaSubmitState();
}

function parseOptionalJsonNumber(raw) {
  const value = String(raw || '').trim();
  if (!value) return '';
  const numericValue = Number(value);
  return Number.isFinite(numericValue) ? numericValue : value;
}

function parseOptionalJsonInteger(raw) {
  const value = String(raw || '').trim();
  if (!value) return '';
  const numericValue = parseInt(value, 10);
  return Number.isNaN(numericValue) ? value : numericValue;
}

function getPagodaDraftSnapshot() {
  return {
    id: getPagodaFieldValue('pagoda-form-id'),
    name: getPagodaFieldValue('pagoda-form-name'),
    nameMyanmar: getPagodaFieldValue('pagoda-form-name-myanmar'),
    yearBuilt: parseOptionalJsonInteger(getPagodaFieldValue('pagoda-form-year-built')),
    latitude: parseOptionalJsonNumber(getPagodaFieldValue('pagoda-form-latitude')),
    longitude: parseOptionalJsonNumber(getPagodaFieldValue('pagoda-form-longitude')),
    height: getPagodaFieldValue('pagoda-form-height'),
    description: getPagodaFieldValue('pagoda-form-description'),
    descriptionMyanmar: getPagodaFieldValue('pagoda-form-description-myanmar'),
    imageUrl: getPagodaFieldValue('pagoda-form-image-url'),
    images: parseLineListInput(document.getElementById('pagoda-form-images')?.value || ''),
    historicalInfo: getPagodaFieldValue('pagoda-form-historical-info'),
    architecturalStyle: getPagodaFieldValue('pagoda-form-architectural-style'),
    legends: getPagodaFieldValue('pagoda-form-legends'),
    religiousImportance: getPagodaFieldValue('pagoda-form-religious-importance'),
    preservationInfo: getPagodaFieldValue('pagoda-form-preservation-info'),
    bestTimeToVisit: getPagodaFieldValue('pagoda-form-best-time'),
    visitorLocation: getPagodaFieldValue('pagoda-form-visitor-location'),
    openingHours: getPagodaFieldValue('pagoda-form-opening-hours'),
    dressCode: getPagodaFieldValue('pagoda-form-dress-code'),
    entranceFee: getPagodaFieldValue('pagoda-form-entrance-fee'),
    photographyRules: getPagodaFieldValue('pagoda-form-photography-rules'),
    finalWords: getPagodaFieldValue('pagoda-form-final-words'),
    uniqueFeatures: normalizeUniqueFeaturesList(
      document.getElementById('pagoda-form-unique-features')?.value || '',
    ),
  };
}

function buildPagodaJsonTemplate() {
  return {
    id: '',
    name: '',
    nameMyanmar: '',
    yearBuilt: '',
    latitude: '',
    longitude: '',
    height: '',
    description: '',
    descriptionMyanmar: '',
    historicalInfo: '',
    architecturalStyle: '',
    legends: '',
    religiousImportance: '',
    preservationInfo: '',
    bestTimeToVisit: '',
    visitorLocation: '',
    openingHours: '',
    dressCode: '',
    entranceFee: '',
    photographyRules: '',
    finalWords: '',
    uniqueFeatures: [
      {
        title: '',
        description: '',
        icon: '',
        imageUrl: '',
      },
    ],
  };
}

function downloadJsonFile(fileName, data) {
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
  const downloadUrl = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = downloadUrl;
  link.download = fileName;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(downloadUrl);
}

function downloadPagodaJsonTemplate() {
  downloadJsonFile('pagoda-template.json', buildPagodaJsonTemplate());
}

function openPagodaJsonPicker() {
  const input = document.getElementById('pagoda-json-file-input');
  if (!input) return;
  input.value = '';
  input.click();
}

function downloadCurrentPagodaJson() {
  const snapshot = getPagodaDraftSnapshot();
  const fileBase = snapshot.id || slugifyPagodaValue(snapshot.name) || 'pagoda-draft';
  downloadJsonFile(`${fileBase}.json`, snapshot);
}

function normalizeImportedPagoda(raw) {
  const source = Array.isArray(raw) ? raw[0] : raw?.pagoda || raw;
  if (!source || typeof source !== 'object') {
    throw new Error('The JSON file must contain one pagoda object.');
  }

  return {
    id: String(source.id || '').trim(),
    name: String(source.name || '').trim(),
    nameMyanmar: String(source.nameMyanmar || '').trim(),
    yearBuilt: source.yearBuilt ?? '',
    latitude: source.latitude ?? '',
    longitude: source.longitude ?? '',
    height: String(source.height || '').trim(),
    description: String(source.description || '').trim(),
    descriptionMyanmar: String(source.descriptionMyanmar || '').trim(),
    imageUrl: String(source.imageUrl || '').trim(),
    images: normalizeStringArray(source.images),
    historicalInfo: String(source.historicalInfo || '').trim(),
    architecturalStyle: String(source.architecturalStyle || '').trim(),
    legends: String(source.legends || '').trim(),
    religiousImportance: String(source.religiousImportance || '').trim(),
    preservationInfo: String(source.preservationInfo || '').trim(),
    bestTimeToVisit: String(source.bestTimeToVisit || '').trim(),
    visitorLocation: String(source.visitorLocation || '').trim(),
    openingHours: String(source.openingHours || '').trim(),
    dressCode: String(source.dressCode || '').trim(),
    entranceFee: String(source.entranceFee || '').trim(),
    photographyRules: String(source.photographyRules || '').trim(),
    finalWords: String(source.finalWords || '').trim(),
    uniqueFeatures: normalizeUniqueFeaturesList(source.uniqueFeatures),
  };
}

async function handlePagodaJsonImport(event) {
  const input = event.target;
  const file = input?.files?.[0];
  if (!file) return;

  try {
    const parsed = JSON.parse(await file.text());
    const pagoda = normalizeImportedPagoda(parsed);
    openCreatePagodaModal(pagoda);
    showToast('JSON imported. Review the form and upload images before saving.', 'success');
  } catch (error) {
    console.error('Failed to import pagoda JSON:', error);
    showToast(error?.message || 'Failed to import pagoda JSON.', 'error');
  } finally {
    input.value = '';
  }
}

function extractFileName(value) {
  const cleanValue = String(value || '').split('?')[0];
  return cleanValue.split('/').pop() || 'image';
}

function resolvePagodaPreviewSrc(value) {
  const normalized = String(value || '').trim();
  if (!normalized) return '';
  if (/^(https?:|data:|blob:)/i.test(normalized)) {
    return normalized;
  }
  if (normalized.startsWith('/')) {
    return normalized;
  }
  if (normalized.startsWith('assets/')) {
    return `/${normalized}`;
  }
  return normalized;
}

function getFileExtension(fileName) {
  const extensionMatch = String(fileName || '').match(/(\.[^.]+)$/);
  return extensionMatch ? extensionMatch[1].toLowerCase() : '.jpg';
}

function isSupportedPagodaImageFile(file) {
  return PAGODA_ALLOWED_IMAGE_EXTENSIONS.includes(getFileExtension(file?.name || '')) &&
    Number(file?.size || 0) <= PAGODA_MAX_UPLOAD_BYTES;
}

function describeSupportedPagodaFormats() {
  return 'JPG, JPEG, PNG, or WEBP (up to 8 MB each)';
}

function withTimeout(promise, timeoutMs, timeoutMessage) {
  let timeoutId;
  return Promise.race([
    promise,
    new Promise((_, reject) => {
      timeoutId = setTimeout(() => reject(new Error(timeoutMessage)), timeoutMs);
    }),
  ]).finally(() => {
    clearTimeout(timeoutId);
  });
}

function getPagodaUploadFolderName() {
  const name = getPagodaFieldValue('pagoda-form-name');
  const id = getPagodaFieldValue('pagoda-form-id');
  const folderName = name || id;
  if (!folderName) {
    throw new Error('Enter the pagoda name or ID before choosing images.');
  }
  return folderName;
}

function mergeUniqueStrings(existingValues, nextValues) {
  const merged = Array.isArray(existingValues) ? [...existingValues] : [];
  (nextValues || []).forEach((value) => {
    if (value && !merged.includes(value)) {
      merged.push(value);
    }
  });
  return merged;
}

async function uploadPagodaFiles(files, subfolder) {
  const fileList = Array.from(files || []).filter(Boolean);
  if (!fileList.length) return [];

  const oversized = fileList.find((file) => Number(file.size || 0) > PAGODA_MAX_UPLOAD_BYTES);
  if (oversized) {
    throw new Error(`${oversized.name} is larger than the 8 MB upload limit.`);
  }

  const formData = new FormData();
  formData.append('pagodaFolder', getPagodaUploadFolderName());
  formData.append('role', subfolder);
  fileList.forEach((file) => {
    formData.append('files', file, file.name);
  });

  const response = await withTimeout(
    fetch('/admin/upload-pagoda-images', {
      method: 'POST',
      body: formData,
    }),
    PAGODA_UPLOAD_TIMEOUT_MS,
    'Image upload timed out. Restart the local admin server and try again.',
  );

  let payload = null;
  try {
    payload = await response.json();
  } catch (error) {
    payload = null;
  }

  if (!response.ok) {
    throw new Error(payload?.error || 'Image upload failed on the local admin server.');
  }

  return Array.isArray(payload?.files) ? payload.files : [];
}

async function handlePrimaryImageFileChange(event) {
  const input = event.target;
  const file = input?.files?.[0];
  if (!file) return;

  if (!isSupportedPagodaImageFile(file)) {
    showToast(`Primary image must be ${describeSupportedPagodaFormats()}. HEIC is not supported here.`, 'error');
    input.value = '';
    return;
  }

  beginPagodaUpload();
  input.disabled = true;

  try {
    const [uploadedImage] = await uploadPagodaFiles([file], 'primary');
    document.getElementById('pagoda-form-image-url').value = uploadedImage?.url || '';
    syncCurrentFormImagesToPreview();
    showToast('Primary image uploaded.', 'success');
  } catch (error) {
    console.error('Failed to upload primary pagoda image:', error);
    showToast(error?.message || 'Primary image upload failed.', 'error');
  } finally {
    input.value = '';
    input.disabled = false;
    finishPagodaUpload();
  }
}

async function handleGalleryImageFilesChange(event) {
  const input = event.target;
  const files = Array.from(input?.files || []);
  if (!files.length) return;

  const unsupportedFiles = files.filter((file) => !isSupportedPagodaImageFile(file));
  if (unsupportedFiles.length) {
    showToast(`Gallery images must be ${describeSupportedPagodaFormats()}. HEIC is not supported here.`, 'error');
    input.value = '';
    return;
  }

  beginPagodaUpload();
  input.disabled = true;

  try {
    const uploadedImages = await uploadPagodaFiles(files, 'gallery');
    const currentImages = parseLineListInput(document.getElementById('pagoda-form-images')?.value || '');
    const nextImages = mergeUniqueStrings(
      currentImages,
      uploadedImages.map((item) => item.url),
    );
    document.getElementById('pagoda-form-images').value = serializeStringList(nextImages);
    syncCurrentFormImagesToPreview();
    showToast(
      `${uploadedImages.length} gallery image${uploadedImages.length === 1 ? '' : 's'} uploaded.`,
      'success',
    );
  } catch (error) {
    console.error('Failed to upload gallery pagoda images:', error);
    showToast(error?.message || 'Gallery image upload failed.', 'error');
  } finally {
    input.value = '';
    input.disabled = false;
    finishPagodaUpload();
  }
}

function syncCurrentFormImagesToPreview() {
  const previewContainer = document.getElementById('pagoda-form-image-preview');
  if (!previewContainer) return;

  const primaryImageUrl = getPagodaFieldValue('pagoda-form-image-url');
  const galleryImages = parseLineListInput(document.getElementById('pagoda-form-images')?.value || '');
  const previewItems = [];

  if (primaryImageUrl) {
    previewItems.push({
      url: primaryImageUrl,
      role: 'Primary',
      action: '<button class="image-preview-remove" type="button" onclick="clearPagodaPrimaryImage()">Remove</button>',
    });
  }

  galleryImages.forEach((url, index) => {
    previewItems.push({
      url,
      role: `Gallery ${index + 1}`,
      action: `<button class="image-preview-remove" type="button" onclick='removePagodaGalleryImage(${serializeForInlineHandler(url)})'>Remove</button>`,
    });
  });

  if (!previewItems.length) {
    previewContainer.innerHTML = `
      <div class="empty-state compact">
        <div class="empty-icon">🖼️</div>
        <p>No images assigned yet.</p>
      </div>
    `;
    return;
  }

  previewContainer.innerHTML = previewItems.map((item) => `
    <div class="image-preview-card">
      <img class="image-preview-thumb" src="${escapeHtml(resolvePagodaPreviewSrc(item.url))}" alt="${escapeHtml(item.role)}" />
      <div class="image-preview-meta">
        <div class="image-preview-role">${escapeHtml(item.role)}</div>
        <div class="image-preview-caption">${escapeHtml(extractFileName(item.url))}</div>
        <div class="image-preview-actions">${item.action}</div>
      </div>
    </div>
  `).join('');
}

function clearPagodaPrimaryImage() {
  const primaryImageField = document.getElementById('pagoda-form-image-url');
  if (!primaryImageField) return;
  primaryImageField.value = '';
  syncCurrentFormImagesToPreview();
}

function removePagodaGalleryImage(url) {
  const galleryField = document.getElementById('pagoda-form-images');
  if (!galleryField) return;

  galleryField.value = serializeStringList(
    parseLineListInput(galleryField.value).filter((item) => item !== url),
  );
  syncCurrentFormImagesToPreview();
}

async function submitPagodaForm(event) {
  event.preventDefault();

  const submitButton = document.getElementById('pagoda-form-submit');
  const shouldRestoreSubmitState = pendingPagodaUploads === 0;
  if (pendingPagodaUploads > 0) {
    showToast('Images are still uploading. Wait until the upload finishes.', 'info');
    return;
  }
  if (submitButton) {
    submitButton.disabled = true;
  }

  try {
    const payload = buildPagodaPayloadFromForm();
    const documentId = currentPagodaEditId || payload.id;
    const documentPath = buildAdminDocumentPath(window.adminCollections.pagodas, documentId);

    if (currentPagodaEditId) {
      const now = createAdminRestTimestamp();
      await runAdminWriteOperation({
        action: 'pagoda update',
        sdkWrite: () =>
          db.collection(window.adminCollections.pagodas).doc(documentId).update({
            ...payload,
            id: currentPagodaEditId,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
          }),
        restWrite: () =>
          window.adminFirestoreRest.patchDocument(documentPath, {
            ...payload,
            id: currentPagodaEditId,
            updatedAt: now,
          }),
      });
      showToast('Pagoda updated successfully.', 'success');
    } else {
      const now = createAdminRestTimestamp();
      await runAdminWriteOperation({
        action: 'pagoda create',
        sdkWrite: () =>
          db.collection(window.adminCollections.pagodas).doc(documentId).set({
            ...payload,
            status: 'active',
            createdAt: firebase.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
          }),
        restWrite: () =>
          window.adminFirestoreRest.setDocument(documentPath, {
            ...payload,
            status: 'active',
            createdAt: now,
            updatedAt: now,
          }),
      });
      showToast('Pagoda created successfully.', 'success');
    }

    closeModal('modal-pagoda-editor');
    await refreshAdminData();
  } catch (error) {
    console.error('Failed to save pagoda:', error);
    showToast(error?.message || 'Failed to save pagoda.', 'error');
  } finally {
    if (submitButton && shouldRestoreSubmitState) {
      syncPagodaSubmitState();
    }
  }
}

async function togglePagodaArchive(id, nextStatus) {
  const pagoda = allPagodas.find((item) => item.id === id);
  if (!pagoda) return;

  const verb = nextStatus === 'archived' ? 'archive' : 'restore';
  if (!(await confirmAdminAction({
    title: nextStatus === 'archived' ? 'Archive this site?' : 'Restore this site?',
    message: nextStatus === 'archived'
      ? `${pagoda.name || id} will be hidden from the live mobile catalog.`
      : `${pagoda.name || id} will be visible in the live mobile catalog again.`,
    eyebrowText: nextStatus === 'archived' ? 'Catalog visibility' : 'Restore catalog entry',
    confirmLabel: nextStatus === 'archived' ? 'Archive site' : 'Restore site',
    tone: nextStatus === 'archived' ? 'warning' : 'success',
  }))) return;

  try {
    const documentPath = buildAdminDocumentPath(window.adminCollections.pagodas, id);
    const now = createAdminRestTimestamp();
    await runAdminWriteOperation({
      action: 'pagoda archive update',
      sdkWrite: () =>
        db.collection(window.adminCollections.pagodas).doc(id).update({
          status: nextStatus,
          updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }),
      restWrite: () =>
        window.adminFirestoreRest.patchDocument(documentPath, {
          status: nextStatus,
          updatedAt: now,
        }),
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
