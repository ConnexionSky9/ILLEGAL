/* =========================================================
   ADMIN MENU - INTERFACE
   ========================================================= */
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'admin_menu';
const $ = (s) => document.querySelector(s);

const post = (endpoint, body = {}) =>
    fetch(`https://${RES}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body),
    }).then((r) => r.json()).catch(() => ({}));

let D = null;              // données reçues du serveur
let lastDataSig = '';
let isOpen = false;
let tab = 'home';
let selectedPlayer = null;
let search = '';
let logSearch = '';
let rankDraft = null;
const drafts = {};

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const has = (p) => !!(D && D.me && D.me.perms && D.me.perms[p] === true);
const any = (...ps) => ps.some(has);
const draft = (k, def = '') => (drafts[k] !== undefined ? drafts[k] : def);
const canEditor = () => !!(D && D.config && D.config.editor && D.me.level >= D.config.editor.minLevel
    && any('editor_spawns', 'editor_props', 'editor_peds', 'editor_harvest', 'editor_crafting', 'editor_zones', 'editor_doors', 'editor_stashes'));
let editorSub = null;
const editorPost = (name, data = {}) => post('editor', { name, data });

/* ---------- Onglets ---------- */
// Titres affichés au-dessus de certains groupes d'onglets
const TAB_GROUP_TITLES = { 5: 'Métiers' };
const TABS = [
    { id: 'home',     group: 1, label: 'Accueil',        ico: '🏠', sub: "Vue d'ensemble du serveur et actions rapides.", show: () => true },
    { id: 'players',  group: 1, label: 'Joueurs',        ico: '👥', sub: 'Choisis un joueur dans la liste pour agir sur lui.', show: () => true },
    { id: 'reports',  group: 1, label: 'Reports',        ico: '📨', sub: 'Demandes envoyées par les joueurs avec /report.', show: () => has('reports'), count: () => (D.reports || []).filter((r) => !r.claimedBy).length },
    { id: 'bans',     group: 1, label: 'Prison et bans',  ico: '⛓️', sub: 'Joueurs en prison et bannissements actifs.', show: () => any('ban', 'unban', 'jail') },
    { id: 'self',     group: 2, label: 'Mes outils',     ico: '🧍', sub: 'Noclip, godmode, wallhack, téléportation…', show: () => any('noclip', 'godmode', 'invisible', 'tp_waypoint', 'tp_coords', 'player_ids', 'wallhack') },
    { id: 'items',    group: 2, label: 'Objets',         ico: '🎁', sub: "Donne n'importe quel objet de l'inventaire (armes comprises), à toi ou à un joueur.", show: () => has('give_item') },
    { id: 'vehicles', group: 2, label: 'Véhicules',      ico: '🚗', sub: 'Fais apparaître ou répare un véhicule.', show: () => any('spawn_vehicle', 'vehicle_tools') },
    { id: 'announce', group: 2, label: 'Annonces',       ico: '📢', sub: 'Un bandeau en haut de l\'écran de tous les joueurs, avec une image si tu veux.', show: () => has('announce') },
    { id: 'world',    group: 2, label: 'Monde',          ico: '🌦', sub: 'Météo, heure et nettoyage.', show: () => any('weather', 'time', 'blackout', 'clear_area') },
    { id: 'editor',   group: 3, label: 'Éditeur de map', ico: '🏗', sub: 'Spawns, props, PNJ, récoltes et ateliers. Réservé SuperAdmin et Fondateur.', show: () => canEditor() },
    { id: 'staff',    group: 4, label: 'Staff',          ico: '🛡', sub: 'Membres du staff et leur grade.', show: () => has('manage_staff') },
    { id: 'ranks',    group: 4, label: 'Grades',         ico: '🎖', sub: 'Crée des grades et choisis leurs permissions.', show: () => has('manage_ranks') },
    { id: 'logs',     group: 4, label: 'Logs',           ico: '📜', sub: 'Historique des actions du staff.', show: () => has('view_logs') },
    { id: 'keys',     group: 4, label: 'Raccourcis',     ico: '⌨', sub: 'Toutes tes touches, modifiables dans les paramètres de FiveM.', show: () => true },
];


/* ---------- Messages Lua ---------- */
window.addEventListener('message', (e) => {
    const m = e.data;
    switch (m.action) {
        case 'open':
            isOpen = true;
            $('#app').classList.remove('hidden');
            break;
        case 'close':
            isOpen = false;
            $('#app').classList.add('hidden');
            closeModal();
            break;
        case 'data': {
            const sig = JSON.stringify(m.data);
            if (sig === lastDataSig && D) break; // rien n'a changé : pas de re-rendu
            lastDataSig = sig;
            D = m.data;
            if (rankDraft && rankDraft.isNew && rankDraft.name && D.ranks && D.ranks[rankDraft.name.toLowerCase()]) {
                rankDraft.name = rankDraft.name.toLowerCase();
                rankDraft.isNew = false;
            }
            if (!TABS.find((t) => t.id === tab && t.show())) tab = 'home';
            render();
            break;
        }
        case 'notify':
            toast(m.message, m.type);
            break;
        case 'announce':
            showAnnounce(m.data);
            break;
        case 'warn':
            showWarn(m.reason, m.by);
            break;
        case 'folderSaved':
            // Dossier tout juste créé : on l'ouvre directement
            if (pendingFolderOpen && m.id) { pendingFolderOpen = false; propView = Number(m.id); drafts.propFolder = String(m.id); }
            break;
        case 'gotoPlayer':
            if (m.id) { tab = 'players'; selectedPlayer = Number(m.id); }
            render();
            break;
        case 'station':
            openStation(m.data);
            break;
        case 'items':
            ITEMS = m.items || [];
            itemsMode = m.mode || '';
            if (isOpen && tab === 'items') render();
            break;
        case 'npc':
            openNpc(m.data);
            break;
        case 'npcClose':
            $('#npc').classList.add('hidden');
            NPC = null;
            break;
        case 'keyshud':
            renderKeysHud(m);
            break;
        case 'zonemsg':
            showZoneMsg(m);
            break;
        case 'door':
            openDoor(m.data);
            break;
        case 'jailhud':
            jailHud(m);
            break;
        case 'dprogress': {
            const el = $('#dprogress');
            clearInterval(window.__dpT);
            if (!m.show) { el.classList.add('hidden'); break; }
            el.querySelector('b').textContent = m.label || '';
            const bar = el.querySelector('i');
            bar.style.transition = 'none'; bar.style.width = '0'; void bar.offsetWidth;
            bar.style.transition = `width ${m.time}s linear`; bar.style.width = '100%';
            const end = Date.now() + m.time * 1000, sp = el.querySelector('span');
            const tick = () => { sp.textContent = Math.max(0, Math.ceil((end - Date.now()) / 1000)) + ' s'; };
            tick(); window.__dpT = setInterval(tick, 250);
            el.classList.remove('hidden');
            break;
        }
        case 'prompt': {
            const el = $('#prompt');
            if (!m.show) { el.classList.add('hidden'); break; }
            el.classList.toggle('muted', !!m.muted);
            el.innerHTML = `<span class="pk">${esc(m.key || 'E')}</span><span class="pt"><span class="pa">${esc(m.verb || '')}</span><span class="pn">${esc(m.name || '')}</span></span>`;
            el.classList.remove('hidden');
            break;
        }
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !$('#station').classList.contains('hidden')) return closeStation();
    if (e.key === 'Escape' && !$('#npc').classList.contains('hidden')) return closeNpc();
    if (e.key === 'Escape' && !$('#door').classList.contains('hidden')) return closeDoor();
    if (!isOpen) return;
    if (e.key === 'Escape') {
        if ($('#modal-root').innerHTML) return closeModal();
        post('close');
    }
});
$('#close-btn').addEventListener('click', () => post('close'));
$('#sb-duty').addEventListener('click', () => selfAction('duty'));

setInterval(() => {
    if (!isOpen) return;
    const a = document.activeElement;
    if (a && ['INPUT', 'TEXTAREA', 'SELECT'].includes(a.tagName)) return; // ne pas casser une saisie
    if ($('#modal-root').innerHTML) return;
    post('refresh');
}, 5000);

/* ---------- Actions ---------- */
const CLOSE_AFTER = ['goto', 'spectate', 'spawn_vehicle'];
function action(name, data = {}) {
    post('action', { name, data });
    if (CLOSE_AFTER.includes(name)) post('close');
}
function selfAction(name, data = {}) {
    return post('self', { name, data }).then((res) => {
        if (res && res.self && D) { D.self = res.self; if (isOpen) render(); }
        return res || {};
    });
}

/* ---------- Rendu global ---------- */
function render() {
    if (!D) return;
    const me = D.me;
    document.documentElement.style.setProperty('--rank', me.color || '#d9b56a');
    $('#me-rank').textContent = me.label;
    $('#sidebar-foot').innerHTML = `Ton ID : ${me.id}<br>Menu : <span class="keycap">${esc(keyName(((D.keys || [])[0] || {}).current || 'F10'))}</span>`;
    $('#sb-players').textContent = `👥 ${D.players.length} en ligne`;
    const duty = onDuty();
    const sd = $('#sb-duty');
    sd.className = `sb-duty ${duty ? 'on' : 'off'}`;
    sd.textContent = duty ? '🛡️ En service' : '🎭 Mode RP';
    updateClock();

    let lastGroup = null;
    $('#tabs').innerHTML = TABS.filter((t) => t.show()).map((t) => {
        const c = t.count ? t.count() : 0;
        const newGroup = lastGroup !== null && t.group !== lastGroup;
        const title = t.group !== lastGroup && TAB_GROUP_TITLES[t.group] ? `<div class="tab-group">${TAB_GROUP_TITLES[t.group]}</div>` : '';
        const sep = (newGroup ? '<div class="tab-sep"></div>' : '') + title;
        lastGroup = t.group;
        return `${sep}<button class="tab ${t.id === tab ? 'active' : ''}" data-tab="${t.id}">
            <span class="ico">${t.ico}</span>${t.label}${c ? `<span class="count">${c}</span>` : ''}</button>`;
    }).join('');

    const current = TABS.find((t) => t.id === tab);
    $('#page-title').textContent = current ? current.label : '';
    $('#page-sub').textContent = current ? current.sub : '';
    if (!duty && tab !== 'keys') {
        $('#page-title').textContent = 'Mode RP';
        $('#page-sub').textContent = 'Fonctions staff désactivées.';
        const box = $('#content');
        box.classList.remove('fixed', 'catalog-mode');
        box.innerHTML = dutyScreen();
        renderedTab = 'duty';
        return;
    }
    const content = $('#content');
    content.classList.toggle('fixed', tab === 'players' || tab === 'ranks' || tab === 'items');
    content.classList.toggle('catalog-mode', tab === 'editor' && editorSub === 'catalog');
    if (tab === 'editor' && !canEditor()) tab = 'home';
    // Vues lourdes (catalogue, objets) : si rien ne les concerne n'a changé, on ne les reconstruit pas
    // (sinon le rafraîchissement automatique toutes les 5 s remettait la liste en haut)
    const sigFn = STABLE_VIEWS[tab];
    const sig = sigFn ? sigFn() : null;
    if (sig && renderedTab === tab && content.dataset.sig === `${tab}|${sig}`) return;
    content.dataset.sig = sig ? `${tab}|${sig}` : '';
    // On garde la position de défilement des listes internes
    const keep = renderedTab === tab ? [...content.querySelectorAll('.list, .detail')].map((x) => x.scrollTop) : [];
    const top = renderedTab === tab ? content.scrollTop : 0;
    content.innerHTML = (VIEWS[tab] || (() => ''))();
    content.querySelectorAll('.list, .detail').forEach((x, i) => { if (keep[i]) x.scrollTop = keep[i]; });
    content.scrollTop = top;
    renderedTab = tab;
}
let renderedTab = null;
// Signature des vues qui ne doivent être reconstruites que si elles changent vraiment
const STABLE_VIEWS = {
    editor: () => (editorSub === 'catalog'
        ? `cat|${catState.mode}|${catState.cat}|${catState.pinned || ''}|${has('editor_props')}|${has('editor_peds')}` : null),
    items: () => (ITEMS ? [ITEMS.length, itemsMode, itemCat, itemLimit, selItem ? selItem.name : '', give.target, give.id, give.count,
        D.players.map((p) => `${p.id}:${p.name}`).join(','), has('give_item')].join('|') : null),
};

const onDuty = () => {
    if (!D) return true;
    if (D.self && typeof D.self.duty === 'boolean') return D.self.duty; // état local, immédiat
    return !(D.me && D.me.duty === false);
};

function dutyScreen() {
    return `<div class="duty-screen">
        <div class="duty-ico">🎭</div>
        <h2>Tu es en mode RP</h2>
        <p>Toutes tes fonctions staff sont désactivées : noclip, godmode, wallhack, raccourcis…<br>
        Tu ne reçois plus les alertes de reports, et ta faim et ta soif reprennent normalement.<br>Les autres joueurs ne voient aucune différence.</p>
        <button class="btn primary big" data-self="duty">🛡️ Reprendre mon service staff</button>
        <p class="muted" style="margin-top:14px;font-size:12px">Astuce : tu peux assigner une touche à « Service staff / mode RP » dans l'onglet Raccourcis.</p>
    </div>`;
}

function updateClock() {
    const d = new Date();
    const el = $('#sb-clock');
    if (el) el.textContent = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}
setInterval(updateClock, 15000);

$('#tabs').addEventListener('click', (e) => {
    const b = e.target.closest('[data-tab]');
    if (!b) return;
    tab = b.dataset.tab;
    render();
});

/* =========================================================
   VUES
   ========================================================= */
const VIEWS = {};

/* ---------- Accueil ---------- */
VIEWS.home = () => {
    const waiting = (D.reports || []).filter((r) => !r.claimedBy);
    const staffOn = D.players.filter((p) => p.rank && p.duty !== false).length;
    const s = D.self || {};
    const stat = (n, label, go, alert) => `<button class="stat ${alert ? 'alert' : ''}" data-go="${go}"><b>${n}</b><span>${label}</span></button>`;
    const quick = (perm, key, label, sub) => has(perm) ? `
        <div class="tile toggle-tile ${s[key] ? 'on' : ''}" data-self="${key}"><div><strong>${label}</strong><span>${sub}</span></div><div class="switch"></div></div>` : '';
    const go = (cond, t, label, sub) => cond ? `<button class="tile" data-go="${t}"><strong>${label}</strong><span>${sub}</span></button>` : '';

    return `<div class="duty-bar"><span>🛡️ Tu es <b>en service</b> : toutes tes fonctions staff sont actives, ta faim et ta soif sont figées.</span>
            <button class="btn" data-self="duty">🎭 Passer en mode RP</button></div>
        <div class="stats">
            ${stat(D.players.length, 'Joueurs en ligne', 'players')}
            ${stat(staffOn, 'Staff en service', has('manage_staff') ? 'staff' : 'players')}
            ${has('reports') ? stat(waiting.length, 'Reports en attente', 'reports', waiting.length > 0) : ''}
            ${D.bans ? stat(D.bans.length, 'Bannissements actifs', 'bans') : ''}
        </div>
        <div class="section"><h2>Actions rapides</h2><div class="grid">
            ${quick('noclip', 'noclip', 'Noclip', `Touche ${esc(keyName(D.config.noclipKey))}`)}
            ${quick('wallhack', 'wallhack', 'Wallhack', 'Voir tous les joueurs')}
            ${quick('godmode', 'godmode', 'Godmode', 'Aucun dégât')}
            ${quick('invisible', 'invisible', 'Invisible', 'Caché aux joueurs')}
            ${has('tp_waypoint') ? '<button class="tile" data-self="tp_waypoint"><strong>TP au marqueur</strong><span>Marqueur de la carte</span></button>' : ''}
            ${go(has('announce'), 'announce', 'Faire une annonce', 'Bandeau avec image')}
            ${has('armor') ? '<button class="tile" data-act="armor_self"><strong>Remplir mon armure</strong><span>Gilet à 100 %</span></button>' : ''}
            ${has('revive_area') ? `<button class="tile" data-act="revive_area_quick"><strong>Réanimer autour de moi</strong><span>Voir la zone avant de valider</span></button>` : ''}
            ${go(has('spawn_vehicle'), 'vehicles', 'Sortir un véhicule', 'Liste ou nom du modèle')}
            ${go(has('give_item'), 'items', 'Donner un objet', 'À toi ou à un joueur')}
            ${go(canEditor(), 'editor', 'Éditeur de map', 'Props, récoltes, ateliers')}
        </div></div>
        <div class="home-cols">
            ${has('reports') ? `<div class="section"><h2>Derniers reports</h2>
                ${waiting.length ? waiting.slice(0, 4).map((r) => `<div class="mini-row"><span class="t">${esc(r.time)}</span><span><b>${esc(r.name)}</b> : ${esc(r.msg)}</span></div>`).join('')
                    : '<p class="muted">Aucun report en attente.</p>'}</div>` : ''}
            ${has('view_logs') ? `<div class="section"><h2>Dernières actions du staff</h2>
                ${(D.logs || []).slice(0, 5).map((l) => `<div class="mini-row"><span class="t">${esc(l.time.split(' ')[1] || l.time)}</span><span><b>${esc(l.admin)}</b> ${esc(l.action)}</span></div>`).join('') || '<p class="muted">Rien pour le moment.</p>'}</div>` : ''}
        </div>`;
};

/* ---------- Joueurs ---------- */
function playerRows() {
    const q = search.trim().toLowerCase();
    const list = D.players
        .filter((p) => !q || p.name.toLowerCase().includes(q) || String(p.id) === q)
        .sort((a, b) => a.id - b.id);
    if (!list.length) return '<div class="empty">Aucun joueur ne correspond.</div>';
    return list.map((p) => `
        <div class="row ${p.id === selectedPlayer ? 'active' : ''}" data-player="${p.id}" style="--stripe:${p.rankColor || 'transparent'}">
            <span class="pid">${p.id}</span>
            <span class="pname">${esc(p.name)}</span>
            ${p.rank && p.duty === false ? '<span title="Staff en mode RP">🎭</span>' : ''}
            ${p.frozen ? '<span title="Freeze">🧊</span>' : ''}
            ${p.warns ? `<span class="muted" title="Avertissements">⚠${p.warns}</span>` : ''}
            <span class="ping">${p.ping} ms</span>
        </div>`).join('');
}

VIEWS.players = () => {
    const p = D.players.find((x) => x.id === selectedPlayer);
    return `<div class="split">
        <div class="list-col">
            <input class="input" id="search" placeholder="Rechercher un nom ou un ID" value="${esc(search)}">
            <div class="list" id="player-list">${playerRows()}</div>
        </div>
        <div class="detail">${p ? playerDetail(p) : '<div class="empty">Choisis un joueur dans la liste pour agir sur lui.</div>'}</div>
    </div>`;
};

function playerDetail(p) {
    const isMe = p.id === D.me.id;
    const above = !isMe && p.level >= D.me.level;
    const b = (perm, act, label, cls = '', disabled = false) =>
        has(perm) ? `<button class="btn ${cls}" data-act="${act}" ${disabled ? 'disabled title="Grade égal ou supérieur au vôtre"' : ''}>${label}</button>` : '';

    const tp = [b('goto', 'goto', 'Aller vers lui', '', isMe), b('bring', 'bring', 'Le ramener', '', isMe || above), b('spectate', 'spectate', 'Spectate', '', isMe)].join('');
    const st = [b('revive', 'revive', 'Réanimer', 'primary'), b('heal', 'heal', '❤️ Soigner'), b('armor', 'armor', '🛡️ Remplir l\'armure'), b('give_item', 'give_to_player', '🎁 Donner un objet'), b('freeze', 'freeze', p.frozen ? 'Libérer' : 'Freeze', p.frozen ? 'on' : '', isMe || above),
                b('give_weapon', 'give_weapon', 'Donner une arme'), b('kill', 'kill', 'Tuer', 'danger', above)].join('');
    const pm = !isMe ? b('staff_pm', 'pm', '✉️ Message privé', 'primary') : '';
    const sa = [b('jail', 'jail', '⛓️ Jail', '', above), b('warn', 'warn', 'Avertir', '', isMe || above), b('kick', 'kick', 'Expulser', 'danger', isMe || above), b('ban', 'ban', 'Bannir', 'danger', isMe || above)].join('');
    const sf = has('manage_staff') && !isMe ? `<button class="btn" data-act="set_rank" ${above ? 'disabled' : ''}>Modifier le grade</button>` : '';

    const group = (title, html) => (html ? `<div class="group"><h3>${title}</h3><div class="btn-row">${html}</div></div>` : '');
    return `
        <div class="detail-head">
            <h2>${esc(p.name)}</h2>
            ${p.rankLabel ? `<span class="badge" style="color:${p.rankColor}">${esc(p.rankLabel)}</span>` : ''}
        </div>
        <div class="detail-meta">
            ID ${p.id} · ping ${p.ping} ms · ${p.warns} avertissement(s)${p.frozen ? ' · actuellement freeze' : ''}
            ${p.license ? `<br>${esc(p.license)}` : ''}
        </div>
        ${group('Téléportation', tp)}
        ${group('Message', pm)}
        ${group('État', st)}
        ${group('Sanctions', sa)}
        ${group('Staff', sf)}`;
}

/* ---------- Personnel ---------- */
VIEWS.self = () => {
    const s = D.self || {};
    const tog = (perm, key, label, sub) => has(perm) ? `
        <div class="tile toggle-tile ${s[key] ? 'on' : ''}" data-self="${key}">
            <div><strong>${label}</strong><span>${sub}</span></div><div class="switch"></div>
        </div>` : '';
    return `
        <div class="section">
            <h2>Modes</h2>
            <div class="grid">
                ${tog('noclip', 'noclip', 'Noclip', `3e personne · touche ${D.config.noclipKey}`)}
                ${tog('godmode', 'godmode', 'Godmode', 'Aucun dégât')}
                ${tog('invisible', 'invisible', 'Invisible', 'Caché aux joueurs')}
                ${tog('wallhack', 'wallhack', 'Wallhack', 'Joueurs à travers les murs et sur la carte')}
                ${tog('player_ids', 'showIds', 'Noms et IDs', 'Au-dessus des joueurs')}
            </div>
        </div>
        ${any('revive', 'revive_area') ? `<div class="section">
            <h2>Réanimation</h2>
            ${has('revive_area') ? `<p class="hint">Choisis un rayon : la zone s'affiche au sol autour de toi et les joueurs à terre sont signalés.
                Tu peux encore changer le rayon à la molette, puis <span class="keycap">E</span> pour réanimer ou <span class="keycap">Retour</span> pour annuler.
                Seuls les joueurs <b>morts</b> sont réanimés.</p>
            <div class="btn-row" style="margin-bottom:10px">${[10, 25, 50, 100].map((r) => `<button class="btn" data-revarea="${r}">Rayon ${r} m</button>`).join('')}</div>` : ''}
            ${has('revive') ? '<button class="btn" data-act="revive_me">Me réanimer</button>' : ''}
        </div>` : ''}
        ${has('transform') && D.me.level >= (D.config.minLevel || 40) ? animalSection() : ''}
        <div class="section">
            <h2>Déplacement</h2>
            <div class="btn-row" style="margin-bottom:12px">
                ${has('tp_waypoint') ? '<button class="btn primary" data-self="tp_waypoint">TP au marqueur</button>' : ''}
                ${has('heal') ? '<button class="btn" data-act="heal_self">❤️ Me soigner</button>' : ''}
                ${has('armor') ? '<button class="btn" data-act="armor_self">🛡️ Remplir mon armure</button>' : ''}
                <button class="btn" data-self="coords">Copier ma position</button>
            </div>
            ${has('tp_coords') ? `
            <div class="tpc">
                <label>📍 Se téléporter à des coordonnées</label>
                <div class="inline">
                    <input class="input" id="tpc-input" placeholder="Colle des coordonnées : vector3(215.7, -810.1, 30.7) · -1037 -2737 20 · x, y…" value="${esc(draft('tpcText', ''))}">
                    <button class="btn primary" data-act="tpc_go">Téléporter</button>
                </div>
                <div class="hint" id="tpc-preview">${tpcPreview(draft('tpcText', ''))}</div>
                <div id="tpc-chips">${tpChips('self')}</div>
            </div>` : ''}
        </div>
        ${any('delete_entity', 'spectate') ? `<div class="section"><h2>Viseur du noclip</h2>
            <p class="hint">En noclip, le point au centre de l'écran vise uniquement les <b>véhicules</b> et les <b>joueurs</b>.
            ${has('delete_entity') ? `${keyOf('Noclip', 'Supprimer le véhicule visé')} supprime le véhicule visé (PNJ ou joueur ; confirmation si un joueur est à bord).` : ''}
            ${has('spectate') ? `${keyOf('Noclip', 'Spectate le joueur visé')} lance le spectate du joueur visé (ou d'un joueur à bord du véhicule).` : ''}
            Les touches s'affichent en bas à droite de l'écran. Les objets de la map se retirent dans <b>Éditeur de map › Props</b>.</p></div>` : ''}`;
};

/* ---------- TP aux coordonnées (partagé avec le menu rapide) ---------- */
// Accepte : vector3(1.0, 2.0, 3.0) · vector4(…) · 1.0, 2.0, 3.0 · 1 2 3 · {x = 1, y = 2, z = 3} · {"x":1,"y":2}
// Sans Z (2 nombres) : on se pose au sol.
function tpcPreview(text) {
    if (!String(text || '').trim()) return 'Tous les formats marchent (vector3, vector4, 3 nombres…). Sans Z, tu es posé au sol. Entrée pour partir.';
    const c = parseCoords(text);
    return c ? `➜ X ${c.x.toFixed(2)} · Y ${c.y.toFixed(2)} · ${c.z === null ? 'Z : au sol' : `Z ${c.z.toFixed(2)}`}` : '<span style="color:var(--danger)">Coordonnées non reconnues.</span>';
}
function parseCoords(text) {
    const clean = String(text || '').replace(/vector[234]\s*\(/gi, '(').replace(/\b[xyzwh]\s*[=:]/gi, ' ');
    const nums = clean.match(/-?\d+(?:\.\d+)?/g);
    if (!nums || nums.length < 2) return null;
    const x = Number(nums[0]), y = Number(nums[1]);
    const z = nums.length >= 3 ? Number(nums[2]) : null;
    if (!Number.isFinite(x) || !Number.isFinite(y) || Math.abs(x) > 10000 || Math.abs(y) > 10000) return null;
    if (z !== null && (!Number.isFinite(z) || z < -300 || z > 3000)) return null;
    return { x, y, z };
}
const fmtCoords = (c) => `${c.x.toFixed(1)}, ${c.y.toFixed(1)}${c.z !== null && c.z !== undefined ? `, ${c.z.toFixed(1)}` : ' (sol)'}`;
const TP_HIST = 'am_tp_history', TP_FAV = 'am_tp_favorites';
function tpLoad(key) { try { const v = JSON.parse(localStorage.getItem(key) || '[]'); return Array.isArray(v) ? v : []; } catch (e) { return []; } }
function tpStore(key, v) { try { localStorage.setItem(key, JSON.stringify(v)); } catch (e) { /* stockage indisponible */ } }
const sameCoords = (a, b) => Math.abs(a.x - b.x) < 0.5 && Math.abs(a.y - b.y) < 0.5 && (a.z ?? null) === (b.z ?? null);
// Téléporte (le serveur journalise) et garde la position dans l'historique
function tpTo(c) {
    const hist = tpLoad(TP_HIST).filter((h) => !sameCoords(h, c));
    hist.unshift({ x: c.x, y: c.y, z: c.z ?? null });
    tpStore(TP_HIST, hist.slice(0, 6));
    return selfAction('tp_coords', { x: c.x, y: c.y, z: c.z === null || c.z === undefined ? undefined : c.z });
}
async function tpFavorite(c) {
    if (!c) return;
    const v = await formModal('Ajouter aux favoris', [{ name: 'label', label: 'Nom du lieu', placeholder: 'ex : Garage central' }], 'Enregistrer');
    if (!v) return;
    const fav = tpLoad(TP_FAV);
    fav.unshift({ x: c.x, y: c.y, z: c.z ?? null, label: String(v.label || '').trim().slice(0, 30) || fmtCoords(c) });
    tpStore(TP_FAV, fav.slice(0, 12));
    toast('Lieu ajouté aux favoris.', 'success');
    const box = $('#tpc-chips'); if (box) box.innerHTML = tpChips('self');
}
function tpChips(prefix) {
    const fav = tpLoad(TP_FAV), hist = tpLoad(TP_HIST);
    const chip = (c, kind, i) => `<span class="tpc-chip ${kind}"><button data-tpc="${prefix}:${kind}:${i}" title="${esc(fmtCoords(c))}">${kind === 'fav' ? '★ ' + esc(c.label || fmtCoords(c)) : '🕘 ' + esc(fmtCoords(c))}</button>${
        kind === 'fav' ? `<button class="tpc-x" data-tpcdel="${i}" title="Retirer des favoris">✕</button>` : `<button class="tpc-x" data-tpcfav="${i}" title="Ajouter aux favoris">☆</button>`}</span>`;
    const out = fav.map((c, i) => chip(c, 'fav', i)).concat(hist.map((c, i) => chip(c, 'hist', i)));
    return out.length ? `<div class="tpc-chips">${out.join('')}</div>` : '';
}

/* ---------- Transformation en animal ---------- */
const ANIMAL_EMOJI = [[/cat/, '🐈'], [/cow/, '🐄'], [/pig/, '🐖'], [/hen/, '🐔'], [/rabbit/, '🐇'], [/deer/, '🦌'], [/boar/, '🐗'],
    [/coyote/, '🐺'], [/mtlion|panther/, '🐆'], [/chimp|rhesus/, '🐒'], [/rat/, '🐀'], [/hawk/, '🦅'], [/pigeon/, '🕊️'],
    [/crow|cormorant|seagull/, '🐦'], [/dolphin/, '🐬'], [/humpback|killerwhale/, '🐋'], [/shark/, '🦈'], [/stingray|fish/, '🐟'],
    [/orleans|yeti/, '🦍'], [/alien/, '👽'], [/chop|husky|retriever|shepherd|rottweiler|poodle|pug|westy/, '🐕']];
const animalEmoji = (m, fb) => { for (const [re, e] of ANIMAL_EMOJI) if (re.test(m)) return e; return fb; };
function animalSection() {
    const cats = D.config.animals || [];
    const cur = D.self && D.self.transformed;
    const curLabel = cur ? ((cats.flatMap((c) => c.list).find((a) => a.model === cur) || {}).label || cur) : null;
    const img = (m) => (window.CATALOG && CATALOG.pedImage ? CATALOG.pedImage.replace('{name}', m) : '');
    return `<div class="section"><h2>🐾 Se transformer en animal</h2>
        ${cur ? `<div class="duty-bar" style="background:rgba(217,181,106,.08);border-color:rgba(217,181,106,.35)">
                <span>Tu es actuellement : <b>${esc(curLabel)}</b></span>
                <button class="btn primary" data-self="human">🧍 Reprendre ma forme humaine</button></div>`
            : '<p class="hint">Ton apparence (vêtements, visage, cheveux), ta vie et ton armure sont sauvegardées et remises à l\'identique quand tu reprends ta forme humaine.</p>'}
        ${cats.map((c) => `<div class="group"><h3>${c.icon} ${esc(c.cat)}</h3><div class="animal-grid">
            ${c.list.map((a) => `<button class="animal ${cur === a.model ? 'active' : ''}" data-animal="${esc(a.model)}" title="${esc(a.model)}">
                <span class="animal-img">${img(a.model) ? `<img src="${esc(img(a.model))}" alt="" loading="lazy" onerror="this.remove()">` : ''}<em>${animalEmoji(a.model, c.icon)}</em></span>
                <span class="animal-name">${esc(a.label)}</span></button>`).join('')}
        </div></div>`).join('')}
        <div class="inline" style="max-width:520px;margin-top:6px">
            <input class="input" placeholder="Autre modèle (animal ajouté, ex : a_c_…)" data-draft="animalModel" value="${esc(draft('animalModel'))}">
            <button class="btn" data-act="animal_custom">Se transformer</button>
        </div>
        <p class="hint" style="margin-top:8px">Les animaux marins ne vivent que dans l'eau. Les oiseaux marchent au sol : combine avec le noclip pour voler.</p>
    </div>`;
}

/* ---------- Véhicules ---------- */
VIEWS.vehicles = () => {
    let html = '';
    if (has('spawn_vehicle')) {
        html += `<div class="section">
            <h2>Faire apparaître</h2>
            <div class="inline" style="margin-bottom:14px">
                <input class="input" id="veh-model" placeholder="Nom du modèle, ex : adder" data-draft="model" value="${esc(draft('model'))}">
                <button class="btn primary" data-act="spawn_input">Faire apparaître</button>
            </div>
            ${D.config.vehicles.map((c) => `
                <div class="group"><h3>${esc(c.cat)}</h3>
                <div class="chips">${c.list.map((m) => `<button class="chip" data-spawn="${esc(m)}">${esc(m)}</button>`).join('')}</div></div>`).join('')}
        </div>`;
    }
    if (has('vehicle_tools')) {
        const t = (tool, label, sub, cls = '') => `<button class="tile ${cls}" data-vtool="${tool}"><strong>${label}</strong><span>${sub}</span></button>`;
        html += `<div class="section">
            <h2>Outils</h2>
            <p class="hint">S'applique à ton véhicule, ou au plus proche dans un rayon de 8 m.</p>
            <div class="grid">
                ${t('repair', 'Réparer', 'Moteur et carrosserie')}
                ${t('clean', 'Nettoyer', 'Saleté et décalques')}
                ${t('flip', 'Retourner', 'Remettre sur ses roues')}
                ${t('upgrade', 'Améliorer', 'Performances max')}
                ${t('unlock', 'Déverrouiller', 'Ouvrir les portes')}
                ${t('delete', 'Supprimer', 'Retirer du monde')}
            </div>
        </div>`;
    }
    return html;
};

/* ---------- Monde ---------- */
VIEWS.world = () => {
    const w = D.world;
    let html = '';
    if (has('weather')) {
        html += `<div class="section"><h2>Météo</h2><div class="grid">
            ${D.config.weathers.map((x) => `<button class="tile ${w.weather === x.id ? 'active' : ''}" data-weather="${x.id}">
                <strong>${esc(x.label)}</strong><span>${x.id}</span></button>`).join('')}
        </div></div>`;
    }
    if (has('time')) {
        const h = draft('hour', w.hour), m = draft('minute', w.minute);
        html += `<div class="section"><h2>Heure</h2>
            <div class="clock" id="clock">${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}</div>
            <div class="field"><label>Heures</label><input type="range" min="0" max="23" value="${h}" data-draft="hour" id="hour"></div>
            <div class="field"><label>Minutes</label><input type="range" min="0" max="59" value="${m}" data-draft="minute" id="minute"></div>
            <div class="btn-row">
                <button class="btn primary" data-act="set_time">Appliquer l'heure</button>
                <button class="btn ${w.freeze ? 'on' : ''}" data-act="freeze_time">${w.freeze ? "Relancer l'horloge" : "Figer l'horloge"}</button>
                ${has('blackout') ? `<button class="btn ${w.blackout ? 'on' : ''}" data-act="blackout">${w.blackout ? 'Rallumer la ville' : 'Blackout'}</button>` : ''}
            </div></div>`;
    } else if (has('blackout')) {
        html += `<div class="section"><h2>Électricité</h2><button class="btn ${w.blackout ? 'on' : ''}" data-act="blackout">${w.blackout ? 'Rallumer la ville' : 'Blackout'}</button></div>`;
    }
    if (has('clear_area')) {
        html += `<div class="section"><h2>Nettoyer la zone</h2>
            <p class="hint">Supprime les véhicules vides et les PNJ autour de toi. Les véhicules occupés par des joueurs sont conservés.</p>
            <div class="inline" style="max-width:420px">
                <select class="input" id="clear-radius" data-draft="radius">
                    ${[25, 50, 100, 200, 500].map((r) => `<option value="${r}" ${String(draft('radius', 50)) === String(r) ? 'selected' : ''}>${r} mètres</option>`).join('')}
                </select>
                <button class="btn danger" data-act="clear_area">Nettoyer</button>
            </div></div>`;
    }
    return html;
};

/* ---------- Objets ---------- */
let ITEMS = null, itemsMode = '', itemsAsked = 0;
let itemSearch = '', itemCat = 'all', selItem = null, itemLimit = 300;
const give = { target: 'me', id: '', count: 1 };
const ITEM_CATS = [
    { id: 'all', label: 'Tout' }, { id: 'server', label: '⭐ Elyzea' },
    { id: 'weapon', label: '🔫 Armes' }, { id: 'ammo', label: '🎯 Munitions' }, { id: 'other', label: '📦 Objets' },
];
const isWeapon = (n) => /^weapon_/i.test(n);
const isAmmo = (n) => /^ammo/i.test(n) || /_ammo$/i.test(n);
const itemKind = (it) => it.kind || (isWeapon(it.name) ? 'weapon' : isAmmo(it.name) ? 'ammo' : 'other');
function serverItems() {
    if (!D || !D.config.editor) return new Set();
    return new Set(knownItems().map((x) => x.toLowerCase()));
}
function itemIcon(it, size) {
    const letter = esc((it.label || it.name || '?').trim().charAt(0).toUpperCase());
    const fallback = `<span class="item-fallback" style="${it.image ? 'display:none' : ''}">${isWeapon(it.name) ? '🔫' : letter}</span>`;
    const img = it.image ? `<img src="${esc(it.image)}" alt="" loading="lazy" onerror="this.style.display='none';this.nextElementSibling.style.display='flex'">` : '';
    return `<div class="item-ico ${size || ''}">${img}${fallback}</div>`;
}
function filteredItems() {
    const q = itemSearch.trim().toLowerCase();
    const srv = itemCat === 'server' ? serverItems() : null;
    return (ITEMS || []).filter((it) => {
        if (q && !it.label.toLowerCase().includes(q) && !it.name.toLowerCase().includes(q)) return false;
        if (itemCat === 'weapon') return itemKind(it) === 'weapon';
        if (itemCat === 'ammo') return itemKind(it) === 'ammo';
        if (itemCat === 'other') return itemKind(it) === 'other';
        if (srv) return srv.has(it.name.toLowerCase());
        return true;
    });
}
function itemCatCount(id) {
    if (!ITEMS || id === 'server') return '';
    const n = id === 'all' ? ITEMS.length : ITEMS.filter((it) => itemKind(it) === id).length;
    return ` <span class="muted">${n}</span>`;
}
function itemGrid() {
    const list = filteredItems();
    if (!list.length) return '<div class="empty">Aucun objet ne correspond.</div>';
    const shown = list.slice(0, itemLimit);
    const rest = list.length - shown.length;
    return shown.map((it) => `<button class="item-card ${selItem && selItem.name === it.name ? 'active' : ''}" data-item="${esc(it.name)}" title="${esc(it.name)}">
            ${itemIcon(it)}<span class="item-label">${esc(it.label)}</span><span class="item-code">${esc(it.name)}</span></button>`).join('')
        + (rest > 0 ? `<div class="item-more"><span class="muted">${shown.length} sur ${list.length} affichés</span>
            <button class="btn" data-imore="300">Afficher ${Math.min(300, rest)} de plus</button>
            <button class="btn" data-imore="all">Tout afficher (${list.length})</button></div>` : '');
}
VIEWS.items = () => {
    if (!ITEMS) {
        if (Date.now() - itemsAsked > 3000) { itemsAsked = Date.now(); action('get_items'); }
        return '<div class="empty">Chargement de la liste des objets…</div>';
    }
    if (!ITEMS.length) return `<div class="empty">Aucun objet trouvé. ${itemsMode === 'none' ? "Aucun inventaire n'est détecté sur le serveur (ox_inventory, qb-core ou ESX)." : ''}</div>`;
    const it = selItem;
    const others = D.players.filter((p) => p.id !== D.me.id).sort((a, b) => a.id - b.id);
    return `<div class="split items-split">
        <div class="list-col">
            <div class="inline">
                <input class="input" id="item-search" placeholder="Rechercher parmi les ${ITEMS.length} objets (nom ou code)…" value="${esc(itemSearch)}">
                <button class="btn" data-act="reload_items" title="Recharger la liste depuis l'inventaire du serveur">🔄</button>
            </div>
            <div class="chips">${ITEM_CATS.map((c) => `<button class="chip ${itemCat === c.id ? 'chip-on' : ''}" data-icat="${c.id}">${c.label}${itemCatCount(c.id)}</button>`).join('')}</div>
            <div class="list"><div class="item-grid" id="item-grid">${itemGrid()}</div></div>
        </div>
        <div class="detail">${!it ? `<div class="empty">Choisis un objet à gauche.<br><span class="muted">${ITEMS.length} objets disponibles sur le serveur (${esc(itemsMode)}).</span>
                <div class="inline" style="max-width:420px;margin:18px auto 0">
                    <input class="input" id="item-code" placeholder="…ou tape le code exact d'un objet">
                    <button class="btn" data-act="item_by_code">Choisir</button></div></div>` : `
            <div class="give-head">${itemIcon(it, 'big')}<div><h2>${esc(it.label)}</h2>
                <div class="muted">${esc(it.name)}${it.weight ? ` · ${it.weight >= 1000 ? (it.weight / 1000) + ' kg' : it.weight + ' g'}` : ''}</div></div></div>
            <div class="section"><h2>Quantité</h2>
                <div class="inline" style="max-width:420px">
                    <input class="input" type="number" min="1" max="10000" data-give="count" value="${esc(give.count)}">
                    ${[1, 5, 10, 50, 100].map((n) => `<button class="btn ${Number(give.count) === n ? 'on' : ''}" data-gcount="${n}">${n}</button>`).join('')}
                </div>
            </div>
            <div class="section"><h2>À qui ?</h2>
                <div class="grid" style="grid-template-columns:1fr 1fr;max-width:520px;margin-bottom:10px">
                    <div class="tile ${give.target === 'me' ? 'active' : ''}" data-gtarget="me"><strong>🙋 À moi</strong><span>Dans ton inventaire</span></div>
                    <div class="tile ${give.target === 'player' ? 'active' : ''}" data-gtarget="player"><strong>👤 À un joueur</strong><span>Par son ID</span></div>
                </div>
                ${give.target === 'player' ? `<div class="form-grid" style="grid-template-columns:120px 1fr;max-width:520px">
                    <div><label>ID</label><input class="input" type="number" min="1" data-give="id" value="${esc(give.id)}" placeholder="ex : 12"></div>
                    <div><label>ou choisis dans la liste</label><select class="input" data-give="id">
                        <option value="">—</option>
                        ${others.map((p) => `<option value="${p.id}" ${String(give.id) === String(p.id) ? 'selected' : ''}>[${p.id}] ${esc(p.name)}</option>`).join('')}
                    </select></div></div>` : ''}
            </div>
            <button class="btn primary big" data-act="give_item">🎁 Donner ${esc(give.count)} × ${esc(it.label)}</button>`}
        </div>
    </div>`;
};

/* ---------- Annonces ---------- */
function annDraft() {
    if (!drafts.ann) drafts.ann = { title: '', message: '', image: 'logo', customUrl: '', style: 'info', duration: 10, ticker: false };
    return drafts.ann;
}
VIEWS.announce = () => {
    const a = annDraft();
    const imgs = D.config.announceImages || [];
    const imgTile = (val, label, inner) => `<button class="preset img-pick ${a.image === val ? 'active' : ''}" data-annimg="${esc(val)}">${inner}<span class="pl">${esc(label)}</span></button>`;
    const isCustom = a.image !== '' && !imgs.find((i) => i.url === a.image);
    const preview = { ...a, image: isCustom ? a.customUrl : a.image, by: D.me.label };
    return `<div class="section"><h2>Aperçu en direct</h2>
            <p class="hint">Voici exactement ce que verront les joueurs en haut de leur écran.</p>
            <div class="an an-preview an-${a.style}">${announceHTML({ ...preview, message: a.message || 'Ton message apparaîtra ici.' })}</div>
        </div>
        <div class="section"><h2>Message</h2>
            <div class="form-grid" style="grid-template-columns:1fr 180px">
                <div><label>Titre (optionnel)</label><input class="input" data-ann="title" maxlength="60" placeholder="ex : Soirée course ce soir !" value="${esc(a.title)}"></div>
                <div><label>Type</label><select class="input" data-ann="style">
                    <option value="info" ${a.style === 'info' ? 'selected' : ''}>Annonce (or)</option>
                    <option value="event" ${a.style === 'event' ? 'selected' : ''}>Événement (bleu)</option>
                    <option value="alert" ${a.style === 'alert' ? 'selected' : ''}>Alerte (rouge)</option></select></div>
            </div>
            <textarea class="input" data-ann="message" maxlength="400" placeholder="Le texte diffusé à tous les joueurs">${esc(a.message)}</textarea>
            <p class="hint" style="margin-top:6px"><span id="ann-count">${(a.message || '').length}</span> / 400 caractères</p>
        </div>
        <div class="section"><h2>Image</h2>
            <div class="preset-grid">
                ${imgTile('', 'Aucune', '<span class="pi">🚫</span>')}
                ${imgs.map((i) => imgTile(i.url, i.label, `<img src="${esc(imgSrc(i.url))}" alt="">`)).join('')}
                <button class="preset img-pick ${isCustom ? 'active' : ''}" data-annimg="__custom"><span class="pi">🔗</span><span class="pl">Lien d'une image</span></button>
            </div>
            ${isCustom ? `<div class="field" style="max-width:620px"><label>Lien de l'image (https://…png, jpg ou gif)</label>
                <input class="input" data-ann="customUrl" placeholder="https://i.imgur.com/…png" value="${esc(a.customUrl)}"></div>` : ''}
        </div>
        <div class="section"><h2>Affichage</h2>
            <div class="form-grid" style="grid-template-columns:1fr 1fr">
                <div><label>Durée à l'écran : <b id="ann-dur">${a.duration} s</b></label><input type="range" min="4" max="60" value="${a.duration}" data-ann="duration"></div>
                <div><label>Style du texte</label><select class="input" data-ann="ticker">
                    <option value="false" ${!a.ticker ? 'selected' : ''}>Texte fixe</option>
                    <option value="true" ${a.ticker ? 'selected' : ''}>Texte défilant</option></select></div>
            </div>
            <button class="btn primary big" data-act="announce">📢 Diffuser à tout le serveur</button>
        </div>`;
};

/* ---------- Reports ---------- */
VIEWS.reports = () => {
    const list = D.reports || [];
    if (!list.length) return '<div class="empty">Aucun report en attente. Les joueurs en envoient avec /report &lt;message&gt;.</div>';
    return list.map((r) => `
        <div class="card">
            <div class="card-head">
                <strong>#${r.id} · ${esc(r.name)} <span class="muted">[${r.src}]</span></strong>
                <span class="muted">${esc(r.time)}${r.offline ? ' · déconnecté' : ''}</span>
            </div>
            <div class="msg">${esc(r.msg)}</div>
            ${r.claimedBy ? `<div class="claimed" style="margin-bottom:10px">Pris en charge par ${esc(r.claimedBy)}</div>` : ''}
            <div class="btn-row">
                ${!r.claimedBy ? `<button class="btn primary" data-report="claim" data-id="${r.id}">Prendre en charge</button>` : ''}
                ${!r.offline && has('goto') ? `<button class="btn" data-report="goto" data-id="${r.id}" data-src="${r.src}">Aller vers lui</button>` : ''}
                ${!r.offline && has('bring') ? `<button class="btn" data-report="bring" data-id="${r.id}" data-src="${r.src}">Le ramener</button>` : ''}
                <button class="btn danger" data-report="close" data-id="${r.id}">Clôturer</button>
            </div>
        </div>`).join('');
};

/* ---------- Bannissements ---------- */
VIEWS.bans = () => `${has('jail') ? jailSection() : ''}${any('ban', 'unban') ? `<div class="section"><h2>⛔ Bannissements</h2>${bansTable()}</div>` : ''}`;

const fmtSec = (sec) => { sec = Math.max(0, Math.floor(sec)); const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s2 = sec % 60;
    return h ? `${h} h ${String(m).padStart(2, '0')}` : `${m}:${String(s2).padStart(2, '0')}`; };
function jailSection() {
    const list = D.jails || [];
    return `<div class="section"><h2>⛓️ En prison (${list.length})</h2>
        ${D.hasJailPoint === false ? '<p class="hint" style="color:var(--signal)">Aucun point de jail défini : Éditeur de map › Points de spawn › « Point de jail ».</p>' : ''}
        ${!list.length ? '<div class="empty">Personne en prison.</div>' : `<table>
            <tr><th>Joueur</th><th>Temps restant</th><th>Raison</th><th>Par</th><th></th></tr>
            ${list.map((j) => `<tr><td>${esc(j.name || '?')} ${j.online ? `<span class="muted">[${j.online}]</span>` : '<span class="muted">(hors ligne : le temps est en pause)</span>'}</td>
                <td><b>${fmtSec(j.remaining)}</b></td><td>${esc(j.reason)}</td><td class="muted">${esc(j.by)}</td>
                <td><button class="btn" data-unjail="${esc(j.license)}" data-name="${esc(j.name || '')}">Libérer</button></td></tr>`).join('')}
        </table>`}</div>`;
}

function bansTable() {
    const list = D.bans || [];
    if (!list.length) return '<div class="empty">Aucun bannissement actif.</div>';
    return `<table>
        <tr><th>#</th><th>Joueur</th><th>Raison</th><th>Par</th><th>Date</th><th>Expiration</th><th></th></tr>
        ${list.map((b) => `<tr>
            <td>${b.id}</td><td>${esc(b.name)}</td><td>${esc(b.reason)}</td><td>${esc(b.by)}</td>
            <td class="small">${esc(b.date)}</td><td>${esc(b.expire)}</td>
            <td>${has('unban') ? `<button class="btn" data-unban="${b.id}" data-name="${esc(b.name)}">Débannir</button>` : ''}</td>
        </tr>`).join('')}
    </table>`;
};

/* ---------- Staff ---------- */
function assignableRanks() {
    return Object.entries(D.ranks)
        .filter(([, r]) => r.level < D.me.level)
        .sort((a, b) => b[1].level - a[1].level);
}

VIEWS.staff = () => {
    const list = (D.staff || []).sort((a, b) => b.level - a.level);
    const ranks = assignableRanks();
    return `<p class="hint muted" style="margin-bottom:14px">Pour recruter : onglet Joueurs → choisir le joueur → Modifier le grade.</p>
    ${list.length ? `<table>
        <tr><th>Membre</th><th>Grade</th><th>Statut</th><th>Identifiant</th><th></th></tr>
        ${list.map((s) => {
            const editable = !s.owner && s.level < D.me.level;
            return `<tr>
                <td>${esc(s.name)}</td>
                <td>${editable
                    ? `<select class="input" data-staff-rank="${esc(s.identifier)}" style="width:170px">
                        ${ranks.map(([k, r]) => `<option value="${k}" ${k === s.rank ? 'selected' : ''}>${esc(r.label)}</option>`).join('')}
                       </select>`
                    : `<span class="badge" style="color:${s.color}">${esc(s.label)}</span>`}</td>
                <td>${s.online ? `<span style="color:var(--ok)">En ligne [${s.online}]</span>` : '<span class="muted">Hors ligne</span>'}</td>
                <td class="small">${esc(s.identifier)}</td>
                <td>${editable ? `<button class="btn danger" data-staff-remove="${esc(s.identifier)}" data-name="${esc(s.name)}">Retirer</button>` : ''}</td>
            </tr>`;
        }).join('')}
    </table>` : '<div class="empty">Aucun membre du staff enregistré.</div>'}`;
};

/* ---------- Grades ---------- */
VIEWS.ranks = () => {
    const ranks = Object.entries(D.ranks).sort((a, b) => b[1].level - a[1].level);
    return `<div class="split">
        <div class="list-col">
            <button class="btn primary" data-rank-new>Nouveau grade</button>
            <div class="list">
                ${ranks.map(([k, r]) => `
                    <div class="row ${rankDraft && rankDraft.name === k && !rankDraft.isNew ? 'active' : ''}" data-rank="${k}" style="--stripe:${r.color}">
                        <span class="pname rank-item">${esc(r.label)}</span>
                        <span class="ping">niveau ${r.level}${r.locked ? ' · verrouillé' : ''}</span>
                    </div>`).join('')}
            </div>
        </div>
        <div class="detail">${rankDraft ? rankEditor() : '<div class="empty">Choisis un grade pour modifier ses permissions, ou crée-en un nouveau.</div>'}</div>
    </div>`;
};

function rankEditor() {
    const r = rankDraft;
    const original = D.ranks[r.name];
    const editable = r.isNew || (original && !original.locked && original.level < D.me.level);
    const cats = {};
    D.config.permissions.forEach((p) => { (cats[p.cat] = cats[p.cat] || []).push(p); });
    const dis = editable ? '' : 'disabled';

    return `
        ${!editable ? `<p class="hint" style="color:var(--signal);margin-bottom:14px">${original && original.locked ? 'Ce grade est verrouillé : il possède toutes les permissions.' : 'Grade égal ou supérieur au vôtre : lecture seule.'}</p>` : ''}
        <div class="form-grid">
            <div><label class="muted">Identifiant</label><input class="input" data-rank-field="name" value="${esc(r.name)}" ${r.isNew ? '' : 'disabled'} placeholder="ex : helper"></div>
            <div><label class="muted">Nom affiché</label><input class="input" data-rank-field="label" value="${esc(r.label)}" ${dis}></div>
            <div><label class="muted">Niveau (max ${D.me.level - 1})</label><input class="input" type="number" min="1" max="${D.me.level - 1}" data-rank-field="level" value="${r.level}" ${dis}></div>
            <div><label class="muted">Couleur</label><input class="input" type="color" data-rank-field="color" value="${esc(r.color)}" ${dis}></div>
        </div>
        ${Object.entries(cats).map(([cat, perms]) => `
            <div class="perm-cat"><h3>${esc(cat)}</h3><div class="perm-grid">
                ${perms.map((p) => {
                    const mine = has(p.key);
                    const locked = !editable || !mine;
                    return `<label class="perm ${locked ? 'locked' : ''}" ${!mine && editable ? 'title="Vous ne possédez pas cette permission"' : ''}>
                        <input type="checkbox" data-perm="${p.key}" ${r.perms[p.key] ? 'checked' : ''} ${locked ? 'disabled' : ''}>${esc(p.label)}</label>`;
                }).join('')}
            </div></div>`).join('')}
        ${editable ? `<div class="btn-row" style="margin-top:8px">
            <button class="btn primary" data-act="save_rank">${r.isNew ? 'Créer le grade' : 'Enregistrer'}</button>
            ${!r.isNew ? '<button class="btn danger" data-act="delete_rank">Supprimer le grade</button>' : ''}
        </div>` : ''}`;
}


/* ---------- Éditeur de map ---------- */
const EDITOR_SUBS = [
    { id: 'spawns',  label: '📍 Points de spawn', perm: 'editor_spawns' },
    { id: 'catalog', label: '📚 Catalogue',     perm: 'editor_props', alt: 'editor_peds' },
    { id: 'props',   label: '📦 Props',         perm: 'editor_props' },
    { id: 'peds',    label: '🧑 PNJ',           perm: 'editor_peds' },
    { id: 'harvest', label: '🌿 Récoltes',      perm: 'editor_harvest' },
    { id: 'search',  label: '🔍 Fouilles',      perm: 'editor_harvest' },
    { id: 'crafting', label: '🛠️ Ateliers',     perm: 'editor_crafting' },
    { id: 'zones',   label: '🗺️ Zones',        perm: 'editor_zones' },
    { id: 'doors',   label: '🚪 Portes',       perm: 'editor_doors' },
    { id: 'stashes', label: '🗄️ Coffres',      perm: 'editor_stashes' },
];
const distTxt = (d) => (d === undefined || d === null ? '' : d < 1000 ? `${d} m` : `${(d / 1000).toFixed(1)} km`);
const byDist = (a, b) => (a.dist ?? 1e9) - (b.dist ?? 1e9);

VIEWS.editor = () => {
    const subs = EDITOR_SUBS.filter((x) => has(x.perm) || (x.alt && has(x.alt)));
    if (!subs.find((x) => x.id === editorSub)) editorSub = subs[0].id;
    const nav = `<div class="protect">🔒 <span>Tout ce que tu crées ici est <b>sauvegardé et protégé</b> : seuls les SuperAdmin et Fondateurs peuvent le modifier ou le supprimer.
        Pour les déplacer ou les supprimer, utilise les boutons des listes ci-dessous.</span></div>
        <div class="segmented">${subs.map((x) => `<button class="seg ${x.id === editorSub ? 'active' : ''}" data-esub="${x.id}">${x.label}</button>`).join('')}</div>`;
    return nav + ({ spawns: edSpawns, props: edProps, peds: edPeds, harvest: edHarvest, search: edSearch, crafting: edCrafting, catalog: edCatalog, zones: edZones, doors: edDoors, stashes: () => (typeof edStashes === 'function' ? edStashes() : '') })[editorSub]();
};

function edList(items, render, empty) {
    if (!items.length) return `<div class="empty">${empty}</div>`;
    return `<table>${items.sort(byDist).slice(0, 80).map(render).join('')}</table>
        ${items.length > 80 ? '<p class="hint muted">Seuls les 80 plus proches sont affichés.</p>' : ''}`;
}
const rowBtns = (kind, id, extra = '') => `<td style="text-align:right;white-space:nowrap">
    ${extra}
    <button class="btn" data-ed="tp" data-kind="${kind}" data-id="${id}">TP</button>
    <button class="btn danger" data-ed="delete" data-kind="${kind}" data-id="${id}">Supprimer</button></td>`;

function edSpawns() {
    const ed = D.editor;
    const nc = ed.spawns.find((x) => x.newcomer);
    return `<div class="section"><h2>Ajouter un point de spawn</h2>
        <p class="hint">Place-toi à l'endroit voulu, tourné dans la bonne direction, puis ajoute ta position.</p>
        <div class="inline" style="max-width:560px">
            <input class="input" placeholder="Nom, ex : Gare centrale" data-draft="spawnName" value="${esc(draft('spawnName'))}">
            <button class="btn primary" data-ed="add_spawn">Ajouter ma position</button>
        </div></div>
        <div class="section"><h2>⛓️ Prison (jail)</h2>
        <p class="hint">${ed.spawns.find((x) => x.jail) ? `Les joueurs mis en prison sont envoyés à <b>${esc(ed.spawns.find((x) => x.jail).name)}</b>. S'ils s'éloignent, ils y sont ramenés.`
            : 'Aucun point de jail : ajoute ta position au bon endroit puis clique « Point de jail » ci-dessous.'}</p></div>
        <div class="section"><h2>Nouveaux arrivants</h2>
        <p class="hint">${nc ? `Les joueurs qui viennent pour la première fois apparaissent à <b>${esc(nc.name)}</b>.`
            : "Aucun point dédié : les nouveaux arrivants apparaissent là où le serveur les place d'habitude. Choisis un point ci-dessous."}</p></div>
        <div class="section"><h2>Points enregistrés (${ed.spawns.length})</h2>
        ${edList(ed.spawns, (sp) => `<tr>
            <td><strong>${esc(sp.name)}</strong>${sp.newcomer ? ' <span class="badge" style="color:var(--ok)">Nouveaux arrivants</span>' : ''}${sp.jail ? ' <span class="badge" style="color:var(--danger)">Prison</span>' : ''}</td>
            <td class="muted">${distTxt(sp.dist)}</td>
            ${rowBtns('spawn', sp.id, `<button class="btn ${sp.newcomer ? 'on' : ''}" data-ed="newcomer" data-id="${sp.id}">${sp.newcomer ? 'Retirer des nouveaux' : 'Pour les nouveaux'}</button>
                <button class="btn ${sp.jail ? 'on' : ''}" data-ed="jailpoint" data-id="${sp.id}">${sp.jail ? '⛓️ Retirer le jail' : '⛓️ Point de jail'}</button>
                <button class="btn" data-ed="rename_spawn" data-id="${sp.id}">Renommer</button>`)}</tr>`,
            'Aucun point de spawn. Ajoute ta position actuelle pour commencer.')}</div>`;
}

/* ----- Props (avec dossiers) ----- */
// propView : 'all' (tous), 'none' (sans dossier) ou id d'un dossier
let propView = 'all', propSearch = '', pendingFolderOpen = false;
const propSel = new Set();
const propFolders = () => (D.editor.propFolders || []);
const folderOf = (id) => propFolders().find((f) => f.id === id);
function propsInView() {
    const q = propSearch.trim().toLowerCase();
    return D.editor.props.filter((r) => {
        if (propView === 'none' && r.folder) return false;
        if (propView !== 'all' && propView !== 'none' && r.folder !== propView) return false;
        return !q || r.model.toLowerCase().includes(q) || String(r.id) === q.replace('#', '');
    });
}
function propRows() {
    const list = propsInView();
    if (!list.length) return `<div class="empty">${D.editor.props.length ? 'Aucun prop ici.' : 'Aucun prop. Choisis un modèle ci-dessus pour en poser un.'}</div>`;
    const folders = propFolders();
    const sorted = [...list].sort(byDist);
    const shown = sorted.slice(0, 150);
    return `<table class="prop-table">${shown.map((r) => {
        const f = folderOf(r.folder);
        return `<tr class="${propSel.has(r.id) ? 'sel' : ''}">
            <td style="width:28px"><input type="checkbox" data-propsel="${r.id}" ${propSel.has(r.id) ? 'checked' : ''}></td>
            <td><strong>${esc(r.model)}</strong> <span class="muted">#${r.id}</span></td>
            <td><select class="input prop-folder-sel" data-propfolder="${r.id}">
                <option value="0" ${!r.folder ? 'selected' : ''}>Sans dossier</option>
                ${folders.map((x) => `<option value="${x.id}" ${r.folder === x.id ? 'selected' : ''}>📁 ${esc(x.name)}</option>`).join('')}</select></td>
            <td class="muted" style="white-space:nowrap">${distTxt(r.dist)}</td>
            <td style="text-align:right;white-space:nowrap">
                <button class="btn" data-ed="prop_show" data-id="${r.id}" title="Le faire briller en jeu">👁️</button>
                <button class="btn" data-ed="move" data-kind="prop" data-id="${r.id}">Déplacer</button>
                <button class="btn" data-ed="tp" data-kind="prop" data-id="${r.id}">TP</button>
                <button class="btn danger" data-ed="delete" data-kind="prop" data-id="${r.id}">Supprimer</button></td></tr>`;
    }).join('')}</table>${list.length > shown.length ? `<p class="hint muted">Les ${shown.length} plus proches sur ${list.length} sont affichés : utilise la recherche ou les dossiers.</p>` : ''}`;
}
function propBulkBar() {
    if (!propSel.size) return '';
    return `<div class="prop-bulk"><b>${propSel.size} sélectionné(s)</b>
        <select class="input" id="prop-bulk-folder"><option value="0">Sans dossier</option>
            ${propFolders().map((f) => `<option value="${f.id}" ${propView === f.id ? 'selected' : ''}>📁 ${esc(f.name)}</option>`).join('')}</select>
        <button class="btn primary" data-ed="props_move_folder">Ranger dans ce dossier</button>
        <button class="btn" data-ed="props_show_sel">👁️ Montrer en jeu</button>
        <button class="btn" data-ed="props_sel_clear">Tout désélectionner</button></div>`;
}
function edProps() {
    const ed = D.editor, cfg = D.config.editor;
    const folders = propFolders();
    if (propView !== 'all' && propView !== 'none' && !folderOf(propView)) propView = 'all';
    const count = (id) => ed.props.filter((r) => (id === 'none' ? !r.folder : r.folder === id)).length;
    const cur = folderOf(propView);
    const dest = draft('propFolder', cur ? String(cur.id) : '0');
    return `<div class="section"><h2>Placer un prop</h2>
        <p class="hint">Le prop suit le point que tu vises et se <b>colle au sol</b> tout seul (il suit même la pente).
            <span class="keycap">G</span> pour le décoller et le placer librement, molette pour tourner, Page haut / Page bas pour la hauteur,
            <span class="keycap">E</span> pour valider. Un prop qui flotte déjà : bouton « Déplacer » dans la liste, puis <span class="keycap">E</span>.</p>
        <div class="inline" style="margin-bottom:12px;max-width:820px">
            <input class="input" id="prop-model" placeholder="Nom du modèle, ex : prop_bench_01a" data-draft="propModel" value="${esc(draft('propModel'))}">
            <select class="input" data-draft="propFolder" style="max-width:240px" title="Dossier où ranger le nouveau prop">
                <option value="0" ${dest === '0' ? 'selected' : ''}>Ranger : sans dossier</option>
                ${folders.map((f) => `<option value="${f.id}" ${dest === String(f.id) ? 'selected' : ''}>Ranger dans 📁 ${esc(f.name)}</option>`).join('')}</select>
            <button class="btn primary" data-ed="place_prop">Placer</button>
            <button class="btn ${drafts.propMagnet ? 'on' : ''}" data-ed="prop_magnet" title="Le nouveau prop se colle à l'objet visé : dessus, devant, derrière, à gauche ou à droite">🧲 Aimant : ${drafts.propMagnet ? 'OUI' : 'NON'}</button>
        </div>
        ${drafts.propMagnet ? `<p class="hint" style="margin-top:-4px">🧲 <b>Aimant activé</b> : approche le viseur de n'importe quel prop (posé par toi ou déjà sur la map, même sans le toucher) :
            le nouveau se colle contre lui, parfaitement aligné, du côté que tu vises.
            <span class="keycap">X</span> force un côté (automatique, dessus, devant, derrière, à gauche, à droite), la molette tourne d'un quart de tour,
            <span class="keycap">M</span> active / coupe l'aimant pendant le placement.</p>` : ''}
        <div class="chips">${cfg.quickProps.map((m) => `<button class="chip" data-ed="place_prop" data-model="${esc(m)}">${esc(m)}</button>`).join('')}</div>
        <div class="btn-row" style="margin-top:10px">
            <button class="btn" data-opencat="props">📚 Parcourir tout le catalogue des props</button>
            <button class="btn" data-ed="prop_select">🎯 Viser un prop en jeu (contour + nom)</button>
        </div>
        </div>

        <div class="section"><h2>Props enregistrés (${ed.props.length})</h2>
        <div class="folder-bar">
            <button class="folder-chip ${propView === 'all' ? 'active' : ''}" data-pview="all">📋 Tous <b>${ed.props.length}</b></button>
            <button class="folder-chip ${propView === 'none' ? 'active' : ''}" data-pview="none">📂 Sans dossier <b>${count('none')}</b></button>
            ${folders.map((f) => `<button class="folder-chip ${propView === f.id ? 'active' : ''}" data-pview="${f.id}">📁 ${esc(f.name)} <b>${count(f.id)}</b></button>`).join('')}
            <button class="folder-chip add" data-ed="folder_new">+ Nouveau dossier</button>
        </div>
        ${cur ? `<div class="folder-head"><span>📁 <b>${esc(cur.name)}</b> · ${count(cur.id)} prop(s)</span>
            <span class="btn-row" style="margin:0">
                <button class="btn" data-ed="folder_rename" data-id="${cur.id}">✏️ Renommer</button>
                <button class="btn" data-ed="folder_show" data-id="${cur.id}">👁️ Montrer en jeu</button>
                <button class="btn danger" data-ed="folder_delete" data-id="${cur.id}">Supprimer le dossier</button></span></div>` : ''}
        <div class="inline" style="margin:10px 0">
            <input class="input" id="prop-search" placeholder="Chercher un prop (modèle ou #numéro)…" value="${esc(propSearch)}">
            <button class="btn" data-ed="props_sel_all">Tout cocher</button>
        </div>
        <div id="prop-bulk">${propBulkBar()}</div>
        <div id="prop-rows">${propRows()}</div>
        </div>
        <div class="section"><h2>Objets de la map retirés (${(ed.hidden || []).length})</h2>
        <p class="hint">Pour enlever un poteau électrique, un panneau, une barrière… déjà présents dans GTA. L'objet est <b>masqué pour tout le monde</b>,
            reste retiré après les redémarrages, et peut être remis à tout moment. (Le jeu ne supprime jamais réellement ces objets :
            c'est la méthode sans risque de crash.)</p>
        <button class="btn primary" data-ed="map_pick" style="margin-bottom:12px">🎯 Choisir un objet de la map à retirer</button>
        ${edList(ed.hidden || [], (h) => `<tr><td><strong>${esc(h.label)}</strong></td><td class="muted">${distTxt(h.dist)}</td>
            <td style="text-align:right;white-space:nowrap">
                <button class="btn" data-ed="rename_hidden" data-id="${h.id}">Renommer</button>
                <button class="btn" data-ed="tp" data-kind="hidden" data-id="${h.id}">Y aller</button>
                <button class="btn danger" data-ed="unhide" data-id="${h.id}">Remettre</button></td></tr>`,
            "Aucun objet retiré pour l'instant.")}</div>`;
}
function refreshPropList() {
    const rows = $('#prop-rows'); if (rows) rows.innerHTML = propRows();
    const bulk = $('#prop-bulk'); if (bulk) bulk.innerHTML = propBulkBar();
}

/* ----- PNJ ----- */
let pedEdit = null;
const PAY_LABELS = { cash: 'Argent liquide', bank: 'Banque', item: 'Objet (argent sale…)' };

function npcSummary(n) {
    if (!n) return '<span class="muted">Décor</span>';
    const parts = [];
    if (n.buyer && n.buyer.items && n.buyer.items.length) {
        parts.push(`💰 Rachète ${n.buyer.items.map((i) => `<b>${esc(itemLabel(i.item))}</b> ${i.min === i.max ? i.min : `${i.min}-${i.max}`} $`).join(', ')}`);
    }
    if (n.shop && n.shop.items && n.shop.items.length) {
        parts.push(`🛒 Vend ${n.shop.items.map((i) => `<b>${esc(itemLabel(i.item))}</b> ${i.price} $`).join(', ')}`);
    }
    if (n.garage) {
        const g = n.garage, sp = (g.spots || []).length;
        parts.push(`🚗 Garage : <b>${g.vehicles.length}</b> véhicule(s)${g.jobs && g.jobs.length ? ` · réservé à ${g.jobs.map((j) => esc(j.job)).join(', ')}` : ''}
            · ${sp ? `${sp} point(s) de sortie` : '<b style="color:var(--danger)">aucun point de sortie</b>'}`);
    }
    if (n.pubgarage) parts.push(`🅿️ Garage public <b>${esc(n.pubgarage.name)}</b> · ${(n.pubgarage.spots || []).length ? `${n.pubgarage.spots.length} place(s) de sortie` : '<b style="color:var(--danger)">aucune place de sortie</b>'}`);
    if (n.catalog) parts.push(`🚘 Catalogue de la concession : <b>${esc(n.catalog.name)}</b> (voir les véhicules, sans achat)`);
    if (n.clothing) parts.push(`👕 Boutique <b>${esc(n.clothing.name)}</b> · prix ${n.clothing.multiplier} % · ${n.clothing.categories && n.clothing.categories.length ? `${n.clothing.categories.length} rayons` : 'tous les rayons'}`);
    if (n.hours) parts.push(`🕘 ${n.hours.from}h → ${n.hours.to}h`);
    const jl = (n.jobs && n.jobs.length ? n.jobs : (n.garage && n.garage.jobs)) || [];
    if (jl.length) parts.push(`🔑 Réservé à ${jl.map((j) => `<b>${esc(jobLabelOf(j.job))}</b>${j.grade ? ` (grade ${j.grade}+)` : ''}`).join(', ')}`);
    return parts.join('<br>');
}

function pedDraftPreset() {
    const p = D.config.editor.npcPresets.find((x) => x.id === draft('pedPreset', 'decor'));
    return p || D.config.editor.npcPresets[0];
}

function placeAccess(pr) {
    const jobs = serverJobs();
    const presetJob = pr.npc && ((pr.npc.jobs && pr.npc.jobs[0]) || (pr.npc.garage && pr.npc.garage.jobs && pr.npc.garage.jobs[0]));
    const cur = draft('pedJob', presetJob ? presetJob.job : '');
    const job = jobs.find((x) => x.name === cur);
    const curGrade = Number(draft('pedJobGrade', presetJob ? presetJob.grade : 0)) || 0;
    return `<div class="form-grid" style="grid-template-columns:2fr 1fr;margin-bottom:10px">
        <div><label>🔑 Qui peut lui parler</label>
            ${jobs.length ? `<select class="input" data-draft="pedJob" data-rerender="1">
                <option value="" ${!cur ? 'selected' : ''}>Tout le monde</option>
                ${jobs.map((x) => `<option value="${esc(x.name)}" ${x.name === cur ? 'selected' : ''}>Uniquement : ${esc(x.label)} (${esc(x.name)})</option>`).join('')}
            </select>` : `<input class="input" data-draft="pedJob" value="${esc(cur)}" placeholder="Vide = tout le monde, sinon nom du métier">`}</div>
        <div><label>Grade minimum</label>
            ${job && job.grades.length ? `<select class="input" data-draft="pedJobGrade">${job.grades.map((g) => `<option value="${g.level}" ${g.level === curGrade ? 'selected' : ''}>${g.level} · ${esc(g.label)}</option>`).join('')}</select>`
                : `<input class="input" type="number" min="0" data-draft="pedJobGrade" value="${curGrade}" ${cur ? '' : 'disabled'}>`}</div>
    </div>`;
}

function edPeds() {
    if (pedEdit) return pedEditor();
    const ed = D.editor, cfg = D.config.editor;
    const pr = pedDraftPreset();
    return `<div class="section"><h2>Placer un PNJ</h2>
        <div class="steps"><span><b>1</b>Choisis son rôle</span><span><b>2</b>Choisis son apparence</span><span><b>3</b>Place-le, puis affine avec « Modifier »</span></div>
        <div class="preset-grid">
            ${cfg.npcPresets.map((p) => `<button class="preset ${pr.id === p.id ? 'active' : ''}" data-npcpreset="${p.id}"><span class="pi">${p.icon || '🧍'}</span><span class="pl">${esc(p.label)}</span></button>`).join('')}
        </div>
        ${pr.npc ? `<p class="hint">${npcSummary(pr.npc)}</p>` : ''}
        <div class="form-grid" style="grid-template-columns:1fr 1fr 1fr">
            <div><label>Apparence (modèle)</label><input class="input" placeholder="ex : s_m_y_dealer_01" data-draft="pedModel" value="${esc(draft('pedModel'))}"></div>
            <div><label>Animation</label><select class="input" data-draft="pedScenario">
                ${cfg.scenarios.map((x) => `<option value="${x.id}" ${draft('pedScenario') === x.id ? 'selected' : ''}>${esc(x.label)}</option>`).join('')}</select></div>
            <div><label>Nom affiché (optionnel)</label><input class="input" placeholder="ex : Vendeur" data-draft="pedName" value="${esc(draft('pedName'))}"></div>
        </div>
        ${pr.npc ? placeAccess(pr) : ''}
        <div class="chips" style="margin-bottom:10px">${cfg.quickPeds.map((m) => `<button class="chip" data-pedmodel="${esc(m)}">${esc(m)}</button>`).join('')}</div>
        <button class="btn" style="margin-bottom:14px" data-opencat="peds">📚 Parcourir tous les personnages</button><br>
        <button class="btn primary big" data-ed="place_ped">Placer le PNJ</button>
        </div>
        <div class="section"><h2>PNJ enregistrés (${ed.peds.length})</h2>
        ${!ed.peds.length ? '<div class="empty">Aucun PNJ pour le moment.</div>' : ed.peds.sort(byDist).slice(0, 80).map((r) => `
            <div class="card">
                <div class="card-head"><strong>${esc(r.name || r.model)}</strong><span class="muted">${distTxt(r.dist)}</span></div>
                <div class="recipe-preview">${npcSummary(r.npc)}</div>
                <div class="btn-row">
                    <button class="btn primary" data-ed="edit_ped" data-id="${r.id}">Modifier son rôle</button>
                    <button class="btn" data-ed="move" data-kind="ped" data-id="${r.id}">Déplacer</button>
                    <button class="btn" data-ed="tp" data-kind="ped" data-id="${r.id}">Y aller</button>
                    ${has('gofast_manage') && !r.npc ? `<button class="btn" data-gf="import_ped" data-id="${r.id}" title="Il devient un contact qui donne des Go Fast">🏎️ Contact GoFast</button>` : ''}
                    <button class="btn danger" data-ed="delete" data-kind="ped" data-id="${r.id}">Supprimer</button>
                </div>
            </div>`).join('')}</div>`;
}

function toPedEdit(r) {
    const n = r.npc || {};
    const b = n.buyer || {};
    return {
        id: r.id, model: r.model, name: r.name || '', scenario: r.scenario || '',
        shopOn: !!(n.shop && n.shop.items && n.shop.items.length),
        shop: clone((n.shop && n.shop.items) || [{ item: '', price: 100 }]),
        buyerOn: !!(b.items && b.items.length),
        buyer: clone(b.items || [{ item: '', min: 50, max: 80 }]),
        maxPerSale: b.maxPerSale ?? 10, cooldown: b.cooldown ?? 60, policeChance: b.policeChance ?? 0, minPolice: b.minPolice ?? 0,
        payment: n.payment || 'cash', paymentItem: n.paymentItem || 'black_money',
        hoursOn: !!n.hours, from: n.hours ? n.hours.from : 20, to: n.hours ? n.hours.to : 5,
        ...garageEdit(n.garage),
        ...jobsEdit(n.jobs && n.jobs.length ? n.jobs : (n.garage && n.garage.jobs)),
        pubOn: !!n.pubgarage,
        pubName: n.pubgarage ? n.pubgarage.name : 'Garage public',
        pubBlip: n.pubgarage ? n.pubgarage.blip !== false : true,
        pubRadius: n.pubgarage ? (n.pubgarage.storeRadius || 4) : 4,
        catalogOn: !!n.catalog,
        catName: n.catalog ? n.catalog.name : 'Catalogue des véhicules',
        catTest: n.catalog ? !!n.catalog.test : true,
        catTestDuration: n.catalog ? (n.catalog.testDuration || 120) : 120,
        clothingOn: !!n.clothing,
        clName: n.clothing ? n.clothing.name : 'Boutique de vêtements',
        clMult: n.clothing ? n.clothing.multiplier : 100,
        clCats: clone(n.clothing && n.clothing.categories && n.clothing.categories.length ? n.clothing.categories : CLOTHING_CATS.map((c) => c.id)),
    };
}
// Catégories de la boutique de vêtements (identiques à elyzea_clothing/config.lua)
const CLOTHING_CATS = [
    { id: 'tops', label: 'Hauts' }, { id: 'undershirts', label: 'T-shirts' }, { id: 'pants', label: 'Pantalons' },
    { id: 'shoes', label: 'Chaussures' }, { id: 'bags', label: 'Sacs' }, { id: 'vests', label: 'Gilets' },
    { id: 'arms', label: 'Gants et bras' }, { id: 'chains', label: 'Colliers, cravates' }, { id: 'masks', label: 'Masques' },
    { id: 'decals', label: 'Logos' }, { id: 'hats', label: 'Chapeaux' }, { id: 'glasses', label: 'Lunettes' },
    { id: 'ears', label: 'Boucles d\'oreilles' }, { id: 'watches', label: 'Montres' }, { id: 'bracelets', label: 'Bracelets' },
];
function jobsEdit(list) {
    return { gJobsOn: !!(list && list.length), gJobs: clone(list && list.length ? list : [{ job: '', grade: 0 }]) };
}
function garageEdit(g) {
    const G = (D.config && D.config.garages) || {};
    return {
        garageOn: !!g,
        gVehicles: clone((g && g.vehicles) || [{ model: 'blista', label: 'Blista', price: 0 }]),
        gPlate: g ? g.plate : (G.platePrefix || 'GAR'),
        gOne: g ? g.onePerPlayer !== false : true,
        gWarp: g ? g.warp !== false : true,
        gFuel: g ? g.fuel : 100,
        gBlip: g ? g.blip === true : false,
        gBlipSprite: g ? g.blipSprite : (G.blipSprite || 357),
        gBlipColor: g ? g.blipColor : (G.blipColor || 3),
    };
}
function applyPresetToPedEdit(id) {
    const p = D.config.editor.npcPresets.find((x) => x.id === id);
    if (!p) return;
    const fresh = toPedEdit({ id: pedEdit.id, model: pedEdit.model, name: p.name || pedEdit.name, scenario: p.scenario || pedEdit.scenario, npc: p.npc ? clone(p.npc) : null });
    pedEdit = fresh;
}
function pedEditPayload(p) {
    const num = (v, d) => (v === '' || v === undefined || isNaN(Number(v)) ? d : Number(v));
    const npc = (p.shopOn || p.buyerOn || p.garageOn || p.clothingOn || p.catalogOn || p.pubOn) ? {
        payment: p.payment, paymentItem: String(p.paymentItem || '').trim(),
        shop: p.shopOn ? { items: p.shop.filter((i) => String(i.item).trim()).map((i) => ({ item: String(i.item).trim(), price: num(i.price, 0) })) } : null,
        buyer: p.buyerOn ? {
            items: p.buyer.filter((i) => String(i.item).trim()).map((i) => ({ item: String(i.item).trim(), min: num(i.min, 0), max: num(i.max, 0) })),
            maxPerSale: num(p.maxPerSale, 10), cooldown: num(p.cooldown, 60), policeChance: num(p.policeChance, 0), minPolice: num(p.minPolice, 0),
        } : null,
        hours: p.hoursOn ? { from: num(p.from, 0), to: num(p.to, 0) } : null,
        catalog: p.catalogOn ? { name: String(p.catName || '').trim(), test: !!p.catTest, testDuration: num(p.catTestDuration, 120) } : null,
        pubgarage: p.pubOn ? { name: String(p.pubName || '').trim(), blip: !!p.pubBlip, blipSprite: 357, blipColor: 3, storeRadius: num(p.pubRadius, 4) } : null,
        clothing: p.clothingOn ? { name: String(p.clName || '').trim(), multiplier: num(p.clMult, 100),
            categories: p.clCats.length === CLOTHING_CATS.length ? [] : p.clCats.slice() } : null,
        jobs: p.gJobsOn ? p.gJobs.filter((j) => String(j.job).trim()).map((j) => ({ job: String(j.job).trim().toLowerCase(), grade: num(j.grade, 0) })) : [],
        garage: p.garageOn ? {
            vehicles: p.gVehicles.filter((v) => String(v.model).trim()).map((v) => ({ model: String(v.model).trim().toLowerCase(), label: String(v.label || '').trim(), price: num(v.price, 0) })),
            plate: String(p.gPlate || '').trim(), onePerPlayer: !!p.gOne, warp: !!p.gWarp, fuel: num(p.gFuel, 100),
            blip: !!p.gBlip, blipSprite: num(p.gBlipSprite, 357), blipColor: num(p.gBlipColor, 3),
        } : null,
    } : false;
    return { id: p.id, name: p.name, scenario: p.scenario, npc };
}

// Menus déroulants des métiers : la liste vient du serveur (tous les métiers créés, mise à jour toute seule)
const serverJobs = () => (D && D.jobs) || [];
const jobLabelOf = (name) => (serverJobs().find((x) => x.name === name) || {}).label || name;
function jobSelect(i, j) {
    const jobs = serverJobs();
    const known = jobs.find((x) => x.name === j.job);
    if (!jobs.length) return `<input class="input" data-pgj="${i}:job" value="${esc(j.job)}" placeholder="ex : police">`;
    return `<select class="input" data-pgj="${i}:job">
        <option value="" ${!j.job ? 'selected' : ''}>— Choisir un métier —</option>
        ${jobs.map((x) => `<option value="${esc(x.name)}" ${x.name === j.job ? 'selected' : ''}>${esc(x.label)} (${esc(x.name)})</option>`).join('')}
        ${j.job && !known ? `<option value="${esc(j.job)}" selected>${esc(j.job)} (introuvable sur le serveur)</option>` : ''}
    </select>`;
}
function gradeSelect(i, j) {
    const job = serverJobs().find((x) => x.name === j.job);
    if (!job || !job.grades.length) return `<input class="input" type="number" min="0" data-pgj="${i}:grade" value="${esc(j.grade)}">`;
    const cur = Number(j.grade) || 0;
    return `<select class="input" data-pgj="${i}:grade">
        ${job.grades.map((g) => `<option value="${g.level}" ${g.level === cur ? 'selected' : ''}>${g.level} · ${esc(g.label)}${g.level === job.grades[0].level ? ' (tous)' : ' et plus'}</option>`).join('')}
    </select>`;
}

// « Qui peut lui parler » : réservé à un ou plusieurs métiers (avec grade minimum)
function clothingCard(p) {
    const all = p.clCats.length === CLOTHING_CATS.length;
    return `<div class="card recipe"><h3 class="sub-h" style="font-size:17px">👕 Boutique de vêtements</h3>
        <p class="hint">Quand un joueur parle à ce PNJ, la boutique s'ouvre : catégories, essayage en direct, panier, paiement en liquide ou par banque.
            Nécessite la ressource <b>elyzea_clothing</b>.${p.shopOn || p.buyerOn || p.garageOn ? ' Avec ce rôle, parler au PNJ ouvre la boutique : ses autres rôles ne sont plus proposés.' : ''}</p>
        <div class="form-grid" style="grid-template-columns:2fr 1fr;margin-bottom:12px">
            <div><label>Nom de la boutique</label><input class="input" data-pe="clName" value="${esc(p.clName)}" placeholder="ex : Ponsonbys"></div>
            <div><label>Prix (% des prix de base)</label><input class="input" type="number" min="0" max="1000" data-pe="clMult" value="${esc(p.clMult)}"></div>
        </div>
        <label>Rayons vendus ${all ? '<span class="muted">(tous)</span>' : `<span class="muted">(${p.clCats.length} sur ${CLOTHING_CATS.length})</span>`}</label>
        <div class="chips" style="margin-top:6px">${CLOTHING_CATS.map((c) => `<button class="chip ${p.clCats.includes(c.id) ? 'active' : ''}" data-ed="cl_cat" data-cat="${c.id}" style="${p.clCats.includes(c.id) ? 'border-color:var(--signal);color:var(--gold-hi);background:rgba(217,181,106,.12)' : 'opacity:.55'}">${p.clCats.includes(c.id) ? '✓ ' : ''}${esc(c.label)}</button>`).join('')}</div>
        <div class="btn-row" style="margin-top:8px"><button class="btn" data-ed="cl_all">Tout cocher</button><button class="btn" data-ed="cl_none">Tout décocher</button></div>
    </div>`;
}

function accessSection(p) {
    const n = serverJobs().length;
    return `<div class="section"><h2>🔑 Qui peut lui parler</h2>
        <p class="hint">Réserve ce PNJ à certains métiers : les autres joueurs ne voient même pas « Parler à… ». Vaut pour tout ce qu'il fait (achat, vente, garage).</p>
        <div class="grid" style="grid-template-columns:1fr 1fr;margin-bottom:10px">
            <div class="tile toggle-tile ${!p.gJobsOn ? 'on' : ''}" data-ed="gjobs_off"><div><strong>Tout le monde</strong><span>Aucune restriction</span></div><div class="switch"></div></div>
            <div class="tile toggle-tile ${p.gJobsOn ? 'on' : ''}" data-ed="gjobs_on"><div><strong>Certains métiers uniquement</strong><span>Avec un grade minimum</span></div><div class="switch"></div></div>
        </div>
        ${p.gJobsOn ? `<p class="hint">${n ? `${n} métiers sur le serveur : tout nouveau métier apparaît automatiquement dans la liste.` : 'Liste des métiers indisponible : tape le nom de code du métier.'}</p>
            <table class="loot"><tr><th style="width:55%">Métier</th><th style="width:38%">Grade minimum</th><th></th></tr>
            ${p.gJobs.map((j, i) => `<tr><td>${jobSelect(i, j)}</td><td>${gradeSelect(i, j)}</td>
                <td><button class="sb-close" data-ed="pgj_del" data-i="${i}">✕</button></td></tr>`).join('')}
            </table><button class="btn" style="margin-top:8px" data-ed="pgj_add">+ Autre métier</button>` : ''}
    </div>`;
}

// Garage public Elyzea (ressource elyzea_garage)
function pubGarageCard(p, tog) {
    const live = (D.editor.peds.find((x) => x.id === p.id) || {}).npc;
    const saved = !!(live && live.pubgarage);
    const spots = (saved && live.pubgarage.spots) || [];
    const stores = (saved && live.pubgarage.stores) || [];
    return `<div class="card recipe"><h3 class="sub-h" style="font-size:17px">🅿️ Elyzea Public Garage</h3>
        <p class="hint">En parlant à ce PNJ, les joueurs ouvrent le garage public : ils voient leurs véhicules et leur état, les sortent et les rangent.
            <b>Tous les garages publics sont connectés</b> : un véhicule rangé ici ressort de n'importe quel autre. Il ressort exactement dans
            l'état où il a été rangé (dégâts, pneus, vitres, déformations, essence). Nécessite la ressource <b>elyzea_garage</b>.
            ${p.shopOn || p.buyerOn || p.garageOn || p.clothingOn || p.catalogOn ? ' Avec ce rôle, parler au PNJ ouvre le garage : ses autres rôles ne sont plus proposés.' : ''}</p>
        <div class="form-grid" style="grid-template-columns:1fr;margin-bottom:10px"><div><label>Nom du garage</label><input class="input" data-pe="pubName" value="${esc(p.pubName)}" placeholder="ex : Garage public de Pillbox"></div></div>
        ${tog('pubBlip', '🗺️ Visible sur la carte', 'Icône de garage pour tous les joueurs')}
        <h3 class="sub-h" style="font-size:16px;margin-top:14px">📍 Places de sortie</h3>
        ${!saved ? '<div class="protect">💾 <span>Enregistre d\'abord le PNJ avec ce rôle, puis reviens ici pour placer les places de sortie.</span></div>' : `
        <p class="hint">Un véhicule « fantôme » apparaît : vise la place, molette pour l'orienter, <span class="keycap">E</span> pour valider.
            Pose-en plusieurs à la suite : le véhicule sort sur la première place libre.</p>
        ${spots.length ? `<table>${spots.map((s, i) => `<tr><td><strong>Place ${i + 1}</strong></td>
            <td class="muted">${s.x.toFixed(1)}, ${s.y.toFixed(1)}, ${s.z.toFixed(1)} · orientée ${Math.round(s.h)}°</td>
            <td style="text-align:right;white-space:nowrap">
                <button class="btn" data-ed="pubgarage_spot_tp" data-i="${i + 1}">Y aller</button>
                <button class="btn" data-ed="pubgarage_spot_move" data-i="${i + 1}" data-h="${s.h}">Déplacer</button>
                <button class="btn danger" data-ed="pubgarage_spot_del" data-i="${i + 1}">Supprimer</button></td></tr>`).join('')}</table>`
            : '<div class="empty">Aucune place de sortie : les joueurs ne pourront rien sortir ici.</div>'}
        <button class="btn primary" style="margin-top:10px" data-ed="pubgarage_spot">📍 Placer ${spots.length ? 'd\'autres places' : 'les places'} de sortie</button>`}

        <h3 class="sub-h" style="font-size:16px;margin-top:18px">🔴 Zones de rangement</h3>
        <p class="hint">Un <b>cercle rouge</b> apparaît au sol : le joueur y entre au volant de son véhicule et appuie sur <span class="keycap">E</span>
            pour le ranger directement, sans parler au gardien. Le rayon s'enregistre avec le PNJ (bouton Enregistrer).</p>
        <div class="form-grid" style="grid-template-columns:1fr;max-width:360px;margin-bottom:10px"><div><label>Rayon du cercle (mètres, 1,5 à 15)</label>
            <input class="input" type="number" min="1.5" max="15" step="0.5" data-pe="pubRadius" value="${esc(p.pubRadius)}"></div></div>
        ${!saved ? '<div class="protect">💾 <span>Enregistre d\'abord le PNJ avec ce rôle pour placer les zones de rangement.</span></div>' : `
        ${stores.length ? `<table>${stores.map((s, i) => `<tr><td><strong>Zone ${i + 1}</strong></td>
            <td class="muted">${s.x.toFixed(1)}, ${s.y.toFixed(1)}, ${s.z.toFixed(1)}</td>
            <td style="text-align:right;white-space:nowrap">
                <button class="btn" data-ed="pubgarage_store_tp" data-i="${i + 1}">Y aller</button>
                <button class="btn" data-ed="pubgarage_store_move" data-i="${i + 1}" data-h="${s.h}">Déplacer</button>
                <button class="btn danger" data-ed="pubgarage_store_del" data-i="${i + 1}">Supprimer</button></td></tr>`).join('')}</table>`
            : '<div class="empty">Aucune zone : les joueurs rangent en reparlant au gardien.</div>'}
        <button class="btn primary" style="margin-top:10px" data-ed="pubgarage_store">🔴 Placer ${stores.length ? 'une autre zone' : 'une zone'} de rangement</button>`}
    </div>`;
}

// Point de départ des essais (PNJ « Catalogue concession »)
function catalogSpotCard(p) {
    const live = (D.editor.peds.find((x) => x.id === p.id) || {}).npc;
    const saved = !!(live && live.catalog);
    const sp = saved && live.catalog.testSpot;
    if (!saved) return '<div class="protect" style="margin-top:10px">💾 <span>Enregistre d\'abord le PNJ avec ce rôle, puis reviens ici pour placer le point de départ des essais.</span></div>';
    return `<div style="margin-top:10px">
        <p class="hint">Le joueur appuie sur « Essai » dans le catalogue : le véhicule apparaît ici, il est mis au volant, et à la fin du temps
            il revient à côté du PNJ. Un véhicule « fantôme » apparaît : vise l'endroit, molette pour l'orienter, <span class="keycap">E</span> pour valider.</p>
        ${sp ? `<p class="muted" style="margin-bottom:8px">📍 ${sp.x.toFixed(1)}, ${sp.y.toFixed(1)}, ${sp.z.toFixed(1)} · orienté ${Math.round(sp.h)}°</p>`
            : '<div class="empty" style="margin-bottom:8px">Aucun point de départ : le bouton « Essai » ne s\'affichera pas.</div>'}
        <div class="btn-row"><button class="btn primary" data-ed="catalog_spot" ${sp ? `data-h="${sp.h}"` : ''}>📍 ${sp ? 'Déplacer' : 'Placer'} le point d'essai</button>
            ${sp ? '<button class="btn" data-ed="catalog_spot_tp">Y aller</button>' : ''}</div>
    </div>`;
}

function garageCard(p, tog, inp) {
    const live = (D.editor.peds.find((x) => x.id === p.id) || {}).npc;
    const spots = (live && live.garage && live.garage.spots) || [];
    const saved = !!(live && live.garage);
    const firstModel = (p.gVehicles.find((v) => String(v.model).trim()) || {}).model || 'blista';
    return `<div class="card recipe"><h3 class="sub-h" style="font-size:17px">🚗 Véhicules du garage</h3>
        <p class="hint">Nom de code du véhicule (ex. <span class="keycap">police</span>, <span class="keycap">sultan</span>), nom affiché au joueur, et prix (0 = gratuit, payé avec la monnaie choisie plus bas).</p>
        <table class="loot"><tr><th style="width:32%">Modèle</th><th style="width:44%">Nom affiché</th><th style="width:18%">Prix</th><th></th></tr>
        ${p.gVehicles.map((v, i) => `<tr>
            <td><input class="input" data-pgv="${i}:model" value="${esc(v.model)}" placeholder="ex : blista"></td>
            <td><input class="input" data-pgv="${i}:label" value="${esc(v.label)}" placeholder="ex : Blista compacte"></td>
            <td><input class="input" type="number" min="0" data-pgv="${i}:price" value="${esc(v.price)}"></td>
            <td><button class="sb-close" data-ed="pgv_del" data-i="${i}">✕</button></td></tr>`).join('')}
        </table>
        <button class="btn" style="margin:8px 0 16px" data-ed="pgv_add">+ Véhicule</button>

        <h3 class="sub-h" style="font-size:17px">📍 Où les véhicules sortent</h3>
        ${!saved ? '<div class="protect">💾 <span>Enregistre d\'abord le PNJ avec le rôle Garage, puis reviens ici pour placer les points de sortie.</span></div>' : `
        <p class="hint">Un véhicule « fantôme » apparaît : vise l'endroit, molette pour l'orienter, <span class="keycap">E</span> pour valider.
            Tu peux en poser plusieurs à la suite (le joueur prend le premier libre), puis Retour pour terminer. Chaque point est enregistré tout de suite.</p>
        ${spots.length ? `<table>${spots.map((s, i) => `<tr><td><strong>Point ${i + 1}</strong></td>
            <td class="muted">${s.x.toFixed(1)}, ${s.y.toFixed(1)}, ${s.z.toFixed(1)} · orienté ${Math.round(s.h)}°</td>
            <td style="text-align:right;white-space:nowrap">
                <button class="btn" data-ed="garage_spot_tp" data-i="${i + 1}">Y aller</button>
                <button class="btn" data-ed="garage_spot_move" data-i="${i + 1}" data-model="${esc(firstModel)}" data-h="${s.h}">Déplacer</button>
                <button class="btn danger" data-ed="garage_spot_del" data-i="${i + 1}">Supprimer</button></td></tr>`).join('')}</table>`
            : '<div class="empty">Aucun point de sortie : les joueurs ne pourront rien sortir.</div>'}
        <button class="btn primary" style="margin:10px 0 16px" data-ed="garage_spot" data-model="${esc(firstModel)}">📍 Placer ${spots.length ? 'd\'autres points' : 'les points'} de sortie</button>`}

        <p class="hint">🔑 Qui peut l'utiliser : section « Qui peut lui parler » plus bas (elle s'applique à tous les rôles du PNJ).</p>

        <h3 class="sub-h" style="font-size:17px">⚙️ Options</h3>
        <div class="grid" style="grid-template-columns:1fr 1fr 1fr;margin-bottom:12px">
            ${tog('gOne', 'Un véhicule à la fois', 'Il doit ranger le sien avant d\'en sortir un autre')}
            ${tog('gWarp', 'Monter dedans', 'Le joueur est placé au volant')}
            ${tog('gBlip', 'Visible sur la carte', 'Icône du garage sur la carte')}
        </div>
        <div class="form-grid" style="grid-template-columns:1fr 1fr 1fr 1fr;margin-bottom:0">
            ${inp('gPlate', 'Début de la plaque (4 max)')}
            ${inp('gFuel', 'Carburant à la sortie (%)', 'number', 'min="0" max="100"')}
            ${p.gBlip ? inp('gBlipSprite', 'Icône (n° de blip)', 'number') : '<div></div>'}
            ${p.gBlip ? inp('gBlipColor', 'Couleur (n°)', 'number') : '<div></div>'}
        </div>
        <p class="hint muted" style="margin-top:10px">Ranger : le joueur revient au volant près du PNJ ou d'un point de sortie et appuie sur <span class="keycap">E</span>, ou utilise le bouton « Ranger » dans le menu du PNJ.</p>
    </div>`;
}

function pedEditor() {
    const p = pedEdit, cfg = D.config.editor;
    const hourOpts = (v) => Array.from({ length: 24 }, (_, h) => `<option value="${h}" ${Number(v) === h ? 'selected' : ''}>${h}h</option>`).join('');
    const tog = (key, label, sub) => `<div class="tile toggle-tile ${p[key] ? 'on' : ''}" data-petoggle="${key}"><div><strong>${label}</strong><span>${sub}</span></div><div class="switch"></div></div>`;
    const inp = (k, label, type = 'text', extra = '') => `<div><label>${label}</label><input class="input" type="${type}" data-pe="${k}" value="${esc(p[k] ?? '')}" ${extra}></div>`;

    return `<div class="btn-row" style="margin-bottom:16px">
            <button class="btn" data-ed="ped_back">← Retour aux PNJ</button>
            <button class="btn primary" data-ed="ped_save">Enregistrer</button></div>
        <h2 class="sub-h">${esc(p.name || p.model)} <span class="muted" style="font-size:14px">#${p.id}</span></h2>

        <div class="section"><h2>Partir d'un rôle tout prêt</h2>
            <p class="hint">Remplace les réglages ci-dessous par ceux du rôle choisi. Tu peux ensuite tout ajuster.</p>
            <div class="preset-grid">${cfg.npcPresets.map((x) => `<button class="preset" data-pepreset="${x.id}"><span class="pi">${x.icon || '🧍'}</span><span class="pl">${esc(x.label)}</span></button>`).join('')}</div>
        </div>

        <div class="section"><h2>Identité</h2>
            <div class="form-grid" style="grid-template-columns:1fr 1fr">
                ${inp('name', 'Nom affiché au-dessus de lui')}
                <div><label>Animation</label><select class="input" data-pe="scenario">
                    ${cfg.scenarios.map((x) => `<option value="${x.id}" ${p.scenario === x.id ? 'selected' : ''}>${esc(x.label)}</option>`).join('')}</select></div>
            </div>
        </div>

        <div class="section"><h2>Ce qu'il fait</h2>
            <div class="grid" style="grid-template-columns:1fr 1fr;margin-bottom:14px">
                ${tog('buyerOn', '💰 Il rachète', 'Les joueurs lui vendent (drogue…)')}
                ${tog('shopOn', '🛒 Il vend', 'Les joueurs lui achètent des objets')}
                ${tog('garageOn', '🚗 Garage', 'Il sort des véhicules aux joueurs')}
                ${tog('clothingOn', '👕 Boutique de vêtements', 'Parler à lui ouvre la boutique')}
                ${tog('catalogOn', '🚘 Catalogue concession', 'Montre les véhicules en vente (sans achat)')}
                ${tog('pubOn', '🅿️ Garage public', 'Les joueurs sortent et rangent leurs véhicules')}
            </div>
            ${p.pubOn ? pubGarageCard(p, tog) : ''}
            ${p.catalogOn ? `<div class="card recipe"><h3 class="sub-h" style="font-size:17px">🚘 Catalogue de la concession</h3>
                <p class="hint">Quand un joueur parle à ce PNJ, le catalogue de la concession s'ouvre : catégories, recherche, fiches avec
                    caractéristiques. Il peut seulement <b>regarder</b> : l'achat se fait avec un vendeur. Les véhicules masqués n'apparaissent pas.
                    Nécessite la ressource <b>elyzea_concess</b>.${p.shopOn || p.buyerOn || p.garageOn || p.clothingOn ? ' Avec ce rôle, parler au PNJ ouvre le catalogue : ses autres rôles ne sont plus proposés.' : ''}</p>
                <div class="form-grid" style="grid-template-columns:2fr 1fr;margin-bottom:12px"><div><label>Titre affiché</label><input class="input" data-pe="catName" value="${esc(p.catName)}" placeholder="ex : Catalogue Premium Deluxe"></div>
                    <div><label>Durée de l'essai (secondes)</label><input class="input" type="number" min="30" max="1800" data-pe="catTestDuration" value="${esc(p.catTestDuration)}"></div></div>
                ${tog('catTest', '🏁 Essai routier', 'Bouton « Essai » sur chaque véhicule du catalogue')}
                ${p.catTest ? catalogSpotCard(p) : ''}
            </div>` : ''}
            ${p.clothingOn ? clothingCard(p) : ''}
            ${p.garageOn ? garageCard(p, tog, inp) : ''}

            ${p.buyerOn ? `<div class="card recipe"><h3 class="sub-h" style="font-size:17px">Ce qu'il rachète</h3>
                <table class="loot"><tr><th>Objet</th><th>Prix min / unité</th><th>Prix max / unité</th><th></th></tr>
                ${p.buyer.map((it, i) => `<tr>
                    <td><input class="input" list="known-items" data-peb="${i}:item" value="${esc(it.item)}" placeholder="ex : cocaine"></td>
                    <td><input class="input" type="number" min="0" data-peb="${i}:min" value="${esc(it.min)}"></td>
                    <td><input class="input" type="number" min="0" data-peb="${i}:max" value="${esc(it.max)}"></td>
                    <td><button class="sb-close" data-ed="peb_del" data-i="${i}">✕</button></td></tr>`).join('')}
                </table>
                <button class="btn" style="margin:8px 0 14px" data-ed="peb_add">+ Objet racheté</button>
                <div class="form-grid" style="grid-template-columns:1fr 1fr 1fr 1fr;margin-bottom:0">
                    ${inp('maxPerSale', 'Quantité max par vente', 'number')}
                    ${inp('cooldown', 'Attente entre 2 ventes (s)', 'number')}
                    ${inp('policeChance', 'Risque d\'alerter la police (%)', 'number')}
                    ${inp('minPolice', 'Policiers en ligne requis', 'number')}
                </div>
            </div>` : ''}

            ${p.shopOn ? `<div class="card recipe"><h3 class="sub-h" style="font-size:17px">Ce qu'il vend</h3>
                <table class="loot"><tr><th>Objet</th><th>Prix / unité</th><th></th></tr>
                ${p.shop.map((it, i) => `<tr>
                    <td><input class="input" list="known-items" data-pes="${i}:item" value="${esc(it.item)}" placeholder="ex : lockpick"></td>
                    <td><input class="input" type="number" min="0" data-pes="${i}:price" value="${esc(it.price)}"></td>
                    <td><button class="sb-close" data-ed="pes_del" data-i="${i}">✕</button></td></tr>`).join('')}
                </table>
                <button class="btn" style="margin-top:8px" data-ed="pes_add">+ Objet vendu</button>
            </div>` : ''}
        </div>

        ${(p.buyerOn || p.shopOn || p.garageOn || p.clothingOn) ? accessSection(p) : ''}
        ${(p.buyerOn || p.shopOn || p.garageOn || p.clothingOn) ? `<div class="section"><h2>Argent et horaires</h2>
            <div class="form-grid" style="grid-template-columns:1fr 1fr 1fr 1fr">
                <div><label>Monnaie utilisée</label><select class="input" data-pe="payment">
                    ${Object.entries(PAY_LABELS).map(([k, l]) => `<option value="${k}" ${p.payment === k ? 'selected' : ''}>${l}</option>`).join('')}</select></div>
                ${p.payment === 'item' ? inp('paymentItem', "Nom de l'objet monnaie", 'text', 'list="known-items"') : '<div></div>'}
                <div><label>Présence</label><select class="input" data-pe="hoursOn">
                    <option value="false" ${!p.hoursOn ? 'selected' : ''}>Toujours là</option>
                    <option value="true" ${p.hoursOn ? 'selected' : ''}>Seulement à certaines heures</option></select></div>
                ${p.hoursOn ? `<div><label>De … à … (heure du jeu)</label><div class="inline">
                    <select class="input" data-pe="from">${hourOpts(p.from)}</select><span class="muted">→</span>
                    <select class="input" data-pe="to">${hourOpts(p.to)}</select></div></div>` : '<div></div>'}
            </div>
        </div>` : '<p class="hint">Sans rôle, ce PNJ reste un simple élément de décor.</p>'}
        ${itemDatalist()}`;
}

const FIELD_INPUTS = [
    ['name', 'Nom de la zone', 'text'], ['model', 'Modèle du plant', 'text'],
    ['item', "Objet donné (nom dans l'inventaire)", 'text'], ['itemLabel', "Nom affiché de l'objet", 'text'],
    ['min', 'Quantité minimum', 'number'], ['max', 'Quantité maximum', 'number'],
    ['duration', 'Durée de récolte (s)', 'number'], ['regrow', 'Temps de repousse (s)', 'number'],
];

function applyFieldPreset(id) {
    const p = D.config.editor.presets.find((x) => x.id === id);
    const keep = drafts.field || { radius: 8, count: 15, blip: 'false' };
    drafts.field = p
        ? { ...keep, preset: p.id, name: p.label, model: p.model, item: p.item, itemLabel: p.itemLabel, min: p.min, max: p.max, duration: p.duration, regrow: p.regrow, blipSprite: p.blipSprite || 1 }
        : { ...keep, preset: 'custom', name: 'Ma zone', model: '', item: '', itemLabel: '', min: 1, max: 1, duration: 5, regrow: 300, blipSprite: 1 };
}
function fieldDraft() {
    if (!drafts.field) applyFieldPreset(D.config.editor.presets[0].id);
    return drafts.field;
}
const fmtTime = (s) => (s >= 3600 ? `${Math.round(s / 360) / 10} h` : s >= 60 ? `${Math.round(s / 6) / 10} min` : `${s} s`);

function edHarvest() {
    const ed = D.editor, f = fieldDraft(), presets = D.config.editor.presets;
    const input = ([k, label, type]) => `<div><label>${label}</label>
        <input class="input" type="${type}" data-field="${k}" value="${esc(f[k])}" ${k === 'item' ? 'list="known-items"' : ''}></div>`;
    return `<div class="section"><h2>Créer une zone de récolte</h2>
        <div class="steps"><span><b>1</b>Choisis ce qui pousse</span><span><b>2</b>Règle la récolte</span><span><b>3</b>Va sur place et crée la zone</span></div>
        <div class="preset-grid">
            ${presets.map((p) => `<button class="preset ${f.preset === p.id ? 'active' : ''}" data-fpreset="${p.id}"><span class="pi">${p.icon || '🌿'}</span><span class="pl">${esc(p.label)}</span></button>`).join('')}
            <button class="preset ${f.preset === 'custom' ? 'active' : ''}" data-fpreset="custom"><span class="pi">✏️</span><span class="pl">Personnalisé</span></button>
        </div>
        <div class="form-grid" style="grid-template-columns:1.4fr 1fr 1fr 1fr 1fr">
            ${input(['name', 'Nom de la zone', 'text'])}
            ${input(['min', 'Quantité min par plant', 'number'])}${input(['max', 'Quantité max par plant', 'number'])}
            ${input(['count', 'Nombre de plants', 'number'])}${input(['radius', 'Rayon de la zone (m)', 'number'])}
        </div>
        <details class="adv"${f.preset === 'custom' ? ' open' : ''}><summary>Réglages avancés : objet donné, modèle 3D, durées, carte</summary>
            <div class="form-grid" style="grid-template-columns:1fr 1fr 1fr 1fr">
                ${input(['item', "Objet donné (nom d'inventaire)", 'text'])}${input(['itemLabel', "Nom affiché de l'objet", 'text'])}
                ${input(['model', 'Modèle 3D du plant', 'text'])}${input(['duration', 'Durée de récolte (s)', 'number'])}
                ${input(['regrow', 'Temps de repousse (s)', 'number'])}
                <div><label>Visible sur la carte</label>
                    <select class="input" data-field="blip"><option value="false" ${f.blip !== 'true' ? 'selected' : ''}>Non, zone secrète</option>
                    <option value="true" ${f.blip === 'true' ? 'selected' : ''}>Oui</option></select></div>
                ${input(['blipSprite', 'Icône de carte (n°)', 'number'])}
            </div>
        </details>
        <p class="hint">Chaque plant donne <b>${f.min === f.max ? f.min : `${f.min} à ${f.max}`} ${esc(f.itemLabel || f.item)}</b>,
            se récolte en ${esc(f.duration)} s et repousse en ${fmtTime(Number(f.regrow) || 0)}. Les plants sont posés autour de toi.</p>
        <button class="btn primary big" data-ed="create_field">Créer la zone ici</button>${itemDatalist()}
        </div>
        <div class="section"><h2>Zones enregistrées (${ed.fields.length})</h2>
        ${!ed.fields.length ? '<div class="empty">Aucune zone de récolte pour le moment.</div>' : ed.fields.sort(byDist).map((z) => `
            <div class="card">
                <div class="card-head"><strong>${esc(z.name)}</strong><span class="muted">${distTxt(z.dist)}</span></div>
                <div class="field-stats">
                    <span><b>${z.min === z.max ? z.min : `${z.min} à ${z.max}`}</b> ${esc(z.itemLabel)} par plant</span>
                    <span><b>${z.plants}</b> plants${z.down ? ` (${z.down} en repousse)` : ''}</span>
                    <span>Récolte <b>${z.duration} s</b></span>
                    <span>Repousse <b>${fmtTime(z.regrow)}</b></span>
                    <span>${z.blip ? '📍 Sur la carte' : '🔒 Secrète'}</span>
                </div>
                <div class="btn-row">
                    <button class="btn primary" data-ed="edit_field" data-id="${z.id}">Modifier les réglages</button>
                    <button class="btn" data-ed="add_plants" data-id="${z.id}">Ajouter des plants</button>
                    <button class="btn" data-ed="tp" data-kind="field" data-id="${z.id}">Y aller</button>
                    <button class="btn danger" data-ed="delete" data-kind="field" data-id="${z.id}">Supprimer</button>
                </div>
            </div>`).join('')}</div>`;
}

/* ----- Ateliers ----- */
let stationEdit = null;
const clone = (o) => JSON.parse(JSON.stringify(o));

function applyStationPreset(id) {
    const p = D.config.editor.craftPresets.find((x) => x.id === id);
    drafts.station = p
        ? { preset: p.id, name: p.label, model: p.model, scenario: p.scenario, blip: 'false', blipSprite: p.blipSprite || 1, recipes: clone(p.recipes) }
        : { preset: 'custom', name: 'Mon atelier', model: 'prop_tool_bench02', scenario: 'PROP_HUMAN_PARKING_METER', blip: 'false', blipSprite: 1, recipes: [] };
}
function stationNewDraft() {
    if (!drafts.station) applyStationPreset(D.config.editor.craftPresets[0].id);
    return drafts.station;
}

// Noms d'objets connus (pour l'autocomplétion)
function knownItems() {
    const set = new Set();
    D.config.editor.presets.forEach((p) => set.add(p.item));
    D.config.editor.craftPresets.forEach((p) => p.recipes.forEach((r) => { set.add(r.output); r.inputs.forEach((i) => set.add(i.item)); }));
    (D.editor.stations || []).forEach((st) => (st.recipes || []).forEach((r) => { set.add(r.output); (r.inputs || []).forEach((i) => set.add(i.item)); }));
    (D.editor.fields || []).forEach((f) => set.add(f.item));
    (D.config.editor.npcPresets || []).forEach((p) => { const n = p.npc || {}; ((n.shop && n.shop.items) || []).concat((n.buyer && n.buyer.items) || []).forEach((i) => set.add(i.item)); });
    (D.config.editor.searchPresets || []).forEach((p) => { if (p.requiredItem) set.add(p.requiredItem); p.loot.forEach((l) => set.add(l.item)); });
    (D.editor.searches || []).forEach((z) => { if (z.requiredItem) set.add(z.requiredItem); (z.loot || []).forEach((l) => set.add(l.item)); });
    return [...set].filter(Boolean).sort();
}
const itemDatalist = () => `<datalist id="known-items">${knownItems().map((i) => `<option value="${esc(i)}">`).join('')}</datalist>`;

const ITEM_NAMES = {
    metal_scrap: 'Ferraille', gun_parts_light: "Pièces d'armes légères", gun_parts_medium: "Pièces d'armes moyennes",
    gun_parts_heavy: "Pièces d'armes lourdes", lockpick: 'Crochet', crowbar: 'Pied-de-biche',
    weed_pouch: 'Pochon de weed', cocaine: 'Cocaïne', meth: 'Méthamphétamine', dried_mushroom: 'Champignons séchés',
    water: 'Eau', burger: 'Burger', black_money: 'Argent sale',
};
// Nom lisible d'un objet (d'après les préréglages et les zones existantes)
function itemLabel(item) {
    const e = D.config.editor;
    const p = e.presets.find((x) => x.item === item) || (D.editor.fields || []).find((x) => x.item === item);
    if (p && p.itemLabel) return p.itemLabel;
    for (const c of e.craftPresets) { const r = c.recipes.find((x) => x.output === item); if (r) return r.label; }
    return ITEM_NAMES[item] || item;
}
const recipeSummary = (r) => `${r.inputs.map((i) => `${i.count} ${esc(itemLabel(i.item))}`).join(' + ') || 'rien'} → <b>${r.count} ${esc(r.label)}</b> <span class="muted">(${r.duration} s)</span>`;

function edCrafting() {
    if (stationEdit) return stationEditor();
    const ed = D.editor, n = stationNewDraft(), cfg = D.config.editor;
    return `<div class="section"><h2>Créer un atelier</h2>
        <div class="steps"><span><b>1</b>Choisis le type d'atelier</span><span><b>2</b>Place-le dans la map</span><span><b>3</b>Ajuste les recettes si besoin</span></div>
        <div class="preset-grid">
            ${cfg.craftPresets.map((p) => `<button class="preset ${n.preset === p.id ? 'active' : ''}" data-spreset="${p.id}"><span class="pi">${p.icon || '🛠️'}</span><span class="pl">${esc(p.label)}</span></button>`).join('')}
            <button class="preset ${n.preset === 'custom' ? 'active' : ''}" data-spreset="custom"><span class="pi">✏️</span><span class="pl">Atelier vide</span></button>
        </div>
        <div class="form-grid" style="grid-template-columns:1.4fr 1fr">
            <div><label>Nom de l'atelier</label><input class="input" data-sn="name" value="${esc(n.name)}"></div>
            <div><label>Meuble (modèle 3D)</label><input class="input" data-sn="model" value="${esc(n.model)}"></div>
        </div>
        <p class="hint">Recettes incluses :</p>
        <div class="recipe-preview">${n.recipes.length ? n.recipes.map((r) => `<div>${recipeSummary(r)}</div>`).join('') : '<span class="muted">Aucune : tu les ajouteras après la création.</span>'}</div>
        <button class="btn primary big" data-ed="place_station">Placer l'atelier</button>
        </div>
        <div class="section"><h2>Ateliers enregistrés (${ed.stations.length})</h2>
        ${!ed.stations.length ? '<div class="empty">Aucun atelier.</div>' : ed.stations.sort(byDist).map((st) => `
            <div class="card">
                <div class="card-head"><strong>${esc(st.name)}</strong><span class="muted">${distTxt(st.dist)}${st.blip ? ' · 📍 sur la carte' : ' · 🔒 secret'}</span></div>
                <div class="recipe-preview">${st.recipes.length ? st.recipes.map((r) => `<div>${recipeSummary(r)}</div>`).join('') : '<span class="muted">Aucune recette.</span>'}</div>
                <div class="btn-row">
                    <button class="btn primary" data-ed="edit_station" data-id="${st.id}">Gérer les recettes</button>
                    <button class="btn" data-ed="move" data-kind="station" data-id="${st.id}">Déplacer</button>
                    <button class="btn" data-ed="tp" data-kind="station" data-id="${st.id}">Y aller</button>
                    <button class="btn danger" data-ed="delete" data-kind="station" data-id="${st.id}">Supprimer</button>
                </div>
            </div>`).join('')}</div>`;
}

function stationEditor() {
    const st = stationEdit, cfg = D.config.editor;
    return `<div class="btn-row" style="margin-bottom:16px">
            <button class="btn" data-ed="station_back">← Retour aux ateliers</button>
            <button class="btn primary" data-ed="station_save">Enregistrer l'atelier</button>
        </div>
        <div class="form-grid" style="grid-template-columns:1.3fr 1fr 1fr .8fr .7fr">
            <div><label class="muted">Nom</label><input class="input" data-st="name" value="${esc(st.name)}"></div>
            <div><label class="muted">Modèle du meuble</label><input class="input" data-st="model" value="${esc(st.model)}"></div>
            <div><label class="muted">Animation</label><select class="input" data-st="scenario">
                ${cfg.craftScenarios.map((x) => `<option value="${x.id}" ${st.scenario === x.id ? 'selected' : ''}>${esc(x.label)}</option>`).join('')}</select></div>
            <div><label class="muted">Sur la carte</label><select class="input" data-st="blip">
                <option value="false" ${!st.blip ? 'selected' : ''}>Non</option><option value="true" ${st.blip ? 'selected' : ''}>Oui</option></select></div>
            <div><label class="muted">Icône n°</label><input class="input" type="number" data-st="blipSprite" value="${esc(st.blipSprite || 1)}"></div>
        </div>
        <h2 class="sub-h">Recettes (${st.recipes.length})</h2>
        <p class="hint">Pour une arme, mets son nom de code en résultat (ex : WEAPON_PISTOL). Pour un objet, son nom dans l'inventaire.</p>
        ${st.recipes.map((r, ri) => `
            <div class="card recipe">
                <div class="form-grid" style="grid-template-columns:1.3fr 1.3fr .6fr .7fr auto;margin-bottom:10px">
                    <div><label class="muted">Nom affiché</label><input class="input" data-r="${ri}:label" value="${esc(r.label)}"></div>
                    <div><label class="muted">Résultat (objet ou arme)</label><input class="input" list="known-items" data-r="${ri}:output" value="${esc(r.output)}"></div>
                    <div><label class="muted">Quantité</label><input class="input" type="number" min="1" data-r="${ri}:count" value="${esc(r.count)}"></div>
                    <div><label class="muted">Durée (s)</label><input class="input" type="number" min="1" data-r="${ri}:duration" value="${esc(r.duration)}"></div>
                    <div style="align-self:end"><button class="btn danger" data-ed="recipe_del" data-ri="${ri}">Supprimer</button></div>
                </div>
                <label class="muted" style="font-size:13px">Ingrédients nécessaires</label>
                ${r.inputs.map((inp, ii) => `<div class="inline ingredient">
                    <input class="input" list="known-items" placeholder="nom de l'objet" data-i="${ri}:${ii}:item" value="${esc(inp.item)}">
                    <input class="input qty" type="number" min="1" data-i="${ri}:${ii}:count" value="${esc(inp.count)}">
                    <button class="icon-btn" data-ed="input_del" data-ri="${ri}" data-ii="${ii}" title="Retirer">✕</button></div>`).join('')}
                <button class="btn" style="margin-top:8px" data-ed="input_add" data-ri="${ri}">+ Ingrédient</button>
            </div>`).join('')}
        <button class="btn" data-ed="recipe_add">+ Nouvelle recette</button>
        ${itemDatalist()}`;
}


/* ----- Fouilles ----- */
let searchEdit = null;
function applySearchPreset(id) {
    const p = D.config.editor.searchPresets.find((x) => x.id === id);
    drafts.search = p
        ? { preset: p.id, name: p.label, model: p.model, requiredItem: p.requiredItem, breakChance: p.breakChance, duration: p.duration,
            cooldown: p.cooldown, blip: false, blipSprite: p.blipSprite || 1, loot: clone(p.loot) }
        : { preset: 'custom', name: 'Ma zone de fouille', model: 'prop_box_wood02a', requiredItem: '', breakChance: 0, duration: 8,
            cooldown: 900, blip: false, blipSprite: 1, loot: [{ item: '', min: 1, max: 1, chance: 100 }] };
}
function searchDraft() {
    if (!drafts.search) applySearchPreset(D.config.editor.searchPresets[0].id);
    return drafts.search;
}
const lootSummary = (loot) => loot.map((l) => `<b>${l.min === l.max ? l.min : `${l.min}-${l.max}`} ${esc(itemLabel(l.item))}</b>${l.chance < 100 ? ` <span class="muted">(${l.chance} %)</span>` : ''}`).join(' + ') || '<span class="muted">rien</span>';

function searchForm(z) {
    const inp = (k, label, type = 'text', extra = '') => `<div><label>${label}</label><input class="input" type="${type}" data-q="${k}" value="${esc(z[k] ?? '')}" ${extra}></div>`;
    return `<div class="form-grid" style="grid-template-columns:1.4fr 1fr 1fr">
            ${inp('name', 'Nom de la zone')}${inp('model', 'Objet à fouiller (modèle 3D)')}
            ${inp('requiredItem', 'Outil obligatoire (vide = aucun)', 'text', 'list="known-items" placeholder="ex : crowbar"')}
        </div>
        <div class="form-grid" style="grid-template-columns:1fr 1fr 1fr 1fr 1fr">
            ${inp('duration', 'Durée de fouille (s)', 'number')}${inp('cooldown', 'Se remplit en (s)', 'number')}
            ${inp('breakChance', 'Risque de casser l\'outil (%)', 'number')}
            <div><label>Sur la carte</label><select class="input" data-q="blip">
                <option value="false" ${!z.blip ? 'selected' : ''}>Non, secret</option><option value="true" ${z.blip ? 'selected' : ''}>Oui</option></select></div>
            ${inp('blipSprite', 'Icône n°', 'number')}
        </div>
        <label class="muted" style="font-size:13px">Ce qu'on peut trouver (chaque ligne est tirée séparément)</label>
        <table class="loot"><tr><th>Objet</th><th>Min</th><th>Max</th><th>Chance</th><th></th></tr>
        ${z.loot.map((l, i) => `<tr>
            <td><input class="input" list="known-items" data-ql="${i}:item" value="${esc(l.item)}" placeholder="nom de l'objet"></td>
            <td><input class="input" type="number" min="0" data-ql="${i}:min" value="${esc(l.min)}"></td>
            <td><input class="input" type="number" min="0" data-ql="${i}:max" value="${esc(l.max)}"></td>
            <td><div class="inline"><input class="input" type="number" min="1" max="100" data-ql="${i}:chance" value="${esc(l.chance)}"><span class="muted">%</span></div></td>
            <td><button class="sb-close" data-ed="loot_del" data-i="${i}" title="Retirer">✕</button></td></tr>`).join('')}
        </table>
        <button class="btn" style="margin:8px 0 16px" data-ed="loot_add">+ Objet à trouver</button>
        ${itemDatalist()}`;
}

function edSearch() {
    const ed = D.editor, cfg = D.config.editor;
    if (searchEdit) {
        return `<div class="btn-row" style="margin-bottom:16px">
                <button class="btn" data-ed="search_back">← Retour aux fouilles</button>
                <button class="btn primary" data-ed="search_save">Enregistrer</button></div>
            <h2 class="sub-h">${esc(searchEdit.name)}</h2>${searchForm(searchEdit)}`;
    }
    const z = searchDraft();
    return `<div class="section"><h2>Créer une zone de fouille</h2>
        <p class="hint">Les joueurs fouillent des objets que tu poses toi-même : épaves de voitures, bennes, caisses… Idéal pour la ferraille et les pièces d'armes.
        Un objet fouillé est vide pendant un moment, puis se remplit tout seul.</p>
        <div class="steps"><span><b>1</b>Choisis le type</span><span><b>2</b>Règle le butin</span><span><b>3</b>Pose les objets un par un</span></div>
        <div class="preset-grid">
            ${cfg.searchPresets.map((p) => `<button class="preset ${z.preset === p.id ? 'active' : ''}" data-qpreset="${p.id}"><span class="pi">${p.icon || '🔍'}</span><span class="pl">${esc(p.label)}</span></button>`).join('')}
            <button class="preset ${z.preset === 'custom' ? 'active' : ''}" data-qpreset="custom"><span class="pi">✏️</span><span class="pl">Personnalisé</span></button>
        </div>
        ${searchForm(z)}
        <p class="hint">À chaque fouille : ${lootSummary(z.loot)}${z.requiredItem ? `. Il faut un(e) <b>${esc(itemLabel(z.requiredItem))}</b>${Number(z.breakChance) ? ` (${z.breakChance} % de risque de le casser)` : ''}` : ''}.
            Se remplit en ${fmtTime(Number(z.cooldown) || 0)}.</p>
        <button class="btn primary big" data-ed="create_search">Créer et poser les objets</button>
        </div>
        <div class="section"><h2>Zones de fouille (${ed.searches.length})</h2>
        ${!ed.searches.length ? '<div class="empty">Aucune zone de fouille pour le moment.</div>' : ed.searches.sort(byDist).map((q) => `
            <div class="card">
                <div class="card-head"><strong>${esc(q.name)}</strong><span class="muted">${distTxt(q.dist)}</span></div>
                <div class="field-stats">
                    <span>${lootSummary(q.loot)}</span>
                    <span><b>${q.points}</b> objets${q.looted ? ` (${q.looted} vides)` : ''}</span>
                    <span>Se remplit en <b>${fmtTime(q.cooldown)}</b></span>
                    <span>${q.requiredItem ? `Outil : <b>${esc(itemLabel(q.requiredItem))}</b>` : 'Sans outil'}</span>
                    <span>${q.blip ? '📍 Sur la carte' : '🔒 Secrète'}</span>
                </div>
                <div class="btn-row">
                    <button class="btn primary" data-ed="edit_search" data-id="${q.id}">Modifier</button>
                    <button class="btn" data-ed="add_searchpoints" data-id="${q.id}">Poser des objets</button>
                    <button class="btn" data-ed="tp" data-kind="search" data-id="${q.id}">Y aller</button>
                    <button class="btn danger" data-ed="delete" data-kind="search" data-id="${q.id}">Supprimer</button>
                </div>
            </div>`).join('')}</div>`;
}

const searchPayload = (z) => ({
    name: z.name, model: String(z.model).trim(), requiredItem: String(z.requiredItem || '').trim(),
    breakChance: Number(z.breakChance) || 0, duration: Number(z.duration) || 6, cooldown: Number(z.cooldown) || 0,
    blip: z.blip === true || z.blip === 'true', blipSprite: Number(z.blipSprite) || 1,
    loot: z.loot.filter((l) => String(l.item).trim()).map((l) => ({ item: String(l.item).trim(), min: Number(l.min) || 0, max: Number(l.max) || 0, chance: Number(l.chance) || 100 })),
});


/* ----- Catalogue (props et personnages) ----- */
const CAT = window.CATALOG || { props: [], peds: [] };
const catState = { mode: 'props', cat: -1, search: '', pinned: null };

function catImage(mode, name) {
    const tpl = mode === 'peds' ? CAT.pedImage : CAT.propImage;
    return tpl ? tpl.replace('{name}', name) : '';
}
function catItems() {
    const groups = CAT[catState.mode] || [];
    const q = catState.search.trim().toLowerCase();
    let list = [];
    groups.forEach((g, gi) => {
        if (!q && catState.cat !== -1 && gi !== catState.cat) return;
        g.items.forEach((name) => { if (!q || name.includes(q)) list.push({ name, cat: g.cat, icon: g.icon }); });
    });
    list.sort((a, b) => a.name.localeCompare(b.name)); // toujours dans l'ordre, même si tu ajoutes des modèles à la main
    return list;
}
function catGrid() {
    const list = catItems();
    if (!list.length) return `<div class="empty">Aucun modèle ne correspond.<br><span class="muted">Tu peux quand même taper un nom exact dans l'onglet ${catState.mode === 'props' ? 'Props' : 'PNJ'}.</span></div>`;
    const shown = list.slice(0, 400);
    return shown.map((it) => `<button class="cat-item ${catState.pinned === it.name ? 'active' : ''}" data-catitem="${esc(it.name)}" data-catname="${esc(it.cat)}">${esc(it.name)}</button>`).join('')
        + (list.length > shown.length ? `<p class="hint">${list.length - shown.length} autres : précise ta recherche.</p>` : '');
}
function catPreviewHTML(name, catName, pinned) {
    if (!name) {
        return `<div class="cat-empty"><div class="pi">👆</div><p>Passe ton curseur sur un modèle pour voir l'aperçu.<br><b>Clique</b> pour le sélectionner, <b>double-clic</b> pour ${catState.mode === 'props' ? 'le placer' : "l'utiliser"} directement.</p></div>`;
    }
    const img = catImage(catState.mode, name);
    const isProp = catState.mode === 'props';
    return `<div class="cat-img">
            ${img ? `<img src="${esc(img)}" alt="" onerror="this.style.display='none';this.nextElementSibling.style.display='flex'">` : ''}
            <div class="cat-noimg" style="${img ? 'display:none' : ''}"><span>${isProp ? '📦' : '🧑'}</span><small>Pas d'image pour ce modèle :<br>utilise « Voir en 3D »</small></div>
        </div>
        <div class="cat-name">${esc(name)}</div>
        <div class="muted" style="font-size:12px;margin-bottom:12px">${esc(catName || '')}</div>
        ${pinned ? `<div class="btn-row" style="flex-direction:column">
            ${isProp ? `<button class="btn primary" data-catact="place">📍 Placer cet objet</button>`
                     : `<button class="btn primary" data-catact="useped">🧑 Utiliser pour un PNJ</button>`}
            <button class="btn" data-catact="view3d">🔍 Voir en 3D (en jeu)</button>
            <button class="btn" data-catact="copy">📋 Copier le nom</button>
        </div>` : '<p class="hint" style="margin:0">Clique pour le sélectionner.</p>'}`;
}
function edCatalog() {
    const canProps = has('editor_props'), canPeds = has('editor_peds');
    if (catState.mode === 'props' && !canProps) catState.mode = 'peds';
    if (catState.mode === 'peds' && !canPeds) catState.mode = 'props';
    const groups = CAT[catState.mode] || [];
    const total = groups.reduce((n, g) => n + g.items.length, 0);
    const pinnedCat = catState.pinned ? (groups.find((g) => g.items.includes(catState.pinned)) || {}).cat : '';
    return `<div class="cat-top">
            <div class="segmented" style="margin:0">
                ${canProps ? `<button class="seg ${catState.mode === 'props' ? 'active' : ''}" data-catmode="props">📦 Props (${CAT.props.reduce((n, g) => n + g.items.length, 0)})</button>` : ''}
                ${canPeds ? `<button class="seg ${catState.mode === 'peds' ? 'active' : ''}" data-catmode="peds">🧑 Personnages (${CAT.peds.reduce((n, g) => n + g.items.length, 0)})</button>` : ''}
            </div>
            <input class="input" id="cat-search" placeholder="Rechercher un modèle (ex : bench, cone, dealer)…" value="${esc(catState.search)}">
        </div>
        <div class="cat-layout">
            <div class="cat-cats">
                <button class="cat-c ${catState.cat === -1 ? 'active' : ''}" data-catcat="-1"><span>📋 Tout</span><b>${total}</b></button>
                ${groups.map((g, i) => `<button class="cat-c ${catState.cat === i ? 'active' : ''}" data-catcat="${i}"><span>${g.icon} ${esc(g.cat)}</span><b>${g.items.length}</b></button>`).join('')}
            </div>
            <div class="cat-grid" id="cat-grid">${catGrid()}</div>
            <div class="cat-preview" id="cat-preview">${catPreviewHTML(catState.pinned, pinnedCat, !!catState.pinned)}</div>
        </div>`;
}
function catPlace(name) {
    if (catState.mode === 'props') return editorPost('place_prop', { model: name });
    drafts.pedModel = name;
    editorSub = 'peds';
    toast(`Apparence choisie : ${name}. Choisis son rôle puis « Placer le PNJ ».`, 'info');
    return render();
}


/* ----- Zones ----- */
const ZONE_PRESETS = [
    { id: 'safe', icon: '🛡️', label: 'Safe zone', s: { name: 'Safe zone', color: 'green', safe: true, noWeapons: true, invincible: true, exemptPolice: true, speedLimit: 0, blip: true, showBorder: false,
        enterMsg: 'Vous entrez dans une zone sécurisée', exitMsg: 'Vous quittez la zone sécurisée' } },
    { id: 'quartier', icon: '🏘️', label: 'Quartier', s: { name: 'Quartier latino', color: 'orange', safe: false, noWeapons: false, invincible: false, exemptPolice: false, speedLimit: 0, blip: true, showBorder: false,
        enterMsg: 'Vous entrez dans le quartier latino', exitMsg: '' } },
    { id: 'message', icon: '📢', label: 'Message seul', s: { name: 'Zone', color: 'gold', safe: false, noWeapons: false, invincible: false, exemptPolice: false, speedLimit: 0, blip: false, showBorder: false,
        enterMsg: 'Bienvenue', exitMsg: '' } },
    { id: 'slow', icon: '🚸', label: 'Zone 30 km/h', s: { name: 'Zone piétonne', color: 'blue', safe: true, noWeapons: false, invincible: false, exemptPolice: true, speedLimit: 30, blip: true, showBorder: false,
        enterMsg: 'Zone limitée à 30 km/h', exitMsg: '' } },
];
let zoneEditId = null;
function zoneDraft() {
    if (!drafts.zone) drafts.zone = { preset: 'safe', radius: 50, ...clone(ZONE_PRESETS[0].s) };
    return drafts.zone;
}
const zoneColor = (id) => ((D.config.editor.zoneColors || []).find((c) => c.id === id) || { hex: '#4fb3a9' }).hex;
const zoneSettingsOf = (z) => ({
    name: z.name, color: z.color, enterMsg: z.enterMsg || '', exitMsg: z.exitMsg || '',
    safe: !!z.safe, noWeapons: !!z.noWeapons, invincible: !!z.invincible, exemptPolice: !!z.exemptPolice,
    speedLimit: Number(z.speedLimit) || 0, blip: !!z.blip, showBorder: !!z.showBorder,
    blipSprite: Math.max(0, Math.floor(Number(z.blipSprite) || 0)), blipScale: Number(z.blipScale) || 0.8,
});
// Icônes de zone : celle choisie, ou l'icône automatique
let zoneIconSearch = '';
const zoneIcons = () => (D.config.editor.zoneIcons || []);
const zoneIconOf = (z) => {
    const id = Number(z.blipSprite) || 0;
    if (!id) return z.safe ? { id: 487, emoji: '🛡️', label: 'Automatique (bouclier)' } : { id: 1, emoji: '⚪', label: 'Automatique (point)' };
    return zoneIcons().find((i) => i.id === id) || { id, emoji: '🔢', label: `Icône n° ${id}` };
};
function zoneIconPicker(z) {
    const q = zoneIconSearch.trim().toLowerCase();
    const icons = zoneIcons().filter((i) => !q || i.label.toLowerCase().includes(q) || i.cat.toLowerCase().includes(q) || String(i.id) === q);
    const cats = [...new Set(icons.map((i) => i.cat))];
    const cur = Number(z.blipSprite) || 0;
    const known = !cur || zoneIcons().some((i) => i.id === cur);
    return `<div class="card recipe zicon-card"><h3 class="sub-h" style="font-size:17px">Icône sur la carte</h3>
        <div class="zicon-top">
            <div class="zicon-now"><span class="zicon-emoji">${zoneIconOf(z).emoji}</span><div><b>${esc(zoneIconOf(z).label)}</b><span class="muted">n° ${zoneIconOf(z).id}</span></div></div>
            <input class="input" id="zicon-search" placeholder="Chercher (garage, voiture, police…)" value="${esc(zoneIconSearch)}">
        </div>
        <div id="zicon-list">${cats.map((c) => `<div class="zicon-cat">${esc(c)}</div><div class="zicon-grid">
            ${icons.filter((i) => i.cat === c).map((i) => `<button class="zicon ${cur === i.id ? 'active' : ''}" data-zicon="${i.id}" title="Blip n° ${i.id}"><span>${i.emoji}</span>${esc(i.label)}</button>`).join('')}</div>`).join('') || '<p class="hint">Aucune icône ne correspond : tape son numéro ci-dessous.</p>'}</div>
        <div class="form-grid" style="grid-template-columns:auto 160px 200px;align-items:end;margin-top:10px">
            <button class="btn ${!cur ? 'on' : ''}" data-zicon="0">Automatique</button>
            <div><label>Autre icône (n° de blip)</label><input class="input" type="number" min="1" max="2000" data-zf="blipSprite" value="${!known ? cur : ''}" placeholder="ex : 357"></div>
            <div><label>Taille</label><select class="input" data-zf="blipScale">
                ${[[0.6, 'Petite'], [0.8, 'Normale'], [1.0, 'Grande'], [1.25, 'Très grande']].map(([v, l]) => `<option value="${v}" ${Number(z.blipScale || 0.8) === v ? 'selected' : ''}>${l}</option>`).join('')}</select></div>
        </div>
        <p class="hint" style="margin-top:8px">Toutes les icônes de GTA marchent : liste complète avec leurs numéros sur docs.fivem.net › Game references › Blips. L'icône prend la couleur de la zone.</p>
    </div>`;
}
function zoneBannerHTML(text, color, safe) {
    return `<div class="zm-inner" style="--zc:${esc(color)}">${safe ? '<span class="zm-ico">🛡️</span>' : ''}<span class="zm-text">${esc(text)}</span></div>`;
}
function zoneBadges(z) {
    const b = [];
    if (z.safe && z.noWeapons) b.push('🔫🚫 Pas d\'armes');
    if (z.safe && z.invincible) b.push('❤️ Invincibles');
    if (z.safe && z.speedLimit) b.push(`🚗 ${z.speedLimit} km/h`);
    if (z.safe && z.exemptPolice) b.push('👮 Sauf police');
    if (z.blip) b.push(`${zoneIconOf(z).emoji} Carte : ${esc(zoneIconOf(z).label)}`);
    if (z.showBorder) b.push('👁️ Limites visibles');
    return b.map((x) => `<span class="zbadge">${x}</span>`).join('');
}
function edZones() {
    const ed = D.editor, z = zoneDraft(), colors = D.config.editor.zoneColors || [];
    const editing = zoneEditId !== null;
    const tog = (k, label, sub) => `<div class="tile toggle-tile ${z[k] ? 'on' : ''}" data-ztoggle="${k}"><div><strong>${label}</strong><span>${sub}</span></div><div class="switch"></div></div>`;
    return `<div class="inline" style="justify-content:space-between;margin-bottom:14px">
            <p class="hint" style="margin:0">Délimite une zone toi-même (n'importe quelle forme, ou un cercle), puis choisis ce qu'elle fait.</p>
            <button class="btn ${D.self && D.self.showZones ? 'on' : ''}" data-self="showZones">👁️ ${D.self && D.self.showZones ? 'Masquer' : 'Afficher'} les limites (staff)</button>
        </div>
        <div class="section"><h2>${editing ? `Modifier la zone « ${esc(z.name)} »` : 'Créer une zone'}</h2>
        ${!editing ? `<div class="steps"><span><b>1</b>Choisis le type</span><span><b>2</b>Écris tes messages</span><span><b>3</b>Dessine-la sur la map</span></div>
        <div class="preset-grid">${ZONE_PRESETS.map((p) => `<button class="preset ${z.preset === p.id ? 'active' : ''}" data-zpreset="${p.id}"><span class="pi">${p.icon}</span><span class="pl">${p.label}</span></button>`).join('')}</div>` : ''}
        <div class="form-grid" style="grid-template-columns:1fr 1fr">
            <div><label>Nom de la zone</label><input class="input" data-zf="name" maxlength="40" value="${esc(z.name)}"></div>
            <div><label>Couleur</label><div class="zcolors">${colors.map((c) => `<button class="zcolor ${z.color === c.id ? 'active' : ''}" data-zcolor="${c.id}" title="${esc(c.label)}" style="background:${c.hex}"></button>`).join('')}</div></div>
            <div><label>Message à l'entrée (vide = aucun)</label><input class="input" data-zf="enterMsg" maxlength="140" value="${esc(z.enterMsg)}" placeholder="ex : Vous entrez dans le quartier latino"></div>
            <div><label>Message à la sortie (vide = aucun)</label><input class="input" data-zf="exitMsg" maxlength="140" value="${esc(z.exitMsg)}" placeholder="ex : Vous quittez le quartier latino"></div>
        </div>
        <label class="muted" style="font-size:13px">Aperçu du message à l'entrée</label>
        <div class="zm-preview" id="zm-preview">${zoneBannerHTML(z.enterMsg || '(aucun message)', zoneColor(z.color), z.safe)}</div>

        <div class="grid" style="grid-template-columns:repeat(3,1fr);margin:14px 0">
            ${tog('safe', '🛡️ Safe zone', 'Règles de sécurité')}
            ${tog('blip', '📍 Sur la carte', 'Zone colorée + nom')}
            ${tog('showBorder', '👁️ Limites visibles', 'Murs colorés pour tous')}
        </div>
        ${z.blip ? zoneIconPicker(z) : ''}
        ${z.safe ? `<div class="card recipe"><h3 class="sub-h" style="font-size:17px">Règles de la safe zone</h3>
            <div class="grid" style="grid-template-columns:repeat(3,1fr);margin-bottom:12px">
                ${tog('noWeapons', '🔫 Pas d\'armes ni de coups', 'Impossible de tirer ou frapper')}
                ${tog('invincible', '❤️ Joueurs invincibles', 'Personne ne peut mourir')}
                ${tog('exemptPolice', '👮 Sauf la police', 'Les policiers en service ne sont pas bloqués')}
            </div>
            <div style="max-width:260px"><label class="muted" style="font-size:13px">Limite de vitesse en véhicule (km/h, 0 = aucune)</label>
                <input class="input" type="number" min="0" max="300" data-zf="speedLimit" value="${esc(z.speedLimit)}"></div>
        </div>` : ''}

        <div class="section" style="margin-top:16px"><h2>${editing ? 'Forme de la zone' : 'Dessiner la zone'}</h2>
            <div class="grid" style="grid-template-columns:1fr 1fr">
                <div class="card" style="margin:0"><strong>✏️ Forme libre</strong>
                    <p class="hint" style="margin:6px 0 10px">Carré, rectangle, quartier entier… Tu poses les coins un par un en visant le sol, puis tu termines. Le noclip marche pendant le dessin.</p>
                    <button class="btn primary" data-ed="zone_draw">${editing ? 'Redessiner la forme' : 'Commencer à dessiner'}</button></div>
                <div class="card" style="margin:0"><strong>⭕ Cercle autour de moi</strong>
                    <p class="hint" style="margin:6px 0 10px">Centré sur ta position actuelle.</p>
                    <div class="inline"><input class="input" type="number" min="3" max="1500" data-zf="radius" value="${esc(z.radius)}" style="width:110px"><span class="muted">mètres</span>
                    <button class="btn" data-ed="zone_circle">${editing ? 'Remplacer par ce cercle' : 'Créer le cercle'}</button></div></div>
            </div>
            ${editing ? `<div class="btn-row" style="margin-top:12px"><button class="btn primary" data-ed="zone_save">Enregistrer les réglages</button><button class="btn" data-ed="zone_cancel">Annuler la modification</button></div>` : ''}
        </div>
        </div>

        <div class="section"><h2>Zones enregistrées (${(ed.zones || []).length})</h2>
        ${!(ed.zones || []).length ? '<div class="empty">Aucune zone pour le moment.</div>' : ed.zones.sort(byDist).map((q) => `
            <div class="card" style="box-shadow:inset 4px 0 0 ${esc(zoneColor(q.color))}">
                <div class="card-head"><strong>${q.safe ? '🛡️ ' : ''}${esc(q.name)}</strong><span class="muted">${q.shape === 'circle' ? `Cercle ${q.radius} m` : `${q.corners} coins`} · ${distTxt(q.dist)}</span></div>
                ${q.enterMsg ? `<div class="msg muted">« ${esc(q.enterMsg)} »</div>` : ''}
                <div class="field-stats">${zoneBadges(q)}</div>
                <div class="btn-row">
                    <button class="btn primary" data-ed="zone_edit" data-id="${q.id}">Modifier</button>
                    <button class="btn" data-ed="tp" data-kind="zone" data-id="${q.id}">Y aller</button>
                    <button class="btn danger" data-ed="delete" data-kind="zone" data-id="${q.id}">Supprimer</button>
                </div>
            </div>`).join('')}</div>`;
}


/* ----- Portes ----- */
let doorEditId = null;
function edDoors() {
    const ed = D.editor;
    const list = (ed.doors || []).slice().sort(byDist);
    const sel = list.find((d) => d.id === doorEditId);
    const others = D.players.slice().sort((a, b) => a.id - b.id);
    return `<div class="section"><h2>Ajouter une porte ou un portail</h2>
        <p class="hint">Vise la porte (ou les 2 battants d'une porte double) et valide. Elle est aussitôt <b>verrouillée</b>.
            Ensuite donne les clés à un ou plusieurs joueurs : eux seuls pourront l'ouvrir avec <span class="keycap">E</span>.
            Le propriétaire peut créer un <b>code</b> pour laisser entrer d'autres personnes.</p>
        <div class="inline" style="max-width:620px">
            <input class="input" placeholder="Nom (optionnel), ex : Villa Vinewood – entrée" data-draft="doorName" value="${esc(draft('doorName'))}">
            <button class="btn primary" data-ed="door_pick">🎯 Choisir la porte</button>
        </div></div>
        ${sel ? `<div class="section"><div class="card recipe">
            <div class="card-head"><strong>🔑 Gérer « ${esc(sel.name)} »</strong><button class="btn" data-ed="door_close">Fermer</button></div>
            <div class="form-grid" style="grid-template-columns:1fr auto;max-width:620px">
                <div><label>Nom</label><input class="input" data-draft="doorRename" value="${esc(draft('doorRename', sel.name))}"></div>
                <div style="align-self:end"><button class="btn" data-ed="door_rename" data-id="${sel.id}">Renommer</button></div>
            </div>
            <h3 class="sub-h" style="font-size:16px">📏 Distance d'ouverture</h3>
            <p class="hint">À quelle distance de la porte on peut appuyer sur <span class="keycap">E</span> pour l'ouvrir ou la fermer
                (portail de garage : 6 à 10 m ; porte d'entrée : 1,5 à 2,5 m).</p>
            <div class="form-grid" style="grid-template-columns:1fr auto auto;max-width:620px;align-items:end">
                <div><label>Distance · <b id="doorDistVal">${Number(draft('doorDist', sel.distance || D.config.doorDistance || 2.2)).toFixed(1)} m</b></label>
                    <input class="input" type="range" style="padding:0" min="${D.config.doorMinDistance || 0.8}" max="${D.config.doorMaxDistance || 15}" step="0.1"
                        data-draft="doorDist" value="${draft('doorDist', sel.distance || D.config.doorDistance || 2.2)}"
                        oninput="document.getElementById('doorDistVal').textContent = Number(this.value).toFixed(1) + ' m'"></div>
                <button class="btn primary" data-ed="door_distance" data-id="${sel.id}">Enregistrer</button>
                <button class="btn" data-ed="door_distance_reset" data-id="${sel.id}" title="Revenir à la distance par défaut">Défaut</button>
            </div>
            <h3 class="sub-h" style="font-size:16px">Personnes qui ont les clés</h3>
            ${(sel.owners || []).length ? `<div class="chips" style="margin-bottom:12px">${sel.owners.map((o) => `<span class="zbadge">🔑 ${esc(o.name)} <button class="kick-owner" data-ed="door_rm_owner" data-id="${sel.id}" data-owner="${esc(o.id)}" title="Retirer">✕</button></span>`).join('')}</div>`
                : '<p class="hint">Personne pour l\'instant : seule l\'équipe staff peut l\'ouvrir.</p>'}
            <div class="inline" style="max-width:620px">
                <select class="input" data-draft="doorOwner"><option value="">Choisir un joueur connecté…</option>
                    ${others.map((p) => `<option value="${p.id}" ${String(draft('doorOwner')) === String(p.id) ? 'selected' : ''}>[${p.id}] ${esc(p.name)}</option>`).join('')}</select>
                <button class="btn primary" data-ed="door_add_owner" data-id="${sel.id}">Donner les clés</button>
            </div>
            <p class="hint" style="margin-top:12px">Code d'accès : <b>${sel.hasCode ? 'défini par le propriétaire' : 'aucun'}</b>
                ${sel.hasCode ? `<button class="btn" style="margin-left:8px" data-ed="door_reset_code" data-id="${sel.id}">Supprimer le code</button>` : ''}</p>
        </div></div>` : ''}
        <div class="section"><h2>Portes enregistrées (${list.length})</h2>
        ${!list.length ? '<div class="empty">Aucune porte pour le moment.</div>' : list.map((d) => `
            <div class="card">
                <div class="card-head"><strong>${d.locked ? '🔒' : '🔓'} ${esc(d.name)}</strong><span class="muted">${d.double ? 'Porte double · ' : ''}${distTxt(d.dist)}</span></div>
                <div class="field-stats">
                    <span>${(d.owners || []).length ? `🔑 ${d.owners.map((o) => esc(o.name)).join(', ')}` : '🔑 Aucun propriétaire'}</span>
                    <span>${d.hasCode ? '🔢 Code défini' : '🔢 Pas de code'}</span>
                    <span>📏 S'ouvre à ${Number(d.distance || D.config.doorDistance || 2.2).toFixed(1)} m${d.distance ? '' : ' (défaut)'}</span>
                </div>
                <div class="btn-row">
                    <button class="btn ${d.locked ? '' : 'on'}" data-ed="door_toggle" data-id="${d.id}">${d.locked ? '🔓 Déverrouiller' : '🔒 Verrouiller'}</button>
                    <button class="btn primary" data-ed="door_manage" data-id="${d.id}">Gérer les clés</button>
                    <button class="btn" data-ed="tp" data-kind="door" data-id="${d.id}">Y aller</button>
                    <button class="btn danger" data-ed="delete" data-kind="door" data-id="${d.id}">Supprimer</button>
                </div>
            </div>`).join('')}</div>`;
}

async function handleEditor(n) {
    const act = n.dataset.ed, kind = n.dataset.kind, id = Number(n.dataset.id);
    switch (act) {
        case 'add_spawn':
            action('editor_add_spawn', { name: draft('spawnName') });
            drafts.spawnName = '';
            return setTimeout(() => post('refresh'), 300);
        case 'place_prop': {
            const model = (n.dataset.model || draft('propModel')).trim();
            if (!model) return toast('Indique un nom de modèle.', 'error');
            return editorPost('place_prop', { model, magnet: !!drafts.propMagnet, folder: Number(draft('propFolder', propView !== 'all' && propView !== 'none' ? String(propView) : '0')) || undefined });
        }
        case 'place_ped': {
            const model = draft('pedModel').trim();
            if (!model) return toast('Choisis une apparence (clique sur un modèle sous le champ).', 'error');
            const pr = pedDraftPreset();
            const npc = pr.npc ? clone(pr.npc) : null;
            if (npc) {
                const job = String(draft('pedJob', '')).trim().toLowerCase();
                npc.jobs = job ? [{ job, grade: Number(draft('pedJobGrade', 0)) || 0 }] : [];
                if (npc.garage) delete npc.garage.jobs;
            }
            return editorPost('place_ped', { model, scenario: draft('pedScenario'), name: draft('pedName'), npc });
        }
        case 'prop_magnet': drafts.propMagnet = !drafts.propMagnet; return render();
        case 'move': return editorPost('move', { kind, id });
        case 'prop_select': return editorPost('prop_select', {});
        case 'prop_show': return editorPost('prop_show', { ids: [id], label: `Prop #${id}` });
        case 'folder_new': {
            const v = await formModal('Nouveau dossier', [{ name: 'name', label: 'Nom du dossier', placeholder: 'ex : Garage central, Mairie, Event Halloween' }], 'Créer');
            if (v && v.name && v.name.trim()) { pendingFolderOpen = true; action('editor_folder_save', { name: v.name.trim() }); }
            return;
        }
        case 'folder_rename': {
            const f = folderOf(id);
            if (!f) return;
            const v = await formModal(`Renommer « ${f.name} »`, [{ name: 'name', label: 'Nouveau nom', value: f.name }], 'Renommer');
            if (v && v.name && v.name.trim()) action('editor_folder_save', { id, name: v.name.trim() });
            return;
        }
        case 'folder_show': {
            const f = folderOf(id);
            const ids = D.editor.props.filter((r) => r.folder === id).map((r) => r.id);
            if (!ids.length) return toast('Ce dossier est vide.', 'error');
            return editorPost('prop_show', { ids, label: `Dossier « ${f ? f.name : ''} »` });
        }
        case 'folder_delete': {
            const f = folderOf(id);
            if (!f) return;
            const n = D.editor.props.filter((r) => r.folder === id).length;
            const v = await formModal(`Supprimer le dossier « ${f.name} » ?`, [{ name: 'mode', label: `Il contient ${n} prop(s).`, type: 'select', value: 'keep',
                options: [{ value: 'keep', label: 'Garder les props (ils passent « Sans dossier »)' }, { value: 'delete', label: 'Supprimer aussi tous ses props' }] }], 'Supprimer', true);
            if (!v) return;
            if (v.mode === 'delete' && n > 0 && !(await confirmBox(`Supprimer ${n} prop(s) ?`, 'Les props du dossier seront supprimés définitivement.'))) return;
            propView = 'all';
            action('editor_folder_delete', { id, withProps: v.mode === 'delete' });
            return;
        }
        case 'props_move_folder': {
            const folder = Number(($('#prop-bulk-folder') || {}).value || 0);
            action('editor_props_folder', { ids: [...propSel], folder });
            propSel.clear();
            return;
        }
        case 'props_show_sel': return editorPost('prop_show', { ids: [...propSel], label: 'Sélection' });
        case 'props_sel_clear': propSel.clear(); return refreshPropList();
        case 'props_sel_all': propsInView().forEach((r) => propSel.add(r.id)); return refreshPropList();
        case 'tp': return editorPost('tp', { kind, id });
        case 'add_plants': return editorPost('add_plants', { id });
        case 'delete': {
            if (kind === 'zone' && zoneEditId === id) { zoneEditId = null; drafts.zone = null; }
            if (kind === 'door' && doorEditId === id) doorEditId = null;
            const labels = { door: 'cette porte (elle sera déverrouillée)', zone: 'cette zone', spawn: 'ce point de spawn', prop: 'ce prop', ped: 'ce PNJ', field: 'cette zone et tous ses plants', stash: 'ce coffre (son contenu reste enregistré)' };
            if (await confirmBox('Supprimer définitivement ?', `Tu vas supprimer ${labels[kind]}. Cette action est sauvegardée.`)) {
                action('editor_delete', { kind, id });
                setTimeout(() => post('refresh'), 300);
            }
            return;
        }
        case 'edit_ped': {
            pedEdit = toPedEdit(D.editor.peds.find((x) => x.id === id));
            return render();
        }
        case 'ped_back': pedEdit = null; return render();
        case 'ped_save': {
            const pl = pedEditPayload(pedEdit);
            if (pl.npc && pl.npc.buyer && !pl.npc.buyer.items.length) return toast('Ajoute au moins un objet racheté, ou désactive « Il rachète ».', 'error');
            if (pl.npc && pl.npc.shop && !pl.npc.shop.items.length) return toast('Ajoute au moins un objet vendu, ou désactive « Il vend ».', 'error');
            if (pl.npc && pl.npc.buyer && pl.npc.buyer.items.some((i) => i.max < i.min)) return toast('Le prix max doit être supérieur ou égal au prix min.', 'error');
            if (pl.npc && pl.npc.garage && !pl.npc.garage.vehicles.length) return toast('Ajoute au moins un véhicule, ou désactive « Garage ».', 'error');
            if (pl.npc && pedEdit.gJobsOn && !pl.npc.jobs.length) return toast('Choisis au moins un métier, ou « Tout le monde ».', 'error');
            if (pl.npc && pl.npc.clothing && !pedEdit.clCats.length) return toast('Choisis au moins un rayon pour la boutique.', 'error');
            action('editor_save_ped', pl);
            pedEdit = null;
            return setTimeout(() => post('refresh'), 300);
        }
        case 'pgv_add': pedEdit.gVehicles.push({ model: '', label: '', price: 0 }); return render();
        case 'pgv_del': pedEdit.gVehicles.splice(Number(n.dataset.i), 1); return render();
        case 'cl_cat': {
            const c = n.dataset.cat, i = pedEdit.clCats.indexOf(c);
            if (i >= 0) pedEdit.clCats.splice(i, 1); else pedEdit.clCats.push(c);
            return render();
        }
        case 'cl_all': pedEdit.clCats = CLOTHING_CATS.map((c) => c.id); return render();
        case 'cl_none': pedEdit.clCats = []; return render();
        case 'pgj_add': pedEdit.gJobs.push({ job: '', grade: 0 }); return render();
        case 'pgj_del': pedEdit.gJobs.splice(Number(n.dataset.i), 1); return render();
        case 'gjobs_on': pedEdit.gJobsOn = true; return render();
        case 'gjobs_off': pedEdit.gJobsOn = false; return render();
        case 'garage_spot': return editorPost('garage_spot', { id: pedEdit.id, model: n.dataset.model });
        case 'garage_spot_move': return editorPost('garage_spot', { id: pedEdit.id, idx: Number(n.dataset.i), model: n.dataset.model, h: Number(n.dataset.h) });
        case 'garage_spot_tp': return editorPost('garage_spot_tp', { id: pedEdit.id, idx: Number(n.dataset.i) });
        case 'pubgarage_spot': return editorPost('pubgarage_spot', { id: pedEdit.id });
        case 'pubgarage_store': return editorPost('pubgarage_store', { id: pedEdit.id });
        case 'pubgarage_store_move': return editorPost('pubgarage_store', { id: pedEdit.id, idx: Number(n.dataset.i), h: Number(n.dataset.h) });
        case 'pubgarage_store_tp': return editorPost('pubgarage_store_tp', { id: pedEdit.id, idx: Number(n.dataset.i) });
        case 'pubgarage_store_del':
            action('editor_pubgarage_store_delete', { pedId: pedEdit.id, idx: Number(n.dataset.i) });
            return setTimeout(() => post('refresh'), 300);
        case 'pubgarage_spot_move': return editorPost('pubgarage_spot', { id: pedEdit.id, idx: Number(n.dataset.i), h: Number(n.dataset.h) });
        case 'pubgarage_spot_tp': return editorPost('pubgarage_spot_tp', { id: pedEdit.id, idx: Number(n.dataset.i) });
        case 'pubgarage_spot_del':
            action('editor_pubgarage_spot_delete', { pedId: pedEdit.id, idx: Number(n.dataset.i) });
            return setTimeout(() => post('refresh'), 300);
        case 'catalog_spot': return editorPost('catalog_spot', { id: pedEdit.id, h: n.dataset.h !== undefined ? Number(n.dataset.h) : undefined });
        case 'catalog_spot_tp': return editorPost('catalog_spot_tp', { id: pedEdit.id });
        case 'garage_spot_del': {
            if (!(await confirmBox('Supprimer ce point de sortie ?', 'Les véhicules ne sortiront plus à cet endroit.'))) return;
            action('editor_garage_spot_delete', { pedId: pedEdit.id, idx: Number(n.dataset.i) });
            return setTimeout(() => post('refresh'), 300);
        }
        case 'peb_add': pedEdit.buyer.push({ item: '', min: 50, max: 80 }); return render();
        case 'peb_del': pedEdit.buyer.splice(Number(n.dataset.i), 1); return render();
        case 'pes_add': pedEdit.shop.push({ item: '', price: 100 }); return render();
        case 'pes_del': pedEdit.shop.splice(Number(n.dataset.i), 1); return render();
        case 'edit_field': {
            const z = D.editor.fields.find((x) => x.id === id);
            const v = await formModal(`Réglages : ${z.name}`, [
                ...FIELD_INPUTS.map(([k, label, type]) => ({ name: k, label, type, value: z[k] })),
                { name: 'blip', label: 'Visible sur la carte', type: 'select', value: String(z.blip), options: [{ value: 'false', label: 'Non (secret)' }, { value: 'true', label: 'Oui' }] },
                { name: 'blipSprite', label: 'Icône de carte (n°)', type: 'number', value: z.blipSprite || 1 },
            ], 'Enregistrer');
            if (v) {
                v.blip = v.blip === 'true';
                if (Number(v.max) < Number(v.min)) return toast('Le maximum doit être supérieur ou égal au minimum.', 'error');
                action('editor_update_field', { id, ...v });
                setTimeout(() => post('refresh'), 300);
            }
            return;
        }
        case 'create_search': {
            const z = searchPayload(searchDraft());
            if (!z.model) return toast("Indique l'objet à fouiller.", 'error');
            if (!z.loot.length) return toast('Ajoute au moins un objet à trouver.', 'error');
            return editorPost('create_search', z);
        }
        case 'add_searchpoints': return editorPost('add_searchpoints', { id });
        case 'map_pick': return editorPost('map_pick');
        case 'door_pick': return editorPost('door_pick', { name: draft('doorName') });
        case 'door_toggle': action('editor_door_toggle', { id }); return setTimeout(() => post('refresh'), 300);
        case 'door_manage': doorEditId = id; drafts.doorRename = undefined; drafts.doorDist = undefined; document.querySelector('#content').scrollTop = 0; return render();
        case 'door_close': doorEditId = null; return render();
        case 'door_rename': action('editor_door_rename', { id, name: draft('doorRename') }); return setTimeout(() => post('refresh'), 300);
        case 'door_distance': action('editor_door_distance', { id, distance: Number(draft('doorDist', 2.2)) }); return setTimeout(() => post('refresh'), 300);
        case 'door_distance_reset': drafts.doorDist = D.config.doorDistance || 2.2; action('editor_door_distance', { id, distance: D.config.doorDistance || 2.2 }); return setTimeout(() => post('refresh'), 300);
        case 'door_add_owner':
            if (!draft('doorOwner')) return toast('Choisis un joueur dans la liste.', 'error');
            action('editor_door_add_owner', { id, target: Number(draft('doorOwner')) });
            drafts.doorOwner = '';
            return setTimeout(() => post('refresh'), 300);
        case 'door_rm_owner': action('editor_door_remove_owner', { id, owner: n.dataset.owner }); return setTimeout(() => post('refresh'), 300);
        case 'door_reset_code':
            if (await confirmBox('Supprimer le code ?', 'Seuls les propriétaires pourront ouvrir la porte.')) { action('editor_door_reset_code', { id }); setTimeout(() => post('refresh'), 300); }
            return;
        case 'jailpoint':
            action('editor_set_jail', { id });
            return setTimeout(() => post('refresh'), 300);
        case 'zone_draw': {
            const z = zoneDraft();
            if (!z.name.trim()) return toast('Donne un nom à la zone.', 'error');
            return editorPost('zone_draw', { id: zoneEditId, settings: zoneSettingsOf(z) });
        }
        case 'zone_circle': {
            const z = zoneDraft();
            if (!z.name.trim()) return toast('Donne un nom à la zone.', 'error');
            editorPost('zone_circle', { id: zoneEditId, radius: Number(z.radius) || 50, settings: zoneSettingsOf(z) });
            zoneEditId = null; drafts.zone = null;
            return setTimeout(() => post('refresh'), 400);
        }
        case 'zone_edit': {
            const q = D.editor.zones.find((x) => x.id === id);
            zoneEditId = id;
            drafts.zone = { preset: null, radius: q.radius || 50, ...zoneSettingsOf(q) };
            document.querySelector('#content').scrollTop = 0;
            return render();
        }
        case 'zone_save':
            action('editor_save_zone', { id: zoneEditId, settings: zoneSettingsOf(zoneDraft()) });
            zoneEditId = null; drafts.zone = null;
            return setTimeout(() => post('refresh'), 400);
        case 'zone_cancel': zoneEditId = null; drafts.zone = null; return render();
        case 'unhide':
            if (await confirmBox('Remettre cet objet ?', "Il réapparaîtra pour tout le monde à son emplacement d'origine.")) {
                action('editor_delete', { kind: 'hidden', id });
                setTimeout(() => post('refresh'), 300);
            }
            return;
        case 'rename_hidden': {
            const h = (D.editor.hidden || []).find((x) => x.id === id);
            const v = await formModal("Renommer l'objet retiré", [{ name: 'name', label: 'Nom (ex : Poteau devant le garage)', value: h.label }], 'Renommer');
            if (v && v.name.trim()) { action('editor_rename_hidden', { id, name: v.name }); setTimeout(() => post('refresh'), 300); }
            return;
        }
        case 'edit_search': {
            const q = D.editor.searches.find((x) => x.id === id);
            searchEdit = clone({ ...q, loot: Array.isArray(q.loot) ? q.loot : [] });
            return render();
        }
        case 'search_back': searchEdit = null; return render();
        case 'search_save': {
            const z = searchPayload(searchEdit);
            if (!z.loot.length) return toast('Ajoute au moins un objet à trouver.', 'error');
            action('editor_update_search', { id: searchEdit.id, ...z });
            searchEdit = null;
            return setTimeout(() => post('refresh'), 300);
        }
        case 'loot_add': (searchEdit || searchDraft()).loot.push({ item: '', min: 1, max: 1, chance: 100 }); return render();
        case 'loot_del': (searchEdit || searchDraft()).loot.splice(Number(n.dataset.i), 1); return render();
        case 'newcomer':
            action('editor_set_newcomer', { id });
            return setTimeout(() => post('refresh'), 300);
        case 'rename_spawn': {
            const sp = D.editor.spawns.find((x) => x.id === id);
            const v = await formModal('Renommer le point de spawn', [{ name: 'name', label: 'Nom', value: sp.name }], 'Renommer');
            if (v && v.name.trim()) { action('editor_rename_spawn', { id, name: v.name }); setTimeout(() => post('refresh'), 300); }
            return;
        }
        case 'place_station': {
            const st = stationNewDraft();
            if (!st.model.trim()) return toast('Indique le modèle du meuble.', 'error');
            return editorPost('place_station', { name: st.name, model: st.model, scenario: st.scenario, blip: st.blip === 'true', blipSprite: Number(st.blipSprite), recipes: st.recipes });
        }
        case 'edit_station': {
            const st = D.editor.stations.find((x) => x.id === id);
            stationEdit = clone({ ...st, recipes: Array.isArray(st.recipes) ? st.recipes : [] });
            stationEdit.recipes.forEach((r) => { if (!Array.isArray(r.inputs)) r.inputs = []; });
            return render();
        }
        case 'station_back': stationEdit = null; return render();
        case 'recipe_add': stationEdit.recipes.push({ label: '', output: '', count: 1, duration: 10, inputs: [{ item: '', count: 1 }] }); return render();
        case 'recipe_del': stationEdit.recipes.splice(Number(n.dataset.ri), 1); return render();
        case 'input_add': stationEdit.recipes[Number(n.dataset.ri)].inputs.push({ item: '', count: 1 }); return render();
        case 'input_del': stationEdit.recipes[Number(n.dataset.ri)].inputs.splice(Number(n.dataset.ii), 1); return render();
        case 'station_save': {
            const st = stationEdit;
            const bad = st.recipes.find((r) => !String(r.output).trim());
            if (bad) return toast('Chaque recette doit avoir un résultat.', 'error');
            action('editor_update_station', {
                id: st.id, name: st.name, model: st.model, scenario: st.scenario, blip: st.blip === true || st.blip === 'true',
                blipSprite: Number(st.blipSprite) || 1,
                recipes: st.recipes.map((r) => ({ label: r.label, output: String(r.output).trim(), count: Number(r.count) || 1, duration: Number(r.duration) || 1,
                    inputs: r.inputs.filter((i) => String(i.item).trim()).map((i) => ({ item: String(i.item).trim(), count: Number(i.count) || 1 })) })),
            });
            stationEdit = null;
            return setTimeout(() => post('refresh'), 300);
        }
        case 'create_field': {
            const f = fieldDraft();
            if (!f.model || !f.item) return toast('Le modèle et l\'objet sont obligatoires.', 'error');
            if (Number(f.max) < Number(f.min)) return toast('Le maximum doit être supérieur ou égal au minimum.', 'error');
            return editorPost('create_field', { ...f, blip: f.blip === 'true' });
        }
    }
}

/* ---------- Raccourcis ---------- */
const KEY_NAMES = {
    SPACE: 'Espace', LCONTROL: 'Ctrl gauche', RCONTROL: 'Ctrl droit', LSHIFT: 'Shift gauche', RSHIFT: 'Shift droit',
    LMENU: 'Alt gauche', RMENU: 'Alt droit', RETURN: 'Entrée', BACK: 'Retour arrière', DELETE: 'Suppr', TAB: 'Tab',
    IOM_WHEEL_UP: 'Molette haut', IOM_WHEEL_DOWN: 'Molette bas',
    MOUSE_LEFT: 'Clic gauche', MOUSE_RIGHT: 'Clic droit', MOUSE_MIDDLE: 'Clic molette',
};
const keyName = (k) => (!k ? 'Aucune' : KEY_NAMES[k] || k);
function keyOf(group, label) {
    const k = (D.keys || []).find((x) => x.group === group && x.label === label);
    return `<span class="keycap">${esc(keyName(k ? (k.current || k.default) : ''))}</span>`;
}

VIEWS.keys = () => {
    const groups = {};
    (D.keys || []).forEach((k) => { (groups[k.group] = groups[k.group] || []).push(k); });
    return `
        <div class="section">
            <p class="hint" style="margin:0 0 12px">Chaque raccourci se change dans les paramètres de FiveM :
            Échap › Paramètres › Assignation des touches › FiveM, puis cherche les lignes qui commencent par « Staff ».</p>
            <button class="btn primary" data-self="open_keybinds">Modifier mes touches</button>
        </div>
        ${Object.entries(groups).map(([g, list]) => `
            <div class="section"><h2>${esc(g)}</h2>
            <table>
                <tr><th>Action</th><th>Ta touche</th><th>Par défaut</th></tr>
                ${list.map((k) => `<tr>
                    <td>${esc(k.label)}</td>
                    <td><span class="keycap">${esc(keyName(k.current || k.default))}</span></td>
                    <td class="muted">${esc(keyName(k.default))}</td>
                </tr>`).join('')}
            </table></div>`).join('')}`;
};

/* ---------- Logs ---------- */
function logRows() {
    const q = logSearch.trim().toLowerCase();
    const list = (D.logs || []).filter((l) => !q || `${l.admin} ${l.action} ${l.details}`.toLowerCase().includes(q));
    if (!list.length) return '<div class="empty">Aucune entrée.</div>';
    return list.map((l) => `<div class="log"><span class="t">${esc(l.time)}</span><span>${esc(l.admin)}</span><span class="a">${esc(l.action)}</span><span>${esc(l.details)}</span></div>`).join('');
}
VIEWS.logs = () => `
    <input class="input" id="log-search" placeholder="Filtrer par staff, action ou détail" value="${esc(logSearch)}" style="margin-bottom:12px">
    <div id="log-list">${logRows()}</div>`;

/* =========================================================
   ÉVÈNEMENTS DU CONTENU
   ========================================================= */
const content = $('#content');

content.addEventListener('input', (e) => {
    const t = e.target;
    if (t.id === 'search') { search = t.value; $('#player-list').innerHTML = playerRows(); return; }
    if (t.dataset.zf) {
        const z = zoneDraft();
        z[t.dataset.zf] = t.value;
        if (t.dataset.zf === 'enterMsg') { const pv = $('#zm-preview'); if (pv) pv.innerHTML = zoneBannerHTML(t.value || '(aucun message)', zoneColor(z.color), z.safe); }
        return;
    }
    if (t.id === 'prop-search') { propSearch = t.value; const rows = $('#prop-rows'); if (rows) rows.innerHTML = propRows(); return; }
    if (t.dataset.propsel) {
        const id = Number(t.dataset.propsel);
        if (t.checked) propSel.add(id); else propSel.delete(id);
        const tr = t.closest('tr'); if (tr) tr.classList.toggle('sel', t.checked);
        const bulk = $('#prop-bulk'); if (bulk) bulk.innerHTML = propBulkBar();
        return;
    }
    if (t.dataset.propfolder && t.tagName === 'SELECT') return;
    if (t.id === 'tpc-input') {
        drafts.tpcText = t.value;
        const pv = $('#tpc-preview'); if (pv) pv.innerHTML = tpcPreview(t.value);
        return;
    }
    if (t.id === 'zicon-search') {
        zoneIconSearch = t.value;
        const box = $('.zicon-card');
        if (box) { const fresh = document.createElement('div'); fresh.innerHTML = zoneIconPicker(zoneDraft()); $('#zicon-list').innerHTML = fresh.querySelector('#zicon-list').innerHTML; }
        return;
    }
    if (t.id === 'cat-search') { catState.search = t.value; const g = $('#cat-grid'); if (g) g.innerHTML = catGrid(); return; }
    if (t.id === 'item-search') { itemSearch = t.value; itemLimit = 300; const g = $('#item-grid'); if (g) g.innerHTML = itemGrid(); return; }
    if (t.dataset.give) {
        give[t.dataset.give] = t.value;
        const b = document.querySelector('[data-act="give_item"]');
        if (b && selItem) b.textContent = `🎁 Donner ${give.count} × ${selItem.label}`;
        if (t.tagName === 'SELECT') render();
    }
    if (t.id === 'log-search') { logSearch = t.value; $('#log-list').innerHTML = logRows(); return; }
    if (t.dataset.draft) drafts[t.dataset.draft] = t.value;
    if (t.dataset.ann) {
        const a = annDraft();
        a[t.dataset.ann] = t.dataset.ann === 'ticker' ? t.value === 'true' : t.value;
        if (t.dataset.ann === 'duration') { const el = $('#ann-dur'); if (el) el.textContent = `${t.value} s`; }
        if (t.dataset.ann === 'message') { const el = $('#ann-count'); if (el) el.textContent = t.value.length; }
        const pv = document.querySelector('.an-preview');
        if (pv && t.dataset.ann !== 'duration') {
            const imgs = D.config.announceImages || [];
            const isCustom = a.image !== '' && !imgs.find((i) => i.url === a.image);
            pv.className = `an an-preview an-${a.style}`;
            pv.innerHTML = announceHTML({ ...a, image: isCustom ? a.customUrl : a.image, by: D.me.label, message: a.message || 'Ton message apparaîtra ici.' });
        }
    }
    if ((t.id === 'hour' || t.id === 'minute') && $('#clock')) {
        $('#clock').textContent = `${String($('#hour').value).padStart(2, '0')}:${String($('#minute').value).padStart(2, '0')}`;
    }
    if (rankDraft && t.dataset.rankField) rankDraft[t.dataset.rankField] = t.value;
    if (t.dataset.field && t.dataset.field !== 'preset') fieldDraft()[t.dataset.field] = t.value;
    if (t.dataset.sn && t.dataset.sn !== 'preset') stationNewDraft()[t.dataset.sn] = t.value;
    if (pedEdit && t.dataset.pe) {
        const v = t.dataset.pe === 'hoursOn' ? t.value === 'true' : t.value;
        pedEdit[t.dataset.pe] = v;
        if (['payment', 'hoursOn'].includes(t.dataset.pe)) render();
    }
    if (pedEdit && t.dataset.peb) { const [i, k] = t.dataset.peb.split(':'); pedEdit.buyer[i][k] = t.value; }
    if (pedEdit && t.dataset.pes) { const [i, k] = t.dataset.pes.split(':'); pedEdit.shop[i][k] = t.value; }
    if (pedEdit && t.dataset.pgv) { const [i, k] = t.dataset.pgv.split(':'); pedEdit.gVehicles[i][k] = t.value; }
    if (pedEdit && t.dataset.pgj) {
        const [i, k] = t.dataset.pgj.split(':');
        pedEdit.gJobs[i][k] = t.value;
        if (k === 'job' && t.tagName === 'SELECT') {
            const job = serverJobs().find((x) => x.name === t.value);
            pedEdit.gJobs[i].grade = job && job.grades.length ? job.grades[0].level : 0;
            render();
        }
    }
    if (t.dataset.q) { const z = searchEdit || searchDraft(); z[t.dataset.q] = t.dataset.q === 'blip' ? t.value === 'true' : t.value; }
    if (t.dataset.ql) { const [i, k] = t.dataset.ql.split(':'); (searchEdit || searchDraft()).loot[i][k] = t.value; }
    if (stationEdit && t.dataset.st) stationEdit[t.dataset.st] = t.value;
    if (stationEdit && t.dataset.r) { const [ri, k] = t.dataset.r.split(':'); stationEdit.recipes[ri][k] = t.value; }
    if (stationEdit && t.dataset.i) { const [ri, ii, k] = t.dataset.i.split(':'); stationEdit.recipes[ri].inputs[ii][k] = t.value; }
    if (rankDraft && t.dataset.perm) rankDraft.perms[t.dataset.perm] = t.checked;
});

content.addEventListener('change', (e) => {
    if (e.target.dataset && e.target.dataset.propfolder) {
        action('editor_props_folder', { ids: [Number(e.target.dataset.propfolder)], folder: Number(e.target.value) });
        return;
    }
    const t = e.target;
    if (t.dataset.draft) drafts[t.dataset.draft] = t.value;
    if (t.dataset.draft === 'pedJob') {
        const job = serverJobs().find((x) => x.name === t.value);
        drafts.pedJobGrade = job && job.grades.length ? job.grades[0].level : 0;
        render();
    }
    if (rankDraft && t.dataset.perm) rankDraft.perms[t.dataset.perm] = t.checked;
    if (t.dataset.staffRank) action('change_staff_rank', { identifier: t.dataset.staffRank, rank: t.value });
    if (t.dataset.field === 'blip') fieldDraft().blip = t.value;
    if (['min', 'max', 'duration', 'regrow', 'itemLabel', 'item'].includes(t.dataset.field)) render();
    if (!searchEdit && (t.dataset.ql || ['requiredItem', 'breakChance', 'cooldown'].includes(t.dataset.q))) render();
    if (stationEdit && t.dataset.st === 'blip') stationEdit.blip = t.value === 'true';
    if (t.dataset.sn === 'preset') {
        const p = D.config.editor.craftPresets.find((x) => x.id === t.value);
        drafts.station = p ? { preset: p.id, name: p.label, model: p.model, scenario: p.scenario, blip: 'false', blipSprite: p.blipSprite || 1, recipes: clone(p.recipes) }
            : { preset: 'custom', name: 'Atelier', model: 'prop_tool_bench02', scenario: 'PROP_HUMAN_PARKING_METER', blip: 'false', blipSprite: 1, recipes: [] };
        render();
    }
    if (t.dataset.field === 'preset') {
        const f = fieldDraft();
        f.preset = t.value;
        const p = D.config.editor.presets.find((x) => x.id === t.value);
        if (p) Object.assign(f, { name: 'Zone : ' + p.label, model: p.model, item: p.item, itemLabel: p.itemLabel, min: p.min, max: p.max,
            duration: p.duration, regrow: p.regrow, blipSprite: p.blipSprite || 1 });
        render();
    }
});

content.addEventListener('mouseover', (e) => {
    const it = e.target.closest('[data-catitem]');
    const pv = $('#cat-preview');
    if (!it || !pv || pv.dataset.shown === it.dataset.catitem) return;
    pv.dataset.shown = it.dataset.catitem;
    pv.innerHTML = catPreviewHTML(it.dataset.catitem, it.dataset.catname, it.dataset.catitem === catState.pinned);
});
content.addEventListener('mouseout', (e) => {
    const grid = e.target.closest('#cat-grid');
    if (!grid || (e.relatedTarget && grid.contains(e.relatedTarget))) return;
    const pv = $('#cat-preview');
    if (!pv) return;
    const groups = CAT[catState.mode] || [];
    const pc = catState.pinned ? (groups.find((g) => g.items.includes(catState.pinned)) || {}).cat : '';
    pv.dataset.shown = catState.pinned || '';
    pv.innerHTML = catPreviewHTML(catState.pinned, pc, !!catState.pinned);
});
content.addEventListener('dblclick', (e) => {
    const it = e.target.closest('[data-catitem]');
    if (it) catPlace(it.dataset.catitem);
});

content.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && e.target.id === 'veh-model') spawnFromInput();
    if (e.key === 'Enter' && e.target.id === 'tpc-input') handleAct('tpc_go');
});

function spawnFromInput() {
    const m = (drafts.model || '').trim();
    if (!m) return toast('Indique un nom de modèle.', 'error');
    action('spawn_vehicle', { model: m });
}

content.addEventListener('click', async (e) => {
    const el = (sel) => e.target.closest(sel);
    let n;

    if ((n = el('[data-player]'))) { selectedPlayer = Number(n.dataset.player); return render(); }
    if ((n = el('[data-esub]'))) { editorSub = n.dataset.esub; stationEdit = null; searchEdit = null; pedEdit = null; return render(); }
    if ((n = el('[data-go]'))) { tab = n.dataset.go; return render(); }
    if ((n = el('[data-zpreset]'))) {
        const p = ZONE_PRESETS.find((x) => x.id === n.dataset.zpreset);
        drafts.zone = { preset: p.id, radius: zoneDraft().radius, ...clone(p.s) };
        return render();
    }
    if ((n = el('[data-ztoggle]'))) { const z = zoneDraft(); z[n.dataset.ztoggle] = !z[n.dataset.ztoggle]; return render(); }
    if ((n = el('[data-pview]'))) {
        const v = n.dataset.pview;
        propView = v === 'all' || v === 'none' ? v : Number(v);
        drafts.propFolder = propView !== 'all' && propView !== 'none' ? String(propView) : '0';
        return render();
    }
    if ((n = el('[data-zcolor]'))) { zoneDraft().color = n.dataset.zcolor; return render(); }
    if ((n = el('[data-tpc]'))) {
        const [, kind, i] = n.dataset.tpc.split(':');
        const c = tpLoad(kind === 'fav' ? TP_FAV : TP_HIST)[Number(i)];
        if (c) { post('close'); tpTo(c); }
        return;
    }
    if ((n = el('[data-tpcfav]'))) { tpFavorite(tpLoad(TP_HIST)[Number(n.dataset.tpcfav)]); return; }
    if ((n = el('[data-tpcdel]'))) {
        const fav = tpLoad(TP_FAV); fav.splice(Number(n.dataset.tpcdel), 1); tpStore(TP_FAV, fav);
        const box = $('#tpc-chips'); if (box) box.innerHTML = tpChips('self');
        return;
    }
    if ((n = el('[data-zicon]'))) { zoneDraft().blipSprite = Number(n.dataset.zicon); return render(); }
    if ((n = el('[data-opencat]'))) { catState.mode = n.dataset.opencat; catState.cat = -1; catState.pinned = null; editorSub = 'catalog'; return render(); }
    if ((n = el('[data-catmode]'))) { catState.mode = n.dataset.catmode; catState.cat = -1; catState.pinned = null; render(); const g = $('#cat-grid'); if (g) g.scrollTop = 0; return; }
    if ((n = el('[data-catcat]'))) { catState.cat = Number(n.dataset.catcat); render(); const g = $('#cat-grid'); if (g) g.scrollTop = 0; return; }
    if ((n = el('[data-catitem]'))) {
        catState.pinned = n.dataset.catitem;
        content.dataset.sig = `editor|cat|${catState.mode}|${catState.cat}|${catState.pinned}|${has('editor_props')}|${has('editor_peds')}`;
        document.querySelectorAll('.cat-item.active').forEach((x) => x.classList.remove('active'));
        n.classList.add('active');
        const pv = $('#cat-preview');
        if (pv) { pv.dataset.shown = n.dataset.catitem; pv.innerHTML = catPreviewHTML(n.dataset.catitem, n.dataset.catname, true); }
        return;
    }
    if ((n = el('[data-catact]'))) {
        const name = catState.pinned;
        if (!name) return;
        if (n.dataset.catact === 'place' || n.dataset.catact === 'useped') return catPlace(name);
        if (n.dataset.catact === 'view3d') {
            if (catState.mode === 'peds') drafts.pedModel = name;
            return editorPost('preview3d', { kind: catState.mode === 'peds' ? 'ped' : 'prop', model: name });
        }
        if (n.dataset.catact === 'copy') { copy(name); return toast(`Copié : ${name}`, 'success'); }
    }
    if ((n = el('[data-item]'))) { selItem = (ITEMS || []).find((x) => x.name === n.dataset.item); return render(); }
    if ((n = el('[data-icat]'))) { itemCat = n.dataset.icat; itemLimit = 300; render(); const l = document.querySelector('.items-split .list'); if (l) l.scrollTop = 0; return; }
    if ((n = el('[data-imore]'))) {
        itemLimit = n.dataset.imore === 'all' ? 100000 : itemLimit + Number(n.dataset.imore);
        const g = $('#item-grid'); if (g) g.innerHTML = itemGrid();
        content.dataset.sig = `items|${STABLE_VIEWS.items()}`;
        return;
    }
    if ((n = el('[data-gcount]'))) { give.count = Number(n.dataset.gcount); return render(); }
    if ((n = el('[data-gtarget]'))) { give.target = n.dataset.gtarget; return render(); }
    if ((n = el('[data-annimg]'))) {
        const a = annDraft();
        a.image = n.dataset.annimg === '__custom' ? (a.customUrl || 'https://') : n.dataset.annimg;
        if (n.dataset.annimg === '__custom' && !a.customUrl) a.customUrl = 'https://';
        return render();
    }
    if ((n = el('[data-revarea]'))) return selfAction('revive_preview', { radius: Number(n.dataset.revarea) });
    if ((n = el('[data-animal]'))) return selfAction('transform', { model: n.dataset.animal });
    if ((n = el('[data-qpreset]'))) { applySearchPreset(n.dataset.qpreset); return render(); }
    if ((n = el('[data-npcpreset]'))) {
        const p = D.config.editor.npcPresets.find((x) => x.id === n.dataset.npcpreset);
        drafts.pedPreset = p.id;
        drafts.pedJob = undefined; drafts.pedJobGrade = undefined;
        if (p.scenario !== undefined) drafts.pedScenario = p.scenario;
        if (p.name !== undefined) drafts.pedName = p.name;
        return render();
    }
    if ((n = el('[data-pepreset]'))) { applyPresetToPedEdit(n.dataset.pepreset); toast('Rôle appliqué. Pense à enregistrer.', 'info'); return render(); }
    if ((n = el('[data-petoggle]'))) { pedEdit[n.dataset.petoggle] = !pedEdit[n.dataset.petoggle]; return render(); }
    if ((n = el('[data-fpreset]'))) { applyFieldPreset(n.dataset.fpreset); return render(); }
    if ((n = el('[data-spreset]'))) { applyStationPreset(n.dataset.spreset); return render(); }
    if ((n = el('[data-pedmodel]'))) { drafts.pedModel = n.dataset.pedmodel; return render(); }
    if ((n = el('[data-ed]'))) return handleEditor(n);
    if ((n = el('[data-self]'))) {
        const res = await selfAction(n.dataset.self);
        if (res.coords) { copy(res.coords); toast(`Copié : ${res.coords}`, 'success'); }
        return;
    }
    if ((n = el('[data-spawn]'))) return action('spawn_vehicle', { model: n.dataset.spawn });
    if ((n = el('[data-vtool]'))) {
        if (n.dataset.vtool === 'delete' && !(await confirmBox('Supprimer le véhicule ?', 'Le véhicule le plus proche sera retiré du monde.'))) return;
        return action('vehicle_tool', { tool: n.dataset.vtool });
    }
    if ((n = el('[data-weather]'))) return action('weather', { weather: n.dataset.weather });
    if ((n = el('[data-report]'))) {
        const id = Number(n.dataset.id), kind = n.dataset.report;
        if (kind === 'claim') return action('report_claim', { id });
        if (kind === 'close') return action('report_close', { id });
        if (kind === 'goto' || kind === 'bring') {
            action('report_claim', { id });
            return action(kind, { target: Number(n.dataset.src) });
        }
    }
    if ((n = el('[data-unjail]'))) {
        if (await confirmBox('Libérer ce joueur ?', `${n.dataset.name} sera renvoyé là où il était avant son jail.`)) action('unjail', { license: n.dataset.unjail });
        return;
    }
    if ((n = el('[data-unban]'))) {
        if (await confirmBox('Débannir ce joueur ?', `${n.dataset.name} pourra de nouveau se connecter.`)) action('unban', { banId: Number(n.dataset.unban) });
        return;
    }
    if ((n = el('[data-staff-remove]'))) {
        if (await confirmBox('Retirer du staff ?', `${n.dataset.name} perdra l'accès au menu.`)) action('remove_staff', { identifier: n.dataset.staffRemove });
        return;
    }
    if ((n = el('[data-rank]'))) {
        const k = n.dataset.rank, r = D.ranks[k];
        rankDraft = { name: k, label: r.label, level: r.level, color: r.color, perms: { ...(Array.isArray(r.perms) ? {} : r.perms) }, isNew: false };
        return render();
    }
    if (el('[data-rank-new]')) {
        rankDraft = { name: '', label: '', level: 1, color: '#8a96ad', perms: {}, isNew: true };
        return render();
    }
    if ((n = el('[data-act]'))) return handleAct(n.dataset.act);
});

async function handleAct(act) {
    const t = selectedPlayer;
    const p = D.players.find((x) => x.id === t);
    const name = p ? p.name : '';

    switch (act) {
        case 'goto': case 'bring': case 'spectate': case 'heal': case 'freeze':
            return action(act, { target: t });
        case 'heal_self':
            return action('heal', { target: D.me.id });
        case 'kill':
            if (await confirmBox(`Tuer ${name} ?`, 'Le joueur tombera immédiatement à terre.')) action('kill', { target: t });
            return;
        case 'give_weapon': {
            const v = await formModal(`Donner une arme à ${name}`, [
                { name: 'weapon', label: 'Arme', type: 'select', options: D.config.weapons.map((w) => ({ value: w.id, label: w.label })) },
                { name: 'custom', label: 'Ou un nom exact (optionnel)', placeholder: 'WEAPON_…' },
            ], 'Donner');
            if (v) action('give_weapon', { target: t, weapon: v.custom.trim() || v.weapon });
            return;
        }
        case 'pm': {
            const v = await formModal(`Message privé à ${name}`, [{ name: 'message', label: 'Il le verra à l\'écran et pourra répondre avec /r', type: 'textarea' }], 'Envoyer');
            if (v && v.message && v.message.trim()) action('staff_pm', { target: t, message: v.message.trim() });
            return;
        }
        case 'warn': {
            const v = await formModal(`Avertir ${name}`, [{ name: 'reason', label: 'Raison', type: 'textarea' }], 'Envoyer l\'avertissement');
            if (v) action('warn', { target: t, reason: v.reason });
            return;
        }
        case 'kick': {
            const v = await formModal(`Expulser ${name}`, [{ name: 'reason', label: 'Raison', type: 'textarea' }], 'Expulser', true);
            if (v) action('kick', { target: t, reason: v.reason });
            return;
        }
        case 'ban': {
            const v = await formModal(`Bannir ${name}`, [
                { name: 'duration', label: 'Durée', type: 'select', options: [
                    { value: 1, label: '1 heure' }, { value: 6, label: '6 heures' }, { value: 24, label: '1 jour' },
                    { value: 72, label: '3 jours' }, { value: 168, label: '7 jours' }, { value: 720, label: '30 jours' },
                    { value: 0, label: 'Permanent' }] },
                { name: 'reason', label: 'Raison', type: 'textarea' },
            ], 'Bannir', true);
            if (v) action('ban', { target: t, duration: Number(v.duration), reason: v.reason });
            return;
        }
        case 'set_rank': {
            const opts = [{ value: 'none', label: 'Aucun (retirer du staff)' }, ...assignableRanks().map(([k, r]) => ({ value: k, label: `${r.label} (niveau ${r.level})` }))];
            const v = await formModal(`Grade de ${name}`, [{ name: 'rank', label: 'Grade', type: 'select', options: opts, value: p && p.rank }], 'Appliquer');
            if (v) action('set_rank', { target: t, rank: v.rank });
            return;
        }
        case 'tpc_go': {
            const c = parseCoords(drafts.tpcText);
            if (!c) return toast('Coordonnées non reconnues. Exemple : 215.7, -810.1, 30.7', 'error');
            drafts.tpcText = '';
            post('close');
            return tpTo(c);
        }
        case 'tp_coords':
            return selfAction('tp_coords', { x: drafts.tpx, y: drafts.tpy, z: drafts.tpz === '' ? undefined : drafts.tpz });
        case 'spawn_input':
            return spawnFromInput();
        case 'set_time':
            return action('time', { hour: Number(draft('hour', D.world.hour)), minute: Number(draft('minute', D.world.minute)) });
        case 'freeze_time': case 'blackout':
            return action(act);
        case 'announce': {
            const a = annDraft();
            if (!a.message.trim()) return toast('Écris un message avant de le diffuser.', 'error');
            const imgs = D.config.announceImages || [];
            const isCustom = a.image !== '' && !imgs.find((i) => i.url === a.image);
            const image = isCustom ? a.customUrl.trim() : a.image;
            if (isCustom && !/^https?:\/\//.test(image)) return toast("Colle un lien d'image qui commence par https://", 'error');
            if (!(await confirmBox('Diffuser cette annonce ?', 'Elle apparaîtra immédiatement en haut de l\'écran de tous les joueurs.'))) return;
            action('announce', { title: a.title, message: a.message, image, style: a.style, duration: Number(a.duration), ticker: a.ticker === true });
            drafts.ann = null;
            return render();
        }
        case 'reload_items':
            ITEMS = null; itemsAsked = Date.now();
            action('get_items', { force: true });
            return render();
        case 'item_by_code': {
            const code = (($('#item-code') || {}).value || '').trim().replace(/[^\w-]/g, '');
            if (!code) return toast("Tape le code de l'objet (ex : water, WEAPON_PISTOL).", 'error');
            selItem = (ITEMS || []).find((x) => x.name.toLowerCase() === code.toLowerCase()) || { name: code, label: code, image: '', weight: 0 };
            return render();
        }
        case 'give_item': {
            if (!selItem) return toast('Choisis un objet.', 'error');
            const count = Math.floor(Number(give.count));
            if (!count || count < 1) return toast('Indique une quantité.', 'error');
            const target = give.target === 'me' ? D.me.id : Number(give.id);
            if (!target) return toast("Indique l'ID du joueur.", 'error');
            if (count >= 100 && !(await confirmBox('Grosse quantité', `Donner ${count} × ${selItem.label} ?`))) return;
            return action('give_item', { target, item: selItem.name, count });
        }
        case 'give_to_player':
            give.target = 'player';
            give.id = t;
            tab = 'items';
            return render();
        case 'armor':
            return action('armor', { target: t });
        case 'jail': {
            if (D.hasJailPoint === false) return toast("Aucun point de jail : définis-le dans Éditeur de map › Points de spawn.", 'error');
            const durs = (D.config.editor && D.config.editor.jailDurations) || [5, 10, 15, 30, 60];
            const v = await formModal(`Mettre ${name} en prison`, [
                { name: 'minutes', label: 'Durée', type: 'select', options: durs.map((m) => ({ value: m, label: m >= 60 ? `${m / 60} h` : `${m} minutes` })).concat([{ value: 'custom', label: 'Autre durée…' }]) },
                { name: 'custom', label: 'Autre durée en minutes (si « Autre durée »)', type: 'number', placeholder: 'ex : 45' },
                { name: 'reason', label: 'Raison (affichée au joueur)', type: 'textarea' },
            ], 'Envoyer en prison', true);
            if (!v) return;
            const minutes = v.minutes === 'custom' ? Number(v.custom) : Number(v.minutes);
            if (!minutes || minutes < 1) return toast('Indique une durée.', 'error');
            return action('jail', { target: t, minutes, reason: v.reason });
        }
        case 'animal_custom': {
            const m = draft('animalModel').trim();
            if (!m) return toast('Indique un nom de modèle.', 'error');
            return selfAction('transform', { model: m });
        }
        case 'armor_self':
            return action('armor', { target: D.me.id });
        case 'revive':
            return action('revive', { target: t });
        case 'revive_me':
            return action('revive', { target: D.me.id });
        case 'revive_area_quick':
            return selfAction('revive_preview', { radius: D.config.reviveRadius });
        case 'clear_area':
            if (await confirmBox('Nettoyer la zone ?', `Véhicules vides et PNJ dans un rayon de ${draft('radius', 50)} m seront supprimés.`))
                action('clear_area', { radius: Number(draft('radius', 50)) });
            return;
        case 'save_rank': {
            const r = rankDraft;
            if (!r.name.trim()) return toast('Donne un identifiant au grade (ex : helper).', 'error');
            action('save_rank', { name: r.name, label: r.label, level: Number(r.level), color: r.color, perms: r.perms });
            return;
        }
        case 'delete_rank':
            if (await confirmBox(`Supprimer le grade ${rankDraft.label} ?`, 'Les membres ayant ce grade seront retirés du staff.')) {
                action('delete_rank', { name: rankDraft.name });
                rankDraft = null;
            }
            return;
    }
}

/* =========================================================
   MODALES, TOASTS, ANNONCES
   ========================================================= */
let modalResolve = null;

function closeModal(value = null) {
    $('#modal-root').innerHTML = '';
    if (modalResolve) { const r = modalResolve; modalResolve = null; r(value); }
}

function formModal(title, fields, confirmLabel = 'Valider', danger = false) {
    closeModal();
    const f = fields.map((x) => {
        let input;
        if (x.type === 'select') {
            input = `<select class="input" name="${x.name}">${x.options.map((o) => `<option value="${esc(o.value)}" ${String(o.value) === String(x.value) ? 'selected' : ''}>${esc(o.label)}</option>`).join('')}</select>`;
        } else if (x.type === 'textarea') {
            input = `<textarea class="input" name="${x.name}" placeholder="${esc(x.placeholder || '')}"></textarea>`;
        } else {
            input = `<input class="input" type="${x.type === 'number' ? 'number' : 'text'}" name="${x.name}" placeholder="${esc(x.placeholder || '')}" value="${esc(x.value ?? '')}">`;
        }
        return `<div class="field"><label>${esc(x.label)}</label>${input}</div>`;
    }).join('');

    $('#modal-root').innerHTML = `<div class="modal-backdrop"><div class="modal">
        <h2>${esc(title)}</h2>${f}
        <div class="btn-row"><button class="btn" data-m="cancel">Annuler</button><button class="btn ${danger ? 'danger' : 'primary'}" data-m="ok">${esc(confirmLabel)}</button></div>
    </div></div>`;
    const first = $('#modal-root .input');
    if (first) first.focus();

    return new Promise((resolve) => {
        modalResolve = resolve;
        $('#modal-root').onclick = (e) => {
            if (e.target.classList.contains('modal-backdrop') || e.target.dataset.m === 'cancel') return closeModal(null);
            if (e.target.dataset.m === 'ok') {
                const values = {};
                $('#modal-root').querySelectorAll('[name]').forEach((i) => { values[i.name] = i.value; });
                closeModal(values);
            }
        };
    });
}

function confirmBox(title, text) {
    closeModal();
    $('#modal-root').innerHTML = `<div class="modal-backdrop"><div class="modal">
        <h2>${esc(title)}</h2><p class="muted" style="margin-bottom:16px;line-height:1.5">${esc(text)}</p>
        <div class="btn-row"><button class="btn" data-m="cancel">Annuler</button><button class="btn danger" data-m="ok">Confirmer</button></div>
    </div></div>`;
    return new Promise((resolve) => {
        modalResolve = resolve;
        $('#modal-root').onclick = (e) => {
            if (e.target.classList.contains('modal-backdrop') || e.target.dataset.m === 'cancel') return closeModal(false);
            if (e.target.dataset.m === 'ok') closeModal(true);
        };
    });
}

function toast(msg, type = 'info') {
    const t = document.createElement('div');
    t.className = `toast ${type}`;
    t.textContent = msg;
    $('#toasts').appendChild(t);
    setTimeout(() => { t.classList.add('out'); setTimeout(() => t.remove(), 300); }, type === 'report' ? 8000 : 4500);
}

const STYLE_LABELS = { info: 'Annonce', event: 'Événement', alert: 'Alerte' };
const imgSrc = (img) => (img === 'logo' ? 'logo.png' : img);

function announceHTML(d) {
    const img = d.image ? `<img class="an-img" src="${esc(imgSrc(d.image))}" alt="" onerror="this.remove()">` : '';
    const title = d.title || `${STYLE_LABELS[d.style] || 'Annonce'} Elyzea`;
    const body = d.ticker
        ? `<div class="an-ticker"><span style="animation-duration:${Math.max(8, Math.min(30, (d.message || '').length / 6))}s">${esc(d.message)}</span></div>`
        : `<div class="an-body">${esc(d.message)}</div>`;
    return `${img}<div class="an-text"><div class="an-title">${esc(title)}<span class="an-by">${esc(d.by || '')}</span></div>${body}</div>`;
}

let announceTimer;
function showAnnounce(d) {
    const a = $('#announce');
    a.className = `an an-${d.style || 'info'}`;
    a.innerHTML = announceHTML(d) + `<div class="an-bar" style="animation-duration:${d.duration || 10}s"></div>`;
    clearTimeout(announceTimer);
    announceTimer = setTimeout(() => a.classList.add('hidden'), (d.duration || 10) * 1000);
}

let warnTimer;
function showWarn(reason, by) {
    const w = $('#warn');
    w.innerHTML = `<div class="box"><h2>Avertissement</h2><p>${esc(reason)}</p><small>Émis par ${esc(by)}</small></div>`;
    w.classList.remove('hidden');
    clearTimeout(warnTimer);
    warnTimer = setTimeout(() => w.classList.add('hidden'), 9000);
}

function copy(text) {
    const ta = document.createElement('textarea');
    ta.value = text;
    document.body.appendChild(ta);
    ta.select();
    document.execCommand('copy');
    ta.remove();
}


/* =========================================================
   ATELIER (interface joueur)
   ========================================================= */
let S = null;
const qty = {};

function openStation(data) {
    S = data;
    renderStation();
    $('#station').classList.remove('hidden');
}
function closeStation() {
    $('#station').classList.add('hidden');
    S = null;
    post('station_close');
}
function renderStation() {
    const el = $('#station');
    el.innerHTML = `<div class="st-box">
        <div class="st-head"><img src="logo.png" alt=""><h2>${esc(S.name)}</h2><button class="sb-close" data-st-close>✕</button></div>
        <div class="st-list">${S.recipes.length ? S.recipes.map((r) => {
            const q = qty[r.idx] || 1;
            const ok = r.inputs.every((i) => i.have >= i.count * q);
            return `<div class="st-recipe">
                <div class="st-out"><strong>${esc(r.label)}</strong><span class="muted">${r.count * q} × ${esc(r.outputLabel)} · ${r.duration * q} s</span></div>
                <div class="st-in">${r.inputs.map((i) => `<span class="${i.have >= i.count * q ? 'have' : 'miss'}">${esc(i.label)} ${i.have}/${i.count * q}</span>`).join('') || '<span class="muted">Aucun ingrédient</span>'}</div>
                <div class="st-act">
                    <div class="stepper"><button data-q="-1" data-idx="${r.idx}">−</button><span>${q}</span><button data-q="1" data-idx="${r.idx}">+</button></div>
                    <button class="btn primary" data-craft="${r.idx}" ${ok ? '' : 'disabled'}>Fabriquer</button>
                </div></div>`;
        }).join('') : '<div class="empty">Cet atelier ne propose rien pour l\'instant.</div>'}</div>
        <p class="muted st-foot">Échap pour fermer · reste près de l'atelier pendant la fabrication</p>
    </div>`;
}
$('#station').addEventListener('click', (e) => {
    if (e.target.closest('[data-st-close]')) return closeStation();
    const q = e.target.closest('[data-q]');
    if (q) {
        const idx = Number(q.dataset.idx);
        qty[idx] = Math.min(10, Math.max(1, (qty[idx] || 1) + Number(q.dataset.q)));
        return renderStation();
    }
    const c = e.target.closest('[data-craft]');
    if (c && !c.disabled) {
        const idx = Number(c.dataset.craft);
        post('craft', { stationId: S.stationId, idx, times: qty[idx] || 1 });
        $('#station').classList.add('hidden');
        S = null;
    }
});


/* =========================================================
   PNJ VENDEUR / ACHETEUR (interface joueur)
   ========================================================= */
let NPC = null;
let npcTab = 'sell';
const nq = {};

function openNpc(data) {
    const first = !NPC || NPC.id !== data.id;
    NPC = data;
    if (first) npcTab = data.buyer.length ? 'sell' : data.shop.length ? 'buy' : 'garage';
    renderNpc();
    $('#npc').classList.remove('hidden');
}
function closeNpc() {
    $('#npc').classList.add('hidden');
    NPC = null;
    post('npc_close');
}
function renderNpc() {
    const n = NPC;
    const avail = [n.buyer.length && ['sell', '💰 Lui vendre'], n.shop.length && ['buy', '🛒 Lui acheter'], n.garage && ['garage', '🚗 Garage']].filter(Boolean);
    if (!avail.find((a) => a[0] === npcTab) && avail.length) npcTab = avail[0][0];
    const tabs = avail.length > 1 ? `<div class="segmented" style="margin:0 20px 4px">
        ${avail.map(([k, l]) => `<button class="seg ${npcTab === k ? 'active' : ''}" data-npctab="${k}">${l}</button>`).join('')}</div>` : '';
    let rows = '';
    if (npcTab === 'garage' && n.garage) {
        const g = n.garage;
        if (!g.allowed) rows += `<div class="protect">🔒 <span>Ce garage est réservé : ${esc(g.jobs)}.</span></div>`;
        else if (!g.spots) rows += '<div class="protect">⚠️ <span>Ce garage n\'a pas encore de place de sortie.</span></div>';
        if (g.out) {
            rows += `<div class="st-recipe">
                <div class="st-out"><strong>🔑 ${esc(g.out.label)}</strong><span class="muted">Ton véhicule est dehors · plaque ${esc(g.out.plate)}</span></div>
                <div class="st-in"><span class="${g.out.storeOk ? 'have' : 'miss'}">${g.out.storeOk ? 'Garé près du garage' : 'Ramène-le près du garage'}</span></div>
                <div class="st-act"><button class="btn primary" data-gstore="${g.out.netId}" ${g.out.storeOk ? '' : 'disabled'}>Ranger</button></div></div>`;
        }
        const blocked = !g.allowed || !g.spots || (g.out && g.onePerPlayer);
        rows += g.vehicles.map((v) => `<div class="st-recipe">
            <div class="st-out"><strong>${esc(v.label)}</strong><span class="muted">${v.price ? `${v.price} $` : 'Gratuit'}</span></div>
            <div class="st-in">${v.price ? `<span class="${v.afford ? 'have' : 'miss'}">${v.afford ? 'Tu peux payer' : 'Pas assez d\'argent'}</span>` : ''}</div>
            <div class="st-act"><button class="btn primary" data-gtake="${v.idx}" ${blocked || !v.afford ? 'disabled' : ''}>Sortir</button></div></div>`).join('');
        if (g.out && g.onePerPlayer) rows += '<p class="hint muted" style="padding:0 4px">Range ton véhicule avant d\'en sortir un autre.</p>';
    } else if (npcTab === 'sell') {
        if (n.cooldown > 0) rows += `<div class="protect">⏳ Il ne veut plus rien pour l'instant. Reviens dans ${n.cooldown} s.</div>`;
        rows += n.buyer.map((r) => {
            const max = Math.max(1, Math.min(r.have, n.maxPerSale));
            const q = Math.min(nq['s' + r.idx] || 1, max);
            const ok = r.have >= q && n.cooldown === 0;
            return `<div class="st-recipe">
                <div class="st-out"><strong>${esc(r.label)}</strong><span class="muted">${r.min === r.max ? r.min : `${r.min} à ${r.max}`} $ l'unité · max ${n.maxPerSale} par vente</span></div>
                <div class="st-in"><span class="${r.have > 0 ? 'have' : 'miss'}">Tu en as ${r.have}</span></div>
                <div class="st-act">
                    <div class="stepper"><button data-nq="-1" data-k="s${r.idx}" data-max="${max}">−</button><span>${q}</span><button data-nq="1" data-k="s${r.idx}" data-max="${max}">+</button></div>
                    <button class="btn primary" data-npcsell="${r.idx}" ${ok ? '' : 'disabled'}>Vendre</button>
                </div></div>`;
        }).join('');
    } else {
        rows += n.shop.map((r) => {
            const q = nq['b' + r.idx] || 1;
            const ok = n.money >= r.price * q;
            return `<div class="st-recipe">
                <div class="st-out"><strong>${esc(r.label)}</strong><span class="muted">${r.price} $ l'unité</span></div>
                <div class="st-in"><span class="${ok ? 'have' : 'miss'}">Total : ${r.price * q} $</span></div>
                <div class="st-act">
                    <div class="stepper"><button data-nq="-1" data-k="b${r.idx}" data-max="100">−</button><span>${q}</span><button data-nq="1" data-k="b${r.idx}" data-max="100">+</button></div>
                    <button class="btn primary" data-npcbuy="${r.idx}" ${ok ? '' : 'disabled'}>Acheter</button>
                </div></div>`;
        }).join('');
    }
    $('#npc').innerHTML = `<div class="st-box">
        <div class="st-head"><img src="logo.png" alt=""><h2>${esc(n.name)}</h2><button class="sb-close" data-npc-close>✕</button></div>
        <p class="muted" style="padding:10px 20px 0;font-size:13px">${esc(n.payment)} : <b style="color:var(--text)">${n.money} ${n.payment === 'Liquide' || n.payment === 'Banque' ? '$' : ''}</b></p>
        ${tabs}
        <div class="st-list">${rows || '<div class="empty">Rien pour le moment.</div>'}</div>
        <p class="muted st-foot">Échap pour fermer</p>
    </div>`;
}
$('#npc').addEventListener('click', (e) => {
    if (e.target.closest('[data-npc-close]')) return closeNpc();
    const t = e.target.closest('[data-npctab]');
    if (t) { npcTab = t.dataset.npctab; return renderNpc(); }
    const q = e.target.closest('[data-nq]');
    if (q) {
        nq[q.dataset.k] = Math.min(Number(q.dataset.max), Math.max(1, (nq[q.dataset.k] || 1) + Number(q.dataset.nq)));
        return renderNpc();
    }
    const s = e.target.closest('[data-npcsell]');
    if (s && !s.disabled) { s.disabled = true; return post('npc_sell', { id: NPC.id, idx: Number(s.dataset.npcsell), qty: nq['s' + s.dataset.npcsell] || 1 }); }
    const b = e.target.closest('[data-npcbuy]');
    if (b && !b.disabled) { b.disabled = true; return post('npc_buy', { id: NPC.id, idx: Number(b.dataset.npcbuy), qty: nq['b' + b.dataset.npcbuy] || 1 }); }
    const gt = e.target.closest('[data-gtake]');
    if (gt && !gt.disabled) { gt.disabled = true; return post('npc_garage_take', { id: NPC.id, idx: Number(gt.dataset.gtake) }); }
    const gs = e.target.closest('[data-gstore]');
    if (gs && !gs.disabled) { gs.disabled = true; return post('npc_garage_store', { id: NPC.id, netId: Number(gs.dataset.gstore) }); }
});


/* =========================================================
   LISTE DES TOUCHES (bas à droite) : noclip, placement…
   ========================================================= */
const HUD_KEYS = {
    SPACE: 'Espace', LCONTROL: 'Ctrl', RCONTROL: 'Ctrl', LSHIFT: 'Shift', RSHIFT: 'Shift', LMENU: 'Alt', RMENU: 'Alt',
    BACK: 'Retour', RETURN: 'Entrée', PRIOR: 'Page ↑', NEXT: 'Page ↓', DELETE: 'Suppr', TAB: 'Tab',
    IOM_WHEEL_UP: 'Molette ↑', IOM_WHEEL_DOWN: 'Molette ↓', MOUSE_LEFT: 'Clic G', MOUSE_RIGHT: 'Clic D', MOUSE_MIDDLE: 'Clic molette',
};
function renderKeysHud(m) {
    const el = $('#keyshud');
    if (!m.show) { el.classList.add('hidden'); return; }
    el.innerHTML = `<div class="kh-title">${esc(m.title || '')}</div>
        ${(m.rows || []).map((r) => {
            let keys = (r.keys || []).filter(Boolean);
            if (keys.includes('IOM_WHEEL_UP') && keys.includes('IOM_WHEEL_DOWN')) keys = keys.filter((k) => !k.startsWith('IOM_WHEEL')).concat(['Molette']);
            return `<div class="kh-row"><span class="kh-keys">${keys.map((k) => `<span class="keycap">${esc(HUD_KEYS[k] || k)}</span>`).join('')}</span><span class="kh-label">${esc(r.label)}</span></div>`;
        }).join('')}
        ${m.footer ? `<div class="kh-foot">${esc(m.footer)}</div>` : ''}`;
    el.classList.remove('hidden');
}


/* =========================================================
   MESSAGE D'ENTRÉE / SORTIE DE ZONE (pour tous les joueurs)
   ========================================================= */
let zoneTimer;
function showZoneMsg(m) {
    const el = $('#zonemsg');
    el.innerHTML = zoneBannerHTML(m.text, m.color || '#d9b56a', m.safe);
    el.classList.remove('hidden', 'zm-out');
    void el.offsetWidth; // relance l'animation
    el.classList.add('zm-in');
    clearTimeout(zoneTimer);
    zoneTimer = setTimeout(() => { el.classList.add('zm-out'); setTimeout(() => el.classList.add('hidden'), 500); }, 4000);
}


/* =========================================================
   PORTE (interface joueur) : verrou, code, clavier
   ========================================================= */
let DOOR = null, doorCode = '', doorNewCode = '';
function openDoor(d) {
    const changed = !DOOR || DOOR.id !== d.id;
    DOOR = d;
    if (changed) { doorCode = ''; doorNewCode = ''; }
    renderDoor();
    $('#door').classList.remove('hidden');
}
function closeDoor() { $('#door').classList.add('hidden'); DOOR = null; post('door_close'); }
function renderDoor() {
    const d = DOOR;
    const state = `<div class="door-state ${d.locked ? 'locked' : 'open'}">${d.locked ? '🔒 Verrouillée' : '🔓 Ouverte'}</div>`;
    let body = '';
    if (d.role === 'owner' || d.role === 'admin') {
        body = `<button class="btn primary big" style="width:100%" data-door="toggle">${d.locked ? '🔓 Déverrouiller' : '🔒 Verrouiller'}</button>
            <div class="door-sep"></div>
            <h3 class="sub-h" style="font-size:16px">Code d'accès pour les invités</h3>
            <p class="hint">${d.hasCode ? 'Un code est défini. Les personnes qui le connaissent peuvent ouvrir et fermer.' : 'Aucun code : seuls les détenteurs des clés peuvent ouvrir.'}</p>
            <div class="inline"><input class="input" id="door-newcode" inputmode="numeric" maxlength="8" placeholder="Nouveau code (4 à 8 chiffres)" value="${esc(doorNewCode)}">
                <button class="btn" data-door="setcode">${d.hasCode ? 'Changer' : 'Créer'}</button></div>
            ${d.hasCode ? '<button class="btn danger" style="margin-top:8px" data-door="delcode">Supprimer le code</button>' : ''}
            ${d.role === 'admin' ? '<p class="hint" style="margin-top:10px">Tu ouvres en tant que staff.</p>' : ''}`;
    } else if (d.hasCode) {
        body = `<p class="hint" style="text-align:center">Entre le code pour ${d.locked ? 'ouvrir' : 'fermer'} :</p>
            <div class="keypad-screen">${doorCode ? '•'.repeat(doorCode.length) : '<span class="muted">— — — —</span>'}</div>
            <div class="keypad">${[1, 2, 3, 4, 5, 6, 7, 8, 9].map((n) => `<button data-key="${n}">${n}</button>`).join('')}
                <button data-key="clear">⌫</button><button data-key="0">0</button><button data-key="ok" class="ok">OK</button></div>`;
    } else {
        body = '<p class="hint" style="text-align:center">Cette porte est verrouillée. Seul le propriétaire peut l\'ouvrir.</p>';
    }
    $('#door').innerHTML = `<div class="st-box door-box">
        <div class="st-head"><img src="logo.png" alt=""><h2>${esc(d.name)}</h2><button class="sb-close" data-door="close">✕</button></div>
        <div style="padding:16px 20px">${state}${body}</div>
        <p class="muted st-foot">Échap pour fermer</p></div>`;
}
$('#door').addEventListener('input', (e) => { if (e.target.id === 'door-newcode') doorNewCode = e.target.value.replace(/\D/g, '').slice(0, 8); });
$('#door').addEventListener('click', (e) => {
    const k = e.target.closest('[data-key]');
    if (k) {
        if (k.dataset.key === 'clear') doorCode = doorCode.slice(0, -1);
        else if (k.dataset.key === 'ok') { if (doorCode) post('door_toggle', { id: DOOR.id, code: doorCode }); doorCode = ''; }
        else if (doorCode.length < 8) doorCode += k.dataset.key;
        return renderDoor();
    }
    const b = e.target.closest('[data-door]');
    if (!b) return;
    const a = b.dataset.door;
    if (a === 'close') return closeDoor();
    if (a === 'toggle') return post('door_toggle', { id: DOOR.id });
    if (a === 'setcode') {
        if (doorNewCode.length < 4) return toast('Le code doit faire au moins 4 chiffres.', 'error');
        post('door_setcode', { id: DOOR.id, code: doorNewCode }); doorNewCode = ''; return;
    }
    if (a === 'delcode') return post('door_setcode', { id: DOOR.id, code: '' });
});

/* =========================================================
   PRISON : temps restant affiché en permanence
   ========================================================= */
function jailHud(m) {
    const el = $('#jailhud');
    if (!m.show) { el.classList.add('hidden'); return; }
    el.innerHTML = `<div class="jh-title">⛓️ Tu es en prison</div><div class="jh-time">${esc(m.time)}</div>
        <div class="jh-reason">${esc(m.reason || '')}</div>`;
    el.classList.remove('hidden');
}
