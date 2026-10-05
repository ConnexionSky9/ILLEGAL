/* =========================================================
   MÉTIERS › CONCESSION
   Structure du métier (ressource elyzea_concess) : informations,
   grades, zones, tenues, permissions, configuration. Le catalogue,
   les employés et les finances sont dans la tablette direction.
   ========================================================= */
(() => {
    TABS.push({
        id: 'concess', group: 5, label: 'Concession', ico: '🚘',
        sub: 'Concession automobile : tablette direction (catalogue, ventes, finances), grades, zones, tenues, permissions.',
        show: () => has('concess_staff') && !!(D && D.concess),
    });

    const SUBS = [
        { id: 'info', label: 'Informations' },
        { id: 'grades', label: 'Grades' },
        { id: 'zones', label: 'Zones' },
        { id: 'uniforms', label: 'Tenues' },
        { id: 'perms', label: 'Permissions' },
        { id: 'config', label: 'Configuration' },
    ];
    const LS = { sub: 'info', general: null, grades: null, perms: null, prices: null, settings: null, zoneType: 'all' };
    const clone = (o) => JSON.parse(JSON.stringify(o));
    const send = (name, data = {}) => action('concess', { name, data });
    const money = (n) => `${Number(n || 0).toLocaleString('fr-FR')} $`;

    const drafts = (d) => {
        if (!LS.general) LS.general = { label: d.job.label, type: d.job.type || '', defaultDuty: !!d.job.defaultDuty, offDutyPay: !!d.job.offDutyPay };
        if (!LS.grades) LS.grades = clone(d.job.grades);
        if (!LS.perms) LS.perms = clone(d.perms || {});
        if (!LS.settings) LS.settings = clone(d.settings || {});
    };
    const zoneLabel = (t) => ((D.concess.zoneTypes || []).find((z) => z.key === t) || {}).label || t;

    VIEWS.concess = () => {
        const d = D.concess;
        if (!d.available) {
            return `<div class="protect">⚠️ <span>La ressource <b>${esc(d.resource || 'elyzea_concess')}</b> n'est pas démarrée.
                Ajoute <span class="keycap">ensure ${esc(d.resource || 'elyzea_concess')}</span> dans server.cfg, après admin_menu.</span></div>`;
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
            <div class="section">
                <div class="duty-bar" style="margin:0 0 14px"><span><b>Tablette direction</b> : catalogue (prix, ajout, masquer), catégories, employés, permissions et finances,
                    avec tous les droits même sans le métier.</span><button class="btn primary" data-lsa="openDirection">📱 Ouvrir la tablette direction</button></div>
            </div>
            <div class="stats">
                <div class="stat"><b>${s.duty}</b><span>Vendeurs en service</span></div>
                <div class="stat"><b>${s.online}</b><span>Vendeurs connectés</span></div>
                <div class="stat"><b>${s.catalog}</b><span>Véhicules au catalogue${s.hidden ? ` · ${s.hidden} masqués` : ''}</span></div>
                <div class="stat"><b>${s.monthSales}</b><span>Ventes (30 j) · ${Number(s.monthTotal || 0).toLocaleString('fr-FR')} $</span></div>
                <div class="stat" data-lss="zones"><b>${s.zones}</b><span>Zones · ${s.presented} véhicule(s) exposé(s), ${s.tests} essai(s)</span></div>
            </div>
            <div class="section"><h2>Métier</h2>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-bottom:12px">
                    <div class="tile toggle-tile ${d.enabled ? 'on' : ''}" data-lsa="toggleEnabled">
                        <div><strong>${d.enabled ? 'Ouverte' : 'Fermée'}</strong><span>${d.enabled ? 'Les vendeurs peuvent vendre.' : 'Plus aucune vente possible.'}</span></div><div class="switch"></div></div>
                    <div class="tile toggle-tile ${g.defaultDuty ? 'on' : ''}" data-lsg="defaultDuty"><div><strong>En service à la connexion</strong><span>Sinon, depuis la tablette ou le bureau.</span></div><div class="switch"></div></div>
                    <div class="tile toggle-tile ${g.offDutyPay ? 'on' : ''}" data-lsg="offDutyPay"><div><strong>Payé hors service</strong><span>Salaire même hors service.</span></div><div class="switch"></div></div>
                </div>
                <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px;max-width:820px">
                    <div class="field"><label>Nom de l'entreprise</label><input class="input" data-lsf="general.label" value="${esc(g.label)}"></div>
                    <div class="field"><label>Identifiant du job</label><input class="input" value="${esc(d.job.name)}" disabled title="Défini dans la config de la ressource"></div>
                    <div class="field"><label>Type</label><input class="input" data-lsf="general.type" value="${esc(g.type)}" placeholder="cardealer"></div>
                </div>
                <div class="btn-row"><button class="btn primary" data-lsa="saveGeneral">Enregistrer</button><button class="btn" data-lsa="resetGeneral">Annuler</button></div>
            </div>
            <div class="section"><h2>Vendeurs connectés (${d.employees.length})</h2>
                ${d.employees.length ? `<table>${d.employees.map((m) => `<tr>
                    <td><strong>[${m.id}] ${esc(m.name)}</strong></td><td class="muted">${esc(m.grade)}</td>
                    <td>${m.onduty ? '<span class="badge" style="color:var(--ok)">En service</span>' : '<span class="badge muted">Hors service</span>'}</td></tr>`).join('')}</table>`
                    : '<div class="empty">Aucun vendeur connecté.</div>'}
            </div>
            ${window.JobTools ? JobTools.sections('concess', 'join') : ''}`;
    };

    /* ---------- Grades ---------- */
    SUBVIEWS.grades = () => `
        <div class="section"><h2>Grades</h2>
            <p class="hint">Le <b>grade</b> est le niveau (0 = le plus bas). Le <b>nom</b> est l'identifiant interne, le <b>label</b> est affiché aux joueurs.
            Les permissions et la remise maximum de chaque grade se règlent dans l'onglet <b>Permissions</b>.</p>
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

    /* ---------- Tenues ---------- */
    SUBVIEWS.uniforms = () => (window.JobTools && JobTools.available('concess')
        ? JobTools.sections('concess', 'uniforms')
        : '<div class="empty">Les tenues ne sont pas disponibles.</div>');

    /* ---------- Permissions ---------- */
    SUBVIEWS.perms = (d) => `
        <div class="section"><h2>Permissions par grade</h2>
            <p class="hint">Coche ce que chaque grade peut faire et fixe sa <b>remise maximum</b>. Vendre, présenter et proposer un essai demandent aussi d'être <b>en service</b>.</p>
            <div style="overflow-x:auto"><table>
                <tr><th>Grade</th>${d.permissions.map((p) => `<th style="text-align:center;font-size:12px">${esc(p.label)}</th>`).join('')}<th style="width:90px">Remise %</th><th></th></tr>
                ${d.job.grades.map((g, i) => {
                    const row = LS.perms[String(i)] || {};
                    return `<tr><td><strong>${i} · ${esc(g.label)}</strong></td>
                        ${d.permissions.map((p) => `<td style="text-align:center"><input type="checkbox" data-lsp="${i}:${p.key}" ${row[p.key] ? 'checked' : ''}></td>`).join('')}
                        <td><input class="input" type="number" min="0" max="100" data-lsf="perms.${i}.discount" value="${Number(row.discount) || 0}"></td>
                        <td style="text-align:right;white-space:nowrap"><button class="btn" data-lsa="permAll" data-i="${i}">Tout</button><button class="btn" data-lsa="permNone" data-i="${i}">Rien</button></td></tr>`;
                }).join('')}
            </table></div>
            <div class="btn-row" style="margin-top:12px"><button class="btn primary" data-lsa="savePerms">Enregistrer les permissions</button><button class="btn" data-lsa="resetPerms">Annuler</button></div>
        </div>`;

    /* ---------- Configuration ---------- */
    const SETTINGS = [
        { k: 'commission', label: 'Commission du vendeur', unit: '%', help: 'Part de chaque vente versée au vendeur ; le reste va au compte de l\'entreprise.' },
        { k: 'offerTimeout', label: 'Temps pour accepter une proposition', unit: 's' },
        { k: 'societyDeposit', label: 'Verser au compte de l\'entreprise', bool: true, help: 'Renewed-Banking.' },
        { k: 'ownGarage', label: 'Garage de la concession', bool: true, help: 'Désactive-le si tu utilises qbx_garages.' },
        { k: 'showBlip', label: 'Icône sur la carte', bool: true, help: 'Sur le podium du showroom.' },
    ];
    SUBVIEWS.config = () => {
        const s = LS.settings;
        return `
            <div class="section"><h2>Réglages</h2>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-bottom:12px">
                    ${SETTINGS.filter((f) => f.bool).map((f) => `<div class="tile toggle-tile ${s[f.k] ? 'on' : ''}" data-lsb="${f.k}"><div><strong>${f.label}</strong><span>${f.help || ''}</span></div><div class="switch"></div></div>`).join('')}
                </div>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(250px,1fr))">
                    ${SETTINGS.filter((f) => !f.bool).map((f) => `<div class="field" style="margin:0"><label>${f.label}${f.unit ? ` (${f.unit})` : ''}</label>
                        <input class="input" type="number" min="0" data-lsf="settings.${f.k}" value="${Number(s[f.k]) || 0}">${f.help ? `<p class="hint" style="margin:4px 0 0">${f.help}</p>` : ''}</div>`).join('')}
                    <div class="field" style="margin:0"><label>Début des plaques (1 à 4 lettres)</label><input class="input" data-lsf="settings.platePrefix" value="${esc(s.platePrefix || 'EL')}" maxlength="4"></div>
                    <div class="field" style="margin:0"><label>Véhicule vendu</label><select class="input" data-lsf="settings.delivery">
                        <option value="spawn" ${s.delivery !== 'garage' ? 'selected' : ''}>Livré sur le parking avec les clés</option>
                        <option value="garage" ${s.delivery === 'garage' ? 'selected' : ''}>Rangé directement au garage</option></select></div>
                </div>
            </div>
            <div class="btn-row"><button class="btn primary" data-lsa="saveSettings">Enregistrer la configuration</button><button class="btn" data-lsa="resetSettings">Annuler</button></div>`;
    };

    /* =========================================================
       Saisie : les valeurs sont gardées pendant les rafraîchissements
       ========================================================= */
    const setPath = (path, value) => {
        const parts = path.split('.');
        let o = LS;
        for (let i = 0; i < parts.length - 1; i++) {
            const k = /^\d+$/.test(parts[i]) && Array.isArray(o) ? Number(parts[i]) : parts[i];
            if (o[k] === undefined) o[k] = {};
            o = o[k];
        }
        o[parts[parts.length - 1]] = value;
    };

    document.addEventListener('input', (ev) => {
        if (!isOpen || tab !== 'concess') return;
        const t = ev.target;
        if (t.dataset.lsf) {
            const num = t.type === 'number';
            setPath(t.dataset.lsf, t.type === 'checkbox' ? t.checked : num ? Number(t.value) : t.value);
        }
        if (t.dataset.lsp) {
            const [g, key] = t.dataset.lsp.split(':');
            LS.perms[g] = LS.perms[g] || {};
            LS.perms[g][key] = t.checked;
        }
    });

    const zoneFields = (z, withPos) => {
        const types = D.concess.zoneTypes.map((t) => ({ value: t.key, label: t.label }));
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
    const findZone = (id) => D.concess.zones.find((z) => z.id === Number(id));

    document.addEventListener('click', async (ev) => {
        if (!isOpen || tab !== 'concess') return;
        let n;
        if ((n = ev.target.closest('[data-lss]'))) { LS.sub = n.dataset.lss; return render(); }
        if ((n = ev.target.closest('[data-lzt]'))) { LS.zoneType = n.dataset.lzt; return render(); }
        if ((n = ev.target.closest('[data-lsg]'))) { LS.general[n.dataset.lsg] = !LS.general[n.dataset.lsg]; return render(); }
        if ((n = ev.target.closest('[data-lsb]'))) { LS.settings[n.dataset.lsb] = !LS.settings[n.dataset.lsb]; return render(); }
        if (!(n = ev.target.closest('[data-lsa]')) || n.disabled) return;
        const a = n.dataset.lsa, i = Number(n.dataset.i), d = D.concess;

        switch (a) {
            case 'openDirection': post('close'); return send('openDirection');
            case 'toggleEnabled':
                if (d.enabled && !(await confirmBox('Fermer la concession ?', 'Plus aucun vendeur ne pourra vendre, présenter ou proposer un essai.'))) return;
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


            case 'permAll': d.permissions.forEach((p) => { (LS.perms[String(i)] = LS.perms[String(i)] || {})[p.key] = true; }); return render();
            case 'permNone': LS.perms[String(i)] = { discount: (LS.perms[String(i)] || {}).discount || 0 }; return render();
            case 'savePerms': send('savePerms', { perms: LS.perms }); LS.perms = null; return;
            case 'resetPerms': LS.perms = null; return render();

            case 'saveSettings': send('saveSettings', LS.settings); LS.settings = null; return;
            case 'resetSettings': LS.settings = null; return render();
        }
    });
})();
