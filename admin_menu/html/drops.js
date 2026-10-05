/* =========================================================
   ÉVÉNEMENT : LARGAGE DE DROPS (onglet Événements)
   Planning (heure + position sur la carte), contenu, escouades
   de gardes, porteur de la clé, ouverture, public prévenu.
   ========================================================= */
(() => {
    'use strict';
    const EVENTS = window.AM_EVENTS = window.AM_EVENTS || [];
    const toArr = (v) => (Array.isArray(v) ? v : (v && typeof v === 'object' ? Object.values(v) : []));
    const clone = (o) => JSON.parse(JSON.stringify(o));
    const DR = { edit: null, settings: null, showSettings: false, itemsAsked: false };
    const Dd = () => (D && D.drops) || null;

    let offset = 0, offFor = null;
    const serverNow = () => {
        const d = Dd();
        if (d && d.now && offFor !== d.now) { offFor = d.now; offset = d.now - Math.floor(Date.now() / 1000); }
        return Math.floor(Date.now() / 1000) + offset;
    };
    const mmss = (s) => { s = Math.max(0, Math.floor(s)); return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`; };
    const tile = (on, key, title, sub, extra = '') => `<div class="tile toggle-tile ${on ? 'on' : ''}" data-drt="${key}" ${extra}><div><strong>${title}</strong><span>${sub}</span></div><div class="switch"></div></div>`;

    const PRESETS = {
        light: { label: 'Gardes légers', count: 12, weapon: 'WEAPON_PISTOL', model: 'g_m_y_mexgoon_01', armor: 0, health: 200, accuracy: 30, heavy: false },
        heavy: { label: 'Gardes lourdement armés', count: 7, weapon: 'WEAPON_CARBINERIFLE', model: 's_m_y_blackops_01', armor: 100, health: 350, accuracy: 55, heavy: true },
        sniper: { label: 'Tireurs d\'élite', count: 2, weapon: 'WEAPON_SNIPERRIFLE', model: 'mp_g_m_pros_01', armor: 50, health: 250, accuracy: 70, heavy: true },
    };
    const newDrop = () => ({
        id: null, name: 'Drop', time: '18:00', repeatDaily: false, enabled: true, coords: null, place: '',
        items: [{ item: '', count: 1 }], squads: [clone(PRESETS.light)], radius: 14,
        keyHolder: 'random', openTime: 15, announceMinutes: 5, audience: 'illegal', requireAllDead: true,
        difficulty: 'normal', vehicles: 3, vehicleModels: '', lockVehicles: true, cover: 4, revealAfter: 5,
    });
    // « 16:32 » + 5 min -> « 16:37 »
    const addMin = (t, m) => {
        const [h, mi] = String(t || '0:0').split(':').map(Number);
        const tot = ((h * 60 + mi + (Number(m) || 0)) % 1440 + 1440) % 1440;
        return `${String(Math.floor(tot / 60)).padStart(2, '0')}:${String(tot % 60).padStart(2, '0')}`;
    };
    const DIFF_INFO = {
        easy: 'Visent mal, peu résistants, restent sur place.',
        normal: 'Se mettent à couvert et tirent depuis leurs abris.',
        hard: 'Précis et coriaces, passent d\'un abri à l\'autre et prennent à revers.',
        extreme: 'Très précis, deux fois plus de vie, foncent sur les cibles à découvert, pas de mort en un tir à la tête.',
    };
    const weaponLabel = (id) => ((Dd() && toArr(Dd().weapons).find((w) => w.id === id)) || {}).label || id;
    const itemLabel = (name) => ((typeof ITEMS !== 'undefined' && ITEMS && ITEMS.find((i) => i.name === name)) || {}).label || name;
    const guardsOf = (d) => toArr(d.squads).reduce((a, q) => a + (Number(q.count) || 0), 0);
    const KEY = { random: 'Au hasard parmi tous les gardes', heavy: 'Sur un garde lourdement armé', light: 'Sur un garde léger' };

    function askItems() {
        if (DR.itemsAsked || typeof ITEMS === 'undefined' || ITEMS || !has('give_item')) return;
        DR.itemsAsked = true;
        action('get_items');
    }

    /* ---------- Vue d'ensemble ---------- */
    function renderMain() {
        const d = Dd();
        const S = d.settings || {};
        const list = toArr(d.list), live = toArr(d.live);
        const now = serverNow();
        const liveHtml = live.length ? live.map((r) => {
            const phase = r.phase === 'announced' ? `📣 Annoncé · largage dans <b>${mmss(r.landAt - now)}</b>`
                : r.phase === 'landed' ? `🪂 À terre · gardes en vie <b>${r.alive}/${r.guards}</b>${r.alerted ? ' · <span style="color:var(--danger)">en combat</span>' : ' · calmes'} · clé ${r.keyFound ? '<b style="color:var(--ok)">trouvée</b>' : 'non trouvée'}
                    ${!r.keyFound && r.revealAfter ? ` · fouilles ratées <b>${r.failed}/${r.revealAfter}</b>${r.revealed ? ' · <b style="color:var(--gold-hi)">clé en surbrillance</b>' : ''}` : ''}`
                : '📦 Ouvert · nettoyage bientôt';
            return `<div class="card"><div class="card-head"><strong>${esc(r.name)}</strong><span class="muted">${esc(r.place || '')}</span></div>
                <div style="margin:6px 0 12px;line-height:1.65;color:var(--text);font-size:13.5px">${phase}</div>
                <div class="btn-row">
                    ${r.phase === 'announced' ? `<button class="btn primary" data-dr="land" data-run="${r.id}">🪂 Larguer maintenant</button>` : ''}
                    <button class="btn" data-dr="tplive" data-x="${r.x}" data-y="${r.y}" data-z="${r.z}">Y aller</button>
                    <button class="btn danger" data-dr="cancel" data-run="${r.id}">Annuler ce drop</button>
                </div></div>`;
        }).join('') : '<div class="empty">Aucun drop en cours.</div>';

        const planHtml = list.length ? list.map((p) => `<div class="card" style="${p.enabled ? '' : 'opacity:.6'}">
            <div class="card-head"><strong><span style="font:700 22px var(--display);color:var(--gold-hi);margin-right:10px">${esc(p.time)}</span>${esc(p.name)}
                <span class="muted" style="font-size:13px;font-weight:500;margin-left:8px">${p.announceMinutes > 0 ? `📣 annonce à ${esc(p.time)} → 🪂 au sol à ${addMin(p.time, p.announceMinutes)}` : `🪂 au sol à ${esc(p.time)} (sans annonce)`}</span></strong>
                <span class="muted">${p.repeatDaily ? '🔁 Tous les jours' : 'Une seule fois'}</span></div>
            <div style="margin:6px 0 12px;line-height:1.65;color:var(--text);font-size:13.5px">📍 ${p.coords ? esc(p.place || `${p.coords.x.toFixed(0)}, ${p.coords.y.toFixed(0)}`) : '<b style="color:var(--danger)">pas de position</b>'}<br>
                🛡️ ${toArr(p.squads).map((q) => `${q.count} × ${esc(weaponLabel(q.weapon))}${q.heavy ? ' (lourds)' : ''}`).join(' + ')} · 🔑 ${esc(KEY[p.keyHolder] || ('escouade ' + String(p.keyHolder).split(':')[1]))}<br>
                📦 ${toArr(p.items).length ? toArr(p.items).map((i) => `${i.count} × ${esc(itemLabel(i.item))}`).join(', ') : '<span class="muted">vide</span>'}<br>
                🧱 difficulté <b>${esc(((Dd().difficulties || {})[p.difficulty] || {}).label || 'Normal')}</b> · ${p.vehicles || 0} véhicule(s) · ${p.cover || 0} abri(s)<br>
                📣 ${p.audience === 'all' ? 'tout le monde' : 'groupes illégaux'} · ouverture ${p.openTime} s · 🔑 surbrillance ${(p.revealAfter ?? 5) ? `après ${p.revealAfter ?? 5} fouilles ratées` : 'jamais'}</div>
            <div class="btn-row">
                ${tile(p.enabled, 'en:' + p.id, p.enabled ? 'Actif' : 'Inactif', p.enabled ? 'Tombera à l\'heure prévue' : 'Ne tombera pas', 'style="min-width:210px;padding:8px 12px"')}
                <button class="btn primary" data-dr="edit" data-id="${p.id}">Modifier</button>
                <button class="btn" data-dr="run" data-id="${p.id}" title="Annonce maintenant, largage après le délai d'annonce">📣 Lancer</button>
                <button class="btn" data-dr="runnow" data-id="${p.id}" title="Largage immédiat, sans annonce préalable">🪂 Larguer tout de suite</button>
                <button class="btn danger" data-dr="del" data-id="${p.id}">Supprimer</button>
            </div></div>`).join('') : '<div class="empty">Aucun drop planifié. Ajoute le premier ci-dessous.</div>';

        return `<div class="section"><div class="grid" style="grid-template-columns:1fr auto;align-items:center">
                ${tile(S.enabled, 'master', S.enabled ? 'Système de drops activé' : 'Système de drops désactivé', S.enabled ? 'Les drops actifs tombent aux heures prévues' : 'Aucun drop ne tombera automatiquement')}
                <div style="text-align:right"><span class="muted">${esc(d.tzLabel || 'Heure')}</span><br><b style="font:700 30px var(--display);color:var(--gold-hi)">${esc(d.clock || '--:--')}</b>
                    ${d.serverClock && d.serverClock !== d.clock ? `<br><span class="muted" style="font-size:11px">horloge brute du serveur : ${esc(d.serverClock)}</span>` : ''}</div></div></div>
            <div class="section"><h2>En cours</h2>${liveHtml}</div>
            <div class="section"><h2>Planning (${list.length})</h2>
                <p class="hint">À l'heure réglée (${esc(d.tzLabel || 'heure réelle')}), l'annonce « un drop va être largué » est faite, sans position. X minutes plus tard : « Le drop est à terre » avec la position, la fumée rouge et les gardes.</p>
                ${planHtml}
                <button class="btn primary big" data-dr="new" style="margin-top:6px">+ Nouveau drop</button></div>
            <div class="section"><h2 style="cursor:pointer" data-dr="toggleSettings">⚙️ Réglages généraux ${DR.showSettings ? '▾' : '▸'}</h2>${DR.showSettings ? settingsForm(S) : ''}</div>`;
    }

    /* ---------- Réglages généraux ---------- */
    function settingsForm(S) {
        if (!DR.settings) DR.settings = clone(S);
        const s = DR.settings;
        const f = (k, l, type = 'text', extra = '') => `<div><label>${l}</label><input class="input" ${type === 'number' ? 'type="number"' : ''} data-drs="${k}" value="${esc(s[k] ?? '')}" ${extra}></div>`;
        return `<div class="form-grid" style="grid-template-columns:1fr 2fr">
                ${f('preTitle', 'Titre de l\'annonce avant')}${f('preMessage', 'Message avant ({min} = minutes)')}
                ${f('landTitle', 'Titre « à terre »')}${f('landMessage', 'Message « à terre »')}
            </div>
            <div class="form-grid">${f('endMessage', 'Message quand le drop est ouvert')}</div>
            <div class="form-grid" style="grid-template-columns:repeat(4,1fr)">
                ${f('inspectTime', 'Inspection d\'un corps (s)', 'number')}
                ${f('shotRadius', 'Tirer à moins de (m) = alerte', 'number')}
                ${f('alertRadius', 'S\'approcher à moins de (m) = alerte (0 = non)', 'number')}
                ${f('maxDuration', 'Disparaît si personne (min)', 'number')}
                ${f('cleanupAfter', 'Nettoyage après ouverture (min)', 'number')}
                ${f('blipSprite', 'Icône du blip (n°)', 'number')}
                ${f('blipColor', 'Couleur du blip (n°)', 'number')}
                ${f('blipRadius', 'Rayon de la zone sur la carte (m)', 'number')}
            </div>
            <div class="form-grid" style="grid-template-columns:1fr 1fr">
                <div><label>Heure utilisée pour le planning</label><select class="input" data-drs="timezone">
                    <option value="paris" ${s.timezone === 'paris' || !s.timezone ? 'selected' : ''}>Heure de Paris (été / hiver automatique)</option>
                    <option value="server" ${s.timezone === 'server' ? 'selected' : ''}>Horloge du serveur (telle quelle)</option>
                    ${[-5, -4, 0, 1, 2, 3, 4].map((n) => `<option value="${n}" ${String(s.timezone) === String(n) ? 'selected' : ''}>UTC${n >= 0 ? '+' : ''}${n}</option>`).join('')}
                </select></div>
                <div class="hint" style="align-self:end">La plupart des hébergeurs règlent le serveur en UTC : « Heure de Paris » évite le décalage d'1 ou 2 h.</div>
            </div>
            <div class="form-grid">${f('illegalJobs', 'Métiers « illégaux » en plus des gangs (séparés par des virgules)', 'text', 'placeholder="ex : cartel, mafia"')}</div>
            <p class="hint">Les annonces « groupes illégaux » vont aux joueurs qui ont un gang (Qbox / QBCore) ou l'un de ces métiers. Le staff en service les reçoit toujours.</p>
            <button class="btn primary" data-dr="saveSettings">Enregistrer les réglages</button>`;
    }

    /* ---------- Éditeur d'un drop ---------- */
    function renderEditor() {
        askItems();
        const e = DR.edit;
        const d = Dd();
        const weapons = toArr(d.weapons), models = toArr(d.models);
        const items = (typeof ITEMS !== 'undefined' && ITEMS) || [];
        const sel = (attr, list, cur) => `<select class="input" ${attr}>${list.map((x) => `<option value="${esc(x.id)}" ${x.id === cur ? 'selected' : ''}>${esc(x.label)}</option>`).join('')}${list.find((x) => x.id === cur) ? '' : `<option value="${esc(cur)}" selected>${esc(cur)}</option>`}</select>`;
        const keyOpts = [['random', KEY.random], ['heavy', KEY.heavy], ['light', KEY.light], ...e.squads.map((q, i) => [`squad:${i + 1}`, `Dans l'escouade ${i + 1} (${q.label || 'gardes'})`])];
        const hasHeavy = e.squads.some((q) => q.heavy), hasLight = e.squads.some((q) => !q.heavy);
        return `<div class="btn-row" style="margin-bottom:14px"><button class="btn" data-dr="back">← Retour au planning</button><button class="btn primary" data-dr="save">Enregistrer le drop</button></div>
        <div class="section"><h2>${e.id ? 'Modifier' : 'Nouveau'} drop</h2>
            <div class="form-grid" style="grid-template-columns:2fr 1fr">
                <div><label>Nom</label><input class="input" data-drf="name" value="${esc(e.name)}" placeholder="ex : Drop 1"></div>
                <div><label>Heure de l'annonce (${esc(d.tzLabel || 'heure réelle')})</label><input class="input" type="time" data-drf="time" value="${esc(e.time)}">
                    <small class="muted">${Number(e.announceMinutes) > 0 ? `Annonce à ${esc(e.time)}, le drop touche le sol à ${addMin(e.time, e.announceMinutes)}.` : `Sans annonce : le drop touche le sol à ${esc(e.time)}.`}</small></div>
            </div>
            <div class="grid" style="grid-template-columns:1fr 1fr;margin-top:6px">
                ${tile(e.repeatDaily, 'repeat', 'Tous les jours', e.repeatDaily ? 'Retombe chaque jour à cette heure' : 'Une seule fois, puis se désactive')}
                ${tile(e.enabled, 'enabled', 'Actif', e.enabled ? 'Tombera à l\'heure prévue' : 'Préparé mais ne tombera pas')}
            </div></div>

        <div class="section"><h2>📍 Position</h2>
            <p class="hint">« Choisir sur la carte » ouvre la carte : pose un repère (point GPS) à l'endroit voulu, puis ferme-la. La position reste secrète jusqu'au largage.</p>
            <div class="card" style="margin-bottom:10px">${e.coords ? `<b>${esc(e.place || 'Position choisie')}</b><br><span class="muted">${e.coords.x.toFixed(1)}, ${e.coords.y.toFixed(1)}, ${e.coords.z.toFixed(1)}</span>` : '<span style="color:var(--danger)">Aucune position choisie.</span>'}</div>
            <div class="btn-row"><button class="btn primary" data-dr="pickmap">🗺️ Choisir sur la carte</button><button class="btn" data-dr="here">📍 Ma position actuelle</button>${e.coords ? '<button class="btn" data-dr="tp">Y aller</button>' : ''}</div></div>

        <div class="section"><h2>📦 Contenu du drop</h2>
            ${items.length ? '' : `<p class="hint">${has('give_item') ? 'Chargement de la liste des objets…' : 'Tape le nom de code des objets (ex : weapon_pistol, money, ammo-9).'}</p>`}
            <datalist id="dr-items">${items.slice(0, 3000).map((i) => `<option value="${esc(i.name)}">${esc(i.label)}</option>`).join('')}</datalist>
            <table class="loot"><tr><th style="width:62%">Objet</th><th style="width:28%">Quantité</th><th></th></tr>
            ${e.items.map((it, i) => `<tr><td><input class="input" list="dr-items" data-dri="${i}:item" value="${esc(it.item)}" placeholder="nom de l'objet">${it.item && itemLabel(it.item) !== it.item ? `<small class="muted">${esc(itemLabel(it.item))}</small>` : ''}</td>
                <td><input class="input" type="number" min="1" data-dri="${i}:count" value="${esc(it.count)}"></td><td><button class="sb-close" data-dr="delitem" data-i="${i}">✕</button></td></tr>`).join('')}
            </table><button class="btn" style="margin-top:8px" data-dr="additem">+ Objet</button></div>

        <div class="section"><h2>🛡️ Gardes (${guardsOf(e)} au total)</h2>
            <p class="hint">Ils restent calmes autour de la caisse. Dès qu'on leur tire dessus (ou qu'on tire près d'eux), tous ripostent.</p>
            ${e.squads.map((q, i) => `<div class="card recipe" style="margin-bottom:10px">
                <div class="card-head"><strong>Escouade ${i + 1}</strong>${e.squads.length > 1 ? `<button class="sb-close" data-dr="delsquad" data-i="${i}">✕</button>` : ''}</div>
                <div class="form-grid" style="grid-template-columns:2fr 1fr 2fr 2fr">
                    <div><label>Nom</label><input class="input" data-drq="${i}:label" value="${esc(q.label)}"></div>
                    <div><label>Nombre</label><input class="input" type="number" min="1" max="40" data-drq="${i}:count" value="${esc(q.count)}"></div>
                    <div><label>Arme</label>${sel(`data-drq="${i}:weapon"`, weapons, q.weapon)}</div>
                    <div><label>Apparence</label>${sel(`data-drq="${i}:model"`, models, q.model)}</div>
                </div>
                <div class="form-grid" style="grid-template-columns:1fr 1fr 1fr 2fr">
                    <div><label>Armure (0-100)</label><input class="input" type="number" min="0" max="100" data-drq="${i}:armor" value="${esc(q.armor)}"></div>
                    <div><label>Santé (100-1000)</label><input class="input" type="number" min="100" max="1000" data-drq="${i}:health" value="${esc(q.health)}"></div>
                    <div><label>Précision (%)</label><input class="input" type="number" min="5" max="100" data-drq="${i}:accuracy" value="${esc(q.accuracy)}"></div>
                    <div style="align-self:end">${tile(q.heavy, 'heavy:' + i, 'Lourdement armés', 'Compte pour « clé sur un garde lourd »')}</div>
                </div></div>`).join('')}
            <div class="btn-row"><button class="btn" data-dr="addsquad" data-p="light">+ Escouade légère (pistolets)</button><button class="btn" data-dr="addsquad" data-p="heavy">+ Escouade lourde</button><button class="btn" data-dr="addsquad" data-p="sniper">+ Tireurs d'élite</button></div>
            <div class="form-grid" style="grid-template-columns:1fr 2fr;margin-top:12px">
                <div><label>Rayon autour de la caisse (m)</label><input class="input" type="number" min="4" max="60" data-drf="radius" value="${esc(e.radius)}"></div>
                <div><label>🔑 Qui porte la clé</label><select class="input" data-drf="keyHolder">${keyOpts.map(([k, l]) => `<option value="${k}" ${k === e.keyHolder ? 'selected' : ''} ${(k === 'heavy' && !hasHeavy) || (k === 'light' && !hasLight) ? 'disabled' : ''}>${esc(l)}</option>`).join('')}</select></div>
            </div></div>

        <div class="section"><h2>🧱 Abris et difficulté</h2>
            <p class="hint">Les gardes se cachent derrière les véhicules, les sacs de sable et la caisse pour tirer. Plus c'est difficile, plus ils sont précis, résistants et mobiles.</p>
            <div class="grid" style="grid-template-columns:repeat(4,1fr);margin-bottom:12px">
                ${Object.entries(d.difficulties || {}).map(([k, v]) => `<div class="tile toggle-tile ${e.difficulty === k ? 'on' : ''}" data-drt="diff:${k}"><div><strong>${esc(v.label)}</strong><span>${esc(DIFF_INFO[k] || '')}</span></div><div class="switch"></div></div>`).join('')}
            </div>
            <div class="form-grid" style="grid-template-columns:1fr 1fr 2fr">
                <div><label>Véhicules garés autour (0-8)</label><input class="input" type="number" min="0" max="8" data-drv="vehicles" value="${esc(e.vehicles)}"></div>
                <div><label>Abris : sacs de sable, barrières (0-12)</label><input class="input" type="number" min="0" max="12" data-drv="cover" value="${esc(e.cover)}"></div>
                <div><label>Modèles de véhicules (vide = selon le style des gardes)</label><input class="input" data-drv="vehicleModels" value="${esc(e.vehicleModels || '')}" placeholder="ex : baller, cavalcade"></div>
            </div>
            <p class="hint">Selon le style des gardes : ${e.squads.map((q) => { const st = toArr(d.models).find((m) => m.id === q.model); return `<b>${esc(st ? st.label : q.model)}</b> → ${st && st.vehicles ? toArr(st.vehicles).map(esc).join(', ') : 'véhicules standards'}`; }).join(' · ')}</p>
            <div class="grid" style="grid-template-columns:1fr 1fr">${tile(e.lockVehicles, 'lockveh', 'Véhicules verrouillés', 'Impossible de partir avec : ils servent d\'abri')}</div>
        </div>

        <div class="section"><h2>🔓 Ouverture et annonce</h2>
            <div class="form-grid" style="grid-template-columns:1fr 1fr 2fr">
                <div><label>Durée d'ouverture (s)</label><input class="input" type="number" min="1" max="300" data-drf="openTime" value="${esc(e.openTime)}"></div>
                <div><label>Délai annonce → sol (min, 0 = aucune annonce)</label><input class="input" type="number" min="0" max="60" data-drf="announceMinutes" value="${esc(e.announceMinutes)}"></div>
                <div style="align-self:end">${tile(e.requireAllDead, 'alldead', 'Tous les gardes doivent être morts', 'Avant de pouvoir ouvrir la caisse')}</div>
            </div>
            <div class="form-grid" style="grid-template-columns:1fr 2fr">
                <div><label>🔑 Surbrillance après X fouilles ratées (0 = jamais)</label><input class="input" type="number" min="0" max="50" data-drv="revealAfter" value="${esc(e.revealAfter ?? 5)}"></div>
                <div class="hint" style="align-self:end">Après ce nombre de corps fouillés sans trouver la clé, le garde qui la porte est mis en surbrillance pour les joueurs (halo doré au sol, flèche au-dessus, lumière qui pulse).</div>
            </div>
            <label>Qui est prévenu (annonces, position, fumée)</label>
            <div class="grid" style="grid-template-columns:1fr 1fr;margin-top:6px">
                ${tile(e.audience === 'illegal', 'aud:illegal', 'Groupes illégaux uniquement', 'Gangs et métiers illégaux (+ staff)')}
                ${tile(e.audience === 'all', 'aud:all', 'Tout le monde', 'Légaux compris (police…)')}
            </div></div>
        <div class="btn-row"><button class="btn" data-dr="back">Annuler</button><button class="btn primary big" data-dr="save">Enregistrer le drop</button></div>`;
    }

    EVENTS.push({
        id: 'drops', label: '🪂 Largage de drops',
        show: () => has('event_drops') && !!Dd(),
        render: () => (DR.edit ? renderEditor() : renderMain()),
    });

    function payload(e) {
        return {
            id: e.id, name: e.name, time: e.time, repeatDaily: e.repeatDaily, enabled: e.enabled, coords: e.coords, place: e.place,
            items: e.items.filter((i) => String(i.item).trim()).map((i) => ({ item: String(i.item).trim(), count: Number(i.count) || 1 })),
            squads: e.squads.map((q) => ({ ...q, count: Number(q.count) || 1, armor: Number(q.armor) || 0, health: Number(q.health) || 200, accuracy: Number(q.accuracy) || 35 })),
            radius: Number(e.radius) || 14, keyHolder: e.keyHolder, openTime: Number(e.openTime) || 15,
            revealAfter: Number(e.revealAfter) || 0,
            difficulty: e.difficulty, vehicles: Number(e.vehicles) || 0, vehicleModels: e.vehicleModels || '', lockVehicles: e.lockVehicles, cover: Number(e.cover) || 0,
            announceMinutes: Number(e.announceMinutes) || 0, audience: e.audience, requireAllDead: e.requireAllDead,
        };
    }
    const refresh = () => setTimeout(() => post('refresh'), 300);
    const onTab = () => isOpen && tab === 'events' && (window.AM_EVENT_STATE || {}).current === 'drops';

    document.addEventListener('click', async (ev) => {
        if (!onTab()) return;
        const t = ev.target.closest('[data-drt]');
        if (t) {
            const k = t.dataset.drt;
            if (k === 'master') { action('drops_settings', { ...Dd().settings, enabled: !Dd().settings.enabled }); return refresh(); }
            if (k.startsWith('en:')) { const id = Number(k.slice(3)); const p = toArr(Dd().list).find((x) => x.id === id); action('drops_toggle', { id, enabled: !p.enabled }); return refresh(); }
            const e = DR.edit; if (!e) return;
            if (k === 'repeat') e.repeatDaily = !e.repeatDaily;
            if (k === 'enabled') e.enabled = !e.enabled;
            if (k === 'alldead') e.requireAllDead = !e.requireAllDead;
            if (k === 'lockveh') e.lockVehicles = !e.lockVehicles;
            if (k.startsWith('diff:')) e.difficulty = k.slice(5);
            if (k.startsWith('aud:')) e.audience = k.slice(4);
            if (k.startsWith('heavy:')) { const q = e.squads[Number(k.slice(6))]; q.heavy = !q.heavy; }
            return render();
        }
        const n = ev.target.closest('[data-dr]');
        if (!n) return;
        const k = n.dataset.dr, e = DR.edit;
        switch (k) {
            case 'toggleSettings': DR.showSettings = !DR.showSettings; DR.settings = null; return render();
            case 'saveSettings': action('drops_settings', DR.settings); DR.settings = null; return refresh();
            case 'new': DR.edit = newDrop(); document.querySelector('#content').scrollTop = 0; return render();
            case 'edit': {
                const p = toArr(Dd().list).find((x) => x.id === Number(n.dataset.id));
                if (!p) return;
                DR.edit = clone({ ...newDrop(), ...p, items: toArr(p.items).length ? toArr(p.items) : [{ item: '', count: 1 }], squads: toArr(p.squads) });
                document.querySelector('#content').scrollTop = 0;
                return render();
            }
            case 'back': DR.edit = null; return render();
            case 'save': {
                const pl = payload(e);
                if (!pl.coords) return toast('Choisis la position du drop.', 'error');
                if (!/^\d{1,2}:\d{2}$/.test(pl.time)) return toast('Heure invalide.', 'error');
                action('drops_save', pl); DR.edit = null; return refresh();
            }
            case 'del': {
                const p = toArr(Dd().list).find((x) => x.id === Number(n.dataset.id));
                if (!(await confirmBox('Supprimer ce drop ?', `« ${p ? p.name : ''} » sera retiré du planning.`))) return;
                action('drops_delete', { id: Number(n.dataset.id) }); return refresh();
            }
            case 'run': action('drops_run', { id: Number(n.dataset.id), now: false }); return refresh();
            case 'runnow': {
                if (!(await confirmBox('Larguer tout de suite ?', 'Le drop tombe maintenant, sans annonce préalable.'))) return;
                action('drops_run', { id: Number(n.dataset.id), now: true }); return refresh();
            }
            case 'land': action('drops_land', { run: Number(n.dataset.run) }); return refresh();
            case 'cancel': {
                if (!(await confirmBox('Annuler ce drop ?', 'La caisse et les gardes disparaissent.'))) return;
                action('drops_cancel', { run: Number(n.dataset.run) }); return refresh();
            }
            case 'tplive': return post('drops_tp', { x: Number(n.dataset.x), y: Number(n.dataset.y), z: Number(n.dataset.z) });
            case 'pickmap': return post('drops_pick', { mode: 'map' });
            case 'here': return post('drops_pick', { mode: 'here' });
            case 'tp': return post('drops_tp', e.coords);
            case 'additem': e.items.push({ item: '', count: 1 }); return render();
            case 'delitem': e.items.splice(Number(n.dataset.i), 1); if (!e.items.length) e.items.push({ item: '', count: 1 }); return render();
            case 'addsquad': if (e.squads.length >= 6) return toast('6 escouades maximum.', 'error'); e.squads.push(clone(PRESETS[n.dataset.p])); return render();
            case 'delsquad': {
                e.squads.splice(Number(n.dataset.i), 1);
                if (/^squad:/.test(e.keyHolder) && Number(e.keyHolder.split(':')[1]) > e.squads.length) e.keyHolder = 'random';
                return render();
            }
        }
    });
    function onInput(ev) {
        if (!onTab()) return;
        const t = ev.target, e = DR.edit;
        if (t.dataset.drs && DR.settings) { DR.settings[t.dataset.drs] = t.type === 'number' ? Number(t.value) : t.value; return; }
        if (t.dataset.drv && e) { e[t.dataset.drv] = t.value; return; }
        if (!e) return;
        if (t.dataset.drf) { e[t.dataset.drf] = t.value; if (ev.type === 'change' && ['keyHolder', 'time', 'announceMinutes'].includes(t.dataset.drf)) render(); return; }
        if (t.dataset.dri) { const [i, key] = t.dataset.dri.split(':'); e.items[Number(i)][key] = t.value; return; }
        if (t.dataset.drq) {
            const [i, key] = t.dataset.drq.split(':');
            e.squads[Number(i)][key] = t.value;
            if (ev.type === 'change' && (key === 'count')) render();
        }
    }
    document.addEventListener('input', onInput);
    document.addEventListener('change', onInput);

    window.addEventListener('message', (ev) => {
        const m = ev.data || {};
        if (m.action !== 'dropsPicked') return;
        if (!DR.edit) DR.edit = newDrop();
        DR.edit.coords = { x: m.x, y: m.y, z: m.z };
        DR.edit.place = m.place || '';
        toast(`Position du drop : ${m.place || 'choisie'}.`, 'success');
        if (onTab()) render();
    });
    // Compte à rebours des drops annoncés
    setInterval(() => { if (onTab() && !DR.edit && Dd() && toArr(Dd().live).some((r) => r.phase === 'announced')) render(); }, 1000);
})();
