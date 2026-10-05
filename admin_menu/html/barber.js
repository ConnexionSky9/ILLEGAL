/* =========================================================
   COIFFEUR / BARBIER - INTERFACE JOUEUR
   Survol = aperçu instantané sur le personnage, clic = panier.
   Optimisé : listes construites une fois par onglet, survol
   regroupé (1 envoi max toutes les 40 ms), aucune boucle au repos.
   ========================================================= */
(() => {
    const root = document.getElementById('barber');
    if (!root) return;

    /* ---------- Noms des styles (jeu de base) ---------- */
    const HAIR = {
        male: ['Rasé de près', 'Coupe en brosse', 'Faux hawk', 'Hipster', 'Raie sur le côté', 'Coupe courte', 'Biker',
            'Queue de cheval', 'Tresses plaquées', 'Plaqué en arrière', 'Court brossé', 'Hérissé', 'César', 'Effilé',
            'Dreadlocks', 'Cheveux longs', 'Boucles en bataille', 'Surfeur', 'Raie courte sur le côté', 'Côtés plaqués',
            'Long plaqué', 'Hipster jeune', 'Mulet', '', 'Tresses classiques', 'Tresses palmier', 'Tresses éclair',
            'Tresses fouettées', 'Tresses zigzag', 'Tresses escargot', 'Hightop', 'Coiffé en arrière', 'Undercut en arrière',
            'Undercut sur le côté', 'Crête hérissée', 'Mod', 'Mod dégradé', 'Flattop', 'Coupe militaire'],
        female: ['Rasée de près', 'Court', 'Carré dégradé', 'Couettes', 'Queue de cheval', 'Crête tressée', 'Tresses',
            'Carré', 'Faux hawk', 'Chignon banane', 'Carré long', 'Attaché lâche', 'Pixie', 'Frange rasée', 'Chignon haut',
            'Carré ondulé', 'Chignon décoiffé', 'Pin-up', 'Chignon serré', 'Carré torsadé', 'Carré garçonne', 'Grande frange',
            'Chignon haut tressé', 'Mulet', '', 'Tresses pincées', 'Tresses en feuille', 'Tresses zigzag', 'Couettes à frange',
            'Tresses ondulées', 'Tresses enroulées', 'Banane roulée', 'Coiffée en arrière', 'Undercut en arrière',
            'Undercut sur le côté', 'Crête hérissée', 'Bandana et tresse', 'Mod dégradé', 'Skinbyrd', 'Chignon soigné', 'Carré court'],
    };
    const BEARD = ['Barbe de 3 jours légère', 'Balbo', 'Barbe ronde', 'Bouc', 'Collier de menton', 'Duvet au menton',
        'Collier fin', 'Négligée', 'Mousquetaire', 'Moustache', 'Barbe taillée', 'Barbe de 3 jours', 'Barbe ronde fine',
        'Fer à cheval', 'Crayon et favoris', 'Collier', 'Balbo et favoris', 'Côtelettes', 'Barbe négligée', 'Bouclée',
        'Bouclée fournie', 'Moustache guidon', 'Faustienne', 'Otto et touffe', 'Otto pleine', 'Franz légère', 'Hampstead',
        'Ambrose', 'Collier Lincoln'];
    const BROWS = ['Équilibrés', 'Mode', 'Cléopâtre', 'Interrogateurs', 'Féminins', 'Séducteurs', 'Pincés', 'Chola',
        'Triomphe', 'Insouciants', 'Galbés', 'Fins et courts', 'Double trait', 'Fins', 'Crayonnés', 'Épilés',
        'Droits et étroits', 'Naturels', 'Duveteux', 'Broussailleux', 'Chenille', 'Classiques', 'Méditerranéens',
        'Soignés', 'Touffus', 'Plumes', 'Épineux', 'Monosourcil', 'Ailés', 'Triple trait', 'Trait arqué', 'Découpés',
        'Estompés', 'Trait unique'];
    const EYES = [
        ['Vert', '#4f8f3a'], ['Émeraude', '#1f9a6b'], ['Bleu clair', '#7fb6e6'], ['Bleu océan', '#2c63b5'],
        ['Marron clair', '#9a6a3a'], ['Marron foncé', '#4e2f1b'], ['Noisette', '#8a6b2c'], ['Gris foncé', '#4b5560'],
        ['Gris clair', '#a9b3bd'], ['Rose', '#e58bb5'], ['Jaune', '#e5c43a'], ['Violet', '#7a4bc9'],
        ['Noir total', '#050505'], ['Nuances de gris', '#777777'], ['Tequila sunrise', '#f08a24'], ['Atomique', '#9be52f'],
        ['Distorsion', '#5a2fd1'], ['E-Cola', '#c4161c'], ['Space ranger', '#1fb8d6'], ['Yin-yang', '#dddddd'],
        ['Cible', '#d6312a'], ['Lézard', '#b3a12c'], ['Dragon', '#d9661a'], ['Extraterrestre', '#3fd17a'],
        ['Chèvre', '#c9a04a'], ['Smiley', '#f2d13c'], ['Possédé', '#f4f4f4'], ['Démon', '#b3121b'],
        ['Infecté', '#cfd65a'], ['Alien', '#1c1c1c'], ['Mort-vivant', '#c8d0c8'], ['Zombie', '#9fb07a'],
    ];
    const NATURAL_EYES = 9;     // 0 à 8 : couleurs naturelles
    const NATURAL_HAIR = 29;    // 0 à 28 : teintes naturelles, ensuite fantaisie

    /* ---------- Onglets ---------- */
    const TABS = [
        { id: 'hair', ico: '✂️', label: 'Coupes', cam: 'head', modes: [{ k: 'hair', label: 'Coupe' }] },
        { id: 'color', ico: '🎨', label: 'Couleurs', cam: 'head', modes: [{ k: 'hair_color', label: 'Couleur' }, { k: 'hair_highlight', label: 'Reflets' }] },
        { id: 'beard', ico: '🧔', label: 'Barbe', cam: 'face', modes: [{ k: 'beard', label: 'Taille' }, { k: 'beard_color', label: 'Couleur' }, { k: 'beard_highlight', label: 'Reflets' }] },
        { id: 'brows', ico: '〰️', label: 'Sourcils', cam: 'face', modes: [{ k: 'brows', label: 'Forme' }, { k: 'brows_color', label: 'Couleur' }] },
        { id: 'eyes', ico: '👁️', label: 'Yeux', cam: 'eyes', modes: [{ k: 'eyes', label: 'Lentilles' }] },
        { id: 'chest', ico: '💪', label: 'Torse', cam: 'bust', modes: [{ k: 'chest', label: 'Pilosité' }, { k: 'chest_color', label: 'Couleur' }] },
    ];
    const KEY_LABEL = {
        hair: 'Coupe', hair_color: 'Couleur des cheveux', hair_highlight: 'Reflets des cheveux',
        beard: 'Barbe', beard_color: 'Couleur de barbe', beard_highlight: 'Reflets de barbe',
        brows: 'Sourcils', brows_color: 'Couleur des sourcils', eyes: 'Lentilles', chest: 'Pilosité du torse', chest_color: 'Couleur du torse',
    };
    const KEY_ICO = { hair: '✂️', hair_color: '🎨', hair_highlight: '✨', beard: '🧔', beard_color: '🎨', beard_highlight: '✨', brows: '〰️', brows_color: '🎨', eyes: '👁️', chest: '💪', chest_color: '🎨' };
    const STYLE = { beard: true, brows: true, chest: true };
    const COLOR = { hair_color: true, hair_highlight: true, beard_color: true, beard_highlight: true, brows_color: true, chest_color: true };
    const CAMS = [{ id: 'head', label: 'Tête' }, { id: 'face', label: 'Visage' }, { id: 'eyes', label: 'Yeux' }, { id: 'bust', label: 'Buste' }];

    const B = { open: false };
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const money = (n) => `${Number(n || 0).toLocaleString('fr-FR')} $`;
    const send = (ep, body = {}) => fetch(`https://${RES}/${ep}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(body),
    }).catch(() => {});

    /* ---------- Valeurs ---------- */
    const priceOf = (k) => (B.shop.prices[k] ?? 0);
    const chosen = (k) => (B.cart[k] ? B.cart[k].value : B.current[k]);
    const same = (k, a, b) => (STYLE[k] ? a.s === b.s && Math.abs(a.o - b.o) < 0.005 : a === b);
    const sameStyle = (k, a, b) => (STYLE[k] ? a.s === b.s : a === b);
    const tabOn = (t) => t.modes.some((m) => B.shop.prices[m.k] !== undefined)
        && (t.id !== 'beard' || B.beardTab) && (t.id !== 'chest' || B.chestTab);

    function labelOf(k, v) {
        if (k === 'hair') return B.customLabels[String(v)] || (HAIR[B.gender] || [])[v] || `Coupe n°${v}`;
        if (k === 'eyes') return (EYES[v] || [`Couleur n°${v}`])[0];
        if (COLOR[k]) return `Teinte n°${v + 1}`;
        const s = v.s;
        if (k === 'beard') return s < 0 ? 'Rasé de près' : (BEARD[s] || `Barbe n°${s + 1}`);
        if (k === 'brows') return s < 0 ? 'Aucun (épilés)' : (BROWS[s] || `Sourcils n°${s + 1}`);
        return s < 0 ? 'Torse lisse' : `Pilosité n°${s + 1}`;
    }

    // Valeur envoyée pour un élément de liste (les styles gardent la densité choisie)
    function valueFor(k, raw) {
        const n = Number(raw);
        if (!STYLE[k]) return n;
        const cur = chosen(k);
        return { s: n, o: cur.s < 0 ? 1 : cur.o };
    }

    /* ---------- Squelette ---------- */
    function frame() {
        const tabs = TABS.filter(tabOn);
        if (!tabs.find((t) => t.id === B.tab)) B.tab = tabs[0] ? tabs[0].id : 'hair';
        const w = B.shop.wallet || {};
        const wallet = Object.entries(w).map(([k, v]) => `<span class="bb-w"><i>${k === 'bank' ? '🏦' : k === 'cash' ? '💵' : '👜'}</i>${money(v)}</span>`).join('');
        root.innerHTML = `
            <div class="bb-stage" id="bb-stage"></div>
            <aside class="bb-panel bb-left">
                <div class="bb-pole" aria-hidden="true"></div>
                <header class="bb-head">
                    <img src="logo.png" alt="">
                    <div class="bb-title"><h1>${esc(B.shop.name)}</h1><p>${wallet || 'Salon de coiffure'}</p></div>
                </header>
                <nav class="bb-tabs" style="grid-template-columns:repeat(${Math.max(tabs.length, 1)},1fr)">
                    ${tabs.map((t) => `<button class="bb-tab ${t.id === B.tab ? 'on' : ''}" data-tab="${t.id}"><span>${t.ico}</span>${t.label}</button>`).join('')}
                </nav>
                <div class="bb-tools" id="bb-tools"></div>
                <div class="bb-list" id="bb-list"></div>
                <div class="bb-foot" id="bb-foot"></div>
            </aside>
            <div class="bb-hover hidden" id="bb-hover"></div>
            <div class="bb-ctrl">
                <button class="bb-rot" data-spin="-1" title="Tourner (←)">⟲</button>
                ${CAMS.map((c) => `<button class="bb-cam ${B.cam === c.id ? 'on' : ''}" data-cam="${c.id}">${c.label}</button>`).join('')}
                <button class="bb-rot" data-spin="1" title="Tourner (→)">⟳</button>
                <small>Glisse sur ton personnage pour le tourner, molette pour zoomer</small>
            </div>
            <aside class="bb-panel bb-right">
                <header class="bb-cart-head"><h2>Panier</h2><span id="bb-count"></span>
                    <button class="sb-close" id="bb-close" title="Quitter sans payer (Échap)">✕</button></header>
                <div class="bb-cart" id="bb-cart"></div>
                <div class="bb-pay" id="bb-pay"></div>
            </aside>`;
        drawTab();
        drawCart();
    }

    /* ---------- Onglet : outils + liste ---------- */
    function currentTab() { return TABS.find((t) => t.id === B.tab) || TABS[0]; }
    function currentKey() {
        const t = currentTab();
        const modes = t.modes.filter((m) => B.shop.prices[m.k] !== undefined);
        if (!modes.find((m) => m.k === B.mode)) B.mode = modes[0] ? modes[0].k : t.modes[0].k;
        return B.mode;
    }

    function drawTab() {
        const t = currentTab();
        const k = currentKey();
        const modes = t.modes.filter((m) => B.shop.prices[m.k] !== undefined);
        const tools = document.getElementById('bb-tools');
        tools.innerHTML = `
            ${modes.length > 1 ? `<div class="bb-modes">${modes.map((m) => `<button class="bb-mode ${m.k === k ? 'on' : ''}" data-mode="${m.k}">${m.label}</button>`).join('')}</div>` : ''}
            <div class="bb-price">${esc(KEY_LABEL[k])} <b>${priceOf(k) ? money(priceOf(k)) : 'Gratuit'}</b></div>
            ${k === 'hair' ? `<input class="input bb-search" id="bb-search" placeholder="Chercher une coupe ou un numéro…" value="${esc(B.search)}">` : ''}`;
        drawList();
        drawFoot();
    }

    function listItems(k) {
        const c = B.counts;
        if (k === 'hair') {
            const bl = new Set((B.blacklist || []).map(Number));
            const q = B.search.trim().toLowerCase();
            const out = [];
            for (let i = 0; i < c.hair; i++) {
                if (bl.has(i)) continue;
                const label = labelOf('hair', i);
                if (q && !label.toLowerCase().includes(q) && String(i) !== q) continue;
                out.push({ v: i, label });
            }
            return out;
        }
        if (k === 'eyes') {
            const max = B.shop.specialEyes ? EYES.length : NATURAL_EYES;
            return EYES.slice(0, max).map((e, i) => ({ v: i, label: e[0], hex: e[1] }));
        }
        if (STYLE[k]) {
            const n = c[k] || 0;
            const out = [{ v: -1, label: labelOf(k, { s: -1 }) }];
            for (let i = 0; i < n; i++) out.push({ v: i, label: labelOf(k, { s: i }) });
            return out;
        }
        return B.colors.map((hex, i) => ({ v: i, hex }));
    }

    function isSel(k, v) { const cur = chosen(k); return STYLE[k] ? cur.s === v : cur === v; }
    function isOrig(k, v) { const cur = B.current[k]; return STYLE[k] ? cur.s === v : cur === v; }

    function drawList() {
        const k = currentKey();
        const list = document.getElementById('bb-list');
        const items = listItems(k);
        const flags = (v) => `${isSel(k, v) ? ' sel' : ''}${isOrig(k, v) ? ' orig' : ''}`;
        if (COLOR[k]) {
            const nat = items.filter((i) => i.v < NATURAL_HAIR), fun = items.filter((i) => i.v >= NATURAL_HAIR);
            const sw = (i) => `<button class="bb-sw${flags(i.v)}" data-v="${i.v}" style="--c:${i.hex}" title="Teinte n°${i.v + 1}"></button>`;
            list.className = 'bb-list';
            list.innerHTML = `<h3>Teintes naturelles</h3><div class="bb-swatches">${nat.map(sw).join('')}</div>
                ${fun.length ? `<h3>Teintes fantaisie</h3><div class="bb-swatches">${fun.map(sw).join('')}</div>` : ''}`;
        } else if (k === 'eyes') {
            list.className = 'bb-list';
            const card = (i) => `<button class="bb-eye${flags(i.v)}" data-v="${i.v}"><i style="--c:${i.hex}"></i><span>${esc(i.label)}</span></button>`;
            list.innerHTML = `<h3>Couleurs naturelles</h3><div class="bb-eyes">${items.filter((i) => i.v < NATURAL_EYES).map(card).join('')}</div>
                ${items.length > NATURAL_EYES ? `<h3>Lentilles fantaisie</h3><div class="bb-eyes">${items.filter((i) => i.v >= NATURAL_EYES).map(card).join('')}</div>` : ''}`;
        } else {
            list.className = 'bb-list';
            list.innerHTML = items.length
                ? `<div class="bb-grid">${items.map((i) => `<button class="bb-item${flags(i.v)}" data-v="${i.v}">
                        <b>${i.v < 0 ? '∅' : i.v + (k === 'hair' ? 0 : 1)}</b><span>${esc(i.label)}</span></button>`).join('')}</div>`
                : `<div class="bb-empty">Aucune coupe ne correspond à « ${esc(B.search)} ». Essaie un autre mot ou un numéro.</div>`;
        }
    }

    // Densité (barbe, sourcils, torse)
    function drawFoot() {
        const k = currentKey();
        const foot = document.getElementById('bb-foot');
        if (!STYLE[k] || chosen(k).s < 0) { foot.innerHTML = ''; return; }
        const o = Math.round(chosen(k).o * 100);
        foot.innerHTML = `<label class="bb-range"><span>Densité <b id="bb-op">${o} %</b></span>
            <input type="range" min="10" max="100" step="5" value="${o}" id="bb-opacity"></label>`;
    }

    // Met à jour les repères « choisi » sans reconstruire la liste (garde le défilement)
    function markList() {
        const k = currentKey();
        document.querySelectorAll('#bb-list [data-v]').forEach((el) => el.classList.toggle('sel', isSel(k, Number(el.dataset.v))));
    }

    /* ---------- Panier ---------- */
    const cartKeys = () => Object.keys(B.cart);
    const total = () => cartKeys().reduce((s, k) => s + B.cart[k].price, 0);

    function drawCart() {
        const keys = cartKeys();
        document.getElementById('bb-count').textContent = keys.length ? `${keys.length} prestation${keys.length > 1 ? 's' : ''}` : '';
        const cart = document.getElementById('bb-cart');
        cart.innerHTML = keys.length ? keys.map((k) => {
            const it = B.cart[k];
            const sw = COLOR[k] ? `<i class="bb-dot" style="--c:${B.colors[it.value]}"></i>` : k === 'eyes' ? `<i class="bb-dot" style="--c:${EYES[it.value][1]}"></i>` : '';
            return `<div class="bb-line"><span class="bb-ico">${KEY_ICO[k]}</span>
                <div class="bb-line-txt"><small>${esc(KEY_LABEL[k])}</small><strong>${sw}${esc(it.label)}${STYLE[k] && it.value.s >= 0 && it.value.o < 1 ? ` <em>${Math.round(it.value.o * 100)} %</em>` : ''}</strong></div>
                <span class="bb-line-price">${it.price ? money(it.price) : 'Offert'}</span>
                <button class="bb-del" data-del="${k}" title="Retirer">✕</button></div>`;
        }).join('') : `<div class="bb-empty">Survole un style pour le voir sur toi, puis clique dessus pour l'ajouter au panier.</div>`;

        const sum = total();
        const pay = document.getElementById('bb-pay');
        const w = B.shop.wallet || {};
        const method = B.shop.payChoice ? B.method : B.shop.payment;
        const have = w[method] ?? w[Object.keys(w)[0]];
        const short = keys.length && sum > 0 && have !== undefined && have < sum;
        pay.innerHTML = `
            <div class="bb-total"><span>Total</span><b>${money(sum)}</b></div>
            ${B.shop.payChoice ? `<div class="bb-modes bb-method">
                <button class="bb-mode ${B.method === 'cash' ? 'on' : ''}" data-method="cash">💵 Liquide</button>
                <button class="bb-mode ${B.method === 'bank' ? 'on' : ''}" data-method="bank">🏦 Banque</button></div>`
                : `<p class="bb-note">Paiement : ${B.shop.payment === 'bank' ? 'banque' : B.shop.payment === 'item' ? esc(B.shop.paymentLabel || 'objet') : 'argent liquide'}</p>`}
            ${short ? `<p class="bb-warn">Il te manque ${money(sum - have)}.</p>` : ''}
            ${B.error ? `<p class="bb-warn bb-shake">${esc(B.error)}</p>` : ''}
            ${B.done ? `<p class="bb-ok">✓ ${esc(B.done)}</p>` : ''}
            <button class="btn primary big bb-go" id="bb-go" ${!keys.length || B.paying || B.done ? 'disabled' : ''}>
                ${B.paying ? 'Paiement en cours…' : sum > 0 ? `Payer ${money(sum)}` : 'Valider'}</button>
            <button class="btn bb-reset" id="bb-reset" ${!keys.length || B.paying ? 'disabled' : ''}>Vider le panier</button>`;
    }

    function addToCart(k, value) {
        B.error = null;
        if (same(k, value, B.current[k]) || (STYLE[k] && value.s < 0 && B.current[k].s < 0)) {
            if (B.cart[k]) { delete B.cart[k]; send('barber_unset', { key: k }); }
        } else {
            B.cart[k] = { value, label: labelOf(k, value), price: priceOf(k) };
            send('barber_set', { key: k, value });
        }
        markList();
        drawFoot();
        drawCart();
    }

    /* ---------- Aperçu au survol (regroupé) ---------- */
    let hoverSent = null, hoverWant = null, hoverTimer = 0, lastSend = 0;
    function flushHover() {
        hoverTimer = 0;
        const sig = JSON.stringify(hoverWant);
        if (sig === hoverSent) return;
        hoverSent = sig;
        lastSend = performance.now();
        send('barber_preview', hoverWant || {});
    }
    function wantPreview(p) {
        hoverWant = p;
        if (hoverTimer) return;
        const wait = Math.max(0, 40 - (performance.now() - lastSend));
        hoverTimer = setTimeout(flushHover, wait);
        const hv = document.getElementById('bb-hover');
        if (p) { hv.textContent = `${KEY_LABEL[p.key]} · ${labelOf(p.key, p.value)}`; hv.classList.remove('hidden'); } else hv.classList.add('hidden');
    }

    /* ---------- Événements ---------- */
    root.addEventListener('mouseover', (e) => {
        const it = e.target.closest('#bb-list [data-v]');
        if (!it || B.paying) return;
        const k = currentKey();
        const v = valueFor(k, it.dataset.v);
        wantPreview({ key: k, value: v });
    });
    root.addEventListener('mouseout', (e) => {
        const list = document.getElementById('bb-list');
        if (!list || !e.target.closest('#bb-list')) return;
        if (e.relatedTarget && list.contains(e.relatedTarget)) return;
        wantPreview(null);
    });

    root.addEventListener('click', (e) => {
        let n;
        if ((n = e.target.closest('#bb-list [data-v]'))) { const k = currentKey(); return addToCart(k, valueFor(k, n.dataset.v)); }
        if ((n = e.target.closest('[data-tab]'))) {
            B.tab = n.dataset.tab; B.mode = null; B.search = '';
            const t = currentTab();
            setCam(t.cam);
            root.querySelectorAll('.bb-tab').forEach((x) => x.classList.toggle('on', x === n));
            return drawTab();
        }
        if ((n = e.target.closest('[data-mode]'))) { B.mode = n.dataset.mode; return drawTab(); }
        if ((n = e.target.closest('[data-cam]'))) return setCam(n.dataset.cam);
        if ((n = e.target.closest('[data-method]'))) { B.method = n.dataset.method; B.error = null; return drawCart(); }
        if ((n = e.target.closest('[data-del]'))) {
            const k = n.dataset.del;
            delete B.cart[k]; B.error = null;
            send('barber_unset', { key: k });
            markList(); drawFoot(); return drawCart();
        }
        if (e.target.closest('#bb-reset')) { B.cart = {}; B.error = null; send('barber_reset'); markList(); drawFoot(); return drawCart(); }
        if (e.target.closest('#bb-go')) {
            if (!cartKeys().length || B.paying) return;
            B.paying = true; B.error = null; drawCart();
            return send('barber_pay', { method: B.method });
        }
        if (e.target.closest('#bb-close')) return close();
    });

    root.addEventListener('input', (e) => {
        if (e.target.id === 'bb-search') {
            B.search = e.target.value;
            clearTimeout(B.searchT);
            B.searchT = setTimeout(drawList, 120);
        }
        if (e.target.id === 'bb-opacity') {
            const k = currentKey();
            const o = Number(e.target.value) / 100;
            document.getElementById('bb-op').textContent = `${e.target.value} %`;
            wantPreview({ key: k, value: { s: chosen(k).s, o } });
        }
    });
    root.addEventListener('change', (e) => {
        if (e.target.id !== 'bb-opacity') return;
        const k = currentKey();
        addToCart(k, { s: chosen(k).s, o: Number(e.target.value) / 100 });
        wantPreview(null);
    });

    function setCam(id) {
        B.cam = id;
        send('barber_cam', { mode: id });
        root.querySelectorAll('.bb-cam').forEach((x) => x.classList.toggle('on', x.dataset.cam === id));
    }

    // Rotation : glisser sur le personnage, boutons maintenus, flèches du clavier
    let drag = false, acc = 0, rotT = 0;
    const flushRot = () => { rotT = 0; if (acc) { send('barber_rotate', { d: acc * 0.45 }); acc = 0; } };
    root.addEventListener('mousedown', (e) => {
        if (e.target.id === 'bb-stage') { drag = true; e.target.classList.add('grab'); }
        const s = e.target.closest('[data-spin]');
        if (s) send('barber_spin', { dir: Number(s.dataset.spin) });
    });
    window.addEventListener('mousemove', (e) => {
        if (!drag || !B.open) return;
        acc += e.movementX;
        if (!rotT) rotT = setTimeout(flushRot, 30);
    });
    window.addEventListener('mouseup', () => {
        if (!B.open) return;
        if (drag) { drag = false; const st = document.getElementById('bb-stage'); if (st) st.classList.remove('grab'); }
        send('barber_spin', { dir: 0 });
    });
    let wheelT = 0;
    root.addEventListener('wheel', (e) => {
        if (e.target.id !== 'bb-stage' || wheelT) return;
        wheelT = setTimeout(() => { wheelT = 0; }, 35);
        send('barber_zoom', { d: e.deltaY > 0 ? 1 : -1 });
    }, { passive: true });

    let spinKey = 0;
    document.addEventListener('keydown', (e) => {
        if (!B.open) return;
        if (e.key === 'Escape') { e.preventDefault(); return close(); }
        const typing = document.activeElement && document.activeElement.tagName === 'INPUT' && document.activeElement.type !== 'range';
        if (typing) return;
        const dir = e.key === 'ArrowLeft' || e.key === 'q' || e.key === 'a' ? -1 : e.key === 'ArrowRight' || e.key === 'd' ? 1 : 0;
        if (dir && spinKey !== dir) { spinKey = dir; send('barber_spin', { dir }); }
    });
    document.addEventListener('keyup', (e) => {
        if (!B.open || !spinKey) return;
        if (['ArrowLeft', 'ArrowRight', 'q', 'a', 'd'].includes(e.key)) { spinKey = 0; send('barber_spin', { dir: 0 }); }
    });

    function close() {
        if (B.paying) return;
        send('barber_close');
    }

    /* ---------- Messages Lua ---------- */
    window.addEventListener('message', (ev) => {
        const m = ev.data;
        if (!m || m.action !== 'barber') return;
        if (m.event === 'payfail') { B.paying = false; B.error = m.msg; return B.open && drawCart(); }
        if (m.event === 'paid') { B.paying = false; B.done = m.msg || 'Payé !'; return B.open && drawCart(); }
        if (m.open) {
            Object.assign(B, {
                open: true, shop: m.shop, gender: m.gender, counts: m.counts || {}, colors: m.colors || [],
                current: m.current, blacklist: m.blacklist || [], customLabels: m.customLabels || {},
                beardTab: !!m.beardTab, chestTab: !!m.chestTab,
                tab: 'hair', mode: null, search: '', cart: {}, cam: 'head',
                method: (m.shop.wallet && m.shop.wallet.cash === undefined) ? 'bank' : 'cash',
                paying: false, error: null, done: null,
            });
            hoverSent = null; hoverWant = null;
            frame();
            const t = currentTab();
            if (t.cam !== 'head') setCam(t.cam);
            root.classList.remove('hidden');
            document.body.classList.add('barber-open');
        } else {
            B.open = false;
            root.classList.add('hidden');
            root.innerHTML = '';
            document.body.classList.remove('barber-open');
        }
    });
})();
