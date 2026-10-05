/* =========================================================
   ONGLET ÉVÉNEMENTS › GOFAST
   Chargé après script.js : utilise ses fonctions (render, toast,
   formModal, confirmBox, esc, has, any, D, VIEWS, TABS).
   ========================================================= */
(() => {
    'use strict';

    const gfPost = (name, data = {}) => post('gofast', { name, data });
    const canManage = () => has('gofast_manage');
    const canMissions = () => has('gofast_missions');

    // ---------- Onglet Événements (partagé par tous les événements) ----------
    // Chaque événement s'inscrit dans window.AM_EVENTS : { id, label, show(), render() }
    const EVENTS = window.AM_EVENTS = window.AM_EVENTS || [];
    const EVT = window.AM_EVENT_STATE = window.AM_EVENT_STATE || { current: null };
    const editorIndex = TABS.findIndex((t) => t.id === 'editor');
    TABS.splice(editorIndex + 1, 0, {
        id: 'events', group: 3, label: 'Événements', ico: '🎯',
        sub: 'Événements du serveur : GoFast, attaque de zombies et largage de drops.',
        show: () => EVENTS.some((e) => e.show()),
    });
    VIEWS.events = () => {
        const list = EVENTS.filter((e) => e.show());
        if (!list.length) return '<div class="empty">Aucun événement disponible.</div>';
        if (!list.find((e) => e.id === EVT.current)) EVT.current = list[0].id;
        const head = `<div class="segmented evt-switch">${list.map((e) => `<button class="seg ${e.id === EVT.current ? 'active' : ''}" data-evt="${e.id}">${e.label}</button>`).join('')}</div>`;
        return head + list.find((e) => e.id === EVT.current).render();
    };

    // ---------- État local (survit aux rafraîchissements) ----------
    const GF = {
        event: 'gofast',
        sub: null,
        edit: null,          // brouillon du contact ouvert
        dlgCat: 'greet',
        openVeh: {},         // [index emplacement] = liste des points véhicule dépliée
        fresh: { label: '', subtitle: '', model: '', scenario: '', locationLabel: '' },
        tierId: null,
        tierDraft: null,
        settingsDraft: null,
        dest: { label: '', zone: '', customZone: '' },
        player: { target: '', value: '', info: null },
        pendingSelect: null,
    };

    const SUBS = [
        { id: 'overview', label: '📊 Vue d\'ensemble', show: () => true },
        { id: 'contacts', label: '🧑 Contacts (PNJ)', show: canManage },
        { id: 'tiers', label: '📦 Contrats', show: canManage },
        { id: 'destinations', label: '📍 Destinations', show: canManage },
        { id: 'settings', label: '⚙️ Réglages', show: canManage },
        { id: 'missions', label: '🚨 Missions et joueurs', show: canMissions },
    ];

    const ROTATION = {
        fixed: 'Ne bouge pas',
        sequential: 'Tour à tour (dans l\'ordre)',
        random: 'Au hasard',
    };

    // ---------- Outils ----------
    // Une table Lua vide peut arriver en objet {} : toutes les listes sont normalisées à la réception
    const toArr = (v) => (Array.isArray(v) ? v : (v && typeof v === 'object' ? Object.values(v) : []));
    function normalize(g) {
        if (!g || g.available === false || g.__normalized) return;
        ['settings', 'tiers', 'tierSchema', 'contacts', 'destinations', 'zones', 'missions', 'dialogueCategories'].forEach((k) => { g[k] = toArr(g[k]); });
        g.tiers.forEach((t) => { t.zones = toArr(t.zones); });
        g.contacts.forEach((c) => {
            c.tiers = toArr(c.tiers);
            c.locations = toArr(c.locations);
            c.locations.forEach((l) => { l.vehicles = toArr(l.vehicles); });
            const dl = c.dialogues && typeof c.dialogues === 'object' ? c.dialogues : {};
            g.dialogueCategories.forEach((cat) => { dl[cat.id] = toArr(dl[cat.id]); });
            c.dialogues = dl;
        });
        const defaults = g.defaultDialogues && typeof g.defaultDialogues === 'object' ? g.defaultDialogues : {};
        Object.keys(defaults).forEach((k) => { defaults[k] = toArr(defaults[k]); });
        g.defaultDialogues = defaults;
        g.__normalized = true;
    }
    const G = () => (D && D.gofast) || null;
    const serverNow = () => {
        const g = G();
        if (!g || !g.now) return Math.floor(Date.now() / 1000);
        if (GF.nowSync !== g.now) { GF.nowSync = g.now; GF.offset = g.now - Math.floor(Date.now() / 1000); }
        return Math.floor(Date.now() / 1000) + (GF.offset || 0);
    };
    const inTime = (epoch) => {
        if (!epoch) return '—';
        const s = epoch - serverNow();
        if (s <= 0) return 'imminent';
        if (s < 60) return `${s} s`;
        if (s < 3600) return `${Math.round(s / 60)} min`;
        return `${Math.floor(s / 3600)} h ${String(Math.round((s % 3600) / 60)).padStart(2, '0')}`;
    };
    const coordTxt = (p) => `${Number(p.x).toFixed(1)}, ${Number(p.y).toFixed(1)}, ${Number(p.z).toFixed(1)}`;
    const tierLabel = (id) => { const t = (G().tiers || []).find((x) => x.id === id); return t ? t.values.label : id; };
    const getContact = (id) => (G().contacts || []).find((c) => c.id === id);
    const tog = (on, attrs, title, sub) => `<div class="tile toggle-tile ${on ? 'on' : ''}" ${attrs}><div><strong>${title}</strong><span>${sub}</span></div><div class="switch"></div></div>`;

    function setPath(path, value) {
        const parts = path.split('.');
        let node = GF;
        for (let i = 0; i < parts.length - 1; i += 1) {
            if (node[parts[i]] === undefined || node[parts[i]] === null) return;
            node = node[parts[i]];
        }
        node[parts[parts.length - 1]] = value;
    }

    function contactIssues(c) {
        const issues = [];
        if (!c.locations.length) issues.push('aucun emplacement');
        else {
            const cur = c.locations[(c.current || 1) - 1];
            if (cur && !cur.vehicles.length) issues.push('pas de point véhicule à l\'emplacement actuel');
        }
        if (!c.tiers.length) issues.push('aucun contrat proposé');
        return issues;
    }

    function toEdit(c) {
        const dialogues = {};
        (G().dialogueCategories || []).forEach((cat) => { dialogues[cat.id] = [...((c.dialogues || {})[cat.id] || [])]; });
        return {
            id: c.id, label: c.label, subtitle: c.subtitle || '', model: c.model, scenario: c.scenario || '',
            enabled: c.enabled !== false, blip: c.blip !== false, marker: c.marker !== false,
            blipSprite: c.blipSprite ?? 500, blipColor: c.blipColor ?? 47,
            tiers: [...(c.tiers || [])],
            rotation: { ...(c.rotation || { mode: 'fixed', intervalMin: 30, intervalMax: 30, onlyWhenAlone: true }) },
            dialogues, dirty: false,
        };
    }

    // =====================================================
    //  RENDU
    // =====================================================
    EVENTS.push({ id: 'gofast', label: '🏎️ GoFast', show: () => any('gofast_manage', 'gofast_missions'), render: goFastView });
    function goFastView() {
        const g = G();
        const head = '';
        if (!g) return `${head}<div class="empty">Chargement…</div>`;
        if (!g.available) {
            return `${head}<div class="gf-off">
                <div class="gf-off-ico">🏎️</div>
                <h2>La ressource « ${esc(g.resource || 'gofast')} » n'est pas démarrée</h2>
                <p class="muted">Vérifie qu'elle est dans <span class="keycap">resources/</span> et que <span class="keycap">ensure ${esc(g.resource || 'gofast')}</span>
                est dans server.cfg (après admin_menu). L'onglet se remplira tout seul dès qu'elle démarre.</p></div>`;
        }
        const subs = SUBS.filter((s) => s.show());
        if (!subs.find((s) => s.id === GF.sub)) GF.sub = subs[0].id;
        const nav = `<div class="segmented gf-subs">${subs.map((s) => `<button class="seg ${s.id === GF.sub ? 'active' : ''}" data-gfsub="${s.id}">${s.label}</button>`).join('')}</div>`;
        const views = { overview, contacts, tiers, destinations, settings, missions };
        return head + nav + views[GF.sub]();
    }

    // ---------- Vue d'ensemble ----------
    function overview() {
        const g = G();
        const active = g.contacts.filter((c) => c.active).length;
        const problems = g.contacts.map((c) => ({ c, issues: contactIssues(c) })).filter((x) => x.issues.length && x.c.enabled !== false);
        const stat = (n, label, sub, alert) => `<button class="stat ${alert ? 'alert' : ''}" ${sub ? `data-gfsub="${sub}"` : ''}><b>${n}</b><span>${label}</span></button>`;
        return `
            <div class="gf-status ${g.enabled ? 'on' : 'off'}">
                <div><strong>${g.enabled ? '🟢 Réseau GoFast ouvert' : '🔴 Réseau GoFast fermé'}</strong>
                <span>${g.enabled ? 'Les contacts sont en place et proposent leurs contrats.' : 'Les contacts ont disparu : aucun nouveau Go Fast possible. Les missions en cours continuent.'}</span></div>
                ${canManage() ? `<button class="btn ${g.enabled ? 'danger' : 'primary'}" data-gf="toggle">${g.enabled ? 'Fermer le réseau' : 'Ouvrir le réseau'}</button>` : ''}
            </div>
            <div class="stats">
                ${stat(`${active}/${g.contacts.length}`, 'Contacts actifs', canManage() ? 'contacts' : null)}
                ${stat(g.missions.length, 'Go Fast en cours', canMissions() ? 'missions' : null)}
                ${stat(g.tiers.filter((t) => t.values.enabled).length, 'Contrats proposés', canManage() ? 'tiers' : null)}
                ${stat(g.destinations.length, 'Destinations', canManage() ? 'destinations' : null, g.destinations.length < 4)}
            </div>
            ${problems.length ? `<div class="section"><h2>⚠️ À corriger</h2>
                ${problems.map((x) => `<div class="gf-warn"><span><b>${esc(x.c.label)}</b> : ${x.issues.join(', ')}.</span>
                    ${canManage() ? `<button class="btn" data-gf="open" data-id="${esc(x.c.id)}">Corriger</button>` : ''}</div>`).join('')}</div>` : ''}
            ${!g.contacts.length && canManage() ? `<div class="section"><h2>Bien démarrer</h2>
                <div class="steps gf-steps"><span><b>1</b>Va à l'endroit voulu</span><span><b>2</b>Contacts › crée le PNJ à ta position</span>
                <span><b>3</b>Ajoute d'autres emplacements et ses répliques</span></div>
                <button class="btn primary big" data-gfsub="contacts">Créer mon premier contact</button></div>` : ''}
            ${canMissions() ? `<div class="section"><h2>Missions en cours</h2>${missionTable(5)}</div>` : ''}`;
    }

    // ---------- Contacts ----------
    function contacts() {
        if (GF.edit) {
            if (!getContact(GF.edit.id)) { GF.edit = null; } else return contactEditor();
        }
        const g = G(), cfg = D.config.editor || {};
        const f = GF.fresh;
        const scenarios = cfg.scenarios || [];
        const editorPeds = (canEditor() && has('editor_peds') && D.editor && D.editor.peds) ? D.editor.peds.filter((p) => !p.npc) : [];

        return `<div class="section"><h2>Créer un contact</h2>
            <p class="hint">Place-toi <b>exactement</b> là où le PNJ doit se tenir, tourné dans la direction où il doit regarder, puis crée-le.
            Un point d'apparition du véhicule est ajouté tout seul sur la route la plus proche ; tu pourras en ajouter d'autres (parking, garage…).</p>
            <div class="form-grid gf-grid-3">
                <div><label>Nom du contact</label><input class="input" data-gfv="fresh.label" value="${esc(f.label)}" placeholder="ex : Le Mécano"></div>
                <div><label>Sous-titre (optionnel)</label><input class="input" data-gfv="fresh.subtitle" value="${esc(f.subtitle)}" placeholder="ex : Garage de Davis"></div>
                <div><label>Nom de l'emplacement (optionnel)</label><input class="input" data-gfv="fresh.locationLabel" value="${esc(f.locationLabel)}" placeholder="ex : Arrière du garage"></div>
                <div><label>Apparence (modèle)</label><input class="input" data-gfv="fresh.model" value="${esc(f.model)}" placeholder="${esc(g.defaults.model)}"></div>
                <div><label>Animation</label><select class="input" data-gfv="fresh.scenario">
                    <option value="">Par défaut (${esc(g.defaults.scenario || 'aucune')})</option>
                    ${scenarios.map((x) => `<option value="${esc(x.id)}" ${f.scenario === x.id && x.id !== '' ? 'selected' : ''}>${esc(x.label)}</option>`).join('')}</select></div>
                <div style="display:flex;align-items:flex-end"><button class="btn primary big" style="width:100%" data-gf="create">➕ Créer à ma position</button></div>
            </div>
            <div class="chips">${(cfg.quickPeds || []).map((m) => `<button class="chip ${f.model === m ? 'chip-on' : ''}" data-gfmodel="${esc(m)}">${esc(m)}</button>`).join('')}</div>
            <p class="hint" style="margin-top:8px">Tous les personnages : Éditeur de map › 📚 Catalogue › Personnages, bouton « Copier le nom ».</p>
        </div>

        ${editorPeds.length ? `<div class="section"><h2>Utiliser un PNJ déjà posé</h2>
            <p class="hint">Transforme un PNJ « Décor » de l'éditeur de map en contact GoFast : il garde son apparence, son animation et sa place.
            Pour un point véhicule automatique, place-toi près de lui avant de le convertir.</p>
            <table>${editorPeds.sort(byDist).slice(0, 12).map((p) => `<tr><td><strong>${esc(p.name || p.model)}</strong> <span class="muted">${esc(p.model)}</span></td>
                <td class="muted">${distTxt(p.dist)}</td>
                <td style="text-align:right;white-space:nowrap"><button class="btn" data-ed="tp" data-kind="ped" data-id="${p.id}">Y aller</button>
                <button class="btn primary" data-gf="import_ped" data-id="${p.id}">🏎️ En faire un contact</button></td></tr>`).join('')}</table></div>` : ''}

        <div class="section"><h2>Contacts (${g.contacts.length}/${g.limits.contacts})</h2>
        ${!g.contacts.length ? '<div class="empty">Aucun contact. Crée le premier ci-dessus.</div>' : g.contacts.map(contactCard).join('')}</div>`;
    }

    function contactCard(c) {
        const issues = contactIssues(c);
        const cur = c.locations[(c.current || 1) - 1];
        const rot = c.rotation || {};
        const moving = rot.mode !== 'fixed' && c.locations.length > 1;
        const badge = c.enabled === false ? '<span class="badge muted">Désactivé</span>'
            : issues.length ? '<span class="badge" style="color:var(--danger)">À corriger</span>'
                : '<span class="badge" style="color:var(--ok)">Actif</span>';
        return `<div class="card gf-card">
            <div class="card-head"><strong>${esc(c.label)} ${badge}</strong><span class="muted">${esc(c.model)}</span></div>
            <div class="recipe-preview">
                <span>📍 ${cur ? `Emplacement ${c.current}/${c.locations.length}${cur.label ? ` : <b>${esc(cur.label)}</b>` : ''} · ${cur.vehicles.length} point(s) véhicule` : '<span style="color:var(--danger)">Aucun emplacement</span>'}</span>
                <span>🔁 ${moving ? `${esc(ROTATION[rot.mode])}, toutes les ${rot.intervalMin === rot.intervalMax ? rot.intervalMin : `${rot.intervalMin} à ${rot.intervalMax}`} min · prochain déplacement : <b>${inTime(c.nextMoveAt)}</b>${rot.onlyWhenAlone ? ' (quand personne n\'est autour)' : ''}`
        : 'Ne bouge pas'}</span>
                <span>📦 ${c.tiers.length ? c.tiers.map((t) => esc(tierLabel(t))).join(', ') : '<span style="color:var(--danger)">Aucun contrat</span>'}</span>
                ${issues.length ? `<span style="color:var(--danger)">⚠️ ${issues.join(', ')}</span>` : ''}
            </div>
            <div class="btn-row">
                <button class="btn primary" data-gf="open" data-id="${esc(c.id)}">Modifier</button>
                ${cur ? `<button class="btn" data-gf="tp" data-id="${esc(c.id)}">Y aller</button>` : ''}
                ${c.locations.length > 1 ? `<button class="btn" data-gf="move_now" data-id="${esc(c.id)}">Le déplacer maintenant</button>` : ''}
                <button class="btn danger" data-gf="contact_delete" data-id="${esc(c.id)}">Supprimer</button>
            </div></div>`;
    }

    function contactEditor() {
        const e = GF.edit, g = G(), c = getContact(e.id), cfg = D.config.editor || {};
        const cats = g.dialogueCategories || [];
        if (!cats.find((x) => x.id === GF.dlgCat)) GF.dlgCat = cats[0] ? cats[0].id : 'greet';
        const cat = cats.find((x) => x.id === GF.dlgCat) || { id: GF.dlgCat, label: '', hint: '' };
        const lines = e.dialogues[GF.dlgCat] || [];
        const defaults = (g.defaultDialogues || {})[GF.dlgCat] || [];
        const rot = e.rotation;

        return `<div class="btn-row gf-sticky">
                <button class="btn" data-gf="close_edit">← Retour aux contacts</button>
                <button class="btn primary" data-gf="save_contact">${e.dirty ? '💾 Enregistrer les modifications' : 'Enregistré'}</button>
                ${e.dirty ? '<button class="btn" data-gf="reset_edit">Annuler les modifications</button>' : ''}
                <span class="muted" style="align-self:center">${e.dirty ? 'Modifications non enregistrées' : ''}</span>
            </div>
            <h2 class="sub-h">${esc(c.label)} <span class="muted" style="font-size:14px">${esc(c.id)}</span></h2>

            <div class="section"><h2>Identité</h2>
                <div class="form-grid gf-grid-3">
                    <div><label>Nom</label><input class="input" data-gfe="label" value="${esc(e.label)}"></div>
                    <div><label>Sous-titre (sinon : nom de l'emplacement)</label><input class="input" data-gfe="subtitle" value="${esc(e.subtitle)}"></div>
                    <div><label>Animation</label><select class="input" data-gfe="scenario">
                        ${(cfg.scenarios || []).map((x) => `<option value="${esc(x.id)}" ${e.scenario === x.id ? 'selected' : ''}>${esc(x.label)}</option>`).join('')}
                        ${e.scenario && !(cfg.scenarios || []).find((x) => x.id === e.scenario) ? `<option value="${esc(e.scenario)}" selected>${esc(e.scenario)}</option>` : ''}</select></div>
                    <div><label>Apparence (modèle)</label><input class="input" data-gfe="model" value="${esc(e.model)}"></div>
                    <div><label>Icône sur la carte (n° de blip)</label><input class="input" type="number" min="1" max="900" data-gfe="blipSprite" value="${esc(e.blipSprite)}"></div>
                    <div><label>Couleur de l'icône (0 à 85)</label><input class="input" type="number" min="0" max="85" data-gfe="blipColor" value="${esc(e.blipColor)}"></div>
                </div>
                <div class="chips" style="margin-bottom:12px">${(cfg.quickPeds || []).map((m) => `<button class="chip ${e.model === m ? 'chip-on' : ''}" data-gfemodel="${esc(m)}">${esc(m)}</button>`).join('')}</div>
                <div class="grid gf-toggles">
                    ${tog(e.enabled, 'data-gfet="enabled"', 'Contact actif', 'Désactivé, il disparaît du jeu')}
                    ${tog(e.blip, 'data-gfet="blip"', 'Visible sur la carte', 'Sinon, les joueurs doivent le trouver')}
                    ${tog(e.marker, 'data-gfet="marker"', 'Cercle au sol', 'Repère à ses pieds')}
                </div>
            </div>

            <div class="section"><h2>Contrats qu'il propose</h2>
                <div class="grid gf-toggles">${g.tiers.map((t) => tog(e.tiers.includes(t.id), `data-gftier="${esc(t.id)}"`,
        esc(t.values.label), `Niveau ${t.values.minLevel} · risque ${'›'.repeat(t.risk)}${t.values.enabled ? '' : ' · désactivé partout'}`)).join('')}</div>
            </div>

            <div class="section"><h2>Emplacements (${c.locations.length}/${g.limits.locations})</h2>
                <p class="hint">Le PNJ se tient à un seul emplacement à la fois. Chaque emplacement a ses <b>points véhicule</b> : là où apparaît la voiture du Go Fast.
                Ajouter un emplacement ou un point se fait <b>à ta position actuelle</b> (pour un point véhicule, monte dans une voiture garée au bon endroit : sa position exacte est reprise).</p>
                ${c.locations.length ? `<table class="gf-locs">${c.locations.map((l, i) => locationRow(c, l, i + 1)).join('')}</table>` : '<div class="empty">Aucun emplacement : le PNJ n\'apparaît nulle part.</div>'}
                <div class="inline" style="max-width:620px;margin-top:12px">
                    <input class="input" placeholder="Nom du nouvel emplacement (optionnel)" data-gfv="newLoc" value="${esc(GF.newLoc || '')}">
                    <button class="btn primary" data-gf="loc_add" style="white-space:nowrap">📍 Ajouter ma position</button>
                </div>
            </div>

            <div class="section"><h2>Déplacements automatiques</h2>
                <p class="hint">Le contact change d'emplacement tout seul. Avec « quand personne n'est autour », il attend qu'aucun joueur ne soit à proximité pour ne pas disparaître sous ses yeux.</p>
                <div class="form-grid gf-grid-3">
                    <div><label>Comment il bouge</label><select class="input" data-gfe="rotation.mode" data-gfr="1">
                        ${Object.entries(ROTATION).map(([k, l]) => `<option value="${k}" ${rot.mode === k ? 'selected' : ''}>${l}</option>`).join('')}</select></div>
                    ${rot.mode !== 'fixed' ? `
                    <div><label>Toutes les … minutes (min)</label><input class="input" type="number" min="1" max="1440" data-gfe="rotation.intervalMin" value="${esc(rot.intervalMin)}"></div>
                    <div><label>… à … minutes (max, au hasard entre les deux)</label><input class="input" type="number" min="1" max="1440" data-gfe="rotation.intervalMax" value="${esc(rot.intervalMax)}"></div>` : '<div></div><div></div>'}
                </div>
                ${rot.mode !== 'fixed' ? `<div class="grid gf-toggles">${tog(rot.onlyWhenAlone, 'data-gfet="rotation.onlyWhenAlone"', 'Seulement quand personne n\'est autour', 'Évite qu\'il disparaisse devant un joueur')}</div>
                    ${c.locations.length < 2 ? '<p class="hint" style="color:var(--danger);margin-top:10px">Ajoute au moins 2 emplacements pour qu\'il puisse bouger.</p>'
        : `<p class="hint" style="margin-top:10px">Prochain déplacement : <b>${inTime(c.nextMoveAt)}</b> (recalculé à l'enregistrement si tu changes le mode).</p>`}` : ''}
            </div>

            <div class="section"><h2>Dialogues</h2>
                <p class="hint">Le contact dit une réplique au hasard parmi la liste. Variables : <span class="keycap">{joueur}</span> <span class="keycap">{contact}</span>
                <span class="keycap">{niveau}</span> <span class="keycap">{palier}</span> <span class="keycap">{temps}</span> (attente restante).
                Liste vide = répliques par défaut de config.lua.</p>
                <div class="segmented">${cats.map((x) => `<button class="seg ${x.id === GF.dlgCat ? 'active' : ''}" data-gfcat="${esc(x.id)}">${esc(x.label)} <span class="muted">${(e.dialogues[x.id] || []).length || '·'}</span></button>`).join('')}</div>
                <p class="hint">${esc(cat.hint)}</p>
                ${lines.map((line, i) => `<div class="gf-line">
                    <textarea class="input" rows="2" maxlength="${g.limits.lineLength}" data-gfdlg="${i}">${esc(line)}</textarea>
                    <button class="sb-close" title="Supprimer" data-gf="dlg_del" data-i="${i}">✕</button></div>`).join('')}
                ${!lines.length ? `<div class="gf-defaults"><span class="muted">Répliques par défaut utilisées :</span>${defaults.map((d) => `<div>« ${esc(d)} »</div>`).join('') || '<div class="muted">aucune</div>'}</div>` : ''}
                <div class="btn-row" style="margin-top:10px">
                    <button class="btn" data-gf="dlg_add" ${lines.length >= g.limits.lines ? 'disabled' : ''}>+ Ajouter une réplique</button>
                    ${!lines.length && defaults.length ? '<button class="btn" data-gf="dlg_copy">Partir des répliques par défaut</button>' : ''}
                </div>
            </div>
            <div class="btn-row" style="margin-bottom:20px">
                <button class="btn primary big" data-gf="save_contact">💾 Enregistrer</button>
                <button class="btn danger" data-gf="contact_delete" data-id="${esc(c.id)}">Supprimer ce contact</button>
            </div>`;
    }

    function locationRow(c, l, index) {
        const isCurrent = index === (c.current || 1);
        const open = GF.openVeh[`${c.id}:${index}`];
        return `<tr class="${isCurrent ? 'gf-current' : ''}">
            <td style="width:34px"><b>${index}</b></td>
            <td><input class="input gf-loc-name" value="${esc(l.label)}" placeholder="Sans nom" data-gflocname="${index}">
                <div class="muted gf-small">${coordTxt(l)}${isCurrent ? ' · <b style="color:var(--ok)">le PNJ est ici</b>' : ''}</div></td>
            <td><button class="btn ${l.vehicles.length ? '' : 'danger'}" data-gf="toggle_veh" data-i="${index}">🚗 ${l.vehicles.length} point(s) véhicule</button></td>
            <td style="text-align:right;white-space:nowrap">
                ${!isCurrent ? `<button class="btn" data-gf="move_now" data-id="${esc(c.id)}" data-i="${index}" title="Le PNJ apparaît ici tout de suite">Faire venir ici</button>` : ''}
                <button class="btn" data-gf="tp" data-id="${esc(c.id)}" data-i="${index}">Y aller</button>
                <button class="btn" data-gf="loc_here" data-i="${index}" title="Remplace la position par la tienne">Mettre à ma position</button>
                <button class="btn danger" data-gf="loc_remove" data-i="${index}">✕</button></td></tr>
            ${open ? `<tr class="gf-vehs"><td></td><td colspan="3">
                ${l.vehicles.map((v, vi) => `<div class="gf-veh"><span>🚗 Point ${vi + 1} <span class="muted">${coordTxt(v)} · ${Math.round(v.h)}°</span></span>
                    <span><button class="btn" data-gf="tp_veh" data-i="${index}" data-v="${vi + 1}">Y aller</button>
                    <button class="btn danger" data-gf="veh_remove" data-i="${index}" data-v="${vi + 1}">✕</button></span></div>`).join('') || '<div class="muted">Aucun point : les missions ne peuvent pas démarrer depuis cet emplacement.</div>'}
                <button class="btn primary" style="margin-top:8px" data-gf="veh_add" data-i="${index}">➕ Ajouter un point véhicule (ma position / mon véhicule)</button>
            </td></tr>` : ''}`;
    }

    // ---------- Contrats (paliers) ----------
    function tiers() {
        const g = G();
        if (GF.tierId) {
            const t = g.tiers.find((x) => x.id === GF.tierId);
            if (t) return tierEditor(t);
            GF.tierId = null;
        }
        return `<p class="hint">Les contrats sont les types de Go Fast proposés par les contacts. Les modifications s'appliquent aux <b>nouvelles</b> missions.</p>
            ${g.tiers.map((t) => {
        const v = t.values;
        return `<div class="card gf-card">
                <div class="card-head"><strong>${esc(v.label)} ${v.enabled ? '' : '<span class="badge muted">Désactivé</span>'} ${t.changed ? '<span class="badge" style="color:var(--signal)">Modifié</span>' : ''}</strong>
                    <span class="muted">${'›'.repeat(t.risk)} risque ${t.risk}/5</span></div>
                <div class="field-stats">
                    <span>Niveau <b>${v.minLevel}</b></span><span>Paie <b>${v.rewardMin} – ${v.rewardMax}</b> + ${v.perKm}/km</span>
                    <span>Livraisons <b>${v.dropsMin === v.dropsMax ? v.dropsMin : `${v.dropsMin}-${v.dropsMax}`}</b></span><span>XP <b>+${v.xp}</b></span>
                    <span>Police <b>${v.policeChance} %</b> (${v.minCops} requis)</span><span>Rare <b>${v.rareChance} %</b></span>
                    <span>Zones <b>${esc((t.zones || []).join(', '))}</b></span>
                </div>
                <div class="btn-row"><button class="btn primary" data-gf="tier_open" data-id="${esc(t.id)}">Modifier</button>
                    <button class="btn" data-gf="tier_toggle" data-id="${esc(t.id)}">${v.enabled ? 'Désactiver' : 'Activer'}</button></div></div>`;
    }).join('')}`;
    }

    function tierEditor(t) {
        const g = G(), d = GF.tierDraft;
        const field = (f) => {
            if (f.type === 'bool') return '';
            const label = `${esc(f.label)}${f.type === 'percent' ? '' : ''}`;
            const attrs = f.type === 'string' ? `maxlength="${f.max || 60}"` : `type="number" ${f.min !== undefined ? `min="${f.min}"` : ''} ${f.max !== undefined ? `max="${f.max}"` : ''} step="${f.type === 'int' ? 1 : 0.1}"`;
            return `<div class="${f.key === 'description' ? 'gf-wide' : ''}"><label>${label}</label><input class="input" ${attrs} data-gfv="tierDraft.${f.key}" value="${esc(d[f.key])}"></div>`;
        };
        return `<div class="btn-row gf-sticky"><button class="btn" data-gf="tier_close">← Retour aux contrats</button>
                <button class="btn primary" data-gf="tier_save">💾 Enregistrer</button>
                ${t.changed ? '<button class="btn" data-gf="tier_reset">Valeurs par défaut</button>' : ''}</div>
            <h2 class="sub-h">${esc(t.values.label)} <span class="muted" style="font-size:14px">${esc(t.id)}</span></h2>
            <div class="grid gf-toggles" style="margin-bottom:14px">${tog(d.enabled, 'data-gftd="enabled"', 'Proposé aux joueurs', 'Désactivé : aucun contact ne le propose')}</div>
            <div class="form-grid gf-grid-3">${g.tierSchema.map(field).join('')}</div>
            <p class="hint">Paie finale = paie de base (tirée entre min et max) + km × paie par km, puis bonus de niveau, rapidité et points de passage, moins les dégâts.
                Temps limite = temps de base + km × temps par km. Niveau max actuel : ${g.maxLevel}.</p>`;
    }

    // ---------- Destinations ----------
    function destinations() {
        const g = G(), d = GF.dest;
        const zoneOpts = g.zones.map((z) => `<option value="${esc(z)}" ${d.zone === z ? 'selected' : ''}>${esc(z)}</option>`).join('');
        return `<div class="section"><h2>Ajouter une destination</h2>
            <p class="hint">Place-toi (à pied ou en voiture) à l'endroit de livraison, puis ajoute-le. Chaque contrat pioche ses livraisons dans ses <b>zones</b>
            (${g.tiers.map((t) => `${esc(t.values.label)} : ${esc((t.zones || []).join(', '))}`).join(' · ')}).
            Les destinations non choisies servent aussi de points de passage.</p>
            <div class="form-grid gf-grid-4">
                <div><label>Nom</label><input class="input" data-gfv="dest.label" value="${esc(d.label)}" placeholder="ex : Hangar de Paleto"></div>
                <div><label>Zone</label><select class="input" data-gfv="dest.zone" data-gfr="1"><option value="">Choisir…</option>${zoneOpts}<option value="__new" ${d.zone === '__new' ? 'selected' : ''}>Nouvelle zone…</option></select></div>
                ${d.zone === '__new' ? `<div><label>Nom de la nouvelle zone</label><input class="input" data-gfv="dest.customZone" value="${esc(d.customZone)}" placeholder="ex : paleto"></div>` : '<div></div>'}
                <div style="display:flex;align-items:flex-end"><button class="btn primary" style="width:100%" data-gf="dest_add">📍 Ajouter ma position</button></div>
            </div></div>
            <div class="section"><h2>Destinations (${g.destinations.length})</h2>
            ${g.destinationsCustom ? '<button class="btn" style="margin-bottom:10px" data-gf="dest_reset">Revenir aux destinations de config.lua</button>' : ''}
            <table>${g.destinations.map((x) => `<tr>
                <td><input class="input" value="${esc(x.label)}" data-gfdestname="${x.index}"></td>
                <td style="width:150px"><select class="input" data-gfdestzone="${x.index}">${g.zones.map((z) => `<option value="${esc(z)}" ${x.zone === z ? 'selected' : ''}>${esc(z)}</option>`).join('')}</select></td>
                <td class="muted gf-small">${coordTxt(x)}</td>
                <td style="text-align:right;white-space:nowrap"><button class="btn" data-gf="dest_tp" data-i="${x.index}">Y aller</button>
                <button class="btn danger" data-gf="dest_remove" data-i="${x.index}">✕</button></td></tr>`).join('')}</table></div>`;
    }

    // ---------- Réglages ----------
    function settings() {
        const g = G();
        if (!GF.settingsDraft) {
            GF.settingsDraft = {};
            g.settings.forEach((s) => { GF.settingsDraft[s.key] = s.value; });
        }
        const d = GF.settingsDraft;
        const groups = [];
        g.settings.forEach((s) => { if (!groups.includes(s.group)) groups.push(s.group); });
        return `<div class="btn-row gf-sticky"><button class="btn primary" data-gf="settings_save">💾 Enregistrer les réglages</button>
                <button class="btn" data-gf="settings_reload">Annuler</button>
                <button class="btn" data-gf="settings_reset">Tout remettre par défaut</button></div>
            ${groups.map((grp) => `<div class="section"><h2>${esc(grp)}</h2>
                <div class="grid gf-toggles">${g.settings.filter((s) => s.group === grp && s.type === 'bool').map((s) => tog(d[s.key], `data-gfset="${s.key}"`, esc(s.label), `Par défaut : ${s.default ? 'oui' : 'non'}`)).join('')}</div>
                <div class="form-grid gf-grid-3" style="margin-top:10px">${g.settings.filter((s) => s.group === grp && s.type !== 'bool').map((s) => `<div>
                    <label>${esc(s.label)} <span class="muted">(défaut ${s.default})</span></label>
                    <input class="input" type="number" min="${s.min}" max="${s.max}" step="${s.type === 'int' ? 1 : 0.1}" data-gfv="settingsDraft.${s.key}" value="${esc(d[s.key])}"></div>`).join('')}</div>
            </div>`).join('')}`;
    }

    // ---------- Missions et joueurs ----------
    function missionTable(limit) {
        const list = G().missions.slice(0, limit || 999);
        if (!list.length) return '<div class="empty">Aucun Go Fast en cours.</div>';
        return `<table><tr><th>Joueur</th><th>Contrat</th><th>Étape</th><th>Temps restant</th><th></th></tr>
            ${list.map((m) => `<tr>
                <td><b>${esc(m.name)}</b> <span class="muted">#${m.target}</span></td>
                <td>${esc(m.tier)}${m.rare ? ' <span class="badge" style="color:var(--signal)">Rare</span>' : ''}<div class="muted gf-small">${esc(m.contact || '')} · ${esc(m.plate)}</div></td>
                <td>${m.phase === 'pickup' ? 'Récupère le véhicule' : `Livraison ${m.step}/${m.steps}`}${m.police ? ' <span class="badge" style="color:var(--danger)">Police</span>' : ''}</td>
                <td>${inTime(m.endsAt)}</td>
                <td style="text-align:right;white-space:nowrap">
                    <button class="btn" data-gf="mission_tp" data-target="${m.target}">Y aller</button>
                    <button class="btn danger" data-gf="mission_stop" data-target="${m.target}" data-name="${esc(m.name)}">Annuler</button></td></tr>`).join('')}</table>`;
    }

    function missions() {
        const p = GF.player, info = p.info;
        const players = [...D.players].sort((a, b) => a.id - b.id);
        return `<div class="section"><h2>Go Fast en cours (${G().missions.length})</h2>
            <p class="hint">« Annuler » arrête la mission sans pénalité d'attente pour le joueur (XP d'échec appliquée).</p>
            ${missionTable()}</div>
            <div class="section"><h2>Joueur</h2>
            <div class="form-grid gf-grid-4">
                <div><label>Joueur en ligne</label><select class="input" data-gfv="player.target" data-gfr="1"><option value="">Choisir…</option>
                    ${players.map((x) => `<option value="${x.id}" ${String(p.target) === String(x.id) ? 'selected' : ''}>#${x.id} ${esc(x.name)}</option>`).join('')}</select></div>
                <div style="display:flex;align-items:flex-end"><button class="btn" style="width:100%" data-gf="player_info">🔎 Voir son niveau</button></div>
                <div style="display:flex;align-items:flex-end"><button class="btn" style="width:100%" data-gf="player_resetcd">⏱️ Retirer son attente</button></div>
                <div></div>
                <div><label>XP</label><input class="input" type="number" data-gfv="player.value" value="${esc(p.value)}" placeholder="ex : 500"></div>
                <div style="display:flex;align-items:flex-end"><button class="btn" style="width:100%" data-gf="player_addxp">➕ Ajouter cette XP</button></div>
                <div style="display:flex;align-items:flex-end"><button class="btn" style="width:100%" data-gf="player_setxp">✏️ Définir son XP</button></div>
            </div>
            ${info && String(info.id) === String(p.target) ? `<div class="card gf-card"><div class="card-head"><strong>${esc(info.name)}</strong><span class="muted">#${info.id}</span></div>
                <div class="field-stats"><span>Niveau <b>${info.level}</b></span><span><b>${info.xp}</b> XP${info.nextLevelXp ? ` (prochain niveau à ${info.nextLevelXp})` : ' (niveau max)'}</span>
                <span>Go Fast réussis <b>${info.missions}</b></span><span>Attente <b>${info.cooldown > 0 ? `${Math.ceil(info.cooldown / 60)} min` : 'aucune'}</b></span></div></div>` : ''}
            </div>`;
    }

    // =====================================================
    //  ACTIONS
    // =====================================================
    function rerender() { if (tab === 'events' || tab === 'editor') render(); }

    function saveContact() {
        const e = GF.edit;
        if (!e) return;
        if (!String(e.label).trim()) return toast('Donne un nom au contact.', 'error');
        if (!String(e.model).trim()) return toast('Indique un modèle de PNJ.', 'error');
        const min = Math.max(1, Math.floor(Number(e.rotation.intervalMin) || 1));
        const max = Math.max(min, Math.floor(Number(e.rotation.intervalMax) || min));
        const dialogues = {};
        Object.keys(e.dialogues).forEach((k) => { dialogues[k] = e.dialogues[k].map((l) => String(l).trim()).filter(Boolean); });
        gfPost('contact_update', {
            id: e.id,
            fields: {
                label: e.label, subtitle: e.subtitle, model: e.model, scenario: e.scenario,
                enabled: e.enabled, blip: e.blip, marker: e.marker,
                blipSprite: Number(e.blipSprite), blipColor: Number(e.blipColor),
                tiers: e.tiers, rotation: { mode: e.rotation.mode, intervalMin: min, intervalMax: max, onlyWhenAlone: e.rotation.onlyWhenAlone },
                dialogues,
            },
        });
        e.dirty = false;
        e.dialogues = dialogues;
        e.rotation.intervalMin = min;
        e.rotation.intervalMax = max;
        rerender();
    }

    async function handle(n) {
        const a = n.dataset.gf;
        const e = GF.edit;
        const idx = Number(n.dataset.i);

        switch (a) {
            case 'toggle':
                if (G().enabled && !(await confirmBox('Fermer le réseau GoFast ?', 'Tous les contacts disparaissent. Les missions déjà lancées continuent jusqu\'à leur fin.'))) return;
                return gfPost('toggle');
            case 'create': {
                const f = GF.fresh;
                if (!f.label.trim()) return toast('Donne un nom au contact.', 'error');
                GF.pendingSelect = true;
                return gfPost('contact_create', {
                    fields: { label: f.label, subtitle: f.subtitle, model: f.model.trim() || undefined, scenario: f.scenario || undefined },
                    locationLabel: f.locationLabel,
                });
            }
            case 'import_ped':
                if (!(await confirmBox('En faire un contact GoFast ?', 'Le PNJ quitte l\'éditeur de map et devient un contact GoFast (même apparence, même place).'))) return;
                GF.pendingSelect = true;
                return gfPost('import_ped', { pedId: Number(n.dataset.id) });
            case 'open': {
                const c = getContact(n.dataset.id);
                if (!c) return;
                GF.edit = toEdit(c);
                GF.sub = 'contacts';
                GF.openVeh = {};
                tab = 'events';
                EVT.current = 'gofast';
                return render();
            }
            case 'close_edit':
                if (e && e.dirty && !(await confirmBox('Quitter sans enregistrer ?', 'Tes modifications (identité, contrats, déplacements, dialogues) seront perdues.'))) return;
                GF.edit = null;
                return render();
            case 'reset_edit':
                GF.edit = toEdit(getContact(e.id));
                return render();
            case 'save_contact':
                return saveContact();
            case 'contact_delete': {
                const c = getContact(n.dataset.id);
                if (!c || !(await confirmBox(`Supprimer « ${c.label} » ?`, 'Le PNJ, ses emplacements et ses dialogues seront supprimés définitivement.'))) return;
                if (GF.edit && GF.edit.id === c.id) GF.edit = null;
                return gfPost('contact_delete', { id: c.id });
            }
            case 'tp':
                return gfPost('tp', { id: n.dataset.id, index: n.dataset.i ? idx : undefined });
            case 'tp_veh':
                return gfPost('tp', { id: e.id, index: idx, point: Number(n.dataset.v) });
            case 'move_now':
                return gfPost('move_now', { id: n.dataset.id, index: n.dataset.i ? idx : undefined });
            case 'loc_add':
                return gfPost('loc_add', { id: e.id, label: GF.newLoc || '' }).then(() => { GF.newLoc = ''; });
            case 'loc_here':
                if (!(await confirmBox(`Déplacer l'emplacement ${idx} ici ?`, 'Sa position est remplacée par la tienne. Ses points véhicule ne bougent pas.'))) return;
                return gfPost('loc_here', { id: e.id, index: idx });
            case 'loc_remove':
                if (!(await confirmBox(`Supprimer l'emplacement ${idx} ?`, 'Ses points véhicule sont supprimés avec lui.'))) return;
                return gfPost('loc_remove', { id: e.id, index: idx });
            case 'toggle_veh':
                GF.openVeh[`${e.id}:${idx}`] = !GF.openVeh[`${e.id}:${idx}`];
                return render();
            case 'veh_add':
                return gfPost('veh_add', { id: e.id, index: idx });
            case 'veh_remove':
                return gfPost('veh_remove', { id: e.id, index: idx, point: Number(n.dataset.v) });
            case 'dlg_add':
                e.dialogues[GF.dlgCat] = e.dialogues[GF.dlgCat] || [];
                e.dialogues[GF.dlgCat].push('');
                e.dirty = true;
                render();
                setTimeout(() => { const all = document.querySelectorAll('[data-gfdlg]'); if (all.length) all[all.length - 1].focus(); }, 0);
                return;
            case 'dlg_del':
                e.dialogues[GF.dlgCat].splice(idx, 1);
                e.dirty = true;
                return render();
            case 'dlg_copy':
                e.dialogues[GF.dlgCat] = [...((G().defaultDialogues || {})[GF.dlgCat] || [])];
                e.dirty = true;
                return render();

            case 'tier_open': {
                const t = G().tiers.find((x) => x.id === n.dataset.id);
                if (!t) return;
                GF.tierId = t.id;
                GF.tierDraft = { ...t.values };
                return render();
            }
            case 'tier_close':
                GF.tierId = null;
                GF.tierDraft = null;
                return render();
            case 'tier_save':
                return gfPost('tier', { id: GF.tierId, values: GF.tierDraft });
            case 'tier_reset': {
                const id = GF.tierId;
                if (!id || !(await confirmBox('Valeurs par défaut ?', 'Ce contrat reprend les valeurs de config.lua.'))) return;
                GF.tierId = null;
                GF.tierDraft = null;
                return gfPost('tier_reset', { id });
            }
            case 'tier_toggle': {
                const t = G().tiers.find((x) => x.id === n.dataset.id);
                return t && gfPost('tier', { id: t.id, values: { enabled: !t.values.enabled } });
            }

            case 'dest_add': {
                const d = GF.dest;
                const zone = d.zone === '__new' ? d.customZone.trim() : d.zone;
                if (!d.label.trim()) return toast('Donne un nom à la destination.', 'error');
                if (!zone) return toast('Choisis une zone.', 'error');
                gfPost('dest_add', { label: d.label, zone });
                GF.dest = { label: '', zone: d.zone === '__new' ? zone.toLowerCase() : d.zone, customZone: '' };
                return;
            }
            case 'dest_tp':
                return gfPost('dest_tp', { index: idx });
            case 'dest_remove':
                if (!(await confirmBox('Supprimer cette destination ?', 'Elle ne sera plus proposée dans les Go Fast.'))) return;
                return gfPost('dest_remove', { index: idx });
            case 'dest_reset':
                if (!(await confirmBox('Revenir aux destinations de config.lua ?', 'Les destinations ajoutées ou modifiées depuis le menu seront perdues.'))) return;
                return gfPost('dest_reset');

            case 'settings_save':
                return gfPost('settings', { values: GF.settingsDraft });
            case 'settings_reload':
                GF.settingsDraft = null;
                return render();
            case 'settings_reset':
                if (!(await confirmBox('Tout remettre par défaut ?', 'Tous les réglages reprennent les valeurs de config.lua.'))) return;
                GF.settingsDraft = null;
                return gfPost('settings_reset');

            case 'mission_tp':
                return gfPost('mission_tp', { target: Number(n.dataset.target) });
            case 'mission_stop':
                if (!(await confirmBox(`Annuler le Go Fast de ${n.dataset.name} ?`, 'Le véhicule est supprimé et la mission comptée comme échouée.'))) return;
                return gfPost('mission_stop', { target: Number(n.dataset.target) });
            case 'player_info': case 'player_resetcd': case 'player_addxp': case 'player_setxp': {
                const target = Number(GF.player.target);
                if (!target) return toast('Choisis un joueur.', 'error');
                if ((a === 'player_addxp' || a === 'player_setxp') && GF.player.value === '') return toast('Indique une quantité d\'XP.', 'error');
                return gfPost(a, { target, value: Number(GF.player.value) });
            }
        }
    }

    // =====================================================
    //  ÉCOUTEURS
    // =====================================================
    content.addEventListener('click', (ev) => {
        const el = (sel) => ev.target.closest(sel);
        let n;
        if ((n = el('[data-evt]'))) { EVT.current = n.dataset.evt; return render(); }
        if ((n = el('[data-gfsub]'))) {
            GF.sub = n.dataset.gfsub;
            if (GF.sub !== 'settings') GF.settingsDraft = null;
            tab = 'events';
            EVT.current = 'gofast';
            return render();
        }
        if ((n = el('[data-gf]'))) { handle(n); return; }
        if ((n = el('[data-gfmodel]'))) { GF.fresh.model = n.dataset.gfmodel; return render(); }
        if ((n = el('[data-gfemodel]'))) { GF.edit.model = n.dataset.gfemodel; GF.edit.dirty = true; return render(); }
        if ((n = el('[data-gfet]'))) {
            const key = n.dataset.gfet;
            if (key.startsWith('rotation.')) GF.edit.rotation[key.slice(9)] = !GF.edit.rotation[key.slice(9)];
            else GF.edit[key] = !GF.edit[key];
            GF.edit.dirty = true;
            return render();
        }
        if ((n = el('[data-gftier]'))) {
            const id = n.dataset.gftier, list = GF.edit.tiers;
            const i = list.indexOf(id);
            if (i >= 0) list.splice(i, 1); else list.push(id);
            GF.edit.dirty = true;
            return render();
        }
        if ((n = el('[data-gfcat]'))) { GF.dlgCat = n.dataset.gfcat; return render(); }
        if ((n = el('[data-gftd]'))) { GF.tierDraft[n.dataset.gftd] = !GF.tierDraft[n.dataset.gftd]; return render(); }
        if ((n = el('[data-gfset]'))) { GF.settingsDraft[n.dataset.gfset] = !GF.settingsDraft[n.dataset.gfset]; return render(); }
    });

    content.addEventListener('input', (ev) => {
        const t = ev.target;
        if (t.dataset.gfv) { setPath(t.dataset.gfv, t.value); return; }
        if (GF.edit && t.dataset.gfe) {
            const key = t.dataset.gfe;
            if (key.startsWith('rotation.')) GF.edit.rotation[key.slice(9)] = t.value;
            else GF.edit[key] = t.value;
            if (!GF.edit.dirty) {
                GF.edit.dirty = true;
                const b = document.querySelector('.gf-sticky [data-gf="save_contact"]');
                if (b) b.textContent = '💾 Enregistrer les modifications';
            }
            return;
        }
        if (GF.edit && t.dataset.gfdlg !== undefined) {
            GF.edit.dialogues[GF.dlgCat][Number(t.dataset.gfdlg)] = t.value;
            GF.edit.dirty = true;
        }
    });

    content.addEventListener('change', (ev) => {
        const t = ev.target;
        if ((t.dataset.gfv || t.dataset.gfe) && t.dataset.gfr) return render();
        if (GF.edit && t.dataset.gflocname) {
            return gfPost('loc_rename', { id: GF.edit.id, index: Number(t.dataset.gflocname), label: t.value });
        }
        if (t.dataset.gfdestname) return gfPost('dest_update', { index: Number(t.dataset.gfdestname), label: t.value });
        if (t.dataset.gfdestzone) return gfPost('dest_update', { index: Number(t.dataset.gfdestzone), zone: t.value });
    });

    window.addEventListener('message', (ev) => {
        const m = ev.data;
        if (!m || m.action !== 'gofastReply') return;
        if (m.player) GF.player.info = m.player;
        if (m.ok && m.select && GF.pendingSelect) {
            GF.pendingSelect = null;
            GF.fresh = { label: '', subtitle: '', model: '', scenario: '', locationLabel: '' };
            GF.selectWhenReady = m.select;
        } else if (!m.ok) {
            GF.pendingSelect = null;
        }
        if (m.ok && GF.sub === 'tiers' && GF.tierId) {
            // Le brouillon reprend les valeurs enregistrées au prochain rendu
            GF.reloadTier = true;
        }
        if (m.ok && GF.sub === 'settings') GF.settingsDraft = null;
    });

    // Après chaque mise à jour des données : ouverture d'un contact créé, rechargement du palier
    const baseRender = render;
    render = function patchedRender() {
        normalize(G());
        if (GF.selectWhenReady && G() && G().contacts) {
            const c = getContact(GF.selectWhenReady);
            if (c) {
                GF.selectWhenReady = null;
                GF.edit = toEdit(c);
                GF.sub = 'contacts';
                GF.openVeh = {};
                tab = 'events';
                EVT.current = 'gofast';
            }
        }
        if (GF.reloadTier && G() && GF.tierId) {
            GF.reloadTier = false;
            const t = G().tiers.find((x) => x.id === GF.tierId);
            if (t) GF.tierDraft = { ...t.values };
        }
        return baseRender();
    };
})();
