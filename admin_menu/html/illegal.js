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
        if (!sel()) return topNav() + (MS.top === 'missions' ? missionsView() : dashboard(d) + progressionSection());
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
       ILLEGAL › GROUPES (progression) et ILLEGAL › MISSIONS
       ========================================================= */
    const MS = { top: 'groups', mission: null, sec: 'general', drafts: {}, dirty: {}, levels: null };
    const MSECS = [
        { id: 'general', label: 'Général' }, { id: 'groups', label: 'Groupes autorisés' }, { id: 'progression', label: 'Progression' },
        { id: 'locations', label: 'Emplacements' }, { id: 'guards', label: 'Gardes' }, { id: 'weapons', label: 'Armes' },
        { id: 'crate', label: 'Colis' }, { id: 'delivery', label: 'Livraison' }, { id: 'timer', label: 'Timer' },
        { id: 'rewards', label: 'Récompenses' }, { id: 'phone', label: 'Téléphone' }, { id: 'cooldown', label: 'Cooldown' }, { id: 'security', label: 'Sécurité' },
    ];
    const clone = (o) => JSON.parse(JSON.stringify(o));
    const mdata = () => D.illegal.missions;
    const mcfg = () => (mdata() ? arr(mdata().list).find((m) => m.id === MS.mission) : null);
    const fmtClock = (s) => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
    const msend = (name, data) => send(name, data);

    // Une table Lua vide arrive parfois en {} : listes remises d'aplomb
    const mnorm = (m) => {
        if (!m || m.normalized) return;
        m.levels = arr(m.levels); m.list = arr(m.list); m.active = arr(m.active); m.groups = arr(m.groups);
        m.behaviors = arr(m.behaviors); m.weaponActions = arr(m.weaponActions);
        m.active.forEach((r) => { r.participants = arr(r.participants); });
        m.list.forEach((c) => {
            c.groups.list = arr(c.groups.list);
            c.rewards.items.list = arr(c.rewards.items.list);
            if (c.guards) c.guards.list = arr(c.guards.list);
            if (c.locations) { c.locations.list = arr(c.locations.list); c.locations.list.forEach((l) => { l.guards = arr(l.guards); }); }
            if (c.delivery) c.delivery.points = arr(c.delivery.points);
        });
        m.normalized = true;
    };

    // Brouillon d'une section : copie de la config serveur tant qu'on n'a rien modifié
    const draft = (sec) => {
        const c = mcfg();
        const src = sec === 'progression' ? 'general' : sec;
        if (!MS.dirty[src] || !MS.drafts[src]) MS.drafts[src] = clone(c[src]);
        return MS.drafts[src];
    };
    const setPath = (obj, path, value) => {
        const parts = path.split('.');
        let o = obj;
        for (let i = 0; i < parts.length - 1; i++) o = o[parts[i]];
        o[parts[parts.length - 1]] = value;
    };

    const topNav = () => `<div class="segmented">
        <button class="seg ${MS.top === 'groups' ? 'active' : ''}" data-mt="groups">Groupes</button>
        <button class="seg ${MS.top === 'missions' ? 'active' : ''}" data-mt="missions">Missions</button></div>`;

    // ---------- Groupes : progression ----------
    function progressionSection() {
        const m = mdata();
        if (!m) return '';
        mnorm(m);
        return `<div class="section"><h2>Progression des groupes</h2>
            <p class="hint">Niveau et XP de chaque groupe (gagnés en missions). L'XP repart à 0 à chaque niveau ; les seuils se règlent dans <b>Missions › Niveaux</b>.</p>
            ${m.groups.length ? `<table><tr><th>Groupe</th><th>Niveau</th><th>XP</th><th></th></tr>
            ${m.groups.map((g) => `<tr><td><strong>${esc(g.groupLabel)}</strong> <span class="muted">${esc(g.name)}</span></td>
                <td><span class="keycap">${g.level}</span> ${esc(g.label)}</td>
                <td>${g.need ? `${g.xp} / ${g.need}` : `${g.xp} · <span class="muted">niveau max</span>`}</td>
                <td style="text-align:right;white-space:nowrap">
                    <button class="btn" data-mx="prog" data-op="add" data-gid="${g.id}">+ XP</button>
                    <button class="btn" data-mx="prog" data-op="remove" data-gid="${g.id}">− XP</button>
                    <button class="btn" data-mx="prog" data-op="setXp" data-gid="${g.id}">Définir XP</button>
                    <button class="btn" data-mx="prog" data-op="setLevel" data-gid="${g.id}">Définir niveau</button>
                    <button class="btn danger" data-mx="prog" data-op="reset" data-gid="${g.id}">Réinitialiser</button></td></tr>`).join('')}</table>`
                : '<div class="empty">Aucun groupe.</div>'}
        </div>`;
    }

    // ---------- Missions : niveaux, liste, missions en cours ----------
    function missionsHome() {
        const m = mdata();
        if (!m) return '<div class="empty">Module des missions indisponible.</div>';
        mnorm(m);
        if (!MS.levels) MS.levels = clone(m.levels);
        const L = MS.levels;
        return `
            ${m.active.length ? `<div class="section"><h2>Missions en cours (${m.active.length})</h2><table>
                <tr><th>Mission</th><th>Groupe</th><th>Étape</th><th>Emplacement</th><th>Participants</th><th>Temps</th><th></th></tr>
                ${m.active.map((r) => `<tr><td><strong>${esc(r.label)}</strong></td><td>${esc(r.group)}</td><td>${esc(r.stage)}</td><td>${esc(r.location || '')}</td>
                    <td>${esc(r.participants.join(', '))}</td><td>${fmtClock(r.remaining)}</td>
                    <td style="text-align:right"><button class="btn danger" data-mx="stopRun" data-rid="${r.runId}">Arrêter</button></td></tr>`).join('')}</table></div>` : ''}
            <div class="section"><h2>Missions</h2>
                <table><tr><th>Mission</th><th>Type</th><th>État</th><th>Niveau requis</th><th>XP</th><th>Joueurs</th><th>Durée</th><th></th></tr>
                ${m.list.map((c) => `<tr><td><strong>${esc(c.general.label)}</strong><br><span class="muted">${esc(c.id)}</span></td><td>${esc(c.typeLabel)}</td>
                    <td>${c.general.enabled ? '<span class="badge" style="color:var(--ok)">Activée</span>' : '<span class="badge muted">Désactivée</span>'}</td>
                    <td>${c.general.levelRequired}</td><td>+${c.general.xp}</td><td>${c.general.minPlayers}-${c.general.maxPlayers}</td><td>${c.timer.minutes} min</td>
                    <td style="text-align:right"><button class="btn primary" data-mx="open" data-mid="${esc(c.id)}">Configurer</button></td></tr>`).join('')}
                </table>
                <p class="hint" style="margin-top:10px">Les nouvelles missions s'ajoutent dans le code (<b>server/missions/&lt;type&gt;.lua</b>) et apparaissent ici automatiquement.</p>
            </div>
            <div class="section"><h2>Niveaux des groupes</h2>
                <p class="hint">« XP requise » = XP à gagner depuis le niveau précédent (l'XP repart à 0 à chaque niveau). Le dernier niveau de la liste est le <b>niveau maximum</b>.</p>
                <table><tr><th style="width:90px">Niveau</th><th>Nom</th><th style="width:200px">XP requise</th></tr>
                ${L.map((l, i) => `<tr><td><span class="keycap">${i}</span></td>
                    <td><input class="input" data-ml="${i}.label" value="${esc(l.label)}"></td>
                    <td>${i === 0 ? '<span class="muted">0 (départ)</span>' : `<input class="input" type="number" min="1" data-ml="${i}.xp" value="${Number(l.xp) || 0}">`}</td></tr>`).join('')}
                </table>
                <div class="btn-row" style="margin-top:12px"><button class="btn" data-mx="lvlAdd">+ Ajouter un niveau</button>
                    <button class="btn danger" data-mx="lvlDel" ${L.length <= 1 ? 'disabled' : ''}>Supprimer le dernier niveau</button>
                    <span style="flex:1"></span><button class="btn" data-mx="lvlReset">Annuler</button><button class="btn primary" data-mx="lvlSave">Enregistrer les niveaux</button></div>
            </div>`;
    }

    // ---------- Page d'une mission ----------
    const inp = (path, value, type = 'text', extra = '') => `<input class="input" ${type === 'number' ? 'type="number"' : ''} data-mf="${path}" value="${esc(value ?? '')}" ${extra}>`;
    const chk = (path, on, label) => `<label class="perm"><input type="checkbox" data-mf="${path}" ${on ? 'checked' : ''}>${esc(label)}</label>`;
    const sel2 = (path, value, opts) => `<select class="input" data-mf="${path}">${opts.map((o) => `<option value="${esc(o.value)}" ${String(o.value) === String(value) ? 'selected' : ''}>${esc(o.label)}</option>`).join('')}</select>`;
    const fld = (label, html) => `<div class="field"><label>${esc(label)}</label>${html}</div>`;
    const grid = (cols, html) => `<div style="display:grid;grid-template-columns:${cols};gap:12px;max-width:980px">${html}</div>`;
    const saveRow = (sec) => `<div class="btn-row" style="margin-top:8px"><button class="btn primary" data-mx="save" data-sec="${sec}">Enregistrer</button>
        <button class="btn" data-mx="reset" data-sec="${sec}">Annuler</button>${MS.dirty[sec] ? '<span class="muted">Modifications non enregistrées</span>' : ''}</div>`;

    const MSEC = {};
    MSEC.general = () => {
        const d = draft('general');
        return `<div class="section"><h2>Général</h2>
            ${grid('2fr 1fr', fld('Nom', inp('general.label', d.label)) + fld('Activée', sel2('general.enabled', String(d.enabled), [{ value: 'true', label: 'Oui' }, { value: 'false', label: 'Non' }])))}
            ${fld('Description', `<textarea class="input" data-mf="general.description">${esc(d.description)}</textarea>`)}
            ${grid('1fr 1fr 1fr 1fr', fld('Niveau requis', inp('general.levelRequired', d.levelRequired, 'number')) + fld('XP gagnée', inp('general.xp', d.xp, 'number'))
                + fld('Joueurs minimum', inp('general.minPlayers', d.minPlayers, 'number')) + fld('Joueurs maximum', inp('general.maxPlayers', d.maxPlayers, 'number')))}
            <p class="hint">Les cooldowns se règlent dans l'onglet <b>Cooldown</b>, la durée dans <b>Timer</b>.</p>
            ${saveRow('general')}</div>`;
    };
    MSEC.groups = () => {
        const d = draft('groups');
        const all = D.illegal.groups;
        return `<div class="section"><h2>Groupes autorisés</h2>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(240px,1fr));margin-bottom:12px">
                <div class="tile toggle-tile ${d.mode !== 'list' ? 'on' : ''}" data-mx="gmode" data-v="all"><div><strong>Tous les groupes</strong><span>Aucune restriction</span></div><div class="switch"></div></div>
                <div class="tile toggle-tile ${d.mode === 'list' ? 'on' : ''}" data-mx="gmode" data-v="list"><div><strong>Groupes sélectionnés</strong><span>Seulement ceux cochés</span></div><div class="switch"></div></div>
            </div>
            ${d.mode === 'list' ? `<div class="perm-grid">${all.map((g) => `<label class="perm"><input type="checkbox" data-mg="${esc(g.name)}" ${d.list.includes(g.name) ? 'checked' : ''}>${esc(g.label)} <span class="muted">${esc(g.typeLabel)}</span></label>`).join('')}</div>` : ''}
            <p class="hint" style="margin-top:10px">Vérifié par le serveur au lancement.</p>
            ${saveRow('groups')}</div>`;
    };
    MSEC.progression = () => {
        const d = draft('progression');
        const m = mdata();
        return `<div class="section"><h2>Progression</h2>
            ${grid('1fr 1fr', fld('Niveau minimum requis', inp('general.levelRequired', d.levelRequired, 'number')) + fld('XP gagnée par le groupe', inp('general.xp', d.xp, 'number')))}
            <p class="hint">XP versée une seule fois au groupe, quel que soit le nombre de participants. Niveaux actuels :
                ${m.levels.map((l, i) => `<b>${i}</b> ${esc(l.label)}${i ? ` (${l.xp} XP)` : ''}`).join(' · ')}</p>
            ${saveRow('general')}</div>`;
    };
    MSEC.timer = () => {
        const d = draft('timer');
        return `<div class="section"><h2>Timer</h2>
            ${grid('220px', fld('Durée (minutes)', inp('timer.minutes', d.minutes, 'number', 'min="1" max="180"')))}
            <div class="chips" style="margin-bottom:10px">${[5, 10, 15, 20, 30].map((x) => `<button class="chip" data-mx="preset" data-path="timer.minutes" data-v="${x}">${x} min</button>`).join('')}</div>
            <p class="hint">À 0 : mission échouée, gardes, PNJ, objets, blips et objectifs supprimés, aucune récompense ni XP.</p>
            ${saveRow('timer')}</div>`;
    };
    MSEC.cooldown = () => {
        const d = draft('cooldown');
        return `<div class="section"><h2>Cooldown (minutes, à partir de la fin de la mission)</h2>
            ${grid('1fr 1fr 1fr', fld('Mission (tous les groupes)', inp('cooldown.mission', d.mission, 'number')) + fld('Groupe', inp('cooldown.group', d.group, 'number'))
                + fld('Joueur', inp('cooldown.player', d.player, 'number')))}
            <p class="hint">Contrôlés par le serveur, conservés après un redémarrage (historique en base).</p>
            ${saveRow('cooldown')}</div>`;
    };
    MSEC.phone = () => {
        const d = draft('phone');
        const ta = (k, label) => fld(label, `<textarea class="input" data-mf="phone.${k}">${esc(d[k])}</textarea>`);
        return `<div class="section"><h2>Téléphone</h2>
            ${grid('300px', fld('Numéro / nom de l\'expéditeur', inp('phone.sender', d.sender)))}
            ${ta('start', 'Message de début')}${ta('fail', 'Message d\'échec')}${ta('finish', 'Message de fin')}
            ${ta('levelup', 'Message de level-up ({level}, {label}, {group})')}
            <p class="hint">Envoyés par le téléphone du serveur (lb-phone, sinon notification).</p>
            ${saveRow('phone')}</div>`;
    };
    MSEC.security = () => {
        const d = draft('security');
        return `<div class="section"><h2>Sécurité</h2>
            ${grid('1fr 1fr', fld('Rayon des participants au lancement (m)', inp('security.participantRadius', d.participantRadius, 'number'))
                + fld('Distance d\'interaction (m)', inp('security.interactDistance', d.interactDistance, 'number')))}
            <p class="hint">Toutes les étapes sont validées par le serveur : participant du bon groupe, garde réellement neutralisé, clé réellement trouvée,
                durée réelle des animations, distance au colis et au point de livraison, porteur du colis. Le client ne choisit ni l'emplacement, ni la récompense, ni l'XP.</p>
            ${saveRow('security')}</div>`;
    };
    MSEC.weapons = () => {
        const d = draft('weapons');
        return `<div class="section"><h2>Restrictions d'armes</h2>
            <div class="perm-grid" style="margin-bottom:12px">${chk('weapons.firearms', d.firearms, 'Armes à feu autorisées')}${chk('weapons.melee', d.melee, 'Armes blanches autorisées')}
                ${chk('weapons.explosives', d.explosives, 'Explosifs autorisés')}${chk('weapons.vehicles', d.vehicles, 'Véhicules autorisés (dans la zone)')}</div>
            ${grid('300px', fld('Si une arme interdite est utilisée', sel2('weapons.action', d.action, mdata().weaponActions.map((x) => ({ value: x.key, label: x.label })))))}
            <p class="hint">Détection serveur des dégâts infligés aux gardes ; les poings sont toujours autorisés.</p>
            ${saveRow('weapons')}</div>`;
    };
    MSEC.crate = () => {
        const d = draft('crate');
        return `<div class="section"><h2>Colis et clé</h2>
            ${grid('1fr 1fr 1fr', fld('Objet du colis', inp('crate.model', d.model)) + fld('Durée d\'ouverture (s)', inp('crate.openSeconds', d.openSeconds, 'number'))
                + fld('Durée de fouille d\'un garde (s)', inp('crate.searchSeconds', d.searchSeconds, 'number')))}
            ${grid('1fr 1fr 1fr', fld('Animation (dictionnaire)', inp('crate.animDict', d.animDict)) + fld('Animation (nom)', inp('crate.animName', d.animName))
                + fld('Nom de la clé', inp('crate.keyLabel', d.keyLabel)))}
            ${grid('1fr 1fr 1fr 1fr', fld('Clé sur', sel2('crate.keyMode', d.keyMode, [{ value: 'random', label: 'Un garde au hasard' }, { value: 'specific', label: 'Un garde précis' }, { value: 'chance', label: 'Probabilité à chaque fouille' }]))
                + fld('Garde précis (n°)', inp('crate.keyGuard', d.keyGuard, 'number')) + fld('Probabilité (%)', inp('crate.keyChance', d.keyChance, 'number'))
                + fld('Surbrillance après X fouilles ratées (0 = jamais)', inp('crate.revealAfter', d.revealAfter, 'number')))}
            <div class="perm-grid">${chk('crate.requireAllDead', d.requireAllDead, 'Tous les gardes doivent être neutralisés pour ouvrir')}</div>
            <p class="hint">La mission n'est jamais bloquée : le dernier garde fouillé a forcément la clé, et si le porteur disparaît, la clé passe au suivant.</p>
            ${saveRow('crate')}</div>`;
    };
    MSEC.guards = () => {
        const d = draft('guards');
        const beh = mdata().behaviors.map((b) => ({ value: b.key, label: b.label }));
        return `<div class="section"><h2>Gardes (${d.list.length})</h2>
            <p class="hint">Chaque garde se règle individuellement. Positions : définies par emplacement (onglet Emplacements), sinon en cercle autour du colis.
                Armes : WEAPON_UNARMED (poings), WEAPON_KNIFE, WEAPON_BAT, WEAPON_PISTOL…</p>
            ${d.list.map((x, i) => `<div class="card" style="max-width:980px">
                <div class="card-head"><strong>Garde ${i + 1}</strong><button class="btn danger" data-mx="guardDel" data-i="${i}">✕</button></div>
                ${grid('1.4fr 1.4fr 1fr 1fr 1fr', fld('Modèle', inp(`guards.list.${i}.model`, x.model)) + fld('Arme', inp(`guards.list.${i}.weapon`, x.weapon))
                    + fld('Santé', inp(`guards.list.${i}.health`, x.health, 'number')) + fld('Armure', inp(`guards.list.${i}.armor`, x.armor, 'number'))
                    + fld('Précision (%)', inp(`guards.list.${i}.accuracy`, x.accuracy, 'number')))}
                ${grid('1.6fr 1fr 1fr 1fr', fld('Comportement', sel2(`guards.list.${i}.behavior`, x.behavior, beh)) + fld('Détection (m)', inp(`guards.list.${i}.detect`, x.detect, 'number'))
                    + fld('Agression (m)', inp(`guards.list.${i}.attack`, x.attack, 'number')) + fld('Poursuite (m)', inp(`guards.list.${i}.chase`, x.chase, 'number')))}
                <div class="perm-grid">${chk(`guards.list.${i}.returnHome`, x.returnHome, 'Retour à sa position')}${chk(`guards.list.${i}.canChase`, x.canChase, 'Peut poursuivre')}</div>
            </div>`).join('')}
            <div class="btn-row"><button class="btn" data-mx="guardAdd">+ Ajouter un garde</button></div>
            ${saveRow('guards')}</div>`;
    };
    MSEC.rewards = () => {
        const d = draft('rewards');
        const m = d.money, it = d.items;
        return `<div class="section"><h2>Argent (coffre du groupe)</h2>
            ${grid('1fr 1fr 1fr 1fr', fld('Activé', sel2('rewards.money.enabled', String(m.enabled), [{ value: 'true', label: 'Oui' }, { value: 'false', label: 'Non' }]))
                + fld('Minimum', inp('rewards.money.min', m.min, 'number')) + fld('Maximum', inp('rewards.money.max', m.max, 'number'))
                + fld('Compte', sel2('rewards.money.account', m.account, [{ value: 'dirty', label: 'Argent sale' }, { value: 'clean', label: 'Argent propre' }])))}
            </div>
            <div class="section"><h2>Objets (coffre du groupe)</h2>
            ${grid('220px', fld('Activé', sel2('rewards.items.enabled', String(it.enabled), [{ value: 'true', label: 'Oui' }, { value: 'false', label: 'Non' }])))}
            <table><tr><th>Objet</th><th style="width:120px">Quantité min</th><th style="width:120px">Quantité max</th><th style="width:130px">Probabilité (%)</th><th></th></tr>
            ${it.list.map((x, i) => `<tr><td>${IL.items && IL.items.length ? sel2(`rewards.items.list.${i}.item`, x.item, [{ value: '', label: '— Choisir —' }].concat(IL.items.map((y) => ({ value: y.name, label: `${y.label} (${y.name})` }))).concat(IL.items.find((y) => y.name === x.item) || !x.item ? [] : [{ value: x.item, label: `${x.item} (introuvable)` }]))
                    : inp(`rewards.items.list.${i}.item`, x.item)}</td>
                <td>${inp(`rewards.items.list.${i}.min`, x.min, 'number')}</td><td>${inp(`rewards.items.list.${i}.max`, x.max, 'number')}</td>
                <td>${inp(`rewards.items.list.${i}.chance`, x.chance, 'number')}</td>
                <td style="text-align:right"><button class="btn danger" data-mx="itemDel" data-i="${i}">✕</button></td></tr>`).join('')}</table>
            <div class="btn-row" style="margin-top:10px"><button class="btn" data-mx="itemAdd">+ Ajouter un objet</button></div>
            <p class="hint" style="margin-top:10px">Tout va dans le <b>coffre du groupe</b> (argent : finances du groupe ; objets : inventaire du coffre), jamais au joueur, une seule fois quel que soit le nombre de participants.</p>
            ${saveRow('rewards')}</div>`;
    };
    MSEC.locations = () => {
        const c = mcfg();
        const list = c.locations.list;
        return `<div class="section"><h2>Emplacements du colis (${list.length})</h2>
            <p class="hint">Un emplacement activé est tiré au hasard à chaque mission. Place-toi à l'endroit voulu (le colis est posé à ta position).
                Positions des gardes : place-toi où doit se tenir chaque garde (dans l'ordre des gardes) puis « + Garde ici ».</p>
            <div class="btn-row" style="margin-bottom:12px"><button class="btn primary" data-mx="ptAdd" data-sec="locations">📍 Ajouter un emplacement à ma position</button></div>
            ${list.length ? `<table><tr><th>Nom</th><th>Coordonnées</th><th>Rayon</th><th>Gardes placés</th><th>Activé</th><th></th></tr>
            ${list.map((l, i) => `<tr><td><strong>${esc(l.label)}</strong></td><td class="muted">${l.x.toFixed(1)}, ${l.y.toFixed(1)}, ${l.z.toFixed(1)}</td>
                <td>${l.radius} m</td><td>${l.guards.length || '<span class="muted">auto</span>'}</td>
                <td><div class="tile toggle-tile ${l.enabled !== false ? 'on' : ''}" data-mx="ptToggle" data-sec="locations" data-i="${i}" style="padding:6px 8px"><span></span><div class="switch"></div></div></td>
                <td style="text-align:right;white-space:nowrap">
                    <button class="btn" data-mx="ptTp" data-sec="locations" data-i="${i}">Y aller</button>
                    <button class="btn" data-mx="ptEdit" data-sec="locations" data-i="${i}">Modifier</button>
                    <button class="btn" data-mx="ptHere" data-sec="locations" data-i="${i}" title="Déplacer à ma position">📍</button>
                    <button class="btn" data-mx="ptCoords" data-sec="locations" data-i="${i}" title="Coordonnées">🎯</button>
                    <button class="btn" data-mx="guardHere" data-i="${i}">+ Garde ici</button>
                    <button class="btn" data-mx="guardClear" data-i="${i}" ${l.guards.length ? '' : 'disabled'}>Effacer gardes</button>
                    <button class="btn danger" data-mx="ptDel" data-sec="locations" data-i="${i}">✕</button></td></tr>`).join('')}</table>`
                : '<div class="empty">Aucun emplacement : la mission ne peut pas être lancée.</div>'}
        </div>`;
    };
    MSEC.delivery = () => {
        const c = mcfg();
        const d = draft('delivery');
        const list = c.delivery.points;
        return `<div class="section"><h2>Livraison</h2>
            ${grid('1fr 1fr', fld('Choix du point', sel2('delivery.select', d.select, [{ value: 'closest', label: 'Le plus proche du lancement' }, { value: 'random', label: 'Au hasard' }]))
                + fld('Durée de la livraison (s)', inp('delivery.deliverSeconds', d.deliverSeconds, 'number')))}
            ${saveRow('delivery')}</div>
            <div class="section"><h2>Points de livraison (${list.length})</h2>
            <div class="btn-row" style="margin-bottom:12px"><button class="btn primary" data-mx="ptAdd" data-sec="delivery">📍 Ajouter un point à ma position</button></div>
            ${list.length ? `<table><tr><th>Nom</th><th>PNJ</th><th>Texte</th><th>Distance</th><th>Activé</th><th></th></tr>
            ${list.map((p, i) => `<tr><td><strong>${esc(p.label)}</strong><br><span class="muted">${p.x.toFixed(1)}, ${p.y.toFixed(1)}, ${p.z.toFixed(1)}</span></td>
                <td>${esc(p.ped)}<br><span class="muted">${esc(p.scenario || p.animName || '')}</span></td><td>${esc(p.text)}</td><td>${p.distance} m</td>
                <td><div class="tile toggle-tile ${p.enabled !== false ? 'on' : ''}" data-mx="ptToggle" data-sec="delivery" data-i="${i}" style="padding:6px 8px"><span></span><div class="switch"></div></div></td>
                <td style="text-align:right;white-space:nowrap">
                    <button class="btn" data-mx="ptTp" data-sec="delivery" data-i="${i}">Y aller</button>
                    <button class="btn" data-mx="ptEdit" data-sec="delivery" data-i="${i}">Modifier</button>
                    <button class="btn" data-mx="ptHere" data-sec="delivery" data-i="${i}" title="Déplacer à ma position">📍</button>
                    <button class="btn" data-mx="ptCoords" data-sec="delivery" data-i="${i}" title="Coordonnées">🎯</button>
                    <button class="btn danger" data-mx="ptDel" data-sec="delivery" data-i="${i}">✕</button></td></tr>`).join('')}</table>`
                : '<div class="empty">Aucun point de livraison : la mission ne peut pas être lancée.</div>'}
        </div>`;
    };

    function missionPage() {
        const c = mcfg();
        if (!c) { MS.mission = null; return missionsHome(); }
        return `<div class="btn-row" style="margin-bottom:12px;align-items:center"><button class="btn" data-mx="close">← Toutes les missions</button>
                <span style="font-family:var(--display);font-size:22px;font-weight:700">${esc(c.general.label)}</span>
                <span class="badge">${esc(c.typeLabel)}</span>${c.general.enabled ? '' : '<span class="badge muted">Désactivée</span>'}</div>
            <div class="segmented">${MSECS.map((s) => `<button class="seg ${s.id === MS.sec ? 'active' : ''}" data-msec="${s.id}">${s.label}</button>`).join('')}</div>
            ${(MSEC[MS.sec] || MSEC.general)()}`;
    }

    const missionsView = () => {
        const m = mdata();
        if (m) mnorm(m);
        return MS.mission ? missionPage() : missionsHome();
    };

    // ---------- Saisies ----------
    document.addEventListener('input', (ev) => {
        if (!isOpen || tab !== 'illegal' || MS.top !== 'missions') return;
        const t = ev.target;
        if (t.dataset.ml !== undefined && MS.levels) {
            const [i, k] = t.dataset.ml.split('.');
            MS.levels[Number(i)][k] = k === 'xp' ? Number(t.value) : t.value;
            return;
        }
        if (t.dataset.mf) {
            const path = t.dataset.mf;
            const sec = path.split('.')[0];
            draft(sec === 'general' ? 'general' : sec);
            MS.dirty[sec] = true;
            let v = t.type === 'checkbox' ? t.checked : t.value;
            if (t.type === 'number') v = Number(v);
            if (t.tagName === 'SELECT' && (v === 'true' || v === 'false')) v = v === 'true';
            setPath(MS.drafts, path, v);
        }
        if (t.dataset.mg !== undefined) {
            const d = draft('groups');
            MS.dirty.groups = true;
            const name = t.dataset.mg;
            d.list = d.list.filter((x) => x !== name);
            if (t.checked) d.list.push(name);
        }
    });

    const pointFields = (sec, p) => (sec === 'locations'
        ? [{ name: 'label', label: 'Nom', value: p ? p.label : 'Emplacement' }, { name: 'radius', label: 'Rayon de la zone (m)', type: 'number', value: p ? p.radius : 30 }]
        : [{ name: 'label', label: 'Nom', value: p ? p.label : 'Point de livraison' },
            { name: 'ped', label: 'PNJ (modèle)', value: p ? p.ped : 'g_m_m_armboss_01' },
            { name: 'scenario', label: 'Animation d\'attente (scénario, vide = aucune)', value: p ? p.scenario : 'WORLD_HUMAN_SMOKING' },
            { name: 'animDict', label: 'Animation de livraison (dictionnaire)', value: p ? p.animDict : 'mp_common' },
            { name: 'animName', label: 'Animation de livraison (nom)', value: p ? p.animName : 'givetake1_a' },
            { name: 'text', label: 'Texte de l\'interaction', value: p ? p.text : 'Livrer le colis' },
            { name: 'distance', label: 'Distance d\'interaction (m)', type: 'number', value: p ? p.distance : 2 },
            { name: 'blipSprite', label: 'Blip : icône (n°)', type: 'number', value: p ? p.blipSprite : 478 },
            { name: 'blipColor', label: 'Blip : couleur (n°)', type: 'number', value: p ? p.blipColor : 5 }]);
    const numFields = ['radius', 'distance', 'blipSprite', 'blipColor'];
    const toPoint = (v) => { const o = { ...v }; numFields.forEach((k) => { if (o[k] !== undefined) o[k] = Number(o[k]); }); return o; };

    document.addEventListener('click', async (ev) => {
        if (!isOpen || tab !== 'illegal' || !D || !D.illegal) return;
        let n;
        if ((n = ev.target.closest('[data-mt]'))) { MS.top = n.dataset.mt; return render(); }
        if ((n = ev.target.closest('[data-msec]'))) { MS.sec = n.dataset.msec; return render(); }
        if (!(n = ev.target.closest('[data-mx]')) || n.disabled) return;
        const a = n.dataset.mx, i = Number(n.dataset.i), sec = n.dataset.sec, mid = MS.mission;
        let v;
        switch (a) {
            case 'open': MS.mission = n.dataset.mid; MS.sec = 'general'; MS.drafts = {}; MS.dirty = {}; return render();
            case 'close': MS.mission = null; MS.drafts = {}; MS.dirty = {}; return render();
            case 'save': {
                const s = sec === 'progression' ? 'general' : sec;
                const data = MS.drafts[s] || clone(mcfg()[s]);
                MS.dirty[s] = false;
                return msend('missionSave', { missionId: mid, section: s, data });
            }
            case 'reset': MS.dirty[sec] = false; MS.drafts[sec] = null; return render();
            case 'preset': draft(n.dataset.path.split('.')[0]); MS.dirty[n.dataset.path.split('.')[0]] = true; setPath(MS.drafts, n.dataset.path, Number(n.dataset.v)); return render();
            case 'gmode': { const d = draft('groups'); d.mode = n.dataset.v; MS.dirty.groups = true; return render(); }
            case 'guardAdd': {
                const d = draft('guards');
                d.list.push(clone(d.list[d.list.length - 1] || { model: 'g_m_y_mexgoon_01', weapon: 'WEAPON_UNARMED', health: 200, armor: 0, accuracy: 30, behavior: 'wary',
                    detect: 10, attack: 7, chase: 30, returnHome: true, canChase: true }));
                MS.dirty.guards = true; return render();
            }
            case 'guardDel': { const d = draft('guards'); d.list.splice(i, 1); MS.dirty.guards = true; return render(); }
            case 'itemAdd': { const d = draft('rewards'); d.items.list.push({ item: '', min: 1, max: 1, chance: 100 }); MS.dirty.rewards = true; return render(); }
            case 'itemDel': { const d = draft('rewards'); d.items.list.splice(i, 1); MS.dirty.rewards = true; return render(); }

            // Points (emplacements, livraison) : enregistrés directement côté serveur
            case 'ptAdd':
                v = await formModal(sec === 'locations' ? 'Nouvel emplacement (à ta position)' : 'Nouveau point de livraison (à ta position)', pointFields(sec, null), 'Ajouter ici');
                if (v) msend('missionPoint', { missionId: mid, section: sec, op: 'add', data: { ...toPoint(v), useMyPosition: true } });
                return;
            case 'ptEdit': {
                const p = mcfg()[sec][sec === 'locations' ? 'list' : 'points'][i];
                v = await formModal(`Modifier « ${p.label} »`, pointFields(sec, p), 'Enregistrer');
                if (v) msend('missionPoint', { missionId: mid, section: sec, op: 'update', index: i + 1, data: toPoint(v) });
                return;
            }
            case 'ptToggle': {
                const p = mcfg()[sec][sec === 'locations' ? 'list' : 'points'][i];
                return msend('missionPoint', { missionId: mid, section: sec, op: 'update', index: i + 1, data: { enabled: p.enabled === false } });
            }
            case 'ptHere':
                if (await confirmBox('Déplacer ce point à ta position ?', 'Il prendra aussi ta direction.')) msend('missionPoint', { missionId: mid, section: sec, op: 'update', index: i + 1, data: { useMyPosition: true } });
                return;
            case 'ptCoords': {
                const p = mcfg()[sec][sec === 'locations' ? 'list' : 'points'][i];
                v = await formModal('Coordonnées', [{ name: 'x', label: 'X', type: 'number', value: p.x.toFixed(2) }, { name: 'y', label: 'Y', type: 'number', value: p.y.toFixed(2) },
                    { name: 'z', label: 'Z', type: 'number', value: p.z.toFixed(2) }, { name: 'h', label: 'Heading', type: 'number', value: (p.h || 0).toFixed(1) }], 'Enregistrer');
                if (v) msend('missionPoint', { missionId: mid, section: sec, op: 'update', index: i + 1, data: { x: Number(v.x), y: Number(v.y), z: Number(v.z), h: Number(v.h) } });
                return;
            }
            case 'ptTp': post('close'); return msend('missionTp', { missionId: mid, section: sec, index: i + 1 });
            case 'ptDel':
                if (await confirmBox('Supprimer ce point ?', 'Les missions déjà en cours ne sont pas touchées.')) msend('missionPoint', { missionId: mid, section: sec, op: 'delete', index: i + 1 });
                return;
            case 'guardHere': return msend('missionPoint', { missionId: mid, section: 'locations', op: 'guardAdd', index: i + 1, data: { useMyPosition: true } });
            case 'guardClear':
                if (await confirmBox('Effacer les positions des gardes ?', 'Les gardes seront placés automatiquement en cercle autour du colis.'))
                    msend('missionPoint', { missionId: mid, section: 'locations', op: 'guardClear', index: i + 1 });
                return;

            // Missions en cours
            case 'stopRun':
                if (await confirmBox('Arrêter cette mission ?', 'Elle échoue : gardes et objectifs supprimés, aucune récompense.')) msend('missionStop', { runId: Number(n.dataset.rid) });
                return;

            // Niveaux
            case 'lvlAdd': {
                const last = MS.levels[MS.levels.length - 1];
                MS.levels.push({ label: `Niveau ${MS.levels.length}`, xp: Math.max(100, (Number(last && last.xp) || 50) * 2) });
                return render();
            }
            case 'lvlDel': MS.levels.pop(); return render();
            case 'lvlReset': MS.levels = null; return render();
            case 'lvlSave': {
                const levels = MS.levels;
                MS.levels = null;
                return msend('levelsSave', { levels });
            }

            // Progression d'un groupe
            case 'prog': {
                const op = n.dataset.op, gid2 = Number(n.dataset.gid);
                const g = mdata().groups.find((x) => x.id === gid2);
                if (op === 'reset') {
                    if (await confirmBox(`Réinitialiser ${g.groupLabel} ?`, 'Niveau 0, 0 XP.')) msend('progress', { id: gid2, op: 'reset' });
                    return;
                }
                const labels = { add: 'XP à ajouter', remove: 'XP à retirer', setXp: `XP dans le niveau (actuel : ${g.xp})`, setLevel: `Niveau (0 à ${mdata().levels.length - 1})` };
                v = await formModal(`${g.groupLabel} : ${labels[op]}`, [{ name: 'value', label: labels[op], type: 'number', value: op === 'setLevel' ? g.level : '' }], 'Valider');
                if (v && v.value !== '') msend('progress', { id: gid2, op, value: Number(v.value) });
                return;
            }
        }
    });

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
