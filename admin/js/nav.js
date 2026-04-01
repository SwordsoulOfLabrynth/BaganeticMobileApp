// ============================================================
// NAVIGATION MODULE
// ============================================================
document.addEventListener('DOMContentLoaded', () => {
  const navLinks = document.querySelectorAll('.nav-link[data-page]');
  navLinks.forEach((link) => {
    link.addEventListener('click', () => {
      navigateTo(link.dataset.page);
    });
  });
});

function navigateTo(pageId) {
  document.querySelectorAll('.nav-link[data-page]').forEach((link) => {
    link.classList.toggle('active', link.dataset.page === pageId);
  });

  document.querySelectorAll('.page').forEach((page) => {
    page.classList.toggle('active', page.id === `page-${pageId}`);
  });

  const titles = {
    dashboard: '📊 Dashboard',
    pagodas: '🏛️ Pagodas',
    users: '👥 Users',
    trips: '🗺️ Trips',
    community: '💬 Community',
  };

  const title = document.getElementById('page-title');
  if (title) {
    title.textContent = titles[pageId] || pageId;
  }

  window.scrollTo({ top: 0, behavior: 'smooth' });
}
