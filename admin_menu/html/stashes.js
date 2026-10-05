/* =========================================================
   ÉDITEUR DE MAP › 🗄️ COFFRES
   Un objet posé sur la map qui ouvre un inventaire partagé.
   Poids, emplacements, et accès : tout le monde, certains métiers
   et/ou certains groupes illégaux (gangs), avec grade minimum.
   ========================================================= */
const STASH_MODELS = [
    { model: 'prop_box_wood02a', label: 'Caisse en bois' },
    { model: 'prop_mil_crate_01', label: 'Caisse militaire' },
    { model: 'xm_prop_x17_chest_closed', label: 'Coffre de pirate' },
    { model: 'prop_ld_int_safe_01', label: 'Coffre-fort' },
    { model: 'p_v_43_safe_s', label: 'Petit coffre-fort' },
    { model: 'prop_toolchest_05', label: 'Servante à outils' },
    { model: 'prop_rub_cabinet01', label: 'Armoire métallique' },
    { model: 'prop_ld_suitcase_01', label: 'Valise' },
    { model: 'prop_cs_cardbox_01', label: 'Carton' },
];
let stashEdit = null;   // coffre en cours de modification (null = création)

const serverGangs = () => (D && D.gangs) || [];
function newStashDraft() {
    return { name: 'Coffre', model: STASH_MODELS[0].model, weight: 100, slots: 50,
        jobsOn: false, jobs: [{ job: '', grade: 0 }], gangsOn: false, gangs: [{ gang: '', grade: 0 }] };
}
const stashDraft = () => stashEdit || (drafts.stash = drafts.stash || newStashDraft());

function groupRows(kind, list) {
    const all = kind === 'job' ? serverJobs() : serverGangs();
    const key = kind;
    return `<table class="loot"><tr><th style="width:55%">${kind === 'job' ? 'Métier' : 'Groupe illégal'}</th><th style="width:38%">Grade minimum</th><th></th></tr>
        ${list.map((r, i) => {
            const cur = all.find((x) => x.name === r[key]);
            const sel = all.length ? `<select class="input" data-sxg="${kind}:${i}:${key}">
                <option value="" ${!r[key] ? 'selected' : ''}>— Choisir —</option>
                ${all.map((x) => `<option value="${esc(x.name)}" ${x.name === r[key] ? 'selected' : ''}>${esc(x.label)} (${esc(x.name)})</option>`).join('')}
                ${r[key] && !cur ? `<option value="${esc(r[key])}" selected>${esc(r[key])} (introuvable)</option>` : ''}</select>`
                : `<input class="input" data-sxg="${kind}:${i}:${key}" value="${esc(r[key])}" placeholder="nom de code">`;
            const g = Number(r.grade) || 0;
            const grade = cur && cur.grades.length ? `<select class="input" data-sxg="${kind}:${i}:grade">
                ${cur.grades.map((x) => `<option value="${x.level}" ${x.level === g ? 'selected' : ''}>${x.level} · ${esc(x.label)}${x.level === cur.grades[0].level ? ' (tous)' : ' et plus'}</option>`).join('')}</select>`
                : `<input class="input" type="number" min="0" data-sxg="${kind}:${i}:grade" value="${g}">`;
            return `<tr><td>${sel}</td><td>${grade}</td><td><button class="sb-close" data-sx="del_${kind}" data-i="${i}">✕</button></td></tr>`;
        }).join('')}</table>
        <button class="btn" style="margin-top:8px" data-sx="add_${kind}">+ ${kind === 'job' ? 'Autre métier' : 'Autre groupe'}</button>`;
}

function stashForm(st) {
    const custom = !STASH_MODELS.find((m) => m.model === st.model);
    const tile = (on, k, title, sub) => `<div class="tile toggle-tile ${on ? 'on' : ''}" data-sx="${k}"><div><strong>${title}</strong><span>${sub}</span></div><div class="switch"></div></div>`;
    return `<div class="form-grid" style="grid-template-columns:1.4fr 1fr 1fr">
            <div><label>Nom du coffre</label><input class="input" data-sxf="name" value="${esc(st.name)}" placeholder="ex : Coffre des Ballas"></div>
            <div><label>Poids maximum (kg)</label><input class="input" type="number" min="1" max="100000" data-sxf="weight" value="${esc(st.weight)}"></div>
            <div><label>Emplacements</label><input class="input" type="number" min="1" max="500" data-sxf="slots" value="${esc(st.slots)}"></div>
        </div>
        ${stashEdit ? '' : `<label>Apparence</label>
        <div class="preset-grid" style="margin:6px 0 10px">${STASH_MODELS.map((m) => `<button class="preset ${st.model === m.model ? 'active' : ''}" data-sxm="${esc(m.model)}"><span class="pi">🗄️</span><span class="pl">${esc(m.label)}</span></button>`).join('')}</div>
        <div class="inline" style="max-width:520px;margin-bottom:14px"><input class="input" data-sxf="model" value="${esc(st.model)}" placeholder="ou n'importe quel prop : nom du modèle">${custom ? '<span class="muted" style="white-space:nowrap">modèle personnalisé</span>' : ''}</div>`}

        <h3 class="sub-h" style="font-size:17px;margin-top:6px">🔑 Qui peut l'ouvrir</h3>
        <p class="hint">Sans restriction, tout le monde peut l'ouvrir. Tu peux réserver le coffre à des métiers, à des groupes illégaux, ou aux deux (il suffit d'être dans l'un des deux).</p>
        <div class="grid" style="grid-template-columns:1fr 1fr 1fr;margin-bottom:12px">
            ${tile(!st.jobsOn && !st.gangsOn, 'open_all', 'Tout le monde', 'Aucune restriction')}
            ${tile(st.jobsOn, 'tog_jobs', 'Métiers', serverJobs().length ? `${serverJobs().length} métiers sur le serveur` : 'Police, EMS, mécano…')}
            ${tile(st.gangsOn, 'tog_gangs', 'Groupes illégaux', serverGangs().length ? `${serverGangs().length} groupes sur le serveur` : 'Gangs, organisations…')}
        </div>
        ${st.jobsOn ? `<div class="card recipe" style="margin-bottom:12px"><h3 class="sub-h" style="font-size:15px">Métiers autorisés</h3>${groupRows('job', st.jobs)}</div>` : ''}
        ${st.gangsOn ? `<div class="card recipe" style="margin-bottom:12px"><h3 class="sub-h" style="font-size:15px">Groupes illégaux autorisés</h3>
            ${serverGangs().length ? '' : '<p class="hint">Liste des groupes indisponible (Qbox ou QBCore requis) : tape le nom de code du gang.</p>'}${groupRows('gang', st.gangs)}</div>` : ''}`;
}

function stashAccessText(r) {
    const jl = (r.jobs || []).map((j) => `${esc(jobLabelOf(j.job))}${j.grade ? ` (${j.grade}+)` : ''}`);
    const gl = (r.gangs || []).map((g) => `${esc((serverGangs().find((x) => x.name === g.gang) || {}).label || g.gang)}${g.grade ? ` (${g.grade}+)` : ''}`);
    if (!jl.length && !gl.length) return '<span class="muted">Tout le monde</span>';
    return [jl.length ? `💼 ${jl.join(', ')}` : '', gl.length ? `🩸 ${gl.join(', ')}` : ''].filter(Boolean).join(' · ');
}

function edStashes() {
    const list = (D.editor.stashes || []);
    if (stashEdit) {
        return `<div class="btn-row" style="margin-bottom:16px">
                <button class="btn" data-sx="back">← Retour aux coffres</button>
                <button class="btn primary" data-sx="save">Enregistrer</button></div>
            <h2 class="sub-h">${esc(stashEdit.name)} <span class="muted" style="font-size:14px">#${stashEdit.id}</span></h2>
            <div class="section">${stashForm(stashEdit)}</div>`;
    }
    const st = stashDraft();
    return `<div class="section"><h2>Placer un coffre</h2>
        <div class="steps"><span><b>1</b>Nom, poids et accès</span><span><b>2</b>Apparence</span><span><b>3</b>Place-le (comme un prop), E pour valider</span></div>
        ${stashForm(st)}
        <button class="btn primary big" data-sx="place">🗄️ Placer le coffre</button></div>
        <div class="section"><h2>Coffres enregistrés (${list.length})</h2>
        ${!list.length ? '<div class="empty">Aucun coffre pour le moment.</div>' : [...list].sort(byDist).slice(0, 100).map((r) => `
            <div class="card">
                <div class="card-head"><strong>🗄️ ${esc(r.name)}</strong><span class="muted">${distTxt(r.dist)}</span></div>
                <div class="recipe-preview">⚖️ <b>${r.weight} kg</b> · ${r.slots} emplacements · <span class="muted">${esc(r.model)}</span><br>🔑 ${stashAccessText(r)}</div>
                <div class="btn-row">
                    <button class="btn primary" data-sx="edit" data-id="${r.id}">Modifier</button>
                    <button class="btn" data-sx="open" data-id="${r.id}" title="Ouvrir le contenu (staff)">📦 Voir le contenu</button>
                    <button class="btn" data-ed="move" data-kind="stash" data-id="${r.id}">Déplacer</button>
                    <button class="btn" data-ed="tp" data-kind="stash" data-id="${r.id}">Y aller</button>
                    <button class="btn danger" data-ed="delete" data-kind="stash" data-id="${r.id}">Supprimer</button>
                </div>
            </div>`).join('')}</div>`;
}

function stashPayload(st) {
    const clean = (arr, key) => arr.filter((r) => String(r[key] || '').trim()).map((r) => ({ [key]: String(r[key]).trim().toLowerCase(), grade: Number(r.grade) || 0 }));
    return { id: st.id, name: String(st.name || '').trim(), model: String(st.model || '').trim().toLowerCase(),
        weight: Number(st.weight) || 100, slots: Number(st.slots) || 50,
        jobs: st.jobsOn ? clean(st.jobs, 'job') : [], gangs: st.gangsOn ? clean(st.gangs, 'gang') : [] };
}
function validStash(pl, st) {
    if (!pl.name) return toast('Donne un nom au coffre.', 'error'), false;
    if (!stashEdit && !pl.model) return toast('Choisis une apparence.', 'error'), false;
    if (st.jobsOn && !pl.jobs.length && !(st.gangsOn && pl.gangs.length)) return toast('Choisis au moins un métier, ou désactive « Métiers ».', 'error'), false;
    if (st.gangsOn && !pl.gangs.length && !(st.jobsOn && pl.jobs.length)) return toast('Choisis au moins un groupe, ou désactive « Groupes illégaux ».', 'error'), false;
    return true;
}

document.addEventListener('click', async (ev) => {
    if (!isOpen || tab !== 'editor' || editorSub !== 'stashes') return;
    const m = ev.target.closest('[data-sxm]');
    if (m) { stashDraft().model = m.dataset.sxm; return render(); }
    const n = ev.target.closest('[data-sx]');
    if (!n) return;
    const st = stashDraft(), k = n.dataset.sx, i = Number(n.dataset.i);
    switch (k) {
        case 'open_all': st.jobsOn = false; st.gangsOn = false; return render();
        case 'tog_jobs': st.jobsOn = !st.jobsOn; return render();
        case 'tog_gangs': st.gangsOn = !st.gangsOn; return render();
        case 'add_job': st.jobs.push({ job: '', grade: 0 }); return render();
        case 'del_job': st.jobs.splice(i, 1); if (!st.jobs.length) st.jobs.push({ job: '', grade: 0 }); return render();
        case 'add_gang': st.gangs.push({ gang: '', grade: 0 }); return render();
        case 'del_gang': st.gangs.splice(i, 1); if (!st.gangs.length) st.gangs.push({ gang: '', grade: 0 }); return render();
        case 'place': {
            const pl = stashPayload(st);
            if (!validStash(pl, st)) return;
            delete pl.id;
            return editorPost('place_stash', pl);
        }
        case 'edit': {
            const r = (D.editor.stashes || []).find((x) => x.id === Number(n.dataset.id));
            if (!r) return;
            stashEdit = { id: r.id, name: r.name, model: r.model, weight: r.weight, slots: r.slots,
                jobsOn: !!(r.jobs && r.jobs.length), jobs: clone(r.jobs && r.jobs.length ? r.jobs : [{ job: '', grade: 0 }]),
                gangsOn: !!(r.gangs && r.gangs.length), gangs: clone(r.gangs && r.gangs.length ? r.gangs : [{ gang: '', grade: 0 }]) };
            document.querySelector('#content').scrollTop = 0;
            return render();
        }
        case 'back': stashEdit = null; return render();
        case 'save': {
            const pl = stashPayload(stashEdit);
            if (!validStash(pl, stashEdit)) return;
            action('editor_update_stash', pl);
            stashEdit = null;
            return setTimeout(() => post('refresh'), 300);
        }
        case 'open': return editorPost('stash_open', { id: Number(n.dataset.id) });
    }
});
function stashInput(ev) {
    if (!isOpen || tab !== 'editor' || editorSub !== 'stashes') return;
    const t = ev.target, st = stashDraft();
    if (t.dataset.sxf) { st[t.dataset.sxf] = t.value; if (t.dataset.sxf === 'model' && ev.type === 'change') render(); return; }
    if (t.dataset.sxg) {
        const [kind, i, key] = t.dataset.sxg.split(':');
        const arr = kind === 'job' ? st.jobs : st.gangs;
        arr[Number(i)][key] = t.value;
        if (key !== 'grade' && t.tagName === 'SELECT' && ev.type === 'change') {
            const all = kind === 'job' ? serverJobs() : serverGangs();
            const x = all.find((y) => y.name === t.value);
            arr[Number(i)].grade = x && x.grades.length ? x.grades[0].level : 0;
            render();
        }
    }
}
document.addEventListener('input', stashInput);
document.addEventListener('change', stashInput);
