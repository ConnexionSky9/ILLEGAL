/* =========================================================
   ILLEGAL
   Gestion des groupes illégaux (ressource elyzea_illegal) : gangs,
   organisations, cartels, grades, membres, argent propre / sale,
   PNJ, commandes et paramètres.
   ========================================================= */
(() => {
    TAB_GROUP_TITLES[6] = 'Illégal';
    TABS.push({
        id: 'illegal', group: 6, label: 'ILLEGAL', ico: '🩸',
        sub: 'Gestion Illegal : gangs, organisations et cartels (grades, membres, finances, PNJ, commandes).',
        show: () => has('illegal_staff') && !!(D && D.illegal),
    });

    const SUBS = [
        { id: 'info', label: 'Informations' },
        { id: 'members', label: 'Membres' },
        { id: 'grades', label: 'Grades' },
        { id: 'finances', label: 'Finances' },
        { id: 'ped', label: 'PED' },
        { id: 'stash', label: 'Coffre' },
        { id: 'orders', label: 'Commandes' },
        { id: 'settings', label: 'Paramètres' },
    ];
    const IL = { sub: 'info', groupId: null, permEdit: null, permDraft: null, settings: null, pedMenu: null, itemsAsked: false, items: null };
    const send = (name, data = {}) => action('illegal', { name, data });
    const money = (n) => `${Number(n || 0).toLocaleString('fr-FR')} $`;
    const signed = (n) => `<span style="color:var(${n >= 0 ? '--ok' : '--danger'})">${n >= 0 ? '+' : '−'}${money(Math.abs(n))}</span>`;
    const date = (t) => (t ? new Date(t * 1000).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—');
    const ACCOUNTS = { clean: 'Argent propre', dirty: 'Argent sale' };
    const PAYMENTS = { clean: 'Argent propre', dirty: 'Argent sale', both: 'Propre ou sale' };
    const TX = { deposit: 'Dépôt', withdraw: 'Retrait', admin_add: 'Ajout staff', admin_remove: 'Retrait staff', order: 'Commande' };
    const STATUS = { pending: 'En attente de validation', preparing: 'En préparation', ready: 'Prête : point GPS envoyé', delivered: 'Livrée', refused: 'Refusée', cancelled: 'Annulée' };
    const hhmm = (t) => (t ? new Date(t * 1000).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' }) : '');
    // Liste des objets ox_inventory : demandée une fois quand on ouvre l'onglet (pour choisir ce qui se commande)
    const askItems = () => { if (!IL.itemsAsked) { IL.itemsAsked = true; setTimeout(() => send('loadItems'), 0); } };
    const itemLabel = (name) => { const it = (IL.items || []).find((x) => x.name === name); return it ? `${it.label} (${name})` : name; };
    const typeOpts = () => D.illegal.types.map((t) => ({ value: t.key, label: t.label }));
    const typeColor = (k) => (D.illegal.types.find((t) => t.key === k) || {}).color || 'var(--muted)';
    const sel = () => D.illegal.selected;

    // Une table Lua vide peut arriver en {} au lieu de [] : on remet les listes d'aplomb
    const arr = (x) => (Array.isArray(x) ? x : Object.values(x || {}));
    const normalize = (d) => {
        if (d.normalized) return;
        ['groups', 'globalOrders', 'types', 'permissions', 'tabs', 'categories', 'spots'].forEach((k) => { d[k] = arr(d[k]); });
        if (d.items) IL.items = arr(d.items);
        if (d.stashConfig) d.stashConfig.models = arr(d.stashConfig.models);
        d.groups.forEach((g) => { g.og = arr(g.og); });
        const g = d.selected;
        if (g) {
            ['memberList', 'grades', 'orders', 'requests', 'logs', 'og', 'stashGrades'].forEach((k) => { g[k] = arr(g[k]); });
            g.finance.history = arr(g.finance.history);
            g.grades.forEach((gr) => { gr.perms = gr.perms && !Array.isArray(gr.perms) ? gr.perms : {}; });
        }
        d.normalized = true;
    };

    // Brouillons remis à zéro quand on change de groupe
    const syncDrafts = () => {
        const g = sel();
        if (!g) { IL.groupId = null; return; }
        if (IL.groupId !== g.id) {
            IL.groupId = g.id; IL.sub = 'info'; IL.permEdit = null; IL.permDraft = null; IL.settings = null; IL.pedMenu = null;
        }
    };

    VIEWS.illegal = () => {
        const d = D.illegal;
        if (!d.available) {
            return `<div class="protect">⚠️ <span>La ressource <b>${esc(d.resource || 'elyzea_illegal')}</b> n'est pas démarrée.
                Ajoute <span class="keycap">ensure ${esc(d.resource || 'elyzea_illegal')}</span> dans server.cfg, après admin_menu.</span></div>`;
        }
        if (d.loading) return '<div class="empty">Chargement du module illégal…</div>';
        normalize(d);
        askItems();
        syncDrafts();
        if (!sel()) return dashboard(d);
        const g = sel();
        const nav = `<div class="btn-row" style="margin-bottom:12px;align-items:center"><button class="btn" data-ila="back">← Tous les groupes</button>
            <span style="font-family:var(--display);font-size:22px;font-weight:700">${esc(g.label)}</span>
            <span class="badge" style="color:${typeColor(g.type)}">${esc(g.typeLabel)}</span><span class="muted">${esc(g.name)}</span></div>
            <div class="segmented">${SUBS.map((s) => `<button class="seg ${s.id === IL.sub ? 'active' : ''}" data-ils="${s.id}">${s.label}</button>`).join('')}</div>`;
        return nav + (SUBVIEWS[IL.sub] || SUBVIEWS.info)(g);
    };

    /* ---------- Dashboard + liste des groupes ---------- */
    function dashboard(d) {
        const s = d.stats;
        return `
            <div class="stats">
                <div class="stat"><b>${s.groups}</b><span>Groupes</span></div>
                <div class="stat"><b>${s.members}</b><span>Membres</span></div>
                <div class="stat"><b>${s.gang || 0}</b><span>Gangs</span></div>
                <div class="stat"><b>${s.organisation || 0}</b><span>Organisations</span></div>
                <div class="stat"><b>${s.cartel || 0}</b><span>Cartels</span></div>
                <div class="stat"><b style="font-size:26px;color:var(--ok)">${money(s.clean)}</b><span>Argent propre total</span></div>
                <div class="stat"><b style="font-size:26px;color:var(--danger)">${money(s.dirty)}</b><span>Argent sale total</span></div>
            </div>
            <div class="section"><h2>Groupes (${d.groups.length})</h2>
                <div class="btn-row" style="margin-bottom:12px"><button class="btn primary" data-ila="createGroup">+ Créer un groupe</button></div>
                ${d.groups.length ? `<table><tr><th>Nom</th><th>Type</th><th>Membres</th><th>OG</th><th>Argent propre</th><th>Argent sale</th><th>PED</th><th></th></tr>
                ${d.groups.map((g) => `<tr>
                    <td><strong style="color:${esc(g.color)}">●</strong> <strong>${esc(g.label)}</strong> <span class="muted">${esc(g.name)}</span></td>
                    <td><span class="badge" style="color:${typeColor(g.type)}">${esc(g.typeLabel)}</span></td>
                    <td>${g.members}</td>
                    <td>${esc(g.og.join(', ') || '—')}</td>
                    <td>${money(g.clean)}</td><td>${money(g.dirty)}</td>
                    <td>${g.ped ? `<span class="muted">${esc(g.ped)}</span>` : '<span class="muted">—</span>'}</td>
                    <td style="text-align:right"><button class="btn primary" data-ila="select" data-id="${g.id}">Gérer</button></td></tr>`).join('')}</table>`
                    : '<div class="empty">Aucun groupe illégal. Crée le premier avec « + Créer un groupe ».</div>'}
            </div>
            <div class="section"><h2>Commandes proposées à tous les groupes (${d.globalOrders.length})</h2>
                <p class="hint">Visibles dans la tablette de chaque groupe. Le catalogue propre à un groupe se règle dans <b>Gérer › Commandes</b>.</p>
                <div class="btn-row" style="margin-bottom:12px"><button class="btn" data-ila="createOrder" data-global="1">+ Créer une commande pour tous</button></div>
                ${ordersTable(d.globalOrders)}
            </div>
            <div class="section"><h2>Points de livraison (${d.spots.length})</h2>
                <p class="hint">Lieux cachés où le chef (bras croisés) et ses gardes armés attendent avec le sac, ${d.delivery.prepareMinutes} minutes après la commande.
                Le lieu choisi est à plus de ${Math.round(d.delivery.minDistance)} m du joueur quand c'est possible.
                ${d.spots.length ? '' : `<b>Aucun point placé : les ${d.defaultSpots} lieux par défaut de config.lua sont utilisés.</b>`}
                Le chef est placé à ta position, tourné dans ta direction ; le sac est posé devant lui.</p>
                <div class="btn-row" style="margin-bottom:12px"><button class="btn primary" data-ila="addSpot">📍 Ajouter un point à ma position</button></div>
                ${d.spots.length ? `<table><tr><th>Nom</th><th>Coordonnées</th><th></th></tr>
                ${d.spots.map((s) => `<tr><td><strong>${esc(s.label)}</strong></td><td class="muted">${s.x.toFixed(1)}, ${s.y.toFixed(1)}, ${s.z.toFixed(1)} · ${s.h.toFixed(0)}°</td>
                    <td style="text-align:right;white-space:nowrap"><button class="btn" data-ila="gotoSpot" data-sid="${s.id}">Y aller</button>
                    <button class="btn danger" data-ila="removeSpot" data-sid="${s.id}">✕</button></td></tr>`).join('')}</table>` : ''}
            </div>`;
    }

    function ordersTable(list) {
        if (!list.length) return '<div class="empty">Aucune commande.</div>';
        const cat = (k) => D.illegal.categories.find((c) => c.key === k) || { label: k, ico: '📦' };
        return `<table><tr><th>Nom</th><th>Type</th><th>Prix</th><th>Paiement</th><th>Objet livré</th><th>Disponible</th><th></th></tr>
            ${list.map((o) => `<tr><td><strong>${esc(o.name)}</strong><br><span class="muted">${esc(o.description)}</span></td>
                <td>${cat(o.category).ico} ${esc(cat(o.category).label)}</td><td>${money(o.price)}</td><td>${PAYMENTS[o.payment]}</td>
                <td>${o.item ? `${esc(itemLabel(o.item))} x${o.itemCount}` : '<span class="muted">— (RP)</span>'}</td>
                <td><div class="tile toggle-tile ${o.available ? 'on' : ''}" data-ila="toggleOrder" data-oid="${o.id}" style="padding:6px 8px"><span></span><div class="switch"></div></div></td>
                <td style="text-align:right;white-space:nowrap"><button class="btn" data-ila="editOrder" data-oid="${o.id}">Modifier</button>
                    <button class="btn danger" data-ila="deleteOrder" data-oid="${o.id}">✕</button></td></tr>`).join('')}</table>`;
    }

    const SUBVIEWS = {};

    /* ---------- Informations ---------- */
    SUBVIEWS.info = (g) => `
        <div class="stats">
            <div class="stat" data-ils="members"><b>${g.members}</b><span>Membres · ${g.memberList.filter((m) => m.online).length} en ligne</span></div>
            <div class="stat" data-ils="grades"><b>${g.grades.length}</b><span>Grades</span></div>
            <div class="stat" data-ils="finances"><b style="font-size:26px;color:var(--ok)">${money(g.clean)}</b><span>Argent propre</span></div>
            <div class="stat" data-ils="finances"><b style="font-size:26px;color:var(--danger)">${money(g.dirty)}</b><span>Argent sale</span></div>
            <div class="stat" data-ils="ped"><b style="font-size:20px">${g.ped ? esc(g.ped) : 'Aucun'}</b><span>PED</span></div>
            <div class="stat" data-ils="stash"><b style="font-size:20px">${g.stashData ? `${g.stashData.weight} kg` : 'Aucun'}</b><span>Coffre${g.stashData ? ` · ${g.stashData.slots} places` : ''}</span></div>
        </div>
        <div class="section"><h2>Informations</h2>
            <table>
                <tr><td class="muted" style="width:180px">Nom affiché</td><td><strong>${esc(g.label)}</strong></td></tr>
                <tr><td class="muted">Nom interne</td><td>${esc(g.name)}</td></tr>
                <tr><td class="muted">Type</td><td>${esc(g.typeLabel)}</td></tr>
                <tr><td class="muted">Description</td><td>${esc(g.description || '—')}</td></tr>
                <tr><td class="muted">OG</td><td>${esc(g.og.join(', ') || '—')}</td></tr>
                <tr><td class="muted">Créé</td><td>${date(g.created)} ${g.createdBy ? `par ${esc(g.createdBy)}` : ''}</td></tr>
            </table>
        </div>
        <div class="section"><h2>Journal du groupe</h2>
            ${g.logs.length ? g.logs.map((l) => `<div class="mini-row"><span class="t" style="min-width:120px">${date(l.created)}</span><span><b>${esc(l.action)}</b> · ${esc(l.details || l.actor)}</span></div>`).join('')
                : '<p class="muted">Rien pour le moment.</p>'}
        </div>`;

    /* ---------- Membres ---------- */
    SUBVIEWS.members = (g) => `
        <div class="section"><h2>Membres (${g.memberList.length})</h2>
            <div class="btn-row" style="margin-bottom:12px"><button class="btn primary" data-ila="addMember">+ Ajouter un membre</button></div>
            ${g.memberList.length ? `<table><tr><th>Nom</th><th>ID</th><th>Grade</th><th>Statut</th><th>Dernière connexion</th><th></th></tr>
            ${g.memberList.map((m) => `<tr>
                <td><strong>${esc(m.name)}</strong><br><span class="muted">${esc(m.cid)}</span></td>
                <td>${m.online ? m.id : '<span class="muted">—</span>'}</td>
                <td>${esc(m.grade)}${m.boss ? ' <span class="badge" style="color:var(--signal)">OG</span>' : ''}</td>
                <td>${m.online ? '<span class="badge" style="color:var(--ok)">En ligne</span>' : '<span class="badge muted">Hors ligne</span>'}</td>
                <td class="muted">${m.online ? 'Maintenant' : date(m.lastSeen)}</td>
                <td style="text-align:right;white-space:nowrap">
                    <button class="btn" data-ila="promote" data-cid="${esc(m.cid)}" title="Promouvoir">↑</button>
                    <button class="btn" data-ila="demote" data-cid="${esc(m.cid)}" title="Rétrograder">↓</button>
                    <button class="btn" data-ila="setGrade" data-cid="${esc(m.cid)}">Grade</button>
                    <button class="btn danger" data-ila="removeMember" data-cid="${esc(m.cid)}">Retirer</button></td></tr>`).join('')}</table>`
                : '<div class="empty">Aucun membre.</div>'}
        </div>`;

    /* ---------- Grades ---------- */
    const permCount = (gr) => (gr.boss ? 'Toutes' : `${Object.keys(gr.perms || {}).length} / ${D.illegal.permissions.length}`);

    SUBVIEWS.grades = (g) => {
        const list = [...g.grades].reverse();
        return `
            <div class="section"><h2>Grades</h2>
                <p class="hint">Le <b>niveau</b> fixe la hiérarchie (plus haut = plus fort) : un membre n'agit que sur les grades inférieurs au sien.
                Un grade <b>OG / chef</b> a toutes les permissions. Les membres d'un grade supprimé passent au grade juste en dessous.</p>
                <div class="btn-row" style="margin-bottom:12px"><button class="btn primary" data-ila="createGrade">+ Créer un grade</button></div>
                <table><tr><th>Niveau</th><th>Label</th><th>Nom</th><th>Membres</th><th>Permissions</th><th></th></tr>
                ${list.map((gr, i) => `<tr>
                    <td><span class="keycap">${gr.level}</span></td>
                    <td><strong>${esc(gr.label)}</strong>${gr.boss ? ' <span class="badge" style="color:var(--signal)">OG</span>' : ''}</td>
                    <td class="muted">${esc(gr.name)}</td><td>${gr.members}</td><td>${permCount(gr)}</td>
                    <td style="text-align:right;white-space:nowrap">
                        <button class="btn" data-ila="moveGrade" data-gid="${gr.id}" data-dir="1" ${i === 0 ? 'disabled' : ''} title="Monter">↑</button>
                        <button class="btn" data-ila="moveGrade" data-gid="${gr.id}" data-dir="-1" ${i === list.length - 1 ? 'disabled' : ''} title="Descendre">↓</button>
                        <button class="btn ${IL.permEdit === gr.id ? 'on' : ''}" data-ila="editPerms" data-gid="${gr.id}" ${gr.boss ? 'disabled' : ''}>Permissions</button>
                        <button class="btn" data-ila="editGrade" data-gid="${gr.id}">Modifier</button>
                        <button class="btn danger" data-ila="deleteGrade" data-gid="${gr.id}" ${g.grades.length <= 1 ? 'disabled' : ''}>✕</button></td></tr>`).join('')}
                </table>
            </div>
            ${permEditor(g)}`;
    };

    function permEditor(g) {
        const gr = g.grades.find((x) => x.id === IL.permEdit);
        if (!gr) return '';
        if (!IL.permDraft) IL.permDraft = { ...(gr.perms || {}) };
        let lastCat = null;
        return `<div class="section"><h2>Permissions : ${esc(gr.label)}</h2>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(250px,1fr))">
            ${D.illegal.permissions.map((p) => {
                const head = p.cat !== lastCat ? `<div style="grid-column:1/-1;color:var(--signal);font-family:var(--display);font-weight:600;margin-top:6px">${esc(p.cat)}</div>` : '';
                lastCat = p.cat;
                return `${head}<div class="tile toggle-tile ${IL.permDraft[p.key] ? 'on' : ''}" data-ilp="${p.key}"><div><strong>${esc(p.label)}</strong></div><div class="switch"></div></div>`;
            }).join('')}</div>
            <div class="btn-row" style="margin-top:12px"><button class="btn" data-ila="permAll">Tout</button><button class="btn" data-ila="permNone">Rien</button>
                <span style="flex:1"></span><button class="btn" data-ila="permCancel">Annuler</button><button class="btn primary" data-ila="permSave">Enregistrer les permissions</button></div>
        </div>`;
    }

    /* ---------- Finances ---------- */
    SUBVIEWS.finances = (g) => {
        const block = (acc) => `<div class="section" style="background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:16px">
            <h2>${ACCOUNTS[acc]}</h2>
            <div style="font-family:var(--display);font-size:34px;font-weight:700;color:var(${acc === 'clean' ? '--ok' : '--danger'});margin-bottom:12px">${money(g.finance[acc])}</div>
            <div class="btn-row"><button class="btn primary" data-ila="money" data-acc="${acc}" data-add="1">Ajouter</button>
                <button class="btn danger" data-ila="money" data-acc="${acc}" data-add="0">Retirer</button></div></div>`;
        const h = g.finance.history;
        return `<div style="display:grid;grid-template-columns:1fr 1fr;gap:14px">${block('clean')}${block('dirty')}</div>
            <div class="section"><h2>Historique financier (${h.length} dernières opérations)</h2>
                ${h.length ? `<table><tr><th>Date</th><th>Joueur</th><th>Type</th><th>Compte</th><th>Montant</th><th>Solde avant → après</th></tr>
                ${h.map((t) => `<tr><td class="muted">${date(t.created)}</td><td>${esc(t.actor)}</td>
                    <td>${TX[t.type] || esc(t.type)}${t.reason ? `<br><span class="muted">${esc(t.reason)}</span>` : ''}</td>
                    <td>${ACCOUNTS[t.account] || ''}</td><td>${signed(t.amount)}</td><td class="muted">${money(t.before)} → ${money(t.after)}</td></tr>`).join('')}</table>`
                    : '<div class="empty">Aucune transaction.</div>'}
            </div>`;
    };

    /* ---------- PED ---------- */
    const tabToggles = (attr, set) => `<div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(200px,1fr))">
        ${D.illegal.tabs.map((t) => `<div class="tile toggle-tile ${set[t.key] ? 'on' : ''}" ${t.key === 'home' ? '' : `${attr}="${t.key}"`} style="${t.key === 'home' ? 'opacity:.6;cursor:default' : ''}">
            <div><strong>${esc(t.label)}</strong>${t.key === 'home' ? '<span>Toujours accessible</span>' : ''}</div><div class="switch"></div></div>`).join('')}</div>`;

    SUBVIEWS.ped = (g) => {
        const p = g.pedData;
        if (!p) {
            return `<div class="section"><h2>PED</h2>
                <p class="hint">Aucun PED. Les membres du groupe ouvrent le menu du groupe en appuyant sur <b>E</b> à côté de lui.</p>
                <div class="btn-row"><button class="btn primary" data-ila="addPed">📍 Ajouter un PED à ma position</button></div></div>`;
        }
        if (!IL.pedMenu) IL.pedMenu = { ...p.menu };
        return `<div class="section"><h2>PED</h2>
                <table>
                    <tr><td class="muted" style="width:180px">Modèle</td><td><strong>${esc(p.model)}</strong></td></tr>
                    <tr><td class="muted">Coordonnées</td><td>${p.x.toFixed(2)}, ${p.y.toFixed(2)}, ${p.z.toFixed(2)}</td></tr>
                    <tr><td class="muted">Heading</td><td>${p.h.toFixed(1)}°</td></tr>
                    <tr><td class="muted">Animation</td><td>${esc(p.scenario || '—')}</td></tr>
                </table>
                <div class="btn-row" style="margin-top:12px">
                    <button class="btn" data-ila="gotoPed">Téléporter vers le PED</button>
                    <button class="btn" data-ila="pedHere">📍 Déplacer le PED à ma position</button>
                    <button class="btn" data-ila="pedCoords">🎯 Modifier les coordonnées</button>
                    <button class="btn" data-ila="pedHeading">Modifier le heading</button>
                    <button class="btn" data-ila="pedModel">Modifier le modèle</button>
                    <button class="btn" data-ila="respawnPed">Respawn</button>
                    <button class="btn danger" data-ila="removePed">Supprimer le PED</button>
                </div></div>
            <div class="section"><h2>Menu accessible depuis le PED</h2>
                <p class="hint">Onglets de la tablette ouverts avec <b>E</b> à côté du PED (toujours limités par les permissions du grade).</p>
                ${tabToggles('data-ilpm', IL.pedMenu)}
                <div class="btn-row" style="margin-top:12px"><button class="btn primary" data-ila="savePedMenu">Enregistrer</button></div></div>`;
    };

    /* ---------- Coffre ---------- */
    const stashModelLabel = (m) => (D.illegal.stashConfig.models.find((x) => x.model === m) || { label: m }).label;
    SUBVIEWS.stash = (g) => {
        const s = g.stashData;
        const access = `<p class="hint">Accès : grades avec la permission <b>« Accès au coffre du groupe »</b>
            (${g.stashGrades.length ? esc(g.stashGrades.join(', ')) : 'aucun'}). Le OG la donne aux grades qu'il veut depuis sa tablette (Grades),
            ou toi depuis l'onglet <b>Grades</b> › Permissions.</p>`;
        if (!s) {
            return `<div class="section"><h2>Coffre du groupe</h2>
                <p class="hint">Un inventaire partagé posé sur la map : poids et nombre de places au choix. Place-toi à l'endroit voulu.</p>${access}
                <div class="btn-row"><button class="btn primary" data-ila="addStash">📍 Placer un coffre à ma position</button></div></div>`;
        }
        return `<div class="section"><h2>Coffre du groupe</h2>
                <table>
                    <tr><td class="muted" style="width:180px">Nom</td><td><strong>${esc(s.label)}</strong></td></tr>
                    <tr><td class="muted">Objet</td><td>${esc(stashModelLabel(s.model))} <span class="muted">${esc(s.model)}</span></td></tr>
                    <tr><td class="muted">Poids maximum</td><td>${s.weight} kg</td></tr>
                    <tr><td class="muted">Places</td><td>${s.slots}</td></tr>
                    <tr><td class="muted">Position</td><td>${s.x.toFixed(2)}, ${s.y.toFixed(2)}, ${s.z.toFixed(2)} · ${s.h.toFixed(0)}°</td></tr>
                </table>
                ${access}
                <div class="btn-row" style="margin-top:12px">
                    <button class="btn primary" data-ila="editStash">Modifier (nom, objet, poids, places)</button>
                    <button class="btn" data-ila="gotoStash">Téléporter vers le coffre</button>
                    <button class="btn" data-ila="stashHere">📍 Déplacer le coffre à ma position</button>
                    <button class="btn danger" data-ila="removeStash">Supprimer le coffre</button>
                </div></div>`;
    };

    /* ---------- Commandes ---------- */
    SUBVIEWS.orders = (g) => `
        <div class="section"><h2>Commandes du groupe (${g.orders.length})</h2>
            <p class="hint">Choisis ce que ce groupe peut commander et à quel prix : une fois enregistré, ses membres le voient dans leur tablette et peuvent commander.
            ${D.illegal.delivery.requireValidation ? 'Un grade autorisé valide, puis le' : 'Le'} coffre du groupe paie ; ${D.illegal.delivery.prepareMinutes} minutes plus tard
            le joueur reçoit un point GPS et récupère le sac devant le chef. Le groupe voit aussi les commandes proposées à tous.</p>
            <div class="btn-row" style="margin-bottom:12px"><button class="btn primary" data-ila="createOrder">+ Créer une commande</button></div>
            ${ordersTable(g.orders)}
        </div>
        <div class="section"><h2>Demandes de commande</h2>
            ${g.requests.length ? `<table><tr><th>Date</th><th>Commande</th><th>Par</th><th>Total</th><th>Statut</th><th></th></tr>
            ${g.requests.map((r) => `<tr><td class="muted">${date(r.created)}</td><td>${r.quantity}x ${esc(r.orderName)}</td><td>${esc(r.requester)}</td>
                <td>${money(r.total)}<br><span class="muted">${ACCOUNTS[r.account]}</span></td>
                <td>${STATUS[r.status] || esc(r.status)}${r.status === 'preparing' && r.readyAt ? ` · prête vers ${hhmm(r.readyAt)}` : ''}
                    ${r.spot && (r.status === 'preparing' || r.status === 'ready') ? `<br><span class="muted">📍 ${esc(r.spot)}</span>` : ''}${r.handledBy ? `<br><span class="muted">${esc(r.handledBy)}</span>` : ''}</td>
                <td style="text-align:right;white-space:nowrap">${r.status === 'preparing' ? `<button class="btn" data-ila="readyNow" data-rid="${r.id}">Rendre prête maintenant</button>` : ''}${r.status === 'pending' ? `<button class="btn primary" data-ila="validateRequest" data-rid="${r.id}">Valider</button>
                    <button class="btn danger" data-ila="refuseRequest" data-rid="${r.id}">Refuser</button>` : ''}</td></tr>`).join('')}</table>`
                : '<div class="empty">Aucune demande.</div>'}
        </div>`;

    /* ---------- Paramètres ---------- */
    SUBVIEWS.settings = (g) => {
        if (!IL.settings) IL.settings = { label: g.label, type: g.type, description: g.description, color: g.color, f5Tabs: { ...g.settings.f5Tabs } };
        const s = IL.settings;
        return `<div class="section"><h2>Paramètres</h2>
                <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px;max-width:860px">
                    <div class="field"><label>Nom affiché</label><input class="input" data-ilf="label" maxlength="64" value="${esc(s.label)}"></div>
                    <div class="field"><label>Nom interne (unique)</label><input class="input" value="${esc(g.name)}" disabled></div>
                    <div class="field"><label>Type</label><select class="input" data-ilf="type">${typeOpts().map((o) => `<option value="${o.value}" ${o.value === s.type ? 'selected' : ''}>${esc(o.label)}</option>`).join('')}</select></div>
                </div>
                <div style="display:grid;grid-template-columns:2fr 1fr;gap:12px;max-width:860px">
                    <div class="field"><label>Description</label><textarea class="input" data-ilf="description" maxlength="500">${esc(s.description)}</textarea></div>
                    <div class="field"><label>Couleur</label><input class="input" data-ilf="color" type="color" value="${esc(s.color)}" style="height:40px;padding:3px"></div>
                </div>
                <h2 style="margin-top:8px">Tablette F5 : onglets accessibles</h2>
                ${tabToggles('data-ilft', s.f5Tabs)}
                <div class="btn-row" style="margin-top:12px"><button class="btn primary" data-ila="saveSettings">Enregistrer</button><button class="btn" data-ila="resetSettings">Annuler</button></div>
            </div>
            <div class="section"><h2 style="color:var(--danger)">Zone dangereuse</h2>
                <p class="hint">Supprime définitivement le groupe, ses grades, ses membres, son PED, ses finances, ses commandes et ses configurations.</p>
                <button class="btn danger" data-ila="deleteGroup">Supprimer ce groupe</button></div>`;
    };

    /* =========================================================
       ÉVÈNEMENTS
       ========================================================= */
    document.addEventListener('input', (ev) => {
        if (!isOpen || tab !== 'illegal' || !IL.settings) return;
        const t = ev.target;
        if (t.dataset.ilf) IL.settings[t.dataset.ilf] = t.value;
    });

    const gradeOpts = (g) => [...g.grades].reverse().map((x) => ({ value: x.id, label: `${x.label} (niveau ${x.level})` }));
    const findMember = (g, cid) => g.memberList.find((m) => m.cid === cid);
    const findGrade = (g, id) => g.grades.find((x) => x.id === Number(id));
    const findOrder = (id) => {
        const g = sel();
        return (g ? g.orders : []).concat(D.illegal.globalOrders).find((o) => o.id === Number(id));
    };
    const itemOptions = (cur) => {
        const items = IL.items || [];
        const opts = [{ value: '', label: '— Aucun objet (commande RP) —' }].concat(items.map((x) => ({ value: x.name, label: `${x.label} (${x.name})` })));
        if (cur && !items.find((x) => x.name === cur)) opts.push({ value: cur, label: `${cur} (introuvable)` });
        return opts;
    };
    const orderFields = (o) => [
        IL.items && IL.items.length
            ? { name: 'item', label: 'Ce qu\'ils peuvent commander (objet livré dans le sac)', type: 'select', value: o && o.item ? o.item : '', options: itemOptions(o && o.item) }
            : { name: 'item', label: 'Objet livré (nom ox_inventory, ex : weapon_pistol)', value: o && o.item ? o.item : '' },
        { name: 'itemCount', label: 'Quantité d\'objet par commande', type: 'number', value: o ? o.itemCount : 1 },
        { name: 'price', label: 'Prix (unité)', type: 'number', value: o ? o.price : 0 },
        { name: 'name', label: 'Nom affiché (vide = nom de l\'objet)', value: o ? o.name : '', placeholder: 'ex : Pistolet' },
        { name: 'description', label: 'Description', value: o ? o.description : '' },
        { name: 'category', label: 'Type', type: 'select', value: o ? o.category : 'other', options: D.illegal.categories.map((c) => ({ value: c.key, label: `${c.ico} ${c.label}` })) },
        { name: 'payment', label: 'Payée avec', type: 'select', value: o ? o.payment : 'dirty', options: Object.entries(PAYMENTS).map(([value, label]) => ({ value, label })) },
        { name: 'available', label: 'Disponibilité', type: 'select', value: o ? String(o.available) : 'true', options: [{ value: 'true', label: 'Disponible' }, { value: 'false', label: 'Indisponible' }] },
    ];
    const orderPayload = (v) => ({ name: v.name, description: v.description, category: v.category, price: Number(v.price), payment: v.payment,
        available: v.available === 'true', item: v.item, itemCount: Number(v.itemCount) });
    const orderRow = (o) => ({ name: o.name, description: o.description, category: o.category, price: o.price, payment: o.payment,
        available: o.available, item: o.item || '', itemCount: o.itemCount });

    document.addEventListener('click', async (ev) => {
        if (!isOpen || tab !== 'illegal' || !D || !D.illegal) return;
        let n;
        const g = sel();
        if ((n = ev.target.closest('[data-ils]'))) { IL.sub = n.dataset.ils; IL.permEdit = null; IL.permDraft = null; return render(); }
        if ((n = ev.target.closest('[data-ilp]'))) { IL.permDraft[n.dataset.ilp] = !IL.permDraft[n.dataset.ilp]; return render(); }
        if ((n = ev.target.closest('[data-ilpm]'))) { IL.pedMenu[n.dataset.ilpm] = !IL.pedMenu[n.dataset.ilpm]; return render(); }
        if ((n = ev.target.closest('[data-ilft]'))) { IL.settings.f5Tabs[n.dataset.ilft] = !IL.settings.f5Tabs[n.dataset.ilft]; return render(); }
        if (!(n = ev.target.closest('[data-ila]')) || n.disabled) return;
        const a = n.dataset.ila, id = g ? g.id : undefined, cid = n.dataset.cid, gid = Number(n.dataset.gid);
        let v;

        switch (a) {
            case 'select': return send('select', { id: Number(n.dataset.id) });
            case 'back': IL.groupId = null; return send('back');

            case 'createGroup':
                v = await formModal('Créer un groupe illégal', [
                    { name: 'name', label: 'Nom interne (unique, minuscules : ex. bloods)', placeholder: 'bloods' },
                    { name: 'label', label: 'Nom affiché', placeholder: 'Bloods' },
                    { name: 'type', label: 'Type', type: 'select', value: 'gang', options: typeOpts() },
                    { name: 'description', label: 'Description', placeholder: 'Gang criminel' },
                    { name: 'color', label: 'Couleur (#rrggbb)', value: '#e0433b' },
                    { name: 'pedModel', label: 'PED (modèle)', value: D.illegal.defaultPed },
                    { name: 'pedHere', label: 'Position du PED', type: 'select', value: '1', options: [{ value: '1', label: 'À ma position actuelle' }, { value: '0', label: 'Plus tard (onglet PED)' }] },
                ], 'Créer le groupe');
                if (v) send('createGroup', { ...v, pedHere: v.pedHere === '1' });
                return;

            /* Membres */
            case 'addMember':
                v = await formModal(`Ajouter un membre à ${g.label}`, [
                    { name: 'target', label: 'ID du joueur connecté, ou citizenid (même hors ligne)', placeholder: '25' },
                    { name: 'gradeId', label: 'Grade', type: 'select', value: (g.grades[0] || {}).id, options: gradeOpts(g) },
                ], 'Ajouter');
                if (v) send('addMember', { id, target: /^\d+$/.test(v.target.trim()) ? Number(v.target) : v.target.trim(), gradeId: Number(v.gradeId) });
                return;
            case 'promote': return send('promote', { id, cid });
            case 'demote': return send('demote', { id, cid });
            case 'setGrade': {
                const m = findMember(g, cid);
                v = await formModal(`Grade de ${m.name}`, [{ name: 'gradeId', label: 'Nouveau grade', type: 'select', value: m.gradeId, options: gradeOpts(g) }], 'Changer');
                if (v) send('setMemberGrade', { id, cid, gradeId: Number(v.gradeId) });
                return;
            }
            case 'removeMember': {
                const m = findMember(g, cid);
                if (await confirmBox(`Retirer ${m.name} ?`, `Il ne fera plus partie de ${g.label}.`)) send('removeMember', { id, cid });
                return;
            }

            /* Grades */
            case 'createGrade':
            case 'editGrade': {
                const gr = a === 'editGrade' ? findGrade(g, gid) : null;
                v = await formModal(gr ? `Modifier ${gr.label}` : 'Créer un grade', [
                    { name: 'name', label: 'Nom (identifiant)', value: gr ? gr.name : '', placeholder: 'lieutenant' },
                    { name: 'label', label: 'Label', value: gr ? gr.label : '', placeholder: 'Lieutenant' },
                    { name: 'level', label: 'Niveau / priorité (0 à 1000)', type: 'number', value: gr ? gr.level : '' },
                    { name: 'boss', label: 'Grade OG / chef (toutes les permissions)', type: 'select', value: gr && gr.boss ? '1' : '0', options: [{ value: '0', label: 'Non' }, { value: '1', label: 'Oui' }] },
                ], gr ? 'Enregistrer' : 'Créer');
                if (v) send(gr ? 'updateGrade' : 'createGrade', { id, gradeId: gr ? gr.id : undefined, name: v.name, label: v.label, level: Number(v.level), boss: v.boss === '1',
                    perms: gr ? gr.perms : {} });
                return;
            }
            case 'deleteGrade': {
                const gr = findGrade(g, gid);
                if (await confirmBox(`Supprimer le grade ${gr.label} ?`, `Ses ${gr.members} membre(s) passeront au grade juste en dessous.`)) send('deleteGrade', { id, gradeId: gid });
                return;
            }
            case 'moveGrade': return send('moveGrade', { id, gradeId: gid, dir: Number(n.dataset.dir) });
            case 'editPerms': IL.permEdit = IL.permEdit === gid ? null : gid; IL.permDraft = null; return render();
            case 'permAll': D.illegal.permissions.forEach((p) => { IL.permDraft[p.key] = true; }); return render();
            case 'permNone': IL.permDraft = {}; return render();
            case 'permCancel': IL.permEdit = null; IL.permDraft = null; return render();
            case 'permSave': {
                const gr = findGrade(g, IL.permEdit);
                if (!gr) return;
                send('updateGrade', { id, gradeId: gr.id, name: gr.name, label: gr.label, level: gr.level, perms: IL.permDraft });
                IL.permEdit = null; IL.permDraft = null;
                return;
            }

            /* Finances */
            case 'money': {
                const add = n.dataset.add === '1', acc = n.dataset.acc;
                v = await formModal(`${add ? 'Ajouter' : 'Retirer'} : ${ACCOUNTS[acc].toLowerCase()} (${g.label})`, [
                    { name: 'amount', label: 'Montant', type: 'number', placeholder: '50000' },
                    { name: 'reason', label: 'Raison (historique)', placeholder: 'facultatif' },
                ], add ? 'Ajouter' : 'Retirer', !add);
                const amount = v && Math.floor(Number(v.amount));
                if (v && (!amount || amount <= 0)) return toast('Montant invalide.', 'error');
                if (v) send('money', { id, account: acc, add, amount, reason: v.reason });
                return;
            }

            /* PED */
            case 'addPed':
            case 'pedModel': {
                const p = g.pedData;
                v = await formModal(p ? 'Modifier le modèle du PED' : 'Ajouter un PED', [
                    { name: 'model', label: 'Modèle', value: p ? p.model : D.illegal.defaultPed },
                    { name: 'scenario', label: 'Animation (scénario, vide = aucune)', value: p ? p.scenario : D.illegal.defaultScenario },
                ], 'Enregistrer');
                if (v) send('setPed', { id, model: v.model, scenario: v.scenario, useMyPosition: !p });
                return;
            }
            case 'pedHere':
                if (await confirmBox('Déplacer le PED ici ?', 'Il sera placé à ta position, tourné dans ta direction.')) send('setPed', { id, useMyPosition: true });
                return;
            case 'pedCoords': {
                const p = g.pedData;
                v = await formModal('Coordonnées du PED', [
                    { name: 'x', label: 'X', type: 'number', value: p.x.toFixed(2) }, { name: 'y', label: 'Y', type: 'number', value: p.y.toFixed(2) },
                    { name: 'z', label: 'Z', type: 'number', value: p.z.toFixed(2) }, { name: 'h', label: 'Heading (0-360)', type: 'number', value: p.h.toFixed(1) },
                ], 'Déplacer');
                if (v) send('setPed', { id, x: Number(v.x), y: Number(v.y), z: Number(v.z), h: Number(v.h) });
                return;
            }
            case 'pedHeading':
                v = await formModal('Heading du PED', [{ name: 'h', label: 'Heading (0-360)', type: 'number', value: g.pedData.h.toFixed(1) }], 'Enregistrer');
                if (v) send('setPed', { id, h: Number(v.h) });
                return;
            case 'gotoPed': post('close'); return send('gotoPed', { id });
            case 'respawnPed': return send('respawnPed', { id });
            case 'removePed':
                if (await confirmBox('Supprimer le PED ?', `Les membres de ${g.label} ne pourront plus ouvrir le menu avec E.`)) send('removePed', { id });
                return;
            case 'savePedMenu': send('setPed', { id, menu: IL.pedMenu }); IL.pedMenu = null; return;

            /* Commandes */
            case 'createOrder': {
                const global = n.dataset.global === '1';
                v = await formModal(global ? 'Commande pour tous les groupes' : `Nouvelle commande : ${g.label}`, orderFields(null), 'Créer');
                if (v) send('createOrder', { id: global ? undefined : id, global, ...orderPayload(v) });
                return;
            }
            case 'editOrder': {
                const o = findOrder(n.dataset.oid);
                v = await formModal(`Modifier ${o.name}`, orderFields(o), 'Enregistrer');
                if (v) send('updateOrder', { id: o.global ? undefined : id, orderId: o.id, ...orderPayload(v) });
                return;
            }
            case 'toggleOrder': {
                const o = findOrder(n.dataset.oid);
                return send('updateOrder', { id: o.global ? undefined : id, orderId: o.id, ...orderRow(o), available: !o.available });
            }
            case 'deleteOrder': {
                const o = findOrder(n.dataset.oid);
                if (await confirmBox(`Supprimer « ${o.name} » ?`, 'La commande ne sera plus proposée.')) send('deleteOrder', { id: o.global ? undefined : id, orderId: o.id });
                return;
            }
            case 'addStash':
            case 'editStash': {
                const s = g.stashData, c = D.illegal.stashConfig;
                const models = c.models.map((m) => ({ value: m.model, label: `${m.label} (${m.model})` }));
                if (s && !c.models.find((m) => m.model === s.model)) models.push({ value: s.model, label: s.model });
                v = await formModal(s ? 'Modifier le coffre' : 'Placer le coffre à ma position', [
                    { name: 'label', label: 'Nom du coffre', value: s ? s.label : 'Coffre' },
                    { name: 'model', label: 'Objet', type: 'select', value: s ? s.model : c.models[0].model, options: models },
                    { name: 'weight', label: `Poids maximum en kg (1 à ${c.maxWeight})`, type: 'number', value: s ? s.weight : c.defaultWeight },
                    { name: 'slots', label: `Nombre de places (1 à ${c.maxSlots})`, type: 'number', value: s ? s.slots : c.defaultSlots },
                ], s ? 'Enregistrer' : 'Placer ici');
                if (v) send('setStash', { id, label: v.label, model: v.model, weight: Number(v.weight), slots: Number(v.slots), useMyPosition: !s });
                return;
            }
            case 'stashHere':
                if (await confirmBox('Déplacer le coffre ici ?', 'Il sera placé à ta position, tourné dans ta direction. Son contenu ne change pas.')) send('setStash', { id, useMyPosition: true });
                return;
            case 'gotoStash': post('close'); return send('gotoStash', { id });
            case 'removeStash':
                if (await confirmBox('Supprimer le coffre ?', `Le coffre de ${g.label} disparaît de la map. Son contenu est conservé : il revient si tu replaces un coffre.`)) send('removeStash', { id });
                return;
            case 'readyNow': return send('readyNow', { id, requestId: Number(n.dataset.rid) });
            case 'addSpot':
                v = await formModal('Nouveau point de livraison', [
                    { name: 'label', label: 'Nom du lieu (le chef sera placé à ta position, tourné dans ta direction : choisis un coin caché et dégagé pour 6 PNJ)',
                        placeholder: 'ex : Entrepôt abandonné du port' },
                ], 'Ajouter ici');
                if (v) send('addSpot', { label: v.label, useMyPosition: true });
                return;
            case 'gotoSpot': post('close'); return send('gotoSpot', { spotId: Number(n.dataset.sid) });
            case 'removeSpot':
                if (await confirmBox('Supprimer ce point de livraison ?', 'Les livraisons déjà en cours ne sont pas touchées.')) send('removeSpot', { spotId: Number(n.dataset.sid) });
                return;
            case 'validateRequest':
                if (await confirmBox('Valider la commande ?', 'Le montant sera retiré du coffre du groupe.')) send('validateRequest', { id, requestId: Number(n.dataset.rid) });
                return;
            case 'refuseRequest': return send('refuseRequest', { id, requestId: Number(n.dataset.rid) });

            /* Paramètres */
            case 'saveSettings': send('updateGroup', { id, ...IL.settings }); IL.settings = null; return;
            case 'resetSettings': IL.settings = null; return render();
            case 'deleteGroup': {
                if (!(await confirmBox('Êtes-vous sûr de vouloir supprimer ce groupe ?',
                    `Cette action supprimera : le groupe « ${g.label} », ses grades, ses membres (${g.members}), son PED, ses finances, ses commandes et ses configurations. Elle est définitive.`))) return;
                v = await formModal('Confirmation finale', [{ name: 'confirm', label: `Tape le nom interne du groupe : ${g.name}`, placeholder: g.name }], 'Supprimer définitivement', true);
                if (v) send('deleteGroup', { id, confirm: v.confirm.trim() });
                return;
            }
        }
    });
})();
