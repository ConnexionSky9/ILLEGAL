/* =========================================================
   ONGLET 🚑 TABLETTE EMS
   Qui peut ouvrir la tablette staff EMS (/ems_staff) :
   grades avec la permission « ems_staff » + accès individuels.
   ========================================================= */
(() => {
    // Tout en bas du menu, dans le groupe « Métiers »
    TABS.push({
        id: 'ems', group: 5, label: 'EMS', ico: '🚑',
        sub: 'Qui peut ouvrir la tablette staff EMS (configuration complète du métier EMS).',
        show: () => !!(D && D.ems) && (has('ems_staff') || has('manage_ranks') || has('manage_staff')),
    });

    let emsAddId = '';

    VIEWS.ems = () => {
        const e = D.ems;
        const warn = !e.available || !e.staffAvailable
            ? `<div class="protect">⚠️ <span>${!e.available ? `La ressource <b>${esc(e.resource)}</b> n'est pas démarrée.` : ''}
                ${!e.staffAvailable ? ` La ressource <b>${esc(e.staffResource)}</b> n'est pas démarrée.` : ''}
                Ajoute <span class="keycap">ensure ${esc(e.resource)}</span> et <span class="keycap">ensure ${esc(e.staffResource)}</span> dans server.cfg, après admin_menu.</span></div>` : '';

        const open = `<div class="section"><h2>Ouvrir la tablette</h2>
            ${e.mine
                ? `<p class="hint">Tu as accès à la tablette staff EMS. Tu peux aussi l'ouvrir avec <span class="keycap">/${esc(e.command)}</span>.</p>
                   <button class="btn primary big" data-ems="open" ${e.staffAvailable ? '' : 'disabled'}>🚑 Ouvrir la tablette staff EMS</button>`
                : `<p class="hint">Ton grade n'a pas accès à la tablette staff EMS.</p>`}
            ${e.requireDuty ? '<p class="hint muted" style="margin-top:10px">Les staffs en mode RP ne peuvent pas l\'ouvrir.</p>' : ''}</div>`;

        const ranks = `<div class="section"><h2>Grades qui ont accès</h2>
            <p class="hint">C'est la permission « Tablette staff EMS » de l'onglet Grades. Tu ne peux changer que les grades inférieurs au tien${has('ems_staff') ? '' : ', et seulement si tu as toi-même l\'accès'}.</p>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(230px,1fr))">
            ${e.ranks.map((r) => {
                const can = e.canManageRanks && r.editable && has('ems_staff');
                return `<div class="tile toggle-tile ${r.on ? 'on' : ''} ${can ? '' : 'locked'}" ${can ? `data-ems="rank" data-rank="${esc(r.name)}" data-on="${r.on ? '0' : '1'}"` : ''} style="${can ? '' : 'opacity:.6;cursor:default'}">
                    <div><strong style="color:${esc(r.color || '#ddd')}">${esc(r.label)}</strong>
                    <span>${r.locked ? 'Toujours tous les accès' : r.on ? 'A accès' : "N'a pas accès"} · niveau ${r.level}</span></div>
                    <div class="switch"></div></div>`;
            }).join('')}</div></div>`;

        const players = (D.players || []).filter((p) => !e.online.find((o) => o.id === p.id)).sort((a, b) => a.id - b.id);
        const indiv = e.canManageStaff ? `<div class="section"><h2>Accès individuels (${e.individuals.length})</h2>
            <p class="hint">Pour donner l'accès à une personne précise sans changer son grade (même si elle n'est pas staff). L'accès suit sa licence.</p>
            ${has('ems_staff') ? `<div class="inline" style="max-width:620px;margin-bottom:12px">
                <select class="input" id="ems-add">
                    <option value="">Choisir un joueur connecté…</option>
                    ${players.map((p) => `<option value="${p.id}" ${String(p.id) === emsAddId ? 'selected' : ''}>[${p.id}] ${esc(p.name)}${p.rankLabel ? ` · ${esc(p.rankLabel)}` : ''}</option>`).join('')}
                </select>
                <button class="btn primary" data-ems="add">Donner l'accès</button></div>` : ''}
            ${e.individuals.length ? `<table>${e.individuals.map((a) => `<tr>
                <td><strong>${esc(a.name || '?')}</strong>${a.online ? ` <span class="badge" style="color:var(--ok)">En ligne · ID ${a.online}</span>` : ''}</td>
                <td class="muted">Donné par ${esc(a.by || '?')} · ${esc(a.date || '')}</td>
                <td style="text-align:right"><button class="btn danger" data-ems="remove" data-license="${esc(a.license)}" data-name="${esc(a.name || '')}">Retirer</button></td></tr>`).join('')}</table>`
                : '<div class="empty">Aucun accès individuel.</div>'}</div>` : '';

        const online = `<div class="section"><h2>Connectés avec l'accès (${e.online.length})</h2>
            ${e.online.length ? `<table>${e.online.map((o) => `<tr>
                <td><strong>[${o.id}] ${esc(o.name)}</strong></td>
                <td>${o.rank ? `<span style="color:${esc(o.color || '#ddd')}">${esc(o.rank)}</span>` : '<span class="muted">Sans grade staff</span>'}</td>
                <td class="muted">${o.via === 'rank' ? 'Par son grade' : 'Accès individuel'}</td>
                <td>${o.rp ? '<span class="badge" style="color:var(--warn,#f2b134)">🎭 Mode RP</span>' : '<span class="badge" style="color:var(--ok)">Peut ouvrir</span>'}</td></tr>`).join('')}</table>`
                : '<div class="empty">Personne de connecté n\'a l\'accès.</div>'}</div>`;

        return warn + open + (e.canManageRanks ? ranks : '') + indiv + online;
    };

    document.addEventListener('change', (ev) => { if (ev.target && ev.target.id === 'ems-add') emsAddId = ev.target.value; });
    document.addEventListener('click', async (ev) => {
        const n = ev.target.closest('[data-ems]');
        if (!n || !isOpen || tab !== 'ems') return;
        const k = n.dataset.ems;
        if (k === 'open') return post('ems_open');
        if (k === 'rank') { action('ems_rank_toggle', { rank: n.dataset.rank, on: n.dataset.on === '1' }); return setTimeout(() => post('refresh'), 300); }
        if (k === 'add') {
            const id = Number(($('#ems-add') || {}).value || emsAddId);
            if (!id) return toast('Choisis un joueur.', 'error');
            emsAddId = '';
            action('ems_access_add', { target: id });
            return setTimeout(() => post('refresh'), 300);
        }
        if (k === 'remove') {
            if (!(await confirmBox('Retirer l\'accès ?', `${n.dataset.name || 'Ce joueur'} ne pourra plus ouvrir la tablette staff EMS (sauf si son grade y a accès).`))) return;
            action('ems_access_remove', { license: n.dataset.license });
            return setTimeout(() => post('refresh'), 300);
        }
    });
})();
