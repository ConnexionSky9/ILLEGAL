/* =========================================================
   ÉVÉNEMENT : ATTAQUE DE ZOMBIES
   - Panneau du staff (onglet Événements › Attaque de zombies)
   - Bandeau des joueurs pendant l'événement
   Chargé après script.js et gofast.js.
   ========================================================= */
(() => {
    'use strict';

    const EVENTS = window.AM_EVENTS = window.AM_EVENTS || [];
    const ZD = {
        duration: 30, custom: '', intensity: 'medium', area: 'city', radius: 800,
        storm: true, blackout: true, night: false, emptyCity: true, headshot: false,
        runners: 20, spitters: 15, damage: 1, announce: true, message: '',
        missions: [],      // missions préparées pour le lancement
        live: [],          // mission préparée pendant l'événement (0 ou 1)
        crates: [],        // types de caisses préparés pour le lancement
        liveCrate: [],     // type de caisse préparé pendant l'événement (0 ou 1)
    };
    const REWARD_TO = {
        participants: 'Tous ceux qui ont participé à la mission',
        laststep: 'Les joueurs présents à la dernière étape',
        finisher: 'Celui qui a validé la dernière étape',
        top: 'Les meilleurs tueurs de zombies',
        area: 'Tous les joueurs dans la zone de l\'événement',
        all: 'Tous les joueurs connectés',
        players: 'Des joueurs que je choisis',
    };
    const REWARD_KIND = { cash: '💵 Argent liquide', bank: '🏦 Banque', item: '🎒 Objet (inventaire)' };
    const AMMO = {
        ox: ['ammo-9', 'ammo-45', 'ammo-rifle', 'ammo-rifle2', 'ammo-shotgun', 'ammo-sniper', 'ammo-heavysniper', 'ammo-22', 'ammo-38', 'ammo-44', 'ammo-50'],
        qb: ['pistol_ammo', 'smg_ammo', 'rifle_ammo', 'shotgun_ammo', 'mg_ammo', 'snp_ammo'],
    };
    let itemsAskedZ = false;
    const clone = (o) => JSON.parse(JSON.stringify(o));
    const STEP_TYPES = {
        reach: { label: '📍 Aller à un lieu', hint: 'Terminée dès qu\'un joueur arrive dans le rayon.' },
        interact: { label: '✋ Maintenir E', hint: 'Un joueur maintient E sur place pendant la durée.' },
        defend: { label: '🛡️ Tenir une zone', hint: 'Au moins un joueur reste dans la zone (temps cumulé). Les zombies affluent.' },
        boss: { label: '☠️ Tuer le boss', hint: 'Un boss géant apparaît sur place, entouré de zombies qui attaquent ceux qui s\'en prennent à lui. Il se déplace dans son territoire, frappe fort et attaque à distance. L\'étape est réussie quand il meurt.' },
    };
    const BOSS_MODELS = [
        ['u_m_y_juggernaut_01', 'Juggernaut (blindé)'], ['ig_orleans', 'Bigfoot'], ['u_m_y_zombie_01', 'Zombie'],
        ['s_m_m_movalien_01', 'Extraterrestre'], ['s_m_y_clown_01', 'Clown'], ['u_m_y_imporage', 'Mutant'],
    ];
    const bossDefaults = () => {
        const b = (Z() && Z().boss) || {};
        return { bossName: b.name || 'Le Colosse', bossHealth: b.health || 8000, bossScale: b.scale || 2.0, bossSpeed: b.speed || 1.6, bossModel: b.model || 'u_m_y_juggernaut_01', minions: b.minions ?? 12, reinforce: b.reinforce !== false };
    };
    const OUTCOMES = {
        decontaminate: '🧪 Décontamination totale : fin de l\'événement, la ville redevient normale',
        killall: '💀 Tous les zombies tombent (l\'événement continue)',
        none: 'Rien de spécial (récompense seulement)',
    };
    const toArr = (v) => (Array.isArray(v) ? v : (v && typeof v === 'object' ? Object.values(v) : []));
    const Z = () => (D && D.zombies) || null;

    let offset = 0, offsetFor = null;
    const serverNow = () => {
        const z = Z();
        if (z && z.now && offsetFor !== z.now) { offsetFor = z.now; offset = z.now - Math.floor(Date.now() / 1000); }
        return Math.floor(Date.now() / 1000) + offset;
    };
    const clock = (s) => {
        s = Math.max(0, Math.floor(s));
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), r = s % 60;
        return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${String(r).padStart(2, '0')}` : `${String(m).padStart(2, '0')}:${String(r).padStart(2, '0')}`;
    };
    const tile = (on, key, title, sub) => `<div class="tile toggle-tile ${on ? 'on' : ''}" data-zbt="${key}"><div><strong>${title}</strong><span>${sub}</span></div><div class="switch"></div></div>`;

    // =====================================================
    //  PANNEAU DU STAFF
    // =====================================================
    function view() {
        const z = Z();
        if (!z) return '<div class="empty">Chargement…</div>';
        askItems();
        return z.active ? activeView(z) : startView(z);
    }

    function startView(z) {
        const intens = toArr(z.intensities);
        const durs = toArr(z.durations);
        const dur = ZD.custom !== '' ? Number(ZD.custom) : ZD.duration;
        return `<div class="zb-hero">
                <div class="zb-hero-ico">🧟</div>
                <div><strong>Attaque de zombies</strong>
                <span>La ville bascule dans l'apocalypse : orage, pluie, rues vides, et des zombies qui apparaissent autour de chaque joueur.
                Pendant l'événement, <b>mourir ne fait rien perdre</b> : le joueur est relevé sur place avec ses armes et son inventaire.</span></div>
            </div>

            <div class="section"><h2>Durée</h2>
                <div class="chips">${durs.map((m) => `<button class="chip ${ZD.custom === '' && ZD.duration === m ? 'chip-on' : ''}" data-zbdur="${m}">${m >= 60 ? `${Math.floor(m / 60)} h${m % 60 ? ` ${m % 60}` : ''}` : `${m} min`}</button>`).join('')}</div>
                <div class="inline" style="max-width:340px;margin-top:10px">
                    <input class="input" type="number" min="1" max="${z.maxDuration}" placeholder="Autre durée (minutes)" data-zbv="custom" value="${esc(ZD.custom)}">
                    <span class="muted" style="white-space:nowrap">max ${z.maxDuration} min</span>
                </div>
            </div>

            <div class="section"><h2>Intensité</h2>
                <div class="preset-grid">${intens.map((i) => `<button class="preset ${ZD.intensity === i.id ? 'active' : ''}" data-zbint="${i.id}">
                    <span class="pi">${{ low: '🧟', medium: '🧟🧟', high: '🧟🧟🧟', nightmare: '☠️' }[i.id] || '🧟'}</span>
                    <span class="pl">${esc(i.label)}<br><span class="muted" style="font-size:12px">${i.perPlayer} par joueur · ${i.global} max</span></span></button>`).join('')}</div>
            </div>

            <div class="section"><h2>Zone</h2>
                <div class="segmented">
                    <button class="seg ${ZD.area === 'city' ? 'active' : ''}" data-zbarea="city">🏙️ Ville de Los Santos</button>
                    <button class="seg ${ZD.area === 'map' ? 'active' : ''}" data-zbarea="map">🗺️ Toute la carte</button>
                    <button class="seg ${ZD.area === 'radius' ? 'active' : ''}" data-zbarea="radius">📍 Autour de moi</button>
                </div>
                ${ZD.area === 'radius' ? `<div class="inline" style="max-width:360px">
                    <label class="muted" style="white-space:nowrap">Rayon (m)</label>
                    <input class="input" type="number" min="100" max="5000" data-zbv="radius" value="${esc(ZD.radius)}"></div>` : ''}
                <p class="hint" style="margin-top:8px">Les zombies apparaissent seulement autour des joueurs qui sont dans la zone, jamais dans les safe zones ni dans les intérieurs.</p>
            </div>

            <div class="section"><h2>Ambiance et règles</h2>
                <div class="grid zb-toggles">
                    ${tile(ZD.storm, 'storm', '⛈️ Orage et pluie', 'Ciel noir, éclairs, filtre apocalyptique')}
                    ${tile(ZD.blackout, 'blackout', '💡 Coupure de courant', 'Lampadaires et enseignes éteints')}
                    ${tile(ZD.night, 'night', '🌙 Nuit', 'Heure bloquée à 23 h')}
                    ${tile(ZD.emptyCity, 'emptyCity', '🏚️ Ville déserte', 'Plus de passants ni de trafic')}
                    ${tile(ZD.headshot, 'headshot', '🎯 Seulement la tête', 'Les tirs au corps ne les arrêtent presque pas')}
                    ${tile(ZD.announce, 'announce', '📢 Annonce aux joueurs', 'Bandeau au début et à la fin')}
                </div>
                <div class="form-grid zb-grid" style="margin-top:12px">
                    <div><label>Zombies coureurs (%)</label><input class="input" type="number" min="0" max="100" data-zbv="runners" value="${esc(ZD.runners)}"></div>
                    <div><label>Cracheurs d'acide (%)</label><input class="input" type="number" min="0" max="100" data-zbv="spitters" value="${esc(ZD.spitters)}"></div>
                    <div><label>Force des coups (1 = normal)</label><input class="input" type="number" min="0.2" max="5" step="0.1" data-zbv="damage" value="${esc(ZD.damage)}"></div>
                </div>
                ${ZD.announce ? `<div class="field" style="max-width:760px"><label>Message de l'annonce</label>
                    <textarea class="input" maxlength="400" data-zbv="message" placeholder="${esc(z.defaultMessage || '')}">${esc(ZD.message)}</textarea></div>` : ''}
            </div>

            <div class="section"><h2>Missions pour les joueurs</h2>
                <p class="hint">Des objectifs à accomplir ensemble pendant l'attaque (ex. remonter à Humane Labs pour lancer la décontamination).
                Un blip et une zone au sol guident les joueurs, un encadré à l'écran indique l'étape en cours. Facultatif.</p>
                ${presetButtons(z, 'start')}
                ${missionEditor(z, 'start')}
            </div>

            <div class="section"><h2>Caisses d'armes</h2>
                ${cratesInfo(z)}
                ${cratePresetButtons(z, 'start')}
                ${crateEditor(z, 'start')}
            </div>
            ${z.reclaimPending > 0 ? `<div class="gf-warn"><span>${z.reclaimPending} joueur(s) doivent encore rendre des armes d'une attaque précédente (reprise à leur prochaine connexion).</span>
                <button class="btn" data-zca="reclaim">Reprendre maintenant</button></div>` : ''}
            ${itemOptions()}

            <button class="btn primary big zb-launch" data-zb="start">☣️ Lancer l'attaque${dur ? ` (${dur} min)` : ''}</button>`;
    }

    function activeView(z) {
        const s = z.settings || {};
        const intens = toArr(z.intensities);
        const remaining = (z.endsAt || 0) - serverNow();
        const top = toArr(z.top);
        const label = (intens.find((i) => i.id === s.intensity) || {}).label || s.intensity;
        return `<div class="zb-live">
                <div class="zb-live-head">
                    <div><span class="zb-pulse"></span><strong>Attaque de zombies en cours</strong>
                    <span class="muted">lancée par ${esc(z.by || '?')} · ${s.area === 'map' ? 'toute la carte' : s.area === 'radius' ? `rayon ${Math.round(s.radius)} m` : 'Los Santos'}</span></div>
                    <div class="zb-timer" id="zb-remaining">${clock(remaining)}</div>
                </div>
                <div class="stats" style="margin:14px 0 0">
                    <div class="stat"><b>${z.alive}</b><span>Zombies en vie</span></div>
                    <div class="stat"><b>${z.killed}</b><span>Zombies tués</span></div>
                    <div class="stat"><b>${z.deaths}</b><span>Joueurs relevés (sans perte)</span></div>
                    <div class="stat"><b>${esc(label)}</b><span>Intensité${z.paused ? ' · <span style="color:var(--danger)">apparitions suspendues</span>' : ''}</span></div>
                </div>
            </div>

            <div class="section"><h2>Actions</h2>
                <div class="btn-row">
                    <button class="btn danger big" data-zb="killall">💀 Tuer tous les zombies</button>
                    <button class="btn big ${z.paused ? 'on' : ''}" data-zb="pause">${z.paused ? '▶️ Reprendre les apparitions' : '⏸️ Suspendre les apparitions'}</button>
                </div>
                <p class="hint" style="margin-top:8px">« Tuer tous les zombies » les fait tomber d'un coup (les corps disparaissent après quelques secondes). L'attaque continue : suspends les apparitions pour une accalmie.</p>
            </div>

            <div class="section"><h2>Durée</h2>
                <div class="btn-row">
                    <button class="btn" data-zbext="-10">− 10 min</button>
                    <button class="btn" data-zbext="10">+ 10 min</button>
                    <button class="btn" data-zbext="30">+ 30 min</button>
                    <button class="btn" data-zbext="60">+ 1 h</button>
                </div>
            </div>

            <div class="section"><h2>Intensité</h2>
                <div class="segmented">${intens.map((i) => `<button class="seg ${s.intensity === i.id ? 'active' : ''}" data-zblive="${i.id}">${esc(i.label)}</button>`).join('')}</div>
            </div>

            <div class="section"><h2>Missions</h2>
                ${missionProgress(z)}
                <h3 class="sub-h" style="font-size:17px;margin-top:14px">Ajouter une mission maintenant</h3>
                ${ZD.live.length ? missionEditor(z, 'live') + `<button class="btn primary" data-zma="launch_live">☣️ Lancer cette mission</button>
                    <button class="btn" data-zma="clear_live">Annuler</button>` : presetButtons(z, 'live')}
            </div>

            <div class="section"><h2>Caisses d'armes</h2>
                ${crateLive(z)}
                <h3 class="sub-h" style="font-size:17px;margin-top:14px">Ajouter un type de caisse</h3>
                ${ZD.liveCrate.length ? crateEditor(z, 'live') + `<button class="btn primary" data-zca="launch_live">📦 Poser ces caisses</button>
                    <button class="btn" data-zca="clear_live">Annuler</button>` : cratePresetButtons(z, 'live')}
                ${itemOptions()}
            </div>

            ${top.length ? `<div class="section"><h2>Meilleurs survivants</h2>
                ${top.map((t, i) => `<div class="mini-row"><span class="t">${['🥇', '🥈', '🥉', '4.', '5.'][i]}</span><span><b>${esc(t.name)}</b> : ${t.kills} zombie${t.kills > 1 ? 's' : ''}</span></div>`).join('')}</div>` : ''}

            <button class="btn danger big" data-zb="stop">⏹️ Arrêter l'événement (la ville redevient normale)</button>`;
    }

    // =====================================================
    //  MISSIONS : éditeur
    // =====================================================
    const listOf = (ctx) => (ctx === 'live' ? ZD.live : ZD.missions);
    const placeOf = (z, id) => toArr(z.places).find((p) => p.id === id);

    function fromPreset(z, preset) {
        const m = clone(preset.mission);
        m.rewards = { ...emptyRewards(), ...(m.rewards || {}) };
        m.rewards.lines = toArr(m.rewards.lines).map((l) => ({ kind: l.kind, item: l.item || '', amount: l.amount }));
        m.rewards.players = toArr(m.rewards.players);
        m.steps = toArr(m.steps).map((st) => {
            const p = placeOf(z, st.place);
            return { ...st, place: p ? p.id : 'custom', x: p ? p.x : null, y: p ? p.y : null, z: p ? p.z : null,
                radius: st.radius ?? 6, seconds: st.seconds ?? 10, desc: st.desc || '' };
        });
        return m;
    }
    const emptyRewards = () => ({ to: 'participants', top: 3, players: [], lines: [] });
    const emptyMission = () => ({ title: '', desc: '', outcome: 'none', delay: 0, rewards: emptyRewards(), steps: [emptyStep()] });
    const emptyStep = () => ({ type: 'reach', title: '', desc: '', place: 'custom', x: null, y: null, z: null, radius: 8, seconds: 10 });

    function presetButtons(z, ctx) {
        const presets = toArr(z.presets);
        const limit = (z.limits && z.limits.missions) || 5;
        const full = ctx === 'start' && ZD.missions.length >= limit;
        return `<div class="btn-row" style="margin-bottom:12px">
            ${presets.map((p) => `<button class="btn" data-zma="preset" data-ctx="${ctx}" data-preset="${esc(p.id)}" ${full ? 'disabled' : ''}>${p.icon || '☣️'} ${esc(p.label)}</button>`).join('')}
            <button class="btn" data-zma="add_mission" data-ctx="${ctx}" ${full ? 'disabled' : ''}>+ Mission vide</button></div>`;
    }

    function missionEditor(z, ctx) {
        const list = listOf(ctx);
        if (!list.length) return '';
        const places = toArr(z.places);
        const maxSteps = (z.limits && z.limits.steps) || 8;
        return list.map((m, mi) => `<div class="card zm-card">
            <div class="card-head"><strong>Mission ${ctx === 'live' ? '' : mi + 1} ${m.outcome === 'decontaminate' ? '<span class="badge" style="color:var(--ok)">Décontamination</span>' : ''}</strong>
                ${ctx === 'start' ? `<button class="sb-close" title="Retirer la mission" data-zma="del_mission" data-ctx="${ctx}" data-mi="${mi}">✕</button>` : ''}</div>
            <div class="form-grid zm-grid">
                <div class="zm-wide"><label>Titre (vu par les joueurs)</label><input class="input" maxlength="60" data-zmf="${ctx}.${mi}.title" value="${esc(m.title)}" placeholder="ex : Décontamination totale"></div>
                <div class="zm-wide"><label>Description</label><input class="input" maxlength="200" data-zmf="${ctx}.${mi}.desc" value="${esc(m.desc)}"></div>
                <div class="zm-wide"><label>Quand la mission est réussie</label><select class="input" data-zmf="${ctx}.${mi}.outcome" data-zmr="1">
                    ${Object.entries(OUTCOMES).map(([k, l]) => `<option value="${k}" ${m.outcome === k ? 'selected' : ''}>${l}</option>`).join('')}</select></div>
                <div><label>Apparaît après (min)</label><input class="input" type="number" min="0" data-zmf="${ctx}.${mi}.delay" value="${esc(m.delay)}"></div>
            </div>
            <p class="hint">${m.delay > 0 ? `La mission apparaît ${m.delay} min après le lancement.` : 'La mission apparaît tout de suite.'}</p>
            ${rewardEditor(ctx, mi, m.rewards)}
            ${toArr(m.steps).map((st, si) => stepRow(ctx, mi, si, st, places, m.steps.length)).join('')}
            <button class="btn" data-zma="add_step" data-ctx="${ctx}" data-mi="${mi}" ${m.steps.length >= maxSteps ? 'disabled' : ''}>+ Ajouter une étape</button>
        </div>`).join('');
    }

    function itemOptions() {
        const z = Z() || {};
        const set = new Set();
        toArr(D.config && D.config.weapons).forEach((w) => set.add(z.inventory === 'qb' ? String(w.id).toLowerCase() : w.id));
        (AMMO[z.inventory] || []).forEach((a) => set.add(a));
        toArr(typeof ITEMS !== 'undefined' ? ITEMS : null).forEach((it) => it && it.name && set.add(it.name));
        return `<datalist id="zb-items">${[...set].filter(Boolean).sort().map((i) => `<option value="${esc(i)}">`).join('')}</datalist>`;
    }
    function askItems() {
        if (itemsAskedZ || typeof ITEMS === 'undefined' || ITEMS || !has('give_item')) return;
        itemsAskedZ = true;
        action('get_items');
    }

    function rewardEditor(ctx, mi, r) {
        r = r || emptyRewards();
        const base = `${ctx}.${mi}`;
        const players = [...toArr(D.players)].sort((a, b) => a.id - b.id);
        return `<div class="zm-step zm-reward">
            <div class="zm-step-head"><b>🎁 Récompenses</b><span class="muted">versées quand la mission est réussie</span></div>
            <div class="form-grid zm-grid">
                <div class="zm-wide"><label>À qui</label><select class="input" data-zmr-to="${base}" data-zmr="1">
                    ${Object.entries(REWARD_TO).map(([k, l]) => `<option value="${k}" ${r.to === k ? 'selected' : ''}>${l}</option>`).join('')}</select></div>
                ${r.to === 'top' ? `<div><label>Combien (les N premiers)</label><input class="input" type="number" min="1" max="50" data-zmr-top="${base}" value="${esc(r.top)}"></div>` : ''}
            </div>
            ${r.to === 'players' ? `<div class="zm-players">${players.map((p) => `<label class="perm"><input type="checkbox" data-zmr-player="${base}" value="${p.id}" ${toArr(r.players).map(Number).includes(p.id) ? 'checked' : ''}>#${p.id} ${esc(p.name)}</label>`).join('') || '<span class="muted">Aucun joueur connecté.</span>'}</div>
                <p class="hint">Seuls les joueurs choisis et connectés au moment de la réussite sont récompensés.</p>` : ''}
            ${toArr(r.lines).map((l, li) => `<div class="zm-line">
                <select class="input" data-zmr-line="${base}.${li}.kind" data-zmr="1">${Object.entries(REWARD_KIND).map(([k, t]) => `<option value="${k}" ${l.kind === k ? 'selected' : ''}>${t}</option>`).join('')}</select>
                ${l.kind === 'item' ? `<input class="input" list="zb-items" placeholder="Nom de l'objet" data-zmr-line="${base}.${li}.item" value="${esc(l.item)}">` : '<span></span>'}
                <input class="input" type="number" min="1" placeholder="${l.kind === 'item' ? 'Quantité' : 'Montant'}" data-zmr-line="${base}.${li}.amount" value="${esc(l.amount)}">
                <button class="sb-close" data-zma="del_reward" data-ctx="${ctx}" data-mi="${mi}" data-li="${li}">✕</button></div>`).join('')}
            <button class="btn zm-mini" data-zma="add_reward" data-ctx="${ctx}" data-mi="${mi}">+ Ajouter une récompense</button>
            ${!toArr(r.lines).length ? '<span class="muted" style="margin-left:8px;font-size:13px">Aucune récompense.</span>' : ''}
        </div>`;
    }

    // ---------- Caisses d'armes ----------
    const crateList = (ctx) => (ctx === 'live' ? ZD.liveCrate : ZD.crates);
    const emptyCrate = () => ({ label: '', model: 'prop_mil_crate_01', mode: 'once', blip: true, color: 1, count: 5, manual: [], contents: [{ item: '', count: 1 }] });
    function cratePresetButtons(z, ctx) {
        const full = ctx === 'start' && ZD.crates.length >= 8;
        return `<div class="btn-row" style="margin-bottom:12px">
            ${toArr(z.cratePresets).map((p) => `<button class="btn" data-zca="preset" data-ctx="${ctx}" data-preset="${esc(p.id)}" ${full ? 'disabled' : ''}>${p.icon || '📦'} ${esc(p.label)}</button>`).join('')}
            <button class="btn" data-zca="add" data-ctx="${ctx}" ${full ? 'disabled' : ''}>+ Caisse vide</button></div>`;
    }
    function crateEditor(z, ctx) {
        const list = crateList(ctx);
        if (!list.length) return '';
        const models = toArr(z.crateModels), colors = toArr(z.crateColors);
        return list.map((t, ci) => {
            const b = `${ctx}.${ci}`;
            return `<div class="card zm-card">
            <div class="card-head"><strong>📦 ${esc(t.label || 'Nouvelle caisse')}</strong>
                ${ctx === 'start' ? `<button class="sb-close" title="Retirer" data-zca="del" data-ctx="${ctx}" data-ci="${ci}">✕</button>` : ''}</div>
            <div class="form-grid zm-grid">
                <div class="zm-wide"><label>Nom (vu par les joueurs)</label><input class="input" maxlength="40" data-zcf="${b}.label" value="${esc(t.label)}" placeholder="ex : Caisse de pistolets"></div>
                <div><label>Apparence</label><select class="input" data-zcf="${b}.model">${models.map((m) => `<option value="${esc(m.id)}" ${t.model === m.id ? 'selected' : ''}>${esc(m.label)}</option>`).join('')}</select></div>
                <div><label>Qui peut se servir</label><select class="input" data-zcf="${b}.mode">
                    <option value="once" ${t.mode === 'once' ? 'selected' : ''}>Le premier qui l'ouvre</option>
                    <option value="each" ${t.mode === 'each' ? 'selected' : ''}>Chaque joueur, une fois</option></select></div>
                <div><label>Nombre placé automatiquement</label><input class="input" type="number" min="0" max="60" data-zcf="${b}.count" value="${esc(t.count)}"></div>
                <div><label>Sur la carte</label><select class="input" data-zcf="${b}.blip" data-zcr="1">
                    <option value="true" ${t.blip ? 'selected' : ''}>Visible</option><option value="false" ${!t.blip ? 'selected' : ''}>Cachée</option></select></div>
                ${t.blip ? `<div><label>Couleur du point</label><select class="input" data-zcf="${b}.color">${colors.map((c) => `<option value="${c.id}" ${Number(t.color) === c.id ? 'selected' : ''}>${esc(c.label)}</option>`).join('')}</select></div>` : '<div></div>'}
            </div>
            <div class="zm-step"><div class="zm-step-head"><b>Contenu</b><span class="muted">armes, munitions ou n'importe quel objet</span></div>
                ${toArr(t.contents).map((c, ii) => `<div class="zm-line zm-line-2">
                    <input class="input" list="zb-items" placeholder="ex : WEAPON_PISTOL, ammo-9…" data-zcc="${b}.${ii}.item" value="${esc(c.item)}">
                    <input class="input" type="number" min="1" data-zcc="${b}.${ii}.count" value="${esc(c.count)}">
                    <button class="sb-close" data-zca="del_item" data-ctx="${ctx}" data-ci="${ci}" data-ii="${ii}">✕</button></div>`).join('')}
                <button class="btn zm-mini" data-zca="add_item" data-ctx="${ctx}" data-ci="${ci}">+ Objet</button>
            </div>
            <div class="zm-step"><div class="zm-step-head"><b>Positions précises (en plus des automatiques)</b>
                <button class="btn zm-mini" data-zca="mypos" data-ctx="${ctx}" data-ci="${ci}">📍 Ajouter ma position</button></div>
                ${toArr(t.manual).map((p, pi) => `<div class="gf-veh"><span>📍 ${Number(p.x).toFixed(1)}, ${Number(p.y).toFixed(1)}, ${Number(p.z).toFixed(1)}</span>
                    <span>${has('tp_coords') ? `<button class="btn zm-mini" data-zca="tp" data-ctx="${ctx}" data-ci="${ci}" data-pi="${pi}">Y aller</button>` : ''}
                    <button class="sb-close" data-zca="del_pos" data-ctx="${ctx}" data-ci="${ci}" data-pi="${pi}">✕</button></span></div>`).join('') || '<span class="muted" style="font-size:13px">Aucune : seulement les emplacements automatiques de la zone.</span>'}
            </div></div>`;
        }).join('');
    }
    function cratesInfo(z) {
        return `<p class="hint">Les caisses apparaissent sur des emplacements dégagés de la zone (stations-service, places, parkings) et/ou aux positions que tu ajoutes.
            Les joueurs maintiennent <span class="keycap">E</span> pour les ouvrir. <b>À la fin de l'événement, tout ce qui a été pris dans les caisses est repris</b>
            ${z.tagged ? '(les objets sont marqués : seuls ceux-là sont retirés, même s\'ils ont été donnés à quelqu\'un d\'autre)'
        : '(au plus la quantité prise, chez ceux qui ont ouvert les caisses)'} ; un joueur déconnecté est repris à sa prochaine connexion.</p>`;
    }
    const cratePayload = (list) => list.map((t) => ({
        label: t.label, model: t.model, mode: t.mode, blip: t.blip === true || t.blip === 'true', color: Number(t.color),
        count: Number(t.count) || 0, manual: toArr(t.manual),
        contents: toArr(t.contents).filter((c) => String(c.item).trim()).map((c) => ({ item: String(c.item).trim(), count: Number(c.count) || 1 })),
    }));
    function checkCrates(list) {
        for (const t of list) {
            if (!String(t.label).trim()) return 'Donne un nom à chaque caisse.';
            if (!toArr(t.contents).some((c) => String(c.item).trim())) return `La caisse « ${t.label} » est vide.`;
        }
        return null;
    }

    async function crateAction(n) {
        const a = n.dataset.zca, ctx = n.dataset.ctx, ci = Number(n.dataset.ci);
        const z = Z();
        const list = ctx ? crateList(ctx) : null;
        switch (a) {
            case 'preset': {
                const p = toArr(z.cratePresets).find((x) => x.id === n.dataset.preset);
                if (!p) return;
                const t = { ...emptyCrate(), ...clone(p), manual: [] };
                t.contents = toArr(t.contents);
                if (ctx === 'live') ZD.liveCrate = [t]; else ZD.crates.push(t);
                return render();
            }
            case 'add': if (ctx === 'live') ZD.liveCrate = [emptyCrate()]; else ZD.crates.push(emptyCrate()); return render();
            case 'del': list.splice(ci, 1); return render();
            case 'add_item': list[ci].contents.push({ item: '', count: 1 }); return render();
            case 'del_item': list[ci].contents.splice(Number(n.dataset.ii), 1); return render();
            case 'mypos': {
                const pos = await post('zombiesPos');
                if (!pos || pos.x === undefined) return toast('Position introuvable.', 'error');
                list[ci].manual.push({ x: pos.x, y: pos.y, z: pos.z });
                return render();
            }
            case 'del_pos': list[ci].manual.splice(Number(n.dataset.pi), 1); return render();
            case 'tp': { const p = list[ci].manual[Number(n.dataset.pi)]; return selfAction('tp_coords', { x: p.x, y: p.y, z: p.z }); }
            case 'launch_live': {
                const err = checkCrates(ZD.liveCrate);
                if (err) return toast(err, 'error');
                action('zombies_crate_type', { crate: cratePayload(ZD.liveCrate)[0] });
                ZD.liveCrate = [];
                return render();
            }
            case 'clear_live': ZD.liveCrate = []; return render();
            case 'more': return action('zombies_crate_more', { type: Number(n.dataset.type), count: 5 });
            case 'here': return action('zombies_crate_here', { type: Number(n.dataset.type) });
            case 'clear':
                if (!(await confirmBox('Retirer toutes les caisses ?', 'Les caisses non ouvertes disparaissent. Ce qui a déjà été pris sera repris à la fin.'))) return;
                return action('zombies_crate_clear');
            case 'reclaim': return action('zombies_reclaim_now');
        }
    }

    function stepRow(ctx, mi, si, st, places, count) {
        const path = `${ctx}.${mi}.${si}`;
        const hasPos = st.x !== null && st.x !== undefined && st.x !== '';
        return `<div class="zm-step">
            <div class="zm-step-head"><b>Étape ${si + 1}</b>
                <span>${si > 0 ? `<button class="btn zm-mini" data-zma="up" data-ctx="${ctx}" data-mi="${mi}" data-si="${si}">↑</button>` : ''}
                ${si < count - 1 ? `<button class="btn zm-mini" data-zma="down" data-ctx="${ctx}" data-mi="${mi}" data-si="${si}">↓</button>` : ''}
                ${count > 1 ? `<button class="sb-close" data-zma="del_step" data-ctx="${ctx}" data-mi="${mi}" data-si="${si}">✕</button>` : ''}</span></div>
            <div class="form-grid zm-grid">
                <div><label>Type</label><select class="input" data-zms="${path}.type" data-zmr="1">
                    ${Object.entries(STEP_TYPES).map(([k, t]) => `<option value="${k}" ${st.type === k ? 'selected' : ''}>${t.label}</option>`).join('')}</select></div>
                <div class="zm-span2"><label>Objectif affiché</label><input class="input" maxlength="60" data-zms="${path}.title" value="${esc(st.title)}" placeholder="ex : Lancer la décontamination"></div>
                <div class="zm-wide"><label>Précision (optionnel)</label><input class="input" maxlength="160" data-zms="${path}.desc" value="${esc(st.desc)}"></div>
                <div class="zm-span2"><label>Lieu</label><select class="input" data-zms="${path}.place" data-zmr="1">
                    ${places.map((p) => `<option value="${esc(p.id)}" ${st.place === p.id ? 'selected' : ''}>${esc(p.label)}</option>`).join('')}
                    <option value="custom" ${st.place === 'custom' ? 'selected' : ''}>${hasPos ? 'Position personnalisée' : 'Choisir…'}</option></select></div>
                <div style="display:flex;align-items:flex-end;gap:6px">
                    <button class="btn" data-zma="pickmap" data-ctx="${ctx}" data-mi="${mi}" data-si="${si}" title="Poser un repère sur la carte">🗺️ Carte</button>
                    <button class="btn" data-zma="mypos" data-ctx="${ctx}" data-mi="${mi}" data-si="${si}" title="Utiliser ta position actuelle">📍 Ma position</button>
                    ${hasPos && has('tp_coords') ? `<button class="btn" data-zma="tp" data-ctx="${ctx}" data-mi="${mi}" data-si="${si}">Y aller</button>` : ''}</div>
                <div><label>${st.type === 'boss' ? 'Territoire du boss (m)' : 'Rayon (m)'}</label><input class="input" type="number" min="3" max="300" data-zms="${path}.radius" value="${esc(st.radius)}"></div>
                ${st.type === 'boss' ? '<div></div>' : st.type !== 'reach' ? `<div><label>${st.type === 'defend' ? 'Temps à tenir (s)' : 'Temps à maintenir E (s)'}</label>
                    <input class="input" type="number" min="3" max="900" data-zms="${path}.seconds" value="${esc(st.seconds)}"></div>` : '<div></div>'}
            </div>
            ${st.type === 'boss' ? `<div class="form-grid zm-grid" style="margin-top:8px;padding:12px;border-radius:12px;background:rgba(224,67,59,.06);border:1px solid rgba(224,67,59,.25)">
                <div class="zm-span2"><label>☠️ Nom du boss</label><input class="input" maxlength="40" data-zms="${path}.bossName" value="${esc(st.bossName)}" placeholder="ex : Le Colosse"></div>
                <div class="zm-span2"><label>Apparence</label><select class="input" data-zms="${path}.bossModel">
                    ${BOSS_MODELS.map(([k, l]) => `<option value="${k}" ${st.bossModel === k ? 'selected' : ''}>${esc(l)}</option>`).join('')}</select></div>
                <div><label>Vie (500 à 200 000)</label><input class="input" type="number" min="500" max="200000" step="500" data-zms="${path}.bossHealth" value="${esc(st.bossHealth)}"></div>
                <div><label>Taille (×1 à ×3)</label><input class="input" type="number" min="1" max="3" step="0.1" data-zms="${path}.bossScale" value="${esc(st.bossScale)}"></div>
                <div><label>Vitesse</label><select class="input" data-zms="${path}.bossSpeed">
                    ${[[0.8, 'Très lent'], [1.2, 'Lent'], [1.6, 'Normal (marche)'], [2.2, 'Rapide (trot)'], [3.0, 'Très rapide (il court)']].map(([v, l]) => `<option value="${v}" ${Math.abs((Number(st.bossSpeed) || 1.6) - v) < 0.05 ? 'selected' : ''}>${l}</option>`).join('')}</select></div>
                <div><label>Zombies autour de lui</label><input class="input" type="number" min="0" max="40" data-zms="${path}.minions" value="${esc(st.minions)}"></div>
                <div><label>Renforts</label><select class="input" data-zms="${path}.reinforce">
                    <option value="true" ${st.reinforce === true || st.reinforce === 'true' ? 'selected' : ''}>Les gardes morts reviennent</option>
                    <option value="false" ${!(st.reinforce === true || st.reinforce === 'true') ? 'selected' : ''}>Pas de renforts</option></select></div>
            </div>` : ''}
            <p class="hint">${STEP_TYPES[st.type].hint} ${hasPos ? `<span class="muted">(${Number(st.x).toFixed(1)}, ${Number(st.y).toFixed(1)}, ${Number(st.z).toFixed(1)})</span>` : '<span style="color:var(--danger)">Aucun lieu choisi.</span>'}</p>
        </div>`;
    }

    function crateLive(z) {
        const c = z.crates || {};
        const types = toArr(c.types);
        return `<p class="hint">${c.given || 0} objet(s) sortis des caisses par ${c.looters || 0} joueur(s) : tout sera repris à la fin de l'attaque.</p>
            ${types.length ? `<table>${types.map((t) => `<tr>
                <td><strong>${esc(t.label)}</strong><div class="muted gf-small">${esc(t.contents)} · ${t.mode === 'each' ? 'chacun sa part' : 'le premier qui l\'ouvre'}${t.blip ? '' : ' · cachées'}</div></td>
                <td class="muted">${t.left} en place · ${t.opened} ouverte(s)</td>
                <td style="text-align:right;white-space:nowrap"><button class="btn" data-zca="more" data-type="${t.index}">+5 (auto)</button>
                    <button class="btn" data-zca="here" data-type="${t.index}">📍 Ici</button></td></tr>`).join('')}</table>
                <button class="btn danger" style="margin-top:10px" data-zca="clear">Retirer toutes les caisses</button>` : '<p class="hint">Aucune caisse pour cette attaque.</p>'}`;
    }

    function missionProgress(z) {
        const ms = toArr(z.missions);
        if (!ms.length) return '<p class="hint">Aucune mission pour cette attaque.</p>';
        const sNow = serverNow();
        return ms.map((m) => {
            const state = { waiting: `⏳ Apparaît dans ${clock((m.startsAt || 0) - sNow)}`, active: '🟢 En cours', done: '✔ Réussie', cancelled: '✕ Annulée' }[m.state] || m.state;
            const prog = m.state === 'active' && m.stepType === 'defend' ? ` · ${m.progress}/${m.seconds} s`
                : m.state === 'active' && m.stepType === 'boss' ? ` · ☠ ${esc(m.bossName || 'boss')} à abattre` : '';
            const open = m.state === 'active' || m.state === 'waiting';
            return `<div class="card zm-card"><div class="card-head"><strong>${esc(m.title)} ${m.outcome === 'decontaminate' ? '<span class="badge" style="color:var(--ok)">Décontamination</span>' : ''}</strong>
                <span class="muted">${state}</span></div>
                <div class="recipe-preview">${m.state === 'active' ? `<span>Étape ${m.step}/${m.total} : <b>${esc(m.stepTitle)}</b>${prog}</span>` : ''}
                <span class="muted">${m.participants} participant(s)</span></div>
                ${open ? `<div class="btn-row"><button class="btn" data-zma="skip" data-id="${m.id}">${m.state === 'waiting' ? '▶️ Lancer maintenant' : '⏭️ Valider l\'étape'}</button>
                    <button class="btn danger" data-zma="cancel" data-id="${m.id}">Annuler la mission</button></div>` : ''}</div>`;
        }).join('');
    }

    function checkRewards(list) {
        for (const m of list) {
            const r = m.rewards;
            for (const l of toArr(r.lines)) {
                if (l.kind === 'item' && !String(l.item || '').trim()) return `« ${m.title} » : indique le nom de l'objet en récompense.`;
                if (!(Number(l.amount) > 0)) return `« ${m.title} » : une récompense a un montant vide.`;
            }
            if (r.to === 'players' && toArr(r.lines).length && !toArr(r.players).length) return `« ${m.title} » : choisis les joueurs à récompenser.`;
        }
        return null;
    }

    function checkMissions(list) {
        for (const m of list) {
            if (!String(m.title).trim()) return 'Donne un titre à chaque mission.';
            if (!m.steps.length) return `« ${m.title} » n'a aucune étape.`;
            for (let i = 0; i < m.steps.length; i += 1) {
                const st = m.steps[i];
                if (!String(st.title).trim()) return `« ${m.title} » : l'étape ${i + 1} n'a pas d'objectif affiché.`;
                if (st.x === null || st.x === undefined || st.x === '') return `« ${m.title} » : l'étape ${i + 1} n'a pas de lieu.`;
            }
        }
        return null;
    }
    const payloadOf = (list) => list.map((m) => ({
        title: m.title, desc: m.desc, outcome: m.outcome, delay: Number(m.delay) || 0,
        rewards: {
            to: m.rewards.to, top: Number(m.rewards.top) || 3, players: toArr(m.rewards.players).map(Number),
            lines: toArr(m.rewards.lines).map((l) => ({ kind: l.kind, item: String(l.item || '').trim(), amount: Number(l.amount) || 0 })),
        },
        steps: m.steps.map((st) => ({ type: st.type, title: st.title, desc: st.desc, x: Number(st.x), y: Number(st.y), z: Number(st.z),
            radius: Number(st.radius), seconds: Number(st.seconds),
            ...(st.type === 'boss' ? { bossName: st.bossName, bossHealth: Number(st.bossHealth), bossScale: Number(st.bossScale), bossSpeed: Number(st.bossSpeed) || 1.6,
                bossModel: st.bossModel, minions: Number(st.minions), reinforce: st.reinforce === true || st.reinforce === 'true' } : {}) })),
    }));

    async function missionAction(n) {
        const a = n.dataset.zma, ctx = n.dataset.ctx, mi = Number(n.dataset.mi), si = Number(n.dataset.si);
        const z = Z();
        const list = ctx ? listOf(ctx) : null;
        switch (a) {
            case 'preset': {
                const p = toArr(z.presets).find((x) => x.id === n.dataset.preset);
                if (!p) return;
                const m = fromPreset(z, p);
                if (ctx === 'live') { m.delay = 0; ZD.live = [m]; } else ZD.missions.push(m);
                return render();
            }
            case 'pickmap': return post('drops_pick', { mode: 'map', tag: `zstep:${ctx}:${mi}:${si}` });
            case 'add_mission':
                if (ctx === 'live') ZD.live = [emptyMission()]; else ZD.missions.push(emptyMission());
                return render();
            case 'del_mission': list.splice(mi, 1); return render();
            case 'add_step': list[mi].steps.push(emptyStep()); return render();
            case 'del_step': list[mi].steps.splice(si, 1); return render();
            case 'up': case 'down': {
                const steps = list[mi].steps, j = a === 'up' ? si - 1 : si + 1;
                [steps[si], steps[j]] = [steps[j], steps[si]];
                return render();
            }
            case 'mypos': {
                const pos = await post('zombiesPos');
                if (!pos || pos.x === undefined) return toast('Position introuvable.', 'error');
                Object.assign(list[mi].steps[si], { x: pos.x, y: pos.y, z: pos.z, place: 'custom' });
                toast('Lieu réglé sur ta position.', 'success');
                return render();
            }
            case 'tp': {
                const st = list[mi].steps[si];
                return selfAction('tp_coords', { x: st.x, y: st.y, z: st.z });
            }
            case 'add_reward': list[mi].rewards.lines.push({ kind: 'cash', item: '', amount: 1000 }); return render();
            case 'del_reward': list[mi].rewards.lines.splice(Number(n.dataset.li), 1); return render();
            case 'launch_live': {
                const err = checkMissions(ZD.live) || checkRewards(ZD.live);
                if (err) return toast(err, 'error');
                action('zombies_mission_add', { mission: payloadOf(ZD.live)[0] });
                ZD.live = [];
                return render();
            }
            case 'clear_live': ZD.live = []; return render();
            case 'skip': return action('zombies_mission_skip', { id: Number(n.dataset.id) });
            case 'cancel':
                if (!(await confirmBox('Annuler cette mission ?', 'Elle disparaît pour tous les joueurs, sans récompense.'))) return;
                return action('zombies_mission_cancel', { id: Number(n.dataset.id) });
        }
    }

    EVENTS.push({ id: 'zombies', label: '🧟 Attaque de zombies', show: () => has('event_zombies'), render: view });

    // Compte à rebours en direct dans le panneau
    setInterval(() => {
        const el = document.getElementById('zb-remaining');
        const z = Z();
        if (el && z && z.active) el.textContent = clock((z.endsAt || 0) - serverNow());
    }, 1000);

    // ---------- Écouteurs ----------
    content.addEventListener('click', async (ev) => {
        const el = (sel) => ev.target.closest(sel);
        let n;
        if ((n = el('[data-zbdur]'))) { ZD.duration = Number(n.dataset.zbdur); ZD.custom = ''; return render(); }
        if ((n = el('[data-zbint]'))) { ZD.intensity = n.dataset.zbint; return render(); }
        if ((n = el('[data-zbarea]'))) { ZD.area = n.dataset.zbarea; return render(); }
        if ((n = el('[data-zbt]'))) { ZD[n.dataset.zbt] = !ZD[n.dataset.zbt]; return render(); }
        if ((n = el('[data-zbext]'))) return action('zombies_extend', { minutes: Number(n.dataset.zbext) });
        if ((n = el('[data-zblive]'))) return action('zombies_intensity', { intensity: n.dataset.zblive });
        if ((n = el('[data-zma]'))) { missionAction(n); return; }
        if ((n = el('[data-zca]'))) { crateAction(n); return; }
        if ((n = el('[data-zb]'))) {
            const a = n.dataset.zb;
            if (a === 'start') {
                const duration = ZD.custom !== '' ? Number(ZD.custom) : ZD.duration;
                if (!duration || duration < 1) return toast('Indique une durée.', 'error');
                const max = (Z() && Z().maxDuration) || 240;
                if (duration > max) return toast(`Durée maximum : ${max} minutes.`, 'error');
                const err = checkMissions(ZD.missions) || checkCrates(ZD.crates) || checkRewards(ZD.missions);
                if (err) return toast(err, 'error');
                if (!(await confirmBox('Lancer l\'attaque de zombies ?', `Pendant ${duration} minutes, tout le serveur passe en mode apocalypse${ZD.missions.length ? `, avec ${ZD.missions.length} mission(s)` : ''}.`))) return;
                return action('zombies_start', {
                    duration, intensity: ZD.intensity, area: ZD.area, radius: Number(ZD.radius),
                    storm: ZD.storm, blackout: ZD.blackout, night: ZD.night, emptyCity: ZD.emptyCity,
                    headshot: ZD.headshot, runners: Number(ZD.runners), spitters: Number(ZD.spitters), damage: Number(ZD.damage),
                    announce: ZD.announce, message: ZD.message, missions: payloadOf(ZD.missions), crates: cratePayload(ZD.crates),
                });
            }
            if (a === 'killall') {
                if (!(await confirmBox('Tuer tous les zombies ?', 'Tous les zombies en vie tombent immédiatement.'))) return;
                return action('zombies_killall');
            }
            if (a === 'pause') return action('zombies_pause');
            if (a === 'stop') {
                if (!(await confirmBox('Arrêter l\'attaque ?', 'Tous les zombies disparaissent, la météo et l\'heure reviennent comme avant.'))) return;
                return action('zombies_stop');
            }
        }
    });

    function setCrateField(t) {
        if (t.dataset.zcf) {
            const [ctx, ci, key] = t.dataset.zcf.split('.');
            const c = crateList(ctx)[Number(ci)];
            if (c) c[key] = key === 'blip' ? t.value === 'true' : t.value;
            return true;
        }
        if (t.dataset.zcc) {
            const [ctx, ci, ii, key] = t.dataset.zcc.split('.');
            const c = crateList(ctx)[Number(ci)];
            if (c && c.contents[Number(ii)]) c.contents[Number(ii)][key] = t.value;
            return true;
        }
        return false;
    }
    function setRewardField(t) {
        const get = (base) => { const [ctx, mi] = base.split('.'); const m = listOf(ctx)[Number(mi)]; return m && m.rewards; };
        if (t.dataset.zmrTo) { const r = get(t.dataset.zmrTo); if (r) r.to = t.value; return true; }
        if (t.dataset.zmrTop) { const r = get(t.dataset.zmrTop); if (r) r.top = t.value; return true; }
        if (t.dataset.zmrPlayer) {
            const r = get(t.dataset.zmrPlayer);
            if (r) {
                const id = Number(t.value);
                r.players = toArr(r.players).map(Number).filter((x) => x !== id);
                if (t.checked) r.players.push(id);
            }
            return true;
        }
        if (t.dataset.zmrLine) {
            const [ctx, mi, li, key] = t.dataset.zmrLine.split('.');
            const m = listOf(ctx)[Number(mi)];
            const l = m && m.rewards.lines[Number(li)];
            if (l) l[key] = t.value;
            return true;
        }
        return false;
    }

    function setMissionField(t) {
        if (t.dataset.zmf) {
            const [ctx, mi, key] = t.dataset.zmf.split('.');
            const m = listOf(ctx)[Number(mi)];
            if (m) m[key] = t.value;
            return true;
        }
        if (t.dataset.zms) {
            const [ctx, mi, si, key] = t.dataset.zms.split('.');
            const m = listOf(ctx)[Number(mi)];
            const st = m && m.steps[Number(si)];
            if (!st) return true;
            st[key] = t.value;
            if (key === 'place' && t.value !== 'custom') {
                const p = placeOf(Z(), t.value);
                if (p) Object.assign(st, { x: p.x, y: p.y, z: p.z });
            }
            if (key === 'type') {
                if (t.value === 'defend') { st.radius = Math.max(Number(st.radius) || 0, 20); if ((Number(st.seconds) || 0) < 30) st.seconds = 60; }
                if (t.value === 'interact') st.radius = Math.min(Number(st.radius) || 6, 10);
                if (t.value === 'boss') {
                    Object.assign(st, { ...bossDefaults(), ...Object.fromEntries(Object.entries(st).filter(([k, v]) => k.startsWith('boss') && v !== undefined && v !== '')) });
                    if (st.minions === undefined) st.minions = bossDefaults().minions;
                    if (st.reinforce === undefined) st.reinforce = bossDefaults().reinforce;
                    st.radius = Math.max(Number(st.radius) || 0, 60);
                    if (!st.title) st.title = `Tuer ${st.bossName}`;
                }
            }
            return true;
        }
        return false;
    }
    content.addEventListener('change', (ev) => {
        const t = ev.target;
        if ((t.dataset.zmf || t.dataset.zms) && setMissionField(t) && t.dataset.zmr) return render();
        if (setRewardField(t) && (t.dataset.zmr || t.dataset.zmrPlayer)) return render();
        if (setCrateField(t) && t.dataset.zcr) return render();
    });

    content.addEventListener('input', (ev) => {
        const t = ev.target;
        if (setMissionField(t)) return;
        if (t.type !== 'checkbox' && (setRewardField(t) || setCrateField(t))) return;
        if (t.dataset.zbv) ZD[t.dataset.zbv] = t.value;
        if (t.dataset.zbv === 'custom') {
            const b = document.querySelector('.zb-launch');
            if (b) b.textContent = `☣️ Lancer l'attaque${t.value ? ` (${t.value} min)` : ` (${ZD.duration} min)`}`;
        }
    });

    // =====================================================
    //  BANDEAU DES JOUEURS
    // =====================================================
    let hudEnd = 0, hudKills = 0, hudTimer = null;
    function drawHud() {
        const box = document.getElementById('zombiehud');
        const left = Math.max(0, Math.round((hudEnd - Date.now()) / 1000));
        box.innerHTML = `<span class="zh-ico">☣</span><span class="zh-title">Attaque de zombies</span>
            <span class="zh-sep"></span><span class="zh-time">${clock(left)}</span>
            <span class="zh-sep"></span><span class="zh-kills">💀 ${hudKills}</span>`;
    }
    function drawMissions(list) {
        let box = document.getElementById('zombiemissions');
        if (!box) {
            box = document.createElement('div');
            box.id = 'zombiemissions';
            document.body.appendChild(box);
        }
        list = toArr(list);
        if (!list.length) { box.classList.add('hidden'); box.innerHTML = ''; return; }
        box.classList.remove('hidden');
        const dist = (d) => (d < 1000 ? `${d} m` : `${(d / 1000).toFixed(1)} km`);
        box.innerHTML = `<div class="zm-head">☣ Missions</div>${list.map((m) => {
            let state = m.inside ? (m.type === 'interact' ? 'Maintiens E' : m.type === 'defend' ? 'Tenez la zone !' : '') : dist(m.distance);
            if (m.type === 'defend' && !m.inside && m.done > 0) state = `${dist(m.distance)} · ${m.done}/${m.seconds} s`;
            if (m.type === 'boss') state = m.bossPct !== undefined && m.bossPct !== null
                ? `☠ ${esc(m.bossName || 'Boss')} · ${m.bossPct} % de vie · ${dist(m.bossDist ?? m.distance)}`
                : `☠ ${esc(m.bossName || 'Boss')} · ${dist(m.distance)}`;
            return `<div class="zm-item ${m.decon ? 'decon' : ''} ${m.type === 'boss' ? 'boss' : ''}">
                <div class="zm-title">${esc(m.title)} <span>${m.step}/${m.total}</span></div>
                <div class="zm-step-now">${esc(m.stepTitle)}</div>
                ${m.desc ? `<div class="zm-desc">${esc(m.desc)}</div>` : ''}
                ${m.progress !== null && m.progress !== undefined ? `<div class="zm-bar"><div style="width:${m.progress}%"></div></div>` : ''}
                <div class="zm-state">${state}</div></div>`;
        }).join('')}`;
    }

    window.addEventListener('message', (ev) => {
        const m = ev.data;
        if (m && m.action === 'zombiemissions') return drawMissions(m.list);
        if (!m || m.action !== 'zombiehud') return;
        const box = document.getElementById('zombiehud');
        if (!m.active) {
            box.classList.add('hidden');
            if (hudTimer) { clearInterval(hudTimer); hudTimer = null; }
            return;
        }
        hudEnd = Date.now() + (Number(m.remaining) || 0) * 1000;
        hudKills = Number(m.kills) || 0;
        box.classList.remove('hidden');
        drawHud();
        if (!hudTimer) hudTimer = setInterval(drawHud, 1000);
    });

    // ---------- Barre de vie du boss ----------
    (() => {
        const css = document.createElement('style');
        css.textContent = `
            #zboss { position: fixed; left: 50%; top: 28px; transform: translateX(-50%); width: min(560px, 80vw); z-index: 55; pointer-events: none; text-align: center; animation: zbIn .35s ease-out; }
            #zboss .zb-name { font: 700 22px var(--brand); letter-spacing: .12em; color: #ffd6cc; text-shadow: 0 0 12px rgba(224,67,59,.8), 0 2px 4px #000; text-transform: uppercase; }
            #zboss .zb-sub { font: 600 12px var(--display); letter-spacing: .18em; color: rgba(255,255,255,.65); text-transform: uppercase; margin: 2px 0 6px; text-shadow: 0 1px 3px #000; }
            #zboss .zb-track { height: 14px; border-radius: 10px; background: rgba(10,6,8,.85); box-shadow: 0 0 0 1px rgba(224,67,59,.6), 0 0 0 2px #000, 0 0 24px -6px rgba(224,67,59,.9); overflow: hidden; position: relative; }
            #zboss .zb-fill { position: absolute; inset: 0 auto 0 0; background: linear-gradient(90deg, #7a0d0d, #e0433b 60%, #ff8a5c); transition: width .3s ease-out; }
            #zboss .zb-ghost { position: absolute; inset: 0 auto 0 0; background: rgba(255,200,180,.35); transition: width 1.2s ease-in .3s; }
            #zboss .zb-hp { font: 700 13px var(--display); color: #fff; margin-top: 4px; text-shadow: 0 1px 3px #000; }
            @keyframes zbIn { from { opacity: 0; transform: translate(-50%, -10px); } }`;
        document.head.appendChild(css);
        window.addEventListener('message', (ev) => {
            const m = ev.data || {};
            if (m.action !== 'zboss') return;
            let el = document.getElementById('zboss');
            if (!m.show) { if (el) el.remove(); return; }
            if (!el) {
                el = document.createElement('div');
                el.id = 'zboss';
                el.innerHTML = '<div class="zb-name"></div><div class="zb-sub">Boss · tuez-le</div><div class="zb-track"><div class="zb-ghost"></div><div class="zb-fill"></div></div><div class="zb-hp"></div>';
                document.body.appendChild(el);
            }
            el.querySelector('.zb-name').textContent = m.name || 'Boss';
            el.querySelector('.zb-fill').style.width = `${m.pct}%`;
            el.querySelector('.zb-ghost').style.width = `${m.pct}%`;
            el.querySelector('.zb-hp').textContent = `${Math.round(m.hp).toLocaleString('fr-FR')} / ${Math.round(m.max).toLocaleString('fr-FR')}`;
        });
    })();

    window.addEventListener('message', (ev) => {
        const m = ev.data || {};
        if (m.action !== 'mapPicked' || !String(m.tag || '').startsWith('zstep:')) return;
        const [, ctx, mi, si] = m.tag.split(':');
        const mission = listOf(ctx)[Number(mi)];
        const st = mission && mission.steps[Number(si)];
        if (!st) return;
        Object.assign(st, { place: 'custom', x: Math.round(m.x * 10) / 10, y: Math.round(m.y * 10) / 10, z: Math.round(m.z * 10) / 10 });
        toast(`Position de l'étape : ${m.place || 'choisie sur la carte'}.`, 'success');
        if (isOpen && tab === 'events') render();
    });
})();
