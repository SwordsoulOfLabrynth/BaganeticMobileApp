// ============================================================
// BRANDED CONFIRMATION DIALOG
// ============================================================
// Browser confirm()/prompt() dialogs cannot match the admin console's visual
// system. This shared dialog also makes irreversible actions require a clear,
// deliberate confirmation without leaving the page.

let activeConfirmationResolver = null;

function confirmAdminAction(options = {}) {
  const overlay = document.getElementById('modal-confirmation');
  const eyebrow = document.getElementById('confirmation-eyebrow');
  const title = document.getElementById('confirmation-title');
  const message = document.getElementById('confirmation-message');
  const icon = document.getElementById('confirmation-icon');
  const tokenWrap = document.getElementById('confirmation-token-wrap');
  const tokenInput = document.getElementById('confirmation-token-input');
  const cancelButton = document.getElementById('confirmation-cancel');
  const submitButton = document.getElementById('confirmation-submit');

  if (!overlay || !title || !message || !tokenWrap || !tokenInput || !cancelButton || !submitButton) {
    console.error('Confirmation dialog markup is unavailable.');
    return Promise.resolve(false);
  }

  if (activeConfirmationResolver) {
    activeConfirmationResolver(false);
    activeConfirmationResolver = null;
  }

  const {
    title: dialogTitle = 'Are you sure?',
    message: dialogMessage = 'Please confirm this action.',
    eyebrowText = 'Confirm action',
    confirmLabel = 'Confirm',
    tone = 'warning',
    requireText = false,
    requiredText = 'DELETE',
  } = options;

  const complete = (confirmed) => {
    if (!activeConfirmationResolver) return;
    const resolve = activeConfirmationResolver;
    activeConfirmationResolver = null;
    overlay.classList.remove('open');
    overlay.setAttribute('aria-hidden', 'true');
    tokenInput.value = '';
    resolve(Boolean(confirmed));
  };

  eyebrow.textContent = eyebrowText;
  title.textContent = dialogTitle;
  message.textContent = dialogMessage;
  icon.textContent = tone === 'danger' ? '!' : '?';
  icon.dataset.tone = tone;
  tokenWrap.hidden = !requireText;
  tokenInput.value = '';
  submitButton.textContent = confirmLabel;
  submitButton.className = tone === 'danger' ? 'btn-danger' : tone === 'success' ? 'btn-success' : 'btn-warning';
  submitButton.disabled = requireText;

  const updateSubmitState = () => {
    if (requireText) {
      submitButton.disabled = tokenInput.value.trim().toUpperCase() !== String(requiredText).toUpperCase();
    }
  };

  tokenInput.oninput = updateSubmitState;
  cancelButton.onclick = () => complete(false);
  submitButton.onclick = () => {
    if (!submitButton.disabled) complete(true);
  };
  overlay.onclick = (event) => {
    if (event.target === overlay) {
      event.stopPropagation();
      complete(false);
    }
  };

  overlay.classList.add('open');
  overlay.setAttribute('aria-hidden', 'false');

  requestAnimationFrame(() => {
    (requireText ? tokenInput : submitButton).focus();
  });

  return new Promise((resolve) => {
    activeConfirmationResolver = resolve;
  });
}

document.addEventListener('keydown', (event) => {
  if (event.key !== 'Escape' || !activeConfirmationResolver) return;
  const overlay = document.getElementById('modal-confirmation');
  overlay?.classList.remove('open');
  overlay?.setAttribute('aria-hidden', 'true');
  const resolve = activeConfirmationResolver;
  activeConfirmationResolver = null;
  resolve(false);
});

window.confirmAdminAction = confirmAdminAction;
