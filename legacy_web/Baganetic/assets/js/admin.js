/**
 * Baganetic Admin Dashboard JavaScript
 * Handles all admin interface functionality
 */

class AdminDashboard {
    constructor() {
        this.apiBase = 'http://localhost:5002/admin';
        this.currentSection = 'dashboard';
        this.currentPagoda = null;
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.checkAuthStatus();
        // Start session watchdog to auto-redirect to login on timeout
        this.startSessionWatchdog();
    }

    setupEventListeners() {
        // Login form
        document.getElementById('loginForm').addEventListener('submit', (e) => {
            e.preventDefault();
            this.login();
        });

        // Logout button
        window.logout = () => this.logout();

        // Section navigation
        window.showSection = (section) => this.showSection(section);

        // Dashboard refresh
        window.refreshDashboard = () => this.refreshDashboard();

        // Pagoda management
        window.showCreatePagodaModal = () => this.showCreatePagodaModal();
        window.savePagoda = () => this.savePagoda();
        window.editPagoda = (id) => this.editPagoda(id);
        window.deletePagoda = (id) => this.deletePagoda(id);

        // User management
        window.refreshUsers = () => this.refreshUsers();
        window.deleteUser = (id) => this.deleteUser(id);
        window.verifyUser = (id) => this.verifyUser(id);
        window.unverifyUser = (id) => this.unverifyUser(id);

        // System management
        window.refreshSystemHealth = () => this.refreshSystemHealth();
        window.restartService = (service) => this.restartService(service);

        // Logs
        window.refreshLogs = () => this.refreshLogs();
    }

    async checkAuthStatus() {
        try {
            const response = await fetch(`${this.apiBase}/status`, {
                credentials: 'include',
            });
            if (response.ok) {
                const data = await response.json();
                if (data.success && data.authenticated) {
                    this.showDashboard(data.username);
                    // Update next expiry checkpoint if provided
                    if (data.session_expires) {
                        this._adminSessionExpiresAt = new Date(data.session_expires).getTime();
                    }
                } else {
                    // Session ended -> show login screen instead of reloading
                    this.showLogin();
                }
            } else {
                // Session ended or server unreachable -> show login screen
                this.showLogin();
            }
        } catch (error) {
            console.error('Auth check failed:', error);
            // Network error -> show login screen instead of reloading
            this.showLogin();
        }
    }

    startSessionWatchdog() {
        // Avoid multiple intervals
        if (this._sessionWatchdogInterval) return;
        // Check every 30 seconds (less aggressive)
        this._sessionWatchdogInterval = setInterval(async () => {
            // Don't check if already on login screen
            if (document.getElementById('loginScreen').classList.contains('hidden') === false) {
                return;
            }
            
            try {
                const response = await fetch(`${this.apiBase}/status`, { cache: 'no-store', credentials: 'include' });
                if (!response.ok) {
                    // Session ended -> show login screen
                    this.showLogin();
                    return;
                }
                const data = await response.json();
                if (!data.success || !data.authenticated) {
                    // Session ended -> show login screen
                    this.showLogin();
                    return;
                }
                if (data.session_expires) {
                    this._adminSessionExpiresAt = new Date(data.session_expires).getTime();
                }
            } catch (e) {
                // Network error: show login screen instead of reloading
                console.warn('Session watchdog network error:', e);
                this.showLogin();
            }
        }, 30000);
    }

    async login() {
        const username = document.getElementById('username').value;
        const password = document.getElementById('password').value;
        const alertDiv = document.getElementById('loginAlert');

        try {
            const response = await fetch(`${this.apiBase}/login`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                credentials: 'include',
                body: JSON.stringify({ username, password })
            });

            const data = await response.json();

            if (data.success) {
                this.showDashboard(username);
                this.showAlert('success', 'Login successful!');
            } else {
                this.showAlert('danger', data.error || 'Login failed');
            }
        } catch (error) {
            console.error('Login error:', error);
            this.showAlert('danger', 'Connection error. Please try again.');
        }
    }

    async logout() {
        try {
            await fetch(`${this.apiBase}/logout`, {
                method: 'POST',
                credentials: 'include'
            });
        } catch (error) {
            console.error('Logout error:', error);
        } finally {
            // Stop session watchdog
            if (this._sessionWatchdogInterval) {
                clearInterval(this._sessionWatchdogInterval);
                this._sessionWatchdogInterval = null;
            }
            this.showLogin();
        }
    }

    showLogin() {
        document.getElementById('loginScreen').classList.remove('hidden');
        document.getElementById('adminDashboard').classList.add('hidden');
        document.getElementById('loginForm').reset();
        document.getElementById('loginAlert').classList.add('hidden');
    }

    showDashboard(username) {
        document.getElementById('loginScreen').classList.add('hidden');
        document.getElementById('adminDashboard').classList.remove('hidden');
        document.getElementById('adminUsername').textContent = `Welcome, ${username}`;
        
        this.loadDashboardData();
    }

    showSection(section) {
        // Update navigation
        document.querySelectorAll('.sidebar .nav-link').forEach(link => {
            link.classList.remove('active');
        });
        document.querySelector(`[onclick="showSection('${section}')"]`).classList.add('active');

        // Show/hide sections
        document.querySelectorAll('[id$="Section"]').forEach(div => {
            div.classList.add('hidden');
        });
        document.getElementById(`${section}Section`).classList.remove('hidden');

        this.currentSection = section;

        // Load section-specific data
        switch (section) {
            case 'dashboard':
                this.loadDashboardData();
                break;
            case 'pagodas':
                this.loadPagodas();
                break;
            case 'users':
                this.loadUsers();
                break;
            case 'system':
                this.loadSystemHealth();
                break;
            case 'logs':
                this.loadLogs();
                break;
        }
    }

    async loadDashboardData() {
        try {
            const response = await fetch(`${this.apiBase}/dashboard/stats`);
            const data = await response.json();

            if (data.success) {
                this.updateDashboardStats(data.stats);
                this.displaySystemHealth(data.system_health);
            }
        } catch (error) {
            console.error('Failed to load dashboard data:', error);
        }

        // Load recent logs
        this.loadRecentLogs();
    }

    updateDashboardStats(stats) {
        document.getElementById('totalPagodas').textContent = stats.total_pagodas || 0;
        document.getElementById('featuredPagodas').textContent = stats.featured_pagodas || 0;
        document.getElementById('temples').textContent = stats.temples || 0;
        document.getElementById('locations').textContent = stats.locations || 0;
        
        // Update user stats if available
        if (document.getElementById('totalUsers')) {
            document.getElementById('totalUsers').textContent = stats.total_users || 0;
        }
        if (document.getElementById('verifiedUsers')) {
            document.getElementById('verifiedUsers').textContent = stats.verified_users || 0;
        }
        if (document.getElementById('recentUsers')) {
            document.getElementById('recentUsers').textContent = stats.recent_users || 0;
        }
        if (document.getElementById('activeUsers')) {
            document.getElementById('activeUsers').textContent = stats.total_users || 0; // Using total as active for now
        }
    }

    updateSystemHealth(health) {
        const updateHealthIndicator = (elementId, isUp) => {
            const element = document.getElementById(elementId);
            if (!element) return;
            
            const indicator = element.querySelector('.health-indicator');
            const textSpans = element.querySelectorAll('span');
            const text = textSpans[textSpans.length - 1]; // Get the last span (text)
            
            if (indicator && text) {
                if (isUp === true) {
                    indicator.className = 'health-indicator health-up';
                    text.textContent = 'Online';
                } else {
                    indicator.className = 'health-indicator health-down';
                    text.textContent = 'Offline';
                }
            }
        };

        // Update each service status
        updateHealthIndicator('mainAppStatus', health.main_app);
        updateHealthIndicator('chatbotStatus', health.chatbot);
        updateHealthIndicator('databaseStatus', health.database);
        
        // Update Node.js server status if element exists
        if (document.getElementById('nodeServerStatus')) {
            updateHealthIndicator('nodeServerStatus', health.node_server);
        }
        
        console.log('System Health Updated:', health); // Debug log
    }

    displaySystemHealth(health) {
        const container = document.getElementById('systemHealth');
        
        const healthHtml = Object.entries(health).map(([service, isUp]) => {
            const serviceName = service.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase());
            const statusClass = isUp ? 'text-success' : 'text-danger';
            const statusIcon = isUp ? 'fa-check-circle' : 'fa-times-circle';
            const statusText = isUp ? 'Online' : 'Offline';
            
            return `
                <div class="d-flex justify-content-between align-items-center mb-3 p-3 border rounded-2" style="background: ${isUp ? '#f8fff8' : '#fff8f8'}; border-color: ${isUp ? '#d4edda' : '#f5c6cb'} !important;">
                    <div class="d-flex align-items-center">
                        <div class="me-3" style="width: 30px; height: 30px; background: ${isUp ? '#d4edda' : '#f5c6cb'}; border-radius: 50%; display: flex; align-items: center; justify-content: center;">
                            <i class="fas ${statusIcon} ${statusClass}" style="font-size: 12px;"></i>
                        </div>
                        <span class="fw-medium" style="color: ${isUp ? '#155724' : '#721c24'}; font-size: 14px;">${serviceName}</span>
                    </div>
                    <span class="${statusClass} fw-medium" style="font-size: 13px;">${statusText}</span>
                </div>
            `;
        }).join('');

        container.innerHTML = healthHtml;
    }

    async loadRecentLogs() {
        try {
            const response = await fetch(`${this.apiBase}/dashboard/logs?limit=5`);
            const data = await response.json();

            if (data.success) {
                this.displayRecentLogs(data.logs);
            }
        } catch (error) {
            console.error('Failed to load recent logs:', error);
        }
    }

    displayRecentLogs(logs) {
        const container = document.getElementById('recentLogs');
        
        if (!logs || logs.length === 0) {
            container.innerHTML = '<div class="empty-state"><i class="fas fa-info-circle"></i><span>No recent activity</span></div>';
            return;
        }

        const logsHtml = logs.map(log => {
            const time = new Date(log.timestamp).toLocaleString();
            const actionClass = this.getActionClass(log.action);
            return `
                <div class="d-flex justify-content-between align-items-start mb-3 p-3 border rounded-2" style="background: #f8f9fa; border-color: #e9ecef !important; transition: all 0.2s ease;">
                    <div class="flex-grow-1">
                        <div class="d-flex align-items-center mb-1">
                            <span class="badge ${actionClass} me-2" style="font-size: 10px; padding: 3px 6px;">${log.action}</span>
                            <small class="text-muted" style="font-size: 11px;">${time}</small>
                        </div>
                        <div class="fw-medium text-dark" style="font-size: 13px;">${log.details}</div>
                    </div>
                </div>
            `;
        }).join('');

        container.innerHTML = logsHtml;
    }

    async loadPagodas() {
        const tbody = document.getElementById('pagodasTableBody');
        tbody.innerHTML = '<tr><td colspan="6" class="text-center py-4"><i class="fas fa-spinner fa-spin me-2"></i>Loading pagodas...</td></tr>';

        try {
            const response = await fetch(`${this.apiBase}/pagodas`);
            const data = await response.json();

            if (data.success) {
                this.displayPagodas(data.data);
            } else {
                tbody.innerHTML = '<tr><td colspan="6" class="text-center py-4 text-danger">Failed to load pagodas</td></tr>';
            }
        } catch (error) {
            console.error('Failed to load pagodas:', error);
            tbody.innerHTML = '<tr><td colspan="6" class="text-center py-4 text-danger">Connection error</td></tr>';
        }
    }

    displayPagodas(pagodas) {
        const tbody = document.getElementById('pagodasTableBody');
        
        if (!pagodas || pagodas.length === 0) {
            tbody.innerHTML = '<tr><td colspan="6" class="text-center py-4">No pagodas found</td></tr>';
            return;
        }

        // Sort alphabetically by name (case-insensitive)
        const sorted = [...pagodas].sort((a, b) => {
            const an = (a.name || '').toLowerCase();
            const bn = (b.name || '').toLowerCase();
            return an.localeCompare(bn);
        });

        const rows = sorted.map(pagoda => `
            <tr>
                <td><code>${pagoda.id}</code></td>
                <td>${pagoda.name}</td>
                <td><span class="badge bg-secondary">${pagoda.type}</span></td>
                <td>
                    <button class="btn btn-link p-0" onclick="toggleFeatured('${pagoda.id}', ${!!pagoda.featured})" title="Toggle Featured" aria-label="Toggle Featured">
                        ${pagoda.featured ? '<i class="fas fa-star text-warning"></i>' : '<i class=\"fas fa-star text-muted\"></i>'}
                    </button>
                </td>
                <td>
                    <span class="badge ${pagoda.status === 'active' ? 'bg-success' : 'bg-secondary'}">
                        ${pagoda.status}
                    </span>
                </td>
                <td>${pagoda.location?.city || 'Bagan'}</td>
                <td>
                    <div class="d-flex gap-2 justify-content-center">
                        <button class="btn btn-sm btn-outline-primary" onclick="editPagoda('${pagoda.id}')" title="Edit Pagoda" style="border-radius: 8px; padding: 8px 12px; font-weight: 500;">
                            <i class="fas fa-edit me-1"></i>Edit
                        </button>
                        <button class="btn btn-sm btn-outline-danger" onclick="deletePagoda('${pagoda.id}')" title="Delete Pagoda" style="border-radius: 8px; padding: 8px 12px; font-weight: 500;">
                            <i class="fas fa-trash me-1"></i>Delete
                        </button>
                    </div>
                </td>
            </tr>
        `).join('');

        tbody.innerHTML = rows;
    }

    async toggleFeatured(id, current) {
        try {
            const response = await fetch(`${this.apiBase}/pagodas/${id}/feature`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ featured: !current })
            });
            const data = await response.json();
            if (data.success) {
                this.showAlert('success', `Featured set to ${data.featured ? 'ON' : 'OFF'}`);
                this.loadPagodas();
            } else {
                this.showAlert('danger', data.error || 'Failed to update featured');
            }
        } catch (err) {
            console.error('Failed to toggle featured:', err);
            this.showAlert('danger', 'Connection error');
        }
    }

    showCreatePagodaModal() {
        this.currentPagoda = null;
        document.getElementById('pagodaModalTitle').textContent = 'Add Pagoda';
        document.getElementById('pagodaForm').reset();
        
        const modal = new bootstrap.Modal(document.getElementById('pagodaModal'));
        modal.show();
    }

    async editPagoda(id) {
        try {
            const response = await fetch(`${this.apiBase}/pagodas/${id}`);
            const data = await response.json();

            if (data.success) {
                this.currentPagoda = data.data;
                this.populatePagodaForm(data.data);
                
                document.getElementById('pagodaModalTitle').textContent = 'Edit Pagoda';
                const modal = new bootstrap.Modal(document.getElementById('pagodaModal'));
                modal.show();
            } else {
                this.showAlert('danger', 'Failed to load pagoda data');
            }
        } catch (error) {
            console.error('Failed to load pagoda:', error);
            this.showAlert('danger', 'Connection error');
        }
    }

    populatePagodaForm(pagoda) {
        document.getElementById('pagodaId').value = pagoda.id || '';
        document.getElementById('pagodaName').value = pagoda.name || '';
        document.getElementById('pagodaShortName').value = pagoda.shortName || '';
        document.getElementById('pagodaNameMm').value = pagoda.nameMm || '';
        document.getElementById('pagodaShortNameMm').value = pagoda.shortNameMm || '';
        document.getElementById('pagodaType').value = pagoda.type || '';
        document.getElementById('pagodaLat').value = pagoda.location?.coordinates?.lat || '';
        document.getElementById('pagodaLng').value = pagoda.location?.coordinates?.lng || '';
        document.getElementById('pagodaShortDesc').value = pagoda.description?.short || '';
        document.getElementById('pagodaLongDesc').value = pagoda.description?.long || '';
        document.getElementById('pagodaShortDescMm').value = pagoda.description?.shortMm || '';
        document.getElementById('pagodaLongDescMm').value = pagoda.description?.longMm || '';
        document.getElementById('pagodaFeatured').checked = pagoda.featured || false;
    }

    async savePagoda() {
        // Basic client-side validation to reduce 400/500s
        const id = document.getElementById('pagodaId').value.trim();
        const name = document.getElementById('pagodaName').value.trim();
        const shortName = document.getElementById('pagodaShortName').value.trim();
        const type = document.getElementById('pagodaType').value.trim();
        const latStr = document.getElementById('pagodaLat').value;
        const lngStr = document.getElementById('pagodaLng').value;

        if (!name || !shortName || !type || (!this.currentPagoda && !id)) {
            this.showAlert('danger', 'Please fill in all required fields (ID, Name, Short Name, Type).');
            return;
        }

        const lat = latStr === '' ? null : parseFloat(latStr);
        const lng = lngStr === '' ? null : parseFloat(lngStr);
        if (lat !== null && Number.isNaN(lat) || lng !== null && Number.isNaN(lng)) {
            this.showAlert('danger', 'Latitude/Longitude must be numbers.');
            return;
        }

        const payload = {
            id,
            name,
            shortName,
            nameMm: document.getElementById('pagodaNameMm').value.trim(),
            shortNameMm: document.getElementById('pagodaShortNameMm').value.trim(),
            type,
            location: {
                city: 'Bagan',
                region: 'Mandalay Region',
                country: 'Myanmar',
                coordinates: {
                    lat,
                    lng
                }
            },
            description: {
                short: document.getElementById('pagodaShortDesc').value,
                long: document.getElementById('pagodaLongDesc').value,
                shortMm: document.getElementById('pagodaShortDescMm').value,
                longMm: document.getElementById('pagodaLongDescMm').value
            },
            featured: document.getElementById('pagodaFeatured').checked,
            status: 'active'
        };

        try {
            const url = this.currentPagoda ?
                `${this.apiBase}/pagodas/${this.currentPagoda.id}` :
                `${this.apiBase}/pagodas`;
            
            const method = this.currentPagoda ? 'PUT' : 'POST';

            const detailFileInput = document.getElementById('pagodaDetailHtml');
            const detailFileInputMm = document.getElementById('pagodaDetailHtmlMm');
            const mainImgInput = document.getElementById('pagodaMainImage');
            const thumbImgInput = document.getElementById('pagodaThumbnail');
            const galleryInput = document.getElementById('pagodaGallery');
            const hasFile = (detailFileInput && detailFileInput.files && detailFileInput.files[0]) ||
                            (detailFileInputMm && detailFileInputMm.files && detailFileInputMm.files[0]) ||
                            (mainImgInput && mainImgInput.files && mainImgInput.files[0]) ||
                            (thumbImgInput && thumbImgInput.files && thumbImgInput.files[0]) ||
                            (galleryInput && galleryInput.files && galleryInput.files.length > 0);

            let response;
            if (hasFile) {
                const form = new FormData();
                form.append('data', JSON.stringify(payload));
                if (detailFileInput && detailFileInput.files[0]) form.append('detailHtml', detailFileInput.files[0]);
                if (detailFileInputMm && detailFileInputMm.files[0]) form.append('detailHtmlMm', detailFileInputMm.files[0]);
                if (mainImgInput && mainImgInput.files[0]) form.append('mainImage', mainImgInput.files[0]);
                if (thumbImgInput && thumbImgInput.files[0]) form.append('thumbnail', thumbImgInput.files[0]);
                if (galleryInput && galleryInput.files && galleryInput.files.length) {
                    Array.from(galleryInput.files).forEach((f) => form.append('gallery', f));
                }
                response = await fetch(url, { method, body: form });
            } else {
                response = await fetch(url, {
                    method: method,
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(payload)
                });
            }

            const data = await response.json();

            if (data.success) {
                this.showAlert('success', data.message);
                bootstrap.Modal.getInstance(document.getElementById('pagodaModal')).hide();
                this.loadPagodas();
            } else {
                this.showAlert('danger', data.error || 'Failed to save pagoda');
            }
        } catch (error) {
            console.error('Failed to save pagoda:', error);
            this.showAlert('danger', 'Connection error');
        }
    }

    async deletePagoda(id) {
        const confirmed = await this.showConfirmation(
            'Delete Pagoda',
            'Are you sure you want to delete this pagoda? This action cannot be undone.',
            'danger'
        );
        
        if (!confirmed) return;

        try {
            const response = await fetch(`${this.apiBase}/pagodas/${id}`, {
                method: 'DELETE'
            });

            const data = await response.json();

            if (data.success) {
                this.showAlert('success', 'Pagoda deleted successfully');
                this.loadPagodas();
            } else {
                this.showAlert('danger', data.error || 'Failed to delete pagoda');
            }
        } catch (error) {
            console.error('Failed to delete pagoda:', error);
            this.showAlert('danger', 'Connection error');
        }
    }


    async loadSystemHealth() {
        const container = document.getElementById('detailedSystemHealth');
        container.innerHTML = '<div class="text-center text-muted py-3"><i class="fas fa-spinner fa-spin me-2"></i>Loading system status...</div>';

        try {
            const response = await fetch(`${this.apiBase}/system/health`);
            const data = await response.json();

            if (data.success) {
                this.displayDetailedSystemHealth(data.health);
            } else {
                container.innerHTML = '<div class="text-center text-danger py-3">Failed to load system status</div>';
            }
        } catch (error) {
            console.error('Failed to load system health:', error);
            container.innerHTML = '<div class="text-center text-danger py-3">Connection error</div>';
        }
    }

    displayDetailedSystemHealth(health) {
        const container = document.getElementById('detailedSystemHealth');
        
        if (!health || Object.keys(health).length === 0) {
            container.innerHTML = '<div class="empty-state"><i class="fas fa-exclamation-triangle"></i><span>No system data available</span></div>';
            return;
        }

        // Calculate system overview stats
        this.updateSystemOverviewStats(health);

        const healthHtml = Object.entries(health).map(([service, info]) => {
            const isUp = info.status === 'up';
            const statusClass = isUp ? 'text-success' : 'text-danger';
            const statusIcon = isUp ? 'fa-check-circle' : 'fa-times-circle';
            const serviceName = service.replace('_', ' ').toUpperCase();
            const responseTime = info.response_time ? `${info.response_time}s` : 'N/A';
            const errorMessage = info.error ? info.error : null;
            
            return `
                <div class="d-flex justify-content-between align-items-center mb-3 p-4 border rounded-3" style="background: ${isUp ? '#f8fff8' : '#fff8f8'}; border-color: ${isUp ? '#d4edda' : '#f5c6cb'} !important; transition: all 0.3s ease; box-shadow: 0 2px 8px rgba(0,0,0,0.05);">
                    <div class="flex-grow-1">
                        <div class="d-flex align-items-center mb-2">
                            <div class="me-3 service-status-indicator" style="background: ${isUp ? '#d4edda' : '#f5c6cb'};">
                                <i class="fas ${statusIcon} ${statusClass}" style="font-size: 18px;"></i>
                            </div>
                            <div>
                                <div class="fw-bold" style="color: ${isUp ? '#155724' : '#721c24'}; font-size: 16px; margin-bottom: 4px;">${serviceName}</div>
                                <div class="d-flex align-items-center gap-3">
                                    <small class="text-muted" style="font-size: 12px;">
                                        <i class="fas fa-clock me-1"></i>Response: ${responseTime}
                                    </small>
                                    ${isUp ? 
                                        '<span class="badge bg-success" style="font-size: 10px; padding: 4px 8px;">ONLINE</span>' : 
                                        '<span class="badge bg-danger" style="font-size: 10px; padding: 4px 8px;">OFFLINE</span>'
                                    }
                                </div>
                                ${errorMessage ? 
                                    `<div class="mt-2">
                                        <small class="text-danger" style="font-size: 11px;">
                                            <i class="fas fa-exclamation-triangle me-1"></i>${errorMessage}
                                        </small>
                                    </div>` : ''
                                }
                            </div>
                        </div>
                    </div>
                </div>
            `;
        }).join('');

        container.innerHTML = healthHtml;
    }

    updateSystemOverviewStats(health) {
        const services = Object.entries(health);
        const totalServices = services.length;
        const onlineServices = services.filter(([_, info]) => info.status === 'up').length;
        const offlineServices = totalServices - onlineServices;
        
        // Calculate average response time
        const responseTimes = services
            .filter(([_, info]) => info.response_time)
            .map(([_, info]) => parseFloat(info.response_time));
        const avgResponseTime = responseTimes.length > 0 
            ? (responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length).toFixed(3)
            : '0.000';

        // Update the stat cards
        const totalServicesEl = document.getElementById('totalServices');
        const onlineServicesEl = document.getElementById('onlineServices');
        const offlineServicesEl = document.getElementById('offlineServices');
        const avgResponseTimeEl = document.getElementById('avgResponseTime');

        if (totalServicesEl) totalServicesEl.textContent = totalServices;
        if (onlineServicesEl) onlineServicesEl.textContent = onlineServices;
        if (offlineServicesEl) offlineServicesEl.textContent = offlineServices;
        if (avgResponseTimeEl) avgResponseTimeEl.textContent = avgResponseTime;
    }

    async restartService(service) {
        const confirmed = await this.showConfirmation(
            'Restart Service',
            `Are you sure you want to restart the ${service}?`,
            'warning'
        );
        
        if (!confirmed) return;

        try {
            const response = await fetch(`${this.apiBase}/system/restart/${service}`, {
                method: 'POST'
            });

            const data = await response.json();

            if (data.success) {
                this.showAlert('success', data.message);
                setTimeout(() => this.loadSystemHealth(), 2000);
            } else {
                this.showAlert('danger', data.error || 'Failed to restart service');
            }
        } catch (error) {
            console.error('Failed to restart service:', error);
            this.showAlert('danger', 'Connection error');
        }
    }

    async loadLogs() {
        const container = document.getElementById('logsList');
        container.innerHTML = '<div class="text-center text-muted py-3"><i class="fas fa-spinner fa-spin me-2"></i>Loading logs...</div>';

        try {
            const response = await fetch(`${this.apiBase}/dashboard/logs?limit=50`);
            const data = await response.json();

            if (data.success) {
                this.displayLogs(data.logs);
            } else {
                container.innerHTML = '<div class="text-center text-danger py-3">Failed to load logs</div>';
            }
        } catch (error) {
            console.error('Failed to load logs:', error);
            container.innerHTML = '<div class="text-center text-danger py-3">Connection error</div>';
        }
    }

    displayLogs(logs) {
        const container = document.getElementById('logsList');
        
        if (!logs || logs.length === 0) {
            container.innerHTML = '<div class="text-center text-muted py-4"><i class="fas fa-info-circle me-2"></i>No logs found</div>';
            return;
        }

        const logsHtml = logs.map(log => {
            const time = new Date(log.timestamp).toLocaleString();
            const actionClass = this.getActionClass(log.action);
            return `
                <div class="d-flex justify-content-between align-items-start mb-3 p-4 border rounded-3" style="background: #f8f9fa; border-color: #e9ecef !important; transition: all 0.2s ease;">
                    <div class="flex-grow-1">
                        <div class="d-flex align-items-center mb-2">
                            <span class="badge ${actionClass} me-2" style="font-size: 11px; padding: 4px 8px;">${log.action}</span>
                            <small class="text-muted">${time}</small>
                        </div>
                        <div class="fw-medium text-dark" style="font-size: 14px;">${log.details}</div>
                    </div>
                </div>
            `;
        }).join('');

        container.innerHTML = logsHtml;
    }

    getActionClass(action) {
        const actionClasses = {
            'LOGIN': 'bg-success',
            'LOGOUT': 'bg-secondary',
            'VERIFY_USER': 'bg-info',
            'UNVERIFY_USER': 'bg-warning',
            'DELETE_USER': 'bg-danger',
            'CREATE_PAGODA': 'bg-primary',
            'UPDATE_PAGODA': 'bg-info',
            'DELETE_PAGODA': 'bg-danger',
            'UPDATE_USER': 'bg-warning'
        };
        return actionClasses[action] || 'bg-secondary';
    }

    refreshDashboard() {
        this.loadDashboardData();
    }

    refreshSystemHealth() {
        this.loadSystemHealth();
    }

    refreshLogs() {
        this.loadLogs();
    }

    async loadUsers() {
        const tbody = document.getElementById('usersTableBody');
        tbody.innerHTML = '<tr><td colspan="7" class="text-center py-4"><i class="fas fa-spinner fa-spin me-2"></i>Loading users...</td></tr>';

        try {
            const response = await fetch(`${this.apiBase}/users`);
            const data = await response.json();

            if (data.success) {
                this.displayUsers(data.data);
                this.updateUserPagination(data.pagination);
            } else {
                tbody.innerHTML = '<tr><td colspan="6" class="text-center py-4 text-danger">Failed to load users</td></tr>';
            }
        } catch (error) {
            console.error('Failed to load users:', error);
            tbody.innerHTML = '<tr><td colspan="6" class="text-center py-4 text-danger">Connection error</td></tr>';
        }
    }

    displayUsers(users) {
        const tbody = document.getElementById('usersTableBody');
        
        if (!users || users.length === 0) {
            tbody.innerHTML = '<tr><td colspan="6" class="text-center py-4">No users found</td></tr>';
            return;
        }

        const rows = users.map(user => {
            const isVerified = user.isAdminVerified || user.isEmailVerified;
            
            return `
                <tr>
                    <td>${user.username || 'N/A'}</td>
                    <td>${user.email || 'N/A'}</td>
                    <td>${user.fullName || 'N/A'}</td>
                    <td>
                        <span class="badge ${isVerified ? 'bg-success' : 'bg-warning'}">
                            ${isVerified ? 'Verified' : 'Unverified'}
                        </span>
                    </td>
                    <td>
                        ${user.lastLogin ? new Date(user.lastLogin).toLocaleDateString() : 'Never'}
                    </td>
                    <td>
                        <div class="d-flex gap-2 justify-content-center">
                            ${!isVerified ? 
                                `<button class="btn btn-sm btn-outline-success" onclick="verifyUser('${user._id}')" title="Verify User" style="border-radius: 8px; padding: 8px 12px; font-weight: 500;">
                                    <i class="fas fa-check me-1"></i>Verify
                                </button>` : 
                                `<button class="btn btn-sm btn-outline-warning" onclick="unverifyUser('${user._id}')" title="Unverify User" style="border-radius: 8px; padding: 8px 12px; font-weight: 500;">
                                    <i class="fas fa-times me-1"></i>Unverify
                                </button>`
                            }
                            <button class="btn btn-sm btn-outline-danger" onclick="deleteUser('${user._id}')" title="Delete User" style="border-radius: 8px; padding: 8px 12px; font-weight: 500;">
                                <i class="fas fa-trash me-1"></i>Delete
                            </button>
                        </div>
                    </td>
                </tr>
            `;
        }).join('');

        tbody.innerHTML = rows;
    }

    updateUserPagination(pagination) {
        const paginationContainer = document.getElementById('userPagination');
        if (!paginationContainer || !pagination) return;

        let paginationHtml = '';
        
        // Previous button
        if (pagination.page > 1) {
            paginationHtml += `<li class="page-item"><a class="page-link" href="#" onclick="loadUserPage(${pagination.page - 1})">Previous</a></li>`;
        }

        // Page numbers
        for (let i = 1; i <= pagination.pages; i++) {
            const isActive = i === pagination.page;
            paginationHtml += `
                <li class="page-item ${isActive ? 'active' : ''}">
                    <a class="page-link" href="#" onclick="loadUserPage(${i})">${i}</a>
                </li>
            `;
        }

        // Next button
        if (pagination.page < pagination.pages) {
            paginationHtml += `<li class="page-item"><a class="page-link" href="#" onclick="loadUserPage(${pagination.page + 1})">Next</a></li>`;
        }

        paginationContainer.innerHTML = paginationHtml;
    }

    async deleteUser(id) {
        const confirmed = await this.showConfirmation(
            'Delete User',
            'Are you sure you want to delete this user? This action cannot be undone.',
            'danger'
        );
        
        if (!confirmed) return;

        try {
            const response = await fetch(`${this.apiBase}/users/${id}`, {
                method: 'DELETE'
            });

            const data = await response.json();

            if (data.success) {
                this.showAlert('success', 'User deleted successfully');
                this.loadUsers();
            } else {
                this.showAlert('danger', data.error || 'Failed to delete user');
            }
        } catch (error) {
            console.error('Failed to delete user:', error);
            this.showAlert('danger', 'Connection error');
        }
    }

    refreshUsers() {
        this.loadUsers();
    }

    async verifyUser(id) {
        const confirmed = await this.showConfirmation(
            'Verify User',
            'Are you sure you want to verify this user?',
            'success'
        );
        
        if (!confirmed) return;

        try {
            const response = await fetch(`${this.apiBase}/users/${id}/verify`, {
                method: 'POST'
            });

            const data = await response.json();

            if (data.success) {
                this.showAlert('success', 'User verified successfully');
                this.loadUsers();
            } else {
                this.showAlert('danger', data.error || 'Failed to verify user');
            }
        } catch (error) {
            console.error('Failed to verify user:', error);
            this.showAlert('danger', 'Connection error');
        }
    }

    async unverifyUser(id) {
        const confirmed = await this.showConfirmation(
            'Unverify User',
            'Are you sure you want to unverify this user?',
            'warning'
        );
        
        if (!confirmed) return;

        try {
            const response = await fetch(`${this.apiBase}/users/${id}/unverify`, {
                method: 'POST'
            });

            const data = await response.json();

            if (data.success) {
                this.showAlert('success', 'User unverified successfully');
                this.loadUsers();
            } else {
                this.showAlert('danger', data.error || 'Failed to unverify user');
            }
        } catch (error) {
            console.error('Failed to unverify user:', error);
            this.showAlert('danger', 'Connection error');
        }
    }

    showConfirmation(title, message, type = 'danger') {
        return new Promise((resolve) => {
            const modal = document.getElementById('confirmationModal');
            const messageEl = document.getElementById('confirmationMessage');
            const confirmBtn = document.getElementById('confirmButton');
            
            // Update modal content
            messageEl.textContent = message;
            
            // Update button colors based on type
            const colors = {
                'danger': 'linear-gradient(135deg, #ff6b6b, #ee5a52)',
                'success': 'linear-gradient(135deg, #27ae60, #2ecc71)',
                'warning': 'linear-gradient(135deg, #f39c12, #e67e22)'
            };
            
            confirmBtn.style.background = colors[type] || colors.danger;
            
            // Set up event listeners
            const handleConfirm = () => {
                // Clean up listeners
                modal.removeEventListener('hidden.bs.modal', handleCancel);
                confirmBtn.removeEventListener('click', handleConfirm);
                // Hide the modal immediately
                const existing = bootstrap.Modal.getInstance(modal);
                if (existing) {
                    existing.hide();
                }
                resolve(true);
            };
            
            const handleCancel = () => {
                confirmBtn.removeEventListener('click', handleConfirm);
                resolve(false);
            };
            
            confirmBtn.addEventListener('click', handleConfirm);
            modal.addEventListener('hidden.bs.modal', handleCancel);
            
            // Show modal (reuse existing instance if present)
            const instance = bootstrap.Modal.getOrCreateInstance(modal);
            instance.show();
        });
    }

    showAlert(type, message) {
        // Create alert element
        const alertDiv = document.createElement('div');
        alertDiv.className = `alert alert-${type} alert-admin alert-dismissible fade show`;
        alertDiv.innerHTML = `
            ${message}
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        `;

        // Insert at top of main content
        const mainContent = document.querySelector('.main-content');
        mainContent.insertBefore(alertDiv, mainContent.firstChild);

        // Auto-remove after 5 seconds
        setTimeout(() => {
            if (alertDiv.parentNode) {
                alertDiv.remove();
            }
        }, 5000);
    }
}

// Initialize admin dashboard when page loads
document.addEventListener('DOMContentLoaded', () => {
    window.adminDashboard = new AdminDashboard();
});
