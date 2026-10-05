/* =========================================================
   GROUPE MÉTIERS : REJOINDRE UN MÉTIER + TENUES DE SERVICE
   Ajouté en bas des onglets 🚑 EMS et 🚓 Police.
   ========================================================= */
(() => {
    const JT = { ems: {}, police: {}, lscustom: {}, concess: {}, trying: false };
    const GROUP_LABEL = { ems: 'EMS', police: 'Police', lscustom: 'LsCustom', concess: 'Concession' };

    const groupData = (g) => (D && D.jobtools && D.jobtools.groups ? D.jobtools.groups[g] : null);
    const sel = (g, key, def) => (JT[g][key] !== undefined ? JT[g][key] : def);

    // Les onglets EMS / Police s'affichent aussi pour ceux qui n'ont que les tenues / le changement de métier
    for (const id of ['ems', 'police']) {
        const t = TABS.find((x) => x.id === id);
        if (!t) continue;
        const show = t.show;
        t.show = () => show() || !!groupData(id);
        const view = VIEWS[id];
        VIEWS[id] = () => {
            const base = D[id] ? view() : '';
            return base + (groupData(id) ? sections(id) : '');
        };
    }

    function pickJob(g) {
        const jobs = groupData(g).jobs.filter((j) => j.exists);
        const name = sel(g, 'job', jobs[0] && jobs[0].name);
        return jobs.find((j) => j.name === name) || jobs[0] || null;
    }

    // Utilisable par d'autres onglets (ex. LsCustom › Tenues) : part = 'join', 'uniforms' ou les deux
    window.JobTools = { sections: (g, part) => (groupData(g) ? sections(g, part) : ''), available: (g) => !!groupData(g) };

    function sections(g, part) {
        const gd = groupData(g);
        const me = D.jobtools.me;
        const job = pickJob(g);
        if (!job) {
            return `<div class="section"><h2>Métier ${GROUP_LABEL[g]}</h2><div class="protect">⚠️ <span>Aucun des métiers configurés
                (${gd.jobs.map((j) => `<span class="keycap">${esc(j.name)}</span>`).join(' ')}) n'existe sur le serveur.
                Vérifie <span class="keycap">Config.${{ ems: 'Ems', police: 'Police', lscustom: 'LsCustom', concess: 'Concess' }[g]}.jobs</span> dans config.lua.</span></div></div>`;
        }
        const jobSelect = gd.jobs.filter((j) => j.exists).length > 1
            ? `<select class="input" data-jt-sel="job" data-g="${g}" style="max-width:220px">${gd.jobs.filter((j) => j.exists).map((j) => `<option value="${esc(j.name)}" ${j.name === job.name ? 'selected' : ''}>${esc(j.label)}</option>`).join('')}</select>`
            : '';
        const grade = Number(sel(g, 'grade', job.grades.length ? job.grades[job.grades.length - 1].level : 0));
        const isHere = me.job === job.name;

        // ---------- Rejoindre ce métier ----------
        const join = `<div class="section"><h2>Rejoindre ce métier</h2>
            <p class="hint">Prends temporairement un métier ${GROUP_LABEL[g]} pour utiliser la tablette des joueurs et tester le métier.
            Ton métier d'origine est gardé : tu le reprends en un clic.</p>
            <div class="card">
                <p style="margin-bottom:10px">Métier actuel : <b>${esc(me.jobLabel || me.job || '?')}</b> · ${esc(me.gradeLabel || '')}
                    ${me.duty ? '<span class="badge" style="color:var(--ok)">En service</span>' : '<span class="badge">Hors service</span>'}</p>
                <div class="inline" style="max-width:720px">
                    ${jobSelect}
                    <select class="input" data-jt-sel="grade" data-g="${g}">${job.grades.map((gr) => `<option value="${gr.level}" ${gr.level === grade ? 'selected' : ''}>${gr.level} · ${esc(gr.label)}</option>`).join('')}</select>
                    <button class="btn primary" data-jt="join" data-g="${g}">${isHere ? 'Changer de grade' : `Devenir ${esc(job.label)}`}</button>
                </div>
                ${me.origin ? `<div class="duty-bar" style="margin:12px 0 0"><span>Métier d'origine gardé : <b>${esc(me.origin.label)} · ${esc(me.origin.gradeLabel)}</b></span>
                    <button class="btn" data-jt="restore">↩ Reprendre mon métier</button></div>` : ''}
            </div></div>`;

        // ---------- Tenues ----------
        if (part === 'join') return join;
        if (!D.jobtools.uniformsEnabled) return part === 'uniforms' ? '' : join;
        // Tenue définie, héritée d'un grade inférieur, ou aucune
        const status = (level, gender) => {
            const own = job.uniforms[String(level)];
            if (own && own[gender]) return '<span class="badge" style="color:var(--ok)">Définie</span>';
            for (let l = level - 1; l >= 0; l--) {
                const u = job.uniforms[String(l)];
                if (u && u[gender]) return `<span class="badge muted">Celle du grade ${l}</span>`;
            }
            return '<span class="badge" style="color:var(--danger)">Aucune</span>';
        };
        const rows = job.grades.map((gr) => {
            const u = job.uniforms[String(gr.level)];
            const chip = (gender, label) => `<span style="display:inline-flex;gap:6px;align-items:center;margin-right:14px">${label} ${status(gr.level, gender)}
                ${u && u[gender] ? `<button class="btn danger" style="padding:2px 8px" data-jt="del" data-g="${g}" data-grade="${gr.level}" data-gender="${gender}" title="Supprimer">✕</button>` : ''}</span>`;
            return `<tr>
                <td><strong>${gr.level} · ${esc(gr.label)}</strong></td>
                <td>${chip('male', 'Homme')}${chip('female', 'Femme')}</td>
                <td style="text-align:right;white-space:nowrap">
                    <button class="btn" data-jt="try" data-g="${g}" data-grade="${gr.level}" ${u ? '' : 'disabled'}>Essayer</button>
                    <button class="btn primary" data-jt="save" data-g="${g}" data-grade="${gr.level}">Enregistrer ma tenue</button>
                </td></tr>`;
        }).join('');
        const uniforms = `<div class="section"><h2>Tenues de service · ${esc(job.label)}</h2>
            <p class="hint">Habille-toi avec ton magasin de vêtements, puis clique « Enregistrer ma tenue » sur le grade voulu.
            La tenue est enfilée automatiquement à la prise de service et retirée à la fin.
            Un grade sans tenue utilise celle du grade inférieur le plus proche. Les tenues homme et femme sont séparées :
            elles sont enregistrées selon ton personnage.</p>
            ${JT.trying ? '<div class="duty-bar" style="margin-bottom:10px"><span>Tu portes une tenue d\'essai.</span><button class="btn" data-jt="untry">Remettre mes vêtements</button></div>' : ''}
            <table>${rows}</table>
            <div style="margin-top:10px;text-align:right"><button class="btn" data-jt="reset" data-g="${g}">Remettre les tenues par défaut</button></div></div>`;
        if (part === 'uniforms') return uniforms;
        return join + uniforms;
    }

    const refresh = () => setTimeout(() => post('refresh'), 300);

    document.addEventListener('change', (ev) => {
        const t = ev.target;
        if (!t.dataset || !t.dataset.jtSel) return;
        const g = t.dataset.g;
        JT[g][t.dataset.jtSel] = t.value;
        if (t.dataset.jtSel === 'job') JT[g].grade = undefined;
        render();
    });

    document.addEventListener('click', async (ev) => {
        const n = ev.target.closest('[data-jt]');
        if (!n || !isOpen || !['ems', 'police', 'lscustom', 'concess'].includes(tab) || n.disabled) return;
        const k = n.dataset.jt;
        const g = n.dataset.g || tab;
        const job = groupData(g) ? pickJob(g) : null;

        if (k === 'join') {
            const grade = Number(sel(g, 'grade', job.grades.length ? job.grades[job.grades.length - 1].level : 0));
            if (!(await confirmBox(`Devenir ${job.label} ?`, `Ton métier actuel est gardé et tu pourras le reprendre ici. Grade choisi : ${grade}.`))) return;
            action('job_switch', { group: g, job: job.name, grade });
            return refresh();
        }
        if (k === 'restore') {
            action('job_restore');
            return refresh();
        }
        if (k === 'save') {
            const r = await post('uniform_capture');
            if (!r || r.error) return toast((r && r.error) || 'Impossible de lire ta tenue.', 'error');
            const has = job.uniforms[String(n.dataset.grade)];
            if (has && has[r.gender] && !(await confirmBox('Remplacer la tenue ?', `Une tenue ${r.gender === 'male' ? 'homme' : 'femme'} existe déjà pour ce grade.`))) return;
            action('uniform_save', { group: g, job: job.name, grade: Number(n.dataset.grade), gender: r.gender, outfit: r.outfit });
            return refresh();
        }
        if (k === 'del') {
            if (!(await confirmBox('Supprimer la tenue ?', `Tenue ${n.dataset.gender === 'male' ? 'homme' : 'femme'} du grade ${n.dataset.grade}.`))) return;
            action('uniform_delete', { group: g, job: job.name, grade: Number(n.dataset.grade), gender: n.dataset.gender });
            return refresh();
        }
        if (k === 'reset') {
            if (!(await confirmBox('Remettre les tenues par défaut ?', `Toutes les tenues enregistrées pour ${job.label} seront remplacées par les tenues de base.`))) return;
            action('uniform_reset', { group: g, job: job.name });
            return refresh();
        }
        if (k === 'try') {
            const r = await post('uniform_try', { job: job.name, grade: Number(n.dataset.grade) });
            if (!r || r.error) return toast((r && r.error) || 'Essai impossible.', 'error');
            JT.trying = true;
            return render();
        }
        if (k === 'untry') {
            await post('uniform_untry');
            JT.trying = false;
            return render();
        }
    });
})();
