/* =========================================================
   ONGLET 🗺️ CARTE
   Mini-carte (forme, position, taille) et icônes de la carte du
   menu Échap : cacher, déplacer, renommer celles des scripts,
   en ajouter de nouvelles.
   ========================================================= */
(() => {
    const at = TABS.findIndex((t) => t.id === 'world');
    TABS.splice(at < 0 ? TABS.length : at + 1, 0, {
        id: 'map', group: 2, label: 'Carte', ico: '🗺️',
        sub: 'Mini-carte et icônes de la carte : cacher, déplacer, renommer, ajouter.',
        show: () => has('manage_map') && !!(D && D.map),
    });

    const SUBS = [{ id: 'minimap', label: 'Mini-carte' }, { id: 'scripts', label: 'Icônes des scripts' }, { id: 'mine', label: 'Icônes ajoutées' }];
    const MP = { sub: 'minimap', draft: null, previewing: false, scan: null, scanning: false, q: '', filter: 'all' };
    const DISPLAY = [{ value: 'all', label: 'Carte et mini-carte' }, { value: 'map', label: 'Carte seulement' }, { value: 'minimap', label: 'Mini-carte seulement' }, { value: 'hidden', label: 'Cachée' }];
    const displayLabel = (v) => (DISPLAY.find((d) => d.value === v) || DISPLAY[0]).label;
    const iconName = (s) => (D.map.icons || {})[String(s)] || `Icône n°${s}`;
    const colorOf = (id) => (D.map.colors || []).find((c) => c.id === Number(id));
    const swatch = (id) => { const c = colorOf(id); return `<span title="${c ? esc(c.label) : `Couleur ${id}`}" style="display:inline-block;width:12px;height:12px;border-radius:50%;background:${c ? c.hex : '#888'};border:1px solid rgba(255,255,255,.3);vertical-align:middle"></span>`; };
    const ruleFor = (id) => (D.map.rules || []).find((r) => r.id === id);

    VIEWS.map = () => {
        const nav = `<div class="segmented">${SUBS.map((s) => `<button class="seg ${s.id === MP.sub ? 'active' : ''}" data-mps="${s.id}">${s.label}</button>`).join('')}</div>`;
        return nav + ({ minimap: viewMinimap, scripts: viewScripts, mine: viewMine }[MP.sub])();
    };

    /* ---------- Mini-carte ---------- */
    const SHAPES = [{ id: 'square', label: 'Carrée' }, { id: 'round', label: 'Ronde' }, { id: 'default', label: 'Rectangle GTA' }];
    const POSITIONS = [{ id: 'top-left', label: '↖ Haut gauche' }, { id: 'top-right', label: '↗ Haut droite' }, { id: 'bottom-left', label: '↙ Bas gauche' }, { id: 'bottom-right', label: '↘ Bas droite' }];
    const SLIDERS = [
        { k: 'size', label: 'Taille', min: 0.08, max: 0.40, step: 0.005, fmt: (v) => `${Math.round(v * 100)} %` },
        { k: 'widthAdjust', label: 'Largeur', min: 60, max: 160, step: 1, fmt: (v) => `${v} %` },
        { k: 'marginX', label: 'Écart du bord (côté)', min: -0.05, max: 0.15, step: 0.001, fmt: (v) => Number(v).toFixed(3) },
        { k: 'marginY', label: 'Écart du bord (haut / bas)', min: -0.05, max: 0.15, step: 0.001, fmt: (v) => Number(v).toFixed(3) },
    ];

    function viewMinimap() {
        if (!MP.draft) MP.draft = JSON.parse(JSON.stringify(D.map.minimap));
        const m = MP.draft;
        if (!MP.conflicts) { MP.conflicts = []; post('minimap_conflicts').then((r) => { MP.conflicts = (r && r.list) || []; if (MP.conflicts.length && isOpen && tab === 'map') render(); }); }
        const conflict = MP.conflicts.length ? `<div class="protect" style="margin-bottom:14px">⚠️ <span>${MP.conflicts.map((c) => `La commande <span class="keycap">/${esc(c.command)}</span> vient de la ressource <b>${esc(c.resource)}</b>`).join('<br>')}.
            Elle est désactivée par le menu, mais cette ressource peut encore reposer sa mini-carte au chargement : le menu repasse derrière elle.
            Pour éviter tout conflit, retire sa partie mini-carte ou arrête-la.</span></div>` : '';
        return `${conflict}
            <div class="section"><h2>Placer la mini-carte</h2>
                <p class="hint">Le menu se cache : <b>fais glisser le cadre</b> à l'endroit voulu (il s'accroche au coin le plus proche),
                <b>molette</b> pour la taille, <b>Entrée</b> pour enregistrer pour tous les joueurs, <b>Échap</b> pour annuler.
                La position ne bouge plus ensuite, même après une reconnexion.</p>
                <button class="btn primary big" data-mma="place">✋ Placer la mini-carte à la souris</button>
            </div>
            <p class="hint">Chaque changement s'applique <b>tout de suite sur ton écran</b> (aperçu, en haut ou en bas de l'écran selon la position).
            « Enregistrer pour tous » l'applique à tous les joueurs. La largeur « 100 % » donne un carré parfait.</p>
            <div class="section"><h2>Forme</h2><div class="btn-row">
                ${SHAPES.map((s) => `<button class="btn ${m.shape === s.id ? 'on' : ''}" data-mmshape="${s.id}">${s.label}</button>`).join('')}</div></div>
            <div class="section"><h2>Position</h2><div class="grid" style="grid-template-columns:repeat(2,minmax(160px,220px))">
                ${POSITIONS.map((p) => `<button class="tile ${m.position === p.id ? 'active' : ''}" data-mmpos="${p.id}"><strong>${p.label}</strong></button>`).join('')}</div></div>
            <div class="section"><h2>Taille et placement</h2>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(280px,1fr))">
                ${SLIDERS.map((s) => `<div class="field" style="margin:0"><label>${s.label} · <b id="mmv-${s.k}">${s.fmt(m[s.k])}</b></label>
                    <input type="range" class="input" style="padding:0" data-mm="${s.k}" min="${s.min}" max="${s.max}" step="${s.step}" value="${m[s.k]}"></div>`).join('')}
                </div></div>
            <div class="section"><h2>Options</h2><div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr))">
                <div class="tile toggle-tile ${m.enabled !== false ? 'on' : ''}" data-mmt="enabled"><div><strong>Gérée par le menu</strong><span>Désactivé : la mini-carte reste celle de GTA.</span></div><div class="switch"></div></div>
                <div class="tile toggle-tile ${m.hideHealthBars ? 'on' : ''}" data-mmt="hideHealthBars"><div><strong>Cacher les barres de vie GTA</strong><span>Les barres vie / armure sous la carte.</span></div><div class="switch"></div></div>
                <div class="tile toggle-tile ${m.onlyInVehicle ? 'on' : ''}" data-mmt="onlyInVehicle"><div><strong>Seulement en véhicule</strong><span>Mini-carte cachée à pied.</span></div><div class="switch"></div></div>
            </div></div>
            <div class="btn-row">
                <button class="btn primary" data-mma="save">Enregistrer pour tous</button>
                <button class="btn" data-mma="cancel">Annuler l'aperçu</button>
                <button class="btn" data-mma="peek">👁 Voir l'écran (5 s)</button>
                <span style="flex:1"></span>
                <button class="btn danger" data-mma="reset">Valeurs par défaut</button>
            </div>`;
    }

    function previewMinimap() {
        MP.previewing = true;
        post('minimap_preview', MP.draft);
    }
    function endPreview() {
        if (!MP.previewing) return;
        MP.previewing = false;
        post('minimap_preview_end');
    }

    /* ---------- Icônes des scripts ---------- */
    function stateOf(item) {
        const r = item.rule && ruleFor(item.rule);
        if (!r) return item.display === 'hidden' ? '<span class="badge muted">Cachée par son script</span>' : '';
        const tags = [];
        if (r.display === 'hidden') tags.push('<span class="badge" style="color:var(--danger)">Cachée</span>');
        else if (r.display) tags.push(`<span class="badge" style="color:var(--info)">${displayLabel(r.display)}</span>`);
        if (r.x !== undefined && r.x !== null) tags.push('<span class="badge" style="color:var(--signal)">Déplacée</span>');
        if (r.name) tags.push(`<span class="badge" style="color:var(--ok)">« ${esc(r.name)} »</span>`);
        if (r.color !== undefined && r.color !== null) tags.push(`<span class="badge muted">Couleur ${swatch(r.color)}</span>`);
        return tags.join(' ') || '<span class="badge muted">Modifiée</span>';
    }

    function viewScripts() {
        const rules = D.map.rules || [];
        if (!MP.scan && !MP.scanning) { MP.scanning = true; scan(); }
        const q = MP.q.trim().toLowerCase();
        const list = (MP.scan || []).filter((it) => {
            if (MP.filter === 'changed' && !it.rule) return false;
            if (MP.filter === 'hidden' && !(it.rule && (ruleFor(it.rule) || {}).display === 'hidden')) return false;
            if (!q) return true;
            const r = it.rule && ruleFor(it.rule);
            return iconName(it.sprite).toLowerCase().includes(q) || String(it.sprite) === q || (r && r.name && r.name.toLowerCase().includes(q));
        });
        return `
            <p class="hint">Toutes les icônes posées par les scripts du serveur, de la plus proche à la plus éloignée de toi.
            Les changements s'appliquent à <b>tous les joueurs</b> et restent après un redémarrage. « Repérer » fait clignoter l'icône sur ta carte (Échap).</p>
            <div class="inline" style="margin-bottom:12px;max-width:900px">
                <input class="input" id="mp-q" placeholder="Rechercher (nom, numéro d'icône)" value="${esc(MP.q)}">
                <button class="btn ${MP.filter === 'all' ? 'on' : ''}" data-mpf="all">Toutes</button>
                <button class="btn ${MP.filter === 'changed' ? 'on' : ''}" data-mpf="changed">Modifiées (${rules.length})</button>
                <button class="btn ${MP.filter === 'hidden' ? 'on' : ''}" data-mpf="hidden">Cachées</button>
                <button class="btn" data-mpa="scan">${MP.scanning ? 'Recherche…' : '↻ Actualiser'}</button>
            </div>
            ${!MP.scan ? '<div class="empty">Recherche des icônes…</div>' : list.length ? `<table>
                <tr><th>Icône</th><th style="width:90px">Distance</th><th>État</th><th></th></tr>
                ${list.slice(0, 250).map((it, i) => {
                    const r = it.rule && ruleFor(it.rule);
                    const hidden = r && r.display === 'hidden';
                    return `<tr>
                        <td>${swatch(r && r.color != null ? r.color : it.color)} <strong>${esc(r && r.name ? r.name : iconName(it.sprite))}</strong> <span class="muted">n°${it.sprite}</span></td>
                        <td class="muted">${it.distance >= 1000 ? (it.distance / 1000).toFixed(1) + ' km' : it.distance + ' m'}</td>
                        <td>${stateOf(it)}</td>
                        <td style="text-align:right;white-space:nowrap">
                            <button class="btn" data-mpa="flash" data-i="${i}" title="Faire clignoter sur la carte">Repérer</button>
                            <button class="btn" data-mpa="goto" data-i="${i}">Y aller</button>
                            <button class="btn ${hidden ? 'on' : ''}" data-mpa="hide" data-i="${i}">${hidden ? 'Afficher' : 'Cacher'}</button>
                            <button class="btn" data-mpa="moveHere" data-i="${i}" title="Déplacer l'icône à ma position">📍</button>
                            <button class="btn" data-mpa="edit" data-i="${i}">Modifier</button>
                            ${r ? `<button class="btn danger" data-mpa="restore" data-rule="${r.id}" title="Remettre comme avant">↺</button>` : ''}</td></tr>`;
                }).join('')}
            </table>${list.length > 250 ? `<p class="hint" style="margin-top:8px">${list.length - 250} icônes de plus : affine la recherche.</p>` : ''}` : '<div class="empty">Aucune icône ne correspond.</div>'}`;
    }
    async function scan() {
        MP.scanning = true;
        const r = await post('map_scan');
        MP.scan = (r && r.list) || [];
        MP.scanning = false;
        if (isOpen && tab === 'map' && MP.sub === 'scripts') render();
    }

    /* ---------- Icônes ajoutées ---------- */
    function viewMine() {
        const list = D.map.custom || [];
        return `
            <div class="section"><h2>Ajouter une icône</h2>
                <p class="hint">Elle apparaît pour tous les joueurs, sur la carte et/ou la mini-carte.</p>
                <div class="btn-row"><button class="btn primary" data-mpa="addHere">📍 À ma position</button>
                    <button class="btn" data-mpa="addCoords">🎯 Par coordonnées</button></div></div>
            <div class="section"><h2>Icônes ajoutées (${list.length})</h2>
                ${list.length ? `<table><tr><th>Icône</th><th>Affichage</th><th>Position</th><th></th></tr>
                    ${list.map((b) => `<tr>
                        <td>${swatch(b.color)} <strong>${esc(b.label)}</strong> <span class="muted">${esc(iconName(b.sprite))} · n°${b.sprite}</span></td>
                        <td class="muted">${displayLabel(b.display)}${b.shortRange ? ' · proche seulement' : ''}</td>
                        <td class="muted" style="font-size:12px;white-space:nowrap">${Number(b.x).toFixed(1)}, ${Number(b.y).toFixed(1)}</td>
                        <td style="text-align:right;white-space:nowrap">
                            <button class="btn" data-mpa="customGoto" data-id="${b.id}">Y aller</button>
                            <button class="btn" data-mpa="customEdit" data-id="${b.id}">Modifier</button>
                            <button class="btn" data-mpa="customMoveHere" data-id="${b.id}" title="Déplacer à ma position">📍</button>
                            <button class="btn danger" data-mpa="customDelete" data-id="${b.id}">✕</button></td></tr>`).join('')}</table>`
                    : '<div class="empty">Aucune icône ajoutée.</div>'}</div>`;
    }

    /* ---------- Fenêtres de saisie ---------- */
    const colorOptions = (withNone) => [...(withNone ? [{ value: '', label: 'Couleur d\'origine' }] : []), ...(D.map.colors || []).map((c) => ({ value: c.id, label: c.label }))];
    const iconOptions = () => (D.map.iconList || []).map((i) => ({ value: i.id, label: `${i.emoji || ''} ${i.label}` }));

    async function customForm(b, withCoords) {
        const fields = [
            { name: 'label', label: 'Nom affiché', value: b ? b.label : '', placeholder: 'ex : Mairie' },
            { name: 'sprite', label: 'Icône', type: 'select', options: iconOptions(), value: b ? b.sprite : 1 },
            { name: 'spriteNum', label: 'Ou numéro d\'icône GTA (docs.fivem.net › Blips)', type: 'number', value: '', placeholder: 'facultatif' },
            { name: 'color', label: 'Couleur', type: 'select', options: colorOptions(false), value: b ? b.color : 0 },
            { name: 'scale', label: 'Taille (0.3 à 3)', type: 'number', value: b ? b.scale : 0.9 },
            { name: 'display', label: 'Affichage', type: 'select', options: DISPLAY, value: b ? b.display : 'all' },
            { name: 'shortRange', label: 'Visible sur la mini-carte', type: 'select', options: [{ value: 'false', label: 'Toujours' }, { value: 'true', label: 'Seulement à proximité' }], value: b && b.shortRange ? 'true' : 'false' },
        ];
        if (withCoords) fields.push({ name: 'x', label: 'X', type: 'number', value: b ? b.x : '' }, { name: 'y', label: 'Y', type: 'number', value: b ? b.y : '' }, { name: 'z', label: 'Z', type: 'number', value: b ? b.z : '' });
        const v = await formModal(b ? `Modifier « ${b.label} »` : 'Nouvelle icône', fields, 'Enregistrer');
        if (!v) return null;
        if (v.spriteNum) v.sprite = Number(v.spriteNum);
        delete v.spriteNum;
        return v;
    }

    /* ---------- Événements ---------- */
    document.addEventListener('input', (e) => {
        if (!isOpen || tab !== 'map') return;
        const t = e.target;
        if (t.dataset.mm) {
            MP.draft[t.dataset.mm] = Number(t.value);
            const s = SLIDERS.find((x) => x.k === t.dataset.mm);
            const lab = $(`#mmv-${t.dataset.mm}`);
            if (lab && s) lab.textContent = s.fmt(Number(t.value));
            previewMinimap();
        }
        if (t.id === 'mp-q') {
            MP.q = t.value;
            const pos = t.selectionStart;
            render();
            const el = $('#mp-q'); if (el) { el.focus(); el.setSelectionRange(pos, pos); }
        }
    });

    // Quitter l'onglet ou fermer le menu : fin de l'aperçu
    document.addEventListener('click', (e) => {
        const tb = e.target.closest('[data-tab]');
        if (tb && tb.dataset.tab !== 'map') endPreview();
    }, true);
    window.addEventListener('message', (e) => { if (e.data && e.data.action === 'close') { endPreview(); MP.draft = null; } });

    document.addEventListener('click', async (e) => {
        if (!isOpen || tab !== 'map') return;
        let n;
        if ((n = e.target.closest('[data-mps]'))) { if (n.dataset.mps !== 'minimap') endPreview(); MP.sub = n.dataset.mps; return render(); }
        if ((n = e.target.closest('[data-mmshape]'))) { MP.draft.shape = n.dataset.mmshape; previewMinimap(); return render(); }
        if ((n = e.target.closest('[data-mmpos]'))) { MP.draft.position = n.dataset.mmpos; previewMinimap(); return render(); }
        if ((n = e.target.closest('[data-mmt]'))) {
            const k = n.dataset.mmt;
            const cur = k === 'enabled' ? MP.draft.enabled !== false : !!MP.draft[k];
            MP.draft[k] = !cur;
            previewMinimap();
            return render();
        }
        if ((n = e.target.closest('[data-mpf]'))) { MP.filter = n.dataset.mpf; return render(); }
        if ((n = e.target.closest('[data-mma]'))) {
            const a = n.dataset.mma;
            if (a === 'save') { action('minimap_save', MP.draft); MP.previewing = false; MP.draft = null; return; }
            if (a === 'cancel') { endPreview(); MP.draft = null; return render(); }
            if (a === 'place') return startPlacing();
            if (a === 'peek') {
                // Le menu se cache 5 s pour voir la mini-carte en entier
                previewMinimap();
                $('#app').style.visibility = 'hidden';
                return setTimeout(() => { $('#app').style.visibility = ''; }, 5000);
            }
            if (a === 'reset') {
                if (!(await confirmBox('Valeurs par défaut ?', 'La mini-carte reprend les réglages de config.lua pour tous les joueurs.'))) return;
                endPreview(); MP.draft = null; return action('minimap_reset');
            }
            return;
        }
        if (!(n = e.target.closest('[data-mpa]')) || n.disabled) return;
        const a = n.dataset.mpa;
        const it = MP.scan && n.dataset.i !== undefined ? filtered()[Number(n.dataset.i)] : null;
        const base = it ? { id: it.rule || undefined, sprite: it.sprite, ox: it.ox, oy: it.oy, oz: it.oz } : null;

        switch (a) {
            case 'scan': MP.scan = null; render(); return scan();
            case 'flash': post('map_flash', { sprite: it.sprite, ox: it.ox, oy: it.oy }); return toast('L\'icône clignote sur ta carte (Échap › Carte).', 'info');
            case 'goto': post('close'); return action('map_tp', { x: it.x, y: it.y, z: it.z });
            case 'hide': {
                const r = it.rule && ruleFor(it.rule);
                const hidden = r && r.display === 'hidden';
                action('blip_rule_save', { ...base, display: hidden ? 'all' : 'hidden' });
                return setTimeout(scan, 600);
            }
            case 'moveHere':
                if (!(await confirmBox('Déplacer l\'icône ici ?', `« ${iconName(it.sprite)} » sera placée à ta position pour tous les joueurs.`))) return;
                action('blip_rule_save', { ...base, move: 'me' });
                return setTimeout(scan, 600);
            case 'edit': {
                const r = (it.rule && ruleFor(it.rule)) || {};
                const v = await formModal(`Modifier « ${r.name || iconName(it.sprite)} »`, [
                    { name: 'name', label: 'Nouveau nom (vide = nom d\'origine)', value: r.name || '' },
                    { name: 'color', label: 'Couleur', type: 'select', options: colorOptions(true), value: r.color ?? '' },
                    { name: 'scale', label: 'Taille (vide = d\'origine, 0.3 à 3)', type: 'number', value: r.scale ?? '' },
                    { name: 'display', label: 'Affichage', type: 'select', options: DISPLAY, value: r.display || it.display || 'all' },
                    { name: 'move', label: 'Position', type: 'select', value: r.x != null ? 'keep' : 'reset',
                      options: [{ value: 'keep', label: 'Ne pas changer' }, { value: 'reset', label: 'Position d\'origine' }, { value: 'me', label: 'Ma position actuelle' }, { value: 'coords', label: 'Coordonnées ci-dessous' }] },
                    { name: 'x', label: 'X', type: 'number', value: r.x ?? '' }, { name: 'y', label: 'Y', type: 'number', value: r.y ?? '' }, { name: 'z', label: 'Z', type: 'number', value: r.z ?? '' },
                ], 'Enregistrer');
                if (!v) return;
                // -1 / 0 = revenir à la couleur / taille d'origine
                action('blip_rule_save', { ...base, name: v.name, color: v.color === '' ? -1 : Number(v.color), scale: v.scale === '' ? 0 : Number(v.scale),
                    display: v.display, move: v.move === 'keep' ? undefined : v.move, x: v.x, y: v.y, z: v.z });
                return setTimeout(scan, 600);
            }
            case 'restore':
                action('blip_rule_delete', { id: Number(n.dataset.rule) });
                return setTimeout(scan, 600);

            case 'addHere': { const v = await customForm(null, false); if (v) action('blip_custom_save', { ...v, useMyPosition: true }); return; }
            case 'addCoords': { const v = await customForm(null, true); if (v) action('blip_custom_save', v); return; }
            case 'customEdit': { const b = (D.map.custom || []).find((x) => x.id === Number(n.dataset.id)); const v = b && await customForm(b, true); if (v) action('blip_custom_save', { id: b.id, ...v }); return; }
            case 'customMoveHere': return action('blip_custom_save', { id: Number(n.dataset.id), useMyPosition: true });
            case 'customGoto': { const b = (D.map.custom || []).find((x) => x.id === Number(n.dataset.id)); if (b) { post('close'); action('map_tp', { x: b.x, y: b.y, z: b.z }); } return; }
            case 'customDelete': {
                const b = (D.map.custom || []).find((x) => x.id === Number(n.dataset.id));
                if (b && await confirmBox('Supprimer l\'icône ?', `« ${b.label} » disparaîtra de la carte de tous les joueurs.`)) action('blip_custom_delete', { id: b.id });
            }
        }
    });

    /* ---------- Placement à la souris ---------- */
    // Même calcul que client/minimap.lua : rectangle de la mini-carte en pixels
    function rectOf(m) {
        const W = window.innerWidth, H = window.innerHeight;
        const h = Number(m.size) || 0.2;
        let w = h * (9 / 16) * ((Number(m.widthAdjust) || 100) / 100);
        if (m.shape === 'default') w = h * 0.8;
        const aspect = W / H;
        const extra = aspect > 16 / 9 + 0.01 ? ((16 / 9) - aspect) / 3.6 : 0;
        const pos = m.position || 'top-right';
        const wPx = w * W, hPx = h * H;
        const left = pos.endsWith('left') ? ((Number(m.marginX) || 0) + extra) * W : W - ((Number(m.marginX) || 0) + extra) * W - wPx;
        const top = pos.startsWith('top') ? (Number(m.marginY) || 0) * H : H - (Number(m.marginY) || 0) * H - hPx;
        return { left, top, wPx, hPx, extra };
    }

    // Position en pixels -> coin le plus proche + écarts
    function fromRect(m, left, top) {
        const W = window.innerWidth, H = window.innerHeight;
        const r = rectOf(m);
        const cx = left + r.wPx / 2, cy = top + r.hPx / 2;
        const horiz = cx < W / 2 ? 'left' : 'right';
        const vert = cy < H / 2 ? 'top' : 'bottom';
        const clamp = (v) => Math.max(-0.05, Math.min(0.6, v));
        m.position = `${vert}-${horiz}`;
        m.marginX = clamp(horiz === 'left' ? left / W - r.extra : (W - left - r.wPx) / W - r.extra);
        m.marginY = clamp(vert === 'top' ? top / H : (H - top - r.hPx) / H);
    }

    let placer = null;
    function startPlacing() {
        if (!MP.draft) MP.draft = JSON.parse(JSON.stringify(D.map.minimap));
        MP.draft.enabled = true;
        placer = document.createElement('div');
        placer.id = 'mm-placer';
        placer.innerHTML = `<div class="mmp-frame"><span>Mini-carte</span></div>
            <div class="mmp-help"><b>Glisse le cadre</b> · <kbd>Molette</kbd> taille · <kbd>Entrée</kbd> enregistrer pour tous · <kbd>Échap</kbd> annuler</div>`;
        document.body.appendChild(placer);
        $('#app').style.visibility = 'hidden';
        drawFrame();
        previewMinimap();
    }

    function drawFrame() {
        if (!placer) return;
        const r = rectOf(MP.draft);
        const f = placer.querySelector('.mmp-frame');
        Object.assign(f.style, { left: `${r.left}px`, top: `${r.top}px`, width: `${r.wPx}px`, height: `${r.hPx}px`,
            borderRadius: MP.draft.shape === 'round' ? '50%' : '6px' });
    }

    function stopPlacing(save) {
        if (!placer) return;
        placer.remove();
        placer = null;
        $('#app').style.visibility = '';
        if (save) {
            action('minimap_save', MP.draft);
            MP.previewing = false;
            MP.draft = null;
        } else {
            endPreview();
            MP.draft = null;
            render();
        }
    }

    let drag = null, sendTimer = null;
    const sendPreview = () => { clearTimeout(sendTimer); sendTimer = setTimeout(previewMinimap, 40); };
    document.addEventListener('mousedown', (e) => {
        if (!placer || e.button !== 0 || !e.target.closest('.mmp-frame')) return;
        const r = rectOf(MP.draft);
        drag = { dx: e.clientX - r.left, dy: e.clientY - r.top };
        e.preventDefault();
    });
    document.addEventListener('mousemove', (e) => {
        if (!placer || !drag) return;
        const r = rectOf(MP.draft);
        const left = Math.max(0, Math.min(window.innerWidth - r.wPx, e.clientX - drag.dx));
        const top = Math.max(0, Math.min(window.innerHeight - r.hPx, e.clientY - drag.dy));
        fromRect(MP.draft, left, top);
        drawFrame();
        sendPreview();
    });
    document.addEventListener('mouseup', () => { drag = null; });
    document.addEventListener('wheel', (e) => {
        if (!placer) return;
        const r = rectOf(MP.draft);
        MP.draft.size = Math.max(0.08, Math.min(0.40, (Number(MP.draft.size) || 0.2) + (e.deltaY > 0 ? -0.01 : 0.01)));
        fromRect(MP.draft, r.left, r.top);   // garde le cadre au même endroit
        drawFrame();
        sendPreview();
    }, { passive: true });
    // Entrée / Échap : avant le raccourci Échap du menu
    document.addEventListener('keydown', (e) => {
        if (!placer) return;
        if (e.key === 'Enter') { e.preventDefault(); e.stopImmediatePropagation(); stopPlacing(true); }
        if (e.key === 'Escape') { e.preventDefault(); e.stopImmediatePropagation(); stopPlacing(false); }
    }, true);

    // Même filtre que l'affichage (pour retrouver l'icône de la ligne cliquée)
    function filtered() {
        const q = MP.q.trim().toLowerCase();
        return (MP.scan || []).filter((it) => {
            if (MP.filter === 'changed' && !it.rule) return false;
            if (MP.filter === 'hidden' && !(it.rule && (ruleFor(it.rule) || {}).display === 'hidden')) return false;
            if (!q) return true;
            const r = it.rule && ruleFor(it.rule);
            return iconName(it.sprite).toLowerCase().includes(q) || String(it.sprite) === q || (r && r.name && r.name.toLowerCase().includes(q));
        });
    }
})();
