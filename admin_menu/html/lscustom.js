/* =========================================================
   MÉTIERS › LSCUSTOM
   Gestion complète du métier (ressource elyzea_lscustom) :
   informations, grades, zones, prix, tenues, permissions, configuration.
   ========================================================= */
(() => {
    TABS.push({
        id: 'lscustom', group: 5, label: 'LsCustom', ico: '🔧',
        sub: 'Gestion complète du métier LsCustom : grades, zones, prix, tenues, permissions et configuration.',
        show: () => has('lscustom_staff') && !!(D && D.lscustom),
    });

    const SUBS = [
        { id: 'info', label: 'Informations' },
        { id: 'grades', label: 'Grades' },
        { id: 'zones', label: 'Zones' },
        { id: 'prices', label: 'Prix' },
        { id: 'uniforms', label: 'Tenues' },
        { id: 'perms', label: 'Permissions' },
        { id: 'config', label: 'Configuration' },
    ];
    const GROUP_LABEL = { service: 'Services', esthetique: 'Esthétique', performance: 'Performance' };
    const LS = { sub: 'info', general: null, grades: null, perms: null, prices: null, settings: null, zoneType: 'all' };
    const clone = (o) => JSON.parse(JSON.stringify(o));
    const send = (name, data = {}) => action('lscustom', { name, data });
    const money = (n) => `${Number(n || 0).toLocaleString('fr-FR')} $`;

    const drafts = (d) => {
        if (!LS.general) LS.general = { label: d.job.label, type: d.job.type || '', defaultDuty: !!d.job.defaultDuty, offDutyPay: !!d.job.offDutyPay };
        if (!LS.grades) LS.grades = clone(d.job.grades);
        if (!LS.perms) LS.perms = clone(d.perms || {});
        if (!LS.prices) LS.prices = clone(d.prices || {});
        if (!LS.settings) LS.settings = clone(d.settings || {});
    };
    const zoneLabel = (t) => ((D.lscustom.zoneTypes || []).find((z) => z.key === t) || {}).label || t;

    VIEWS.lscustom = () => {
        const d = D.lscustom;
        if (!d.available) {
            return `<div class="protect">⚠️ <span>La ressource <b>${esc(d.resource || 'elyzea_lscustom')}</b> n'est pas démarrée.
                Ajoute <span class="keycap">ensure ${esc(d.resource || 'elyzea_lscustom')}</span> dans server.cfg, après admin_menu.</span></div>`;
        }
        drafts(d);
        const nav = `<div class="segmented">${SUBS.map((s) => `<button class="seg ${s.id === LS.sub ? 'active' : ''}" data-lss="${s.id}">${s.label}</button>`).join('')}</div>`;
        return nav + (SUBVIEWS[LS.sub] || SUBVIEWS.info)(d);
    };

    const SUBVIEWS = {};

    /* ---------- Informations ---------- */
    SUBVIEWS.info = (d) => {
        const g = LS.general;
        const s = d.stats;
        return `
            <div class="stats">
                <div class="stat"><b>${s.duty}</b><span>Mécanos en service</span></div>
                <div class="stat"><b>${s.online}</b><span>Mécanos connectés</span></div>
                <div class="stat" data-lss="zones"><b>${s.zones}</b><span>Zones</span></div>
                <div class="stat"><b>${s.inCharge}</b><span>Véhicules pris en charge</span></div>
                <div class="stat"><b>${s.invoicesToday}</b><span>Factures aujourd'hui · ${money(s.revenueToday)}</span></div>
            </div>
            <div class="section"><h2>Métier</h2>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-bottom:12px">
                    <div class="tile toggle-tile ${d.enabled ? 'on' : ''}" data-lsa="toggleEnabled">
                        <div><strong>${d.enabled ? 'Ouvert' : 'Fermé'}</strong><span>${d.enabled ? 'Les mécanos peuvent travailler.' : 'Plus aucune prestation possible.'}</span></div><div class="switch"></div></div>
                    <div class="tile toggle-tile ${g.defaultDuty ? 'on' : ''}" data-lsg="defaultDuty"><div><strong>En service à la connexion</strong><span>Sinon, prise de service à l'accueil.</span></div><div class="switch"></div></div>
                    <div class="tile toggle-tile ${g.offDutyPay ? 'on' : ''}" data-lsg="offDutyPay"><div><strong>Payé hors service</strong><span>Salaire même hors service.</span></div><div class="switch"></div></div>
                </div>
                <div class="form-grid" style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px;max-width:820px">
                    <div class="field"><label>Nom du métier</label><input class="input" data-lsf="general.label" value="${esc(g.label)}"></div>
                    <div class="field"><label>Identifiant du job</label><input class="input" value="${esc(d.job.name)}" disabled title="Défini dans la config de la ressource"></div>
                    <div class="field"><label>Type</label><input class="input" data-lsf="general.type" value="${esc(g.type)}" placeholder="mechanic"></div>
                </div>
                <div class="btn-row"><button class="btn primary" data-lsa="saveGeneral">Enregistrer</button><button class="btn" data-lsa="resetGeneral">Annuler</button></div>
            </div>
            <div class="section"><h2>Mécanos connectés (${d.mechanics.length})</h2>
                ${d.mechanics.length ? `<table>${d.mechanics.map((m) => `<tr>
                    <td><strong>[${m.id}] ${esc(m.name)}</strong></td><td class="muted">${esc(m.grade)}</td>
                    <td>${m.onduty ? '<span class="badge" style="color:var(--ok)">En service</span>' : '<span class="badge muted">Hors service</span>'}</td>
                    <td class="muted">${m.work ? `${esc(m.work)}${m.plate ? ` · <span class="keycap">${esc(m.plate)}</span>` : ''}` : ''}</td></tr>`).join('')}</table>`
                    : '<div class="empty">Aucun mécano connecté.</div>'}
            </div>
            ${window.JobTools ? JobTools.sections('lscustom', 'join') : ''}`;
    };

    /* ---------- Grades ---------- */
    SUBVIEWS.grades = () => `
        <div class="section"><h2>Grades</h2>
            <p class="hint">Le <b>grade</b> est le niveau (0 = le plus bas). Le <b>nom</b> est l'identifiant interne, le <b>label</b> est affiché aux joueurs.
            Les permissions de chaque grade se règlent dans l'onglet <b>Permissions</b>.</p>
            <table>
                <tr><th style="width:70px">Grade</th><th>Nom</th><th>Label</th><th style="width:140px">Salaire</th><th style="width:80px">Patron</th><th style="width:150px"></th></tr>
                ${LS.grades.map((g, i) => `<tr>
                    <td><span class="keycap">${i}</span></td>
                    <td><input class="input" data-lsf="grades.${i}.id" value="${esc(g.id || '')}" placeholder="mecanicien"></td>
                    <td><input class="input" data-lsf="grades.${i}.label" value="${esc(g.label)}"></td>
                    <td><input class="input" type="number" min="0" data-lsf="grades.${i}.payment" value="${Number(g.payment) || 0}"></td>
                    <td><input type="checkbox" data-lsf="grades.${i}.isboss" ${g.isboss ? 'checked' : ''}></td>
                    <td style="text-align:right;white-space:nowrap">
                        <button class="btn" data-lsa="gradeUp" data-i="${i}" ${i === 0 ? 'disabled' : ''} title="Monter">↑</button>
                        <button class="btn" data-lsa="gradeDown" data-i="${i}" ${i === LS.grades.length - 1 ? 'disabled' : ''} title="Descendre">↓</button>
                        <button class="btn danger" data-lsa="gradeRemove" data-i="${i}" ${LS.grades.length <= 1 ? 'disabled' : ''}>✕</button></td></tr>`).join('')}
            </table>
            <div class="btn-row" style="margin-top:12px"><button class="btn" data-lsa="gradeAdd">+ Ajouter un grade</button>
                <span style="flex:1"></span><button class="btn" data-lsa="resetGrades">Annuler</button><button class="btn primary" data-lsa="saveGrades">Enregistrer les grades</button></div>
        </div>`;

    /* ---------- Zones ---------- */
    SUBVIEWS.zones = (d) => {
        const types = d.zoneTypes || [];
        const list = d.zones.filter((z) => LS.zoneType === 'all' || z.type === LS.zoneType);
        return `
            <div class="section"><h2>Ajouter une zone</h2>
                <p class="hint">Place-toi à l'endroit voulu puis « Utiliser ma position actuelle », ou tape les coordonnées.</p>
                <div class="btn-row"><button class="btn primary" data-lsa="zoneAddHere">📍 Utiliser ma position actuelle</button>
                    <button class="btn" data-lsa="zoneAddManual">🎯 Définir la position manuellement</button></div>
            </div>
            <div class="section"><h2>Zones (${d.zones.length})</h2>
                <div class="chips" style="margin-bottom:12px">
                    <button class="btn ${LS.zoneType === 'all' ? 'on' : ''}" data-lzt="all">Toutes</button>
                    ${types.map((t) => `<button class="btn ${LS.zoneType === t.key ? 'on' : ''}" data-lzt="${t.key}">${esc(t.label)} (${d.zones.filter((z) => z.type === t.key).length})</button>`).join('')}
                </div>
                ${list.length ? `<table>
                    <tr><th>Zone</th><th>Type</th><th style="width:80px">Rayon</th><th>Position</th><th style="width:90px">Active</th><th></th></tr>
                    ${list.map((z) => `<tr style="${z.enabled === false ? 'opacity:.55' : ''}">
                        <td><strong>${esc(z.label)}</strong> <span class="muted">#${z.id}</span></td>
                        <td><span class="badge" style="color:var(--signal)">${esc(zoneLabel(z.type))}</span></td>
                        <td>${Number(z.radius).toFixed(1)} m</td>
                        <td class="muted" style="font-size:12px;white-space:nowrap">${z.x.toFixed(1)}, ${z.y.toFixed(1)}, ${z.z.toFixed(1)} · ${Number(z.h || 0).toFixed(0)}°</td>
                        <td><div class="tile toggle-tile ${z.enabled !== false ? 'on' : ''}" data-lsa="zoneToggle" data-id="${z.id}" style="padding:6px 8px"><span></span><div class="switch"></div></div></td>
                        <td style="text-align:right;white-space:nowrap">
                            <button class="btn" data-lsa="zoneTp" data-id="${z.id}">Y aller</button>
                            <button class="btn" data-lsa="zoneEdit" data-id="${z.id}">Modifier</button>
                            <button class="btn" data-lsa="zoneMoveHere" data-id="${z.id}" title="Déplacer la zone à ma position">📍</button>
                            <button class="btn" data-lsa="zoneCoords" data-id="${z.id}" title="Coordonnées manuelles">🎯</button>
                            <button class="btn danger" data-lsa="zoneDelete" data-id="${z.id}">✕</button></td></tr>`).join('')}
                </table>` : '<div class="empty">Aucune zone de ce type.</div>'}
            </div>`;
    };

    /* ---------- Prix ---------- */
    SUBVIEWS.prices = (d) => `
        <p class="hint">Les nouveaux prix s'appliquent immédiatement aux prochaines factures. Les pièces de performance sont facturées <b>par niveau</b>
        (niveau 3 = 3 × le prix).</p>
        ${['service', 'esthetique', 'performance'].map((g) => `<div class="section"><h2>${GROUP_LABEL[g]}</h2>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(250px,1fr))">
            ${d.catalog.filter((c) => c.group === g).map((c) => `<div class="field" style="margin:0">
                <label>${esc(c.label)}${c.perLevel ? ' · par niveau' : ''}</label>
                <input class="input" type="number" min="0" data-lsf="prices.${c.key}" value="${Number(LS.prices[c.key] || 0)}"></div>`).join('')}
            </div></div>`).join('')}
        <div class="btn-row"><button class="btn primary" data-lsa="savePrices">Enregistrer les prix</button><button class="btn" data-lsa="resetPrices">Annuler</button></div>`;

    /* ---------- Tenues ---------- */
    SUBVIEWS.uniforms = () => (window.JobTools && JobTools.available('lscustom')
        ? JobTools.sections('lscustom', 'uniforms')
        : '<div class="empty">Les tenues ne sont pas disponibles.</div>');

    /* ---------- Permissions ---------- */
    SUBVIEWS.perms = (d) => `
        <div class="section"><h2>Permissions par grade</h2>
            <p class="hint">Coche ce que chaque grade peut faire. Un mécano doit aussi être <b>en service</b> et le métier <b>ouvert</b>.</p>
            <table>
                <tr><th>Grade</th>${d.permissions.map((p) => `<th style="text-align:center">${esc(p.label)}</th>`).join('')}<th></th></tr>
                ${d.job.grades.map((g, i) => {
                    const row = LS.perms[String(i)] || {};
                    return `<tr><td><strong>${i} · ${esc(g.label)}</strong></td>
                        ${d.permissions.map((p) => `<td style="text-align:center"><input type="checkbox" data-lsp="${i}:${p.key}" ${row[p.key] ? 'checked' : ''}></td>`).join('')}
                        <td style="text-align:right"><button class="btn" data-lsa="permAll" data-i="${i}">Tout</button><button class="btn" data-lsa="permNone" data-i="${i}">Rien</button></td></tr>`;
                }).join('')}
            </table>
            <div class="btn-row" style="margin-top:12px"><button class="btn primary" data-lsa="savePerms">Enregistrer les permissions</button><button class="btn" data-lsa="resetPerms">Annuler</button></div>
        </div>`;

    /* ---------- Configuration ---------- */
    const SETTINGS = [
        { k: 'commission', label: 'Commission du mécano', unit: '%', help: 'Part de chaque facture versée au mécano ; le reste va au métier.' },
        { k: 'maxInvoice', label: 'Facture maximum', unit: '$' },
        { k: 'invoiceTimeout', label: 'Temps pour accepter une facture', unit: 's' },
        { k: 'repairTime', label: 'Durée d\'une réparation', unit: 's' },
        { k: 'cleanTime', label: 'Durée d\'un nettoyage', unit: 's' },
        { k: 'maxServiceVehicles', label: 'Véhicules de service par mécano', unit: '' },
        { k: 'workInZonesOnly', label: 'Travailler seulement dans les zones', bool: true, help: 'Réparation, nettoyage et modification uniquement dans les zones prévues.' },
        { k: 'showBlips', label: 'Icône sur la carte', bool: true, help: 'Les zones « Modification » apparaissent sur la carte de tous les joueurs.' },
        { k: 'societyDeposit', label: 'Verser au compte du métier', bool: true, help: 'Le reste de chaque facture va au compte du métier (Renewed-Banking).' },
    ];
    SUBVIEWS.config = (d) => {
        const s = LS.settings;
        const vehicles = s.serviceVehicles || [];
        return `
            <div class="section"><h2>Réglages</h2>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-bottom:12px">
                    ${SETTINGS.filter((f) => f.bool).map((f) => `<div class="tile toggle-tile ${s[f.k] ? 'on' : ''}" data-lsb="${f.k}"><div><strong>${f.label}</strong><span>${f.help || ''}</span></div><div class="switch"></div></div>`).join('')}
                </div>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(250px,1fr))">
                    ${SETTINGS.filter((f) => !f.bool).map((f) => `<div class="field" style="margin:0"><label>${f.label}${f.unit ? ` (${f.unit})` : ''}</label>
                        <input class="input" type="number" min="0" data-lsf="settings.${f.k}" value="${Number(s[f.k]) || 0}">${f.help ? `<p class="hint" style="margin:4px 0 0">${f.help}</p>` : ''}</div>`).join('')}
                </div>
            </div>
            <div class="section"><h2>Véhicules de service</h2>
                <p class="hint">Sortis depuis une zone « Garage », ils apparaissent sur la zone « Spawn véhicule » la plus proche et se rangent dans une zone « Parking ».</p>
                <table><tr><th>Modèle</th><th>Nom affiché</th><th style="width:220px">Grade minimum</th><th style="width:60px"></th></tr>
                    ${vehicles.map((v, i) => `<tr>
                        <td><input class="input" data-lsf="settings.serviceVehicles.${i}.model" value="${esc(v.model)}" placeholder="flatbed"></td>
                        <td><input class="input" data-lsf="settings.serviceVehicles.${i}.label" value="${esc(v.label)}"></td>
                        <td><select class="input" data-lsf="settings.serviceVehicles.${i}.grade">${d.job.grades.map((g, gi) => `<option value="${gi}" ${gi === Number(v.grade) ? 'selected' : ''}>${gi} · ${esc(g.label)}</option>`).join('')}</select></td>
                        <td><button class="btn danger" data-lsa="vehRemove" data-i="${i}">✕</button></td></tr>`).join('')}
                </table>
                <div class="btn-row" style="margin-top:10px"><button class="btn" data-lsa="vehAdd">+ Ajouter un véhicule</button></div>
            </div>
            <div class="btn-row"><button class="btn primary" data-lsa="saveSettings">Enregistrer la configuration</button><button class="btn" data-lsa="resetSettings">Annuler</button></div>`;
    };

    /* =========================================================
       Saisie : les valeurs sont gardées pendant les rafraîchissements
       ========================================================= */
    const setPath = (path, value) => {
        const parts = path.split('.');
        let o = LS;
        for (let i = 0; i < parts.length - 1; i++) o = o[/^\d+$/.test(parts[i]) ? Number(parts[i]) : parts[i]];
        o[parts[parts.length - 1]] = value;
    };

    document.addEventListener('input', (ev) => {
        if (!isOpen || tab !== 'lscustom') return;
        const t = ev.target;
        if (t.dataset.lsf) {
            const num = t.type === 'number' || t.tagName === 'SELECT' && /grade$/.test(t.dataset.lsf);
            setPath(t.dataset.lsf, t.type === 'checkbox' ? t.checked : num ? Number(t.value) : t.value);
        }
        if (t.dataset.lsp) {
            const [g, key] = t.dataset.lsp.split(':');
            LS.perms[g] = LS.perms[g] || {};
            LS.perms[g][key] = t.checked;
        }
    });

    const zoneFields = (z, withPos) => {
        const types = D.lscustom.zoneTypes.map((t) => ({ value: t.key, label: t.label }));
        const f = [
            { name: 'type', label: 'Type', type: 'select', options: types, value: z ? z.type : 'modification' },
            { name: 'label', label: 'Nom', value: z ? z.label : '', placeholder: 'ex : Atelier principal' },
            { name: 'radius', label: 'Rayon (m)', type: 'number', value: z ? z.radius : 3 },
        ];
        if (withPos) f.push(
            { name: 'x', label: 'X', type: 'number', value: z ? z.x.toFixed(2) : '' },
            { name: 'y', label: 'Y', type: 'number', value: z ? z.y.toFixed(2) : '' },
            { name: 'z', label: 'Z', type: 'number', value: z ? z.z.toFixed(2) : '' },
            { name: 'h', label: 'Heading (0-360)', type: 'number', value: z ? Number(z.h || 0).toFixed(1) : 0 },
        );
        return f;
    };
    const findZone = (id) => D.lscustom.zones.find((z) => z.id === Number(id));

    document.addEventListener('click', async (ev) => {
        if (!isOpen || tab !== 'lscustom') return;
        let n;
        if ((n = ev.target.closest('[data-lss]'))) { LS.sub = n.dataset.lss; return render(); }
        if ((n = ev.target.closest('[data-lzt]'))) { LS.zoneType = n.dataset.lzt; return render(); }
        if ((n = ev.target.closest('[data-lsg]'))) { LS.general[n.dataset.lsg] = !LS.general[n.dataset.lsg]; return render(); }
        if ((n = ev.target.closest('[data-lsb]'))) { LS.settings[n.dataset.lsb] = !LS.settings[n.dataset.lsb]; return render(); }
        if (!(n = ev.target.closest('[data-lsa]')) || n.disabled) return;
        const a = n.dataset.lsa, i = Number(n.dataset.i), d = D.lscustom;

        switch (a) {
            case 'toggleEnabled':
                if (d.enabled && !(await confirmBox('Fermer LsCustom ?', 'Plus aucun mécano ne pourra réparer, modifier ou facturer.'))) return;
                return send('setEnabled', { enabled: !d.enabled });
            case 'saveGeneral': send('saveGeneral', LS.general); LS.general = null; return;
            case 'resetGeneral': LS.general = null; return render();

            case 'gradeAdd': LS.grades.push({ id: '', label: '', payment: 0, isboss: false }); return render();
            case 'gradeRemove': LS.grades.splice(i, 1); return render();
            case 'gradeUp': [LS.grades[i - 1], LS.grades[i]] = [LS.grades[i], LS.grades[i - 1]]; return render();
            case 'gradeDown': [LS.grades[i + 1], LS.grades[i]] = [LS.grades[i], LS.grades[i + 1]]; return render();
            case 'saveGrades':
                if (LS.grades.length < d.job.grades.length && !(await confirmBox('Supprimer des grades ?', 'Les permissions des grades supprimés seront perdues.'))) return;
                send('saveGrades', { grades: LS.grades }); LS.grades = null; LS.perms = null; return;
            case 'resetGrades': LS.grades = null; return render();

            case 'zoneAddHere': {
                const v = await formModal('Nouvelle zone à ma position', zoneFields(null, false), 'Créer');
                if (v) send('addZone', { ...v, useMyPosition: true });
                return;
            }
            case 'zoneAddManual': {
                const v = await formModal('Nouvelle zone (coordonnées)', zoneFields(null, true), 'Créer');
                if (v) send('addZone', v);
                return;
            }
            case 'zoneEdit': {
                const z = findZone(n.dataset.id);
                const v = z && await formModal(`Modifier « ${z.label} »`, zoneFields(z, false), 'Enregistrer');
                if (v) send('updateZone', { id: z.id, ...v });
                return;
            }
            case 'zoneCoords': {
                const z = findZone(n.dataset.id);
                const v = z && await formModal(`Position de « ${z.label} »`, zoneFields(z, true).slice(3), 'Enregistrer');
                if (v) send('updateZone', { id: z.id, ...v });
                return;
            }
            case 'zoneMoveHere': {
                const z = findZone(n.dataset.id);
                if (z && await confirmBox('Déplacer la zone ici ?', `« ${z.label} » sera placée à ta position actuelle.`)) send('updateZone', { id: z.id, useMyPosition: true });
                return;
            }
            case 'zoneToggle': { const z = findZone(n.dataset.id); if (z) send('updateZone', { id: z.id, enabled: z.enabled === false }); return; }
            case 'zoneTp': post('close'); return send('tpZone', { id: Number(n.dataset.id) });
            case 'zoneDelete': {
                const z = findZone(n.dataset.id);
                if (z && await confirmBox('Supprimer la zone ?', `« ${z.label} » (${zoneLabel(z.type)}) sera supprimée.`)) send('deleteZone', { id: z.id });
                return;
            }

            case 'savePrices': send('savePrices', { prices: LS.prices }); LS.prices = null; return;
            case 'resetPrices': LS.prices = null; return render();

            case 'permAll': d.permissions.forEach((p) => { (LS.perms[String(i)] = LS.perms[String(i)] || {})[p.key] = true; }); return render();
            case 'permNone': LS.perms[String(i)] = {}; return render();
            case 'savePerms': send('savePerms', { perms: LS.perms }); LS.perms = null; return;
            case 'resetPerms': LS.perms = null; return render();

            case 'vehAdd': (LS.settings.serviceVehicles = LS.settings.serviceVehicles || []).push({ model: '', label: '', grade: 0 }); return render();
            case 'vehRemove': LS.settings.serviceVehicles.splice(i, 1); return render();
            case 'saveSettings': send('saveSettings', LS.settings); LS.settings = null; return;
            case 'resetSettings': LS.settings = null; return render();
        }
    });
})();
