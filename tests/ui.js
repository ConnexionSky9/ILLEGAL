// =========================================================
//  Test de rendu des interfaces avec les données réelles du serveur
//  (produites par tests/run.lua avec FIXTURES=<dossier>).
//    FIXTURES=/tmp/fx lua5.4 tests/run.lua && FIXTURES=/tmp/fx node tests/ui.js
// =========================================================
const fs = require('fs');
const vm = require('vm');
const path = require('path');
const FIX = process.env.FIXTURES;
const load = (n) => JSON.parse(fs.readFileSync(path.join(FIX, `${n}.json`), 'utf8'));
let passed = 0, failed = 0;
const check = (cond, label) => { if (cond) passed++; else { failed++; console.log(`  ✗ ${label}`); } };
const clean = (html, label) => {
    check(typeof html === 'string' && html.length > 0, `${label} : rendu non vide`);
    check(!/undefined|NaN|\[object Object\]/.test(html), `${label} : pas de « undefined / NaN / [object Object] »`);
};

// Élément DOM minimal
function el() {
    return { innerHTML: '', textContent: '', value: '', scrollTop: 0, dataset: {}, style: { setProperty() {} }, listeners: {},
        classList: { add() {}, remove() {}, toggle() {}, contains: () => false },
        addEventListener(t, fn) { (this.listeners[t] = this.listeners[t] || []).push(fn); },
        querySelector: () => null, querySelectorAll: () => [], focus() {}, appendChild() {} };
}
const target = (attr, data) => ({ dataset: data, disabled: false, closest: (sel) => (sel === `[${attr}]` ? { dataset: data, disabled: false } : null) });

// ---------------------------------------------------------
//  1. Onglet ILLEGAL du menu staff (admin_menu/html/illegal.js)
// ---------------------------------------------------------
{
    const docListeners = {};
    let html = '';
    const ctx = {
        console, JSON, Object, Array, Number, String, Date, Math, Promise, setTimeout: (fn) => fn(),
        document: { addEventListener: (t, fn) => { (docListeners[t] = docListeners[t] || []).push(fn); } },
        esc: (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])),
        sent: [],
    };
    vm.createContext(ctx);
    vm.runInContext(`
        var TAB_GROUP_TITLES = { 5: 'Métiers' };
        var TABS = [{ id: 'home', group: 1 }];
        var VIEWS = {};
        var D = null, isOpen = true, tab = 'illegal';
        var has = (p) => !!(D && D.me.perms[p]);
        var action = (name, data) => sent.push({ name, data });
        var post = () => Promise.resolve({});
        var render = () => { globalThis.__html = VIEWS.illegal(); };
        var formModal = async () => null, confirmBox = async () => false, toast = () => {};
    `, ctx);
    vm.runInContext(fs.readFileSync('admin_menu/html/illegal.js', 'utf8'), ctx);
    const tabDef = vm.runInContext('TABS.find((t) => t.id === "illegal")', ctx);
    check(tabDef && tabDef.group === 6 && tabDef.label === 'ILLEGAL', 'onglet ILLEGAL ajouté (groupe 6)');
    check(vm.runInContext('TAB_GROUP_TITLES[5] === "Métiers" && TAB_GROUP_TITLES[6] === "Illégal"', ctx), 'titres de groupes existants conservés');
    check(vm.runInContext('TABS[0].id === "home" && TABS.length === 2', ctx), 'onglets existants intacts');

    const setData = (fixture, perms = { illegal_staff: true }) => vm.runInContext(`D = ${JSON.stringify({ me: { perms }, illegal: fixture })};`, ctx);
    setData(load('admin_list'), {});
    check(vm.runInContext('TABS.find((t) => t.id === "illegal").show()', ctx) === false, 'onglet caché sans la permission illegal_staff');
    setData(load('admin_list'));
    check(vm.runInContext('TABS.find((t) => t.id === "illegal").show()', ctx) === true, 'onglet visible avec illegal_staff');
    html = vm.runInContext('VIEWS.illegal()', ctx);
    clean(html, 'dashboard');
    check(ctx.sent.filter((x) => x.data.name === 'loadItems').length === 1, 'liste des objets ox_inventory demandée une fois');
    vm.runInContext('VIEWS.illegal()', ctx);
    check(ctx.sent.filter((x) => x.data.name === 'loadItems').length === 1, 'pas de nouvelle demande au rendu suivant');
    for (const s of ['Groupes', 'Membres', 'Gangs', 'Organisations', 'Cartels', 'Argent propre total', 'Argent sale total', 'Bloods', 'Vagos', 'Cartel Sinaloa', 'Pistolet',
        'Points de livraison', 'lieux par défaut'])
        check(html.includes(s), `dashboard affiche « ${s} »`);
    setData({ available: false, resource: 'elyzea_illegal' });
    check(vm.runInContext('VIEWS.illegal()', ctx).includes('ensure elyzea_illegal'), 'message si la ressource n\'est pas démarrée');

    const click = (attr, data) => docListeners.click.forEach((fn) => fn({ target: target(attr, data) }));
    for (const fx of ['admin_bloods', 'admin_vagos']) {
        setData(load(fx));
        vm.runInContext('render()', ctx);
        for (const sub of ['info', 'members', 'grades', 'finances', 'ped', 'stash', 'orders', 'settings']) {
            click('data-ils', { ils: sub });
            clean(vm.runInContext('__html', ctx), `${fx} › ${sub}`);
        }
    }
    setData(load('admin_bloods'));
    vm.runInContext('render()', ctx);   // le menu fait un rendu à chaque réception de données
    click('data-ils', { ils: 'grades' });
    const og = load('admin_bloods').selected.grades.find((g) => !g.boss);
    click('data-ila', { ila: 'editPerms', gid: String(og.id) });
    const permHtml = vm.runInContext('__html', ctx);
    check(permHtml.includes('Permissions : ') && permHtml.includes('Recrutement'), 'éditeur de permissions d\'un grade');
    click('data-ilp', { ilp: 'kick' });
    click('data-ila', { ila: 'permSave' });
    const last = ctx.sent[ctx.sent.length - 1];
    check(last && last.name === 'illegal' && last.data.name === 'updateGrade' && last.data.data.gradeId === og.id && 'kick' in last.data.data.perms,
        'enregistrer les permissions → action updateGrade');
    click('data-ila', { ila: 'back' });
    check(ctx.sent[ctx.sent.length - 1].data.name === 'back', 'retour à la liste');
}

// ---------------------------------------------------------
//  2. Tablette du joueur (elyzea_illegal/html/app.js)
// ---------------------------------------------------------
for (const fx of ['tablet_og', 'tablet_lieutenant', 'tablet_recrue_vagos']) {
    const els = {};
    const winListeners = {}, docListeners = {};
    const ctx = {
        console, JSON, Object, Array, Number, String, Date, Math, Promise, setInterval: () => 0, setTimeout: () => 0,
        fetch: () => Promise.resolve({ json: () => ({}) }),
        window: { addEventListener: (t, fn) => { (winListeners[t] = winListeners[t] || []).push(fn); } },
        document: { querySelector: (s) => (els[s] = els[s] || el()), addEventListener: (t, fn) => { (docListeners[t] = docListeners[t] || []).push(fn); },
            documentElement: { style: { setProperty() {} } }, createElement: el },
    };
    vm.createContext(ctx);
    vm.runInContext(fs.readFileSync('elyzea_illegal/html/app.js', 'utf8'), ctx);
    const data = load(fx);
    winListeners.message.forEach((fn) => fn({ data: { action: 'open', data } }));
    check(els['#brand-name'].textContent === data.group.label, `${fx} : nom du groupe affiché (${data.group.label})`);
    const tabsHtml = els['#tabs'].innerHTML;
    for (const t of ['home', 'members', 'grades', 'finances', 'orders', 'settings']) {
        if (!tabsHtml.includes(`data-tab="${t}"`)) continue;
        els['#tabs'].listeners.click.forEach((fn) => fn({ target: { closest: () => ({ dataset: { tab: t } }) } }));
        clean(els['#content'].innerHTML, `${fx} › ${t}`);
    }
    const perms = data.me.perms;
    if (fx === 'tablet_lieutenant') {
        els['#tabs'].listeners.click.forEach((fn) => fn({ target: { closest: () => ({ dataset: { tab: 'orders' } }) } }));
        const oh = els['#content'].innerHTML;
        check(oh.includes('data-a="gps"') && oh.includes('Prête : point GPS'), 'commande prête : bouton GPS');
        check(!oh.includes('data-a="createOrder"'), 'catalogue géré par le staff : pas de création côté joueur');
        check(oh.includes('Cannabis') && oh.includes('Pistolet'), 'catalogue du groupe + commandes pour tous');
    }
    if (fx === 'tablet_recrue_vagos') {
        check(!tabsHtml.includes('data-tab="settings"'), 'recrue : pas d\'onglet Paramètres');
        els['#tabs'].listeners.click.forEach((fn) => fn({ target: { closest: () => ({ dataset: { tab: 'members' } }) } }));
        check(!els['#content'].innerHTML.includes('data-a="recruit"'), 'recrue : pas de bouton recruter');
    }
    if (fx === 'tablet_og') {
        check(tabsHtml.includes('data-tab="settings"') && perms.settings, 'OG : onglet Paramètres');
        els['#tabs'].listeners.click.forEach((fn) => fn({ target: { closest: () => ({ dataset: { tab: 'finances' } }) } }));
        const fin = els['#content'].innerHTML;
        check(fin.includes('Argent propre') && fin.includes('Argent sale') && fin.includes('Historique financier'), 'OG : finances et historique');
    }
}

// ---------------------------------------------------------
//  3. Invite [E], notifications et menu F5 : même rendu que le MenuStaff
// ---------------------------------------------------------
{
    const els = {};
    const winListeners = {};
    const ctx = {
        console, JSON, Object, Array, Number, String, Date, Math, Promise, Set, setInterval: () => 0, setTimeout: () => 0,
        fetch: () => Promise.resolve({ json: () => ({}) }),
        window: { addEventListener: (t, fn) => { (winListeners[t] = winListeners[t] || []).push(fn); } },
        document: { querySelector: (s) => (els[s] = els[s] || el()), addEventListener: () => {}, documentElement: { style: { setProperty() {} } },
            createElement: () => { const e = el(); e.className = ''; return e; } },
    };
    vm.createContext(ctx);
    vm.runInContext(fs.readFileSync('elyzea_illegal/html/app.js', 'utf8'), ctx);
    const send = (m) => winListeners.message.forEach((fn) => fn({ data: m }));
    send({ action: 'prompt', show: true, key: 'E', verb: 'Appuyer pour ouvrir le coffre', name: 'Bloods · Planque' });
    // Même balisage que l'invite du MenuStaff (admin_menu/html/script.js, case 'prompt')
    const adminJs = fs.readFileSync('admin_menu/html/script.js', 'utf8');
    check(adminJs.includes('<span class="pk">${esc(m.key || \'E\')}</span><span class="pt"><span class="pa">${esc(m.verb || \'\')}</span><span class="pn">${esc(m.name || \'\')}</span></span>'),
        'référence : balisage de l\'invite du MenuStaff');
    check(els['#prompt'].innerHTML === '<span class="pk">E</span><span class="pt"><span class="pa">Appuyer pour ouvrir le coffre</span><span class="pn">Bloods · Planque</span></span>',
        'invite [E] : balisage identique au MenuStaff');
    const css = fs.readFileSync('elyzea_illegal/html/style.css', 'utf8');
    const adminCss = fs.readFileSync('admin_menu/html/style.css', 'utf8');
    const rule = (src, sel) => { const i = src.indexOf(`${sel} {`); return i < 0 ? null : src.slice(i, src.indexOf('}', i) + 1); };
    for (const sel of ['#prompt', '#prompt .pk', '#prompt .pa', '#prompt .pn', '.toast', '.modal', '.btn.primary', '.tab.active', '.q-panel', '#app', '.statusbar', '.stat', '.segmented'])
        check(rule(css, sel) && rule(css, sel) === rule(adminCss, sel), `CSS « ${sel} » identique au MenuStaff`);
    let added = null;
    ctx.document.querySelector('#toasts').appendChild = (t) => { added = t; };
    send({ action: 'notify', message: 'Commande récupérée', type: 'success' });
    check(added && added.className === 'toast success' && added.textContent === 'Commande récupérée', 'notification au format du MenuStaff');
    send({ action: 'f5', data: { label: 'Bloods', grade: 'OG', color: '#aa0000' } });
    check(els['#quick'].innerHTML.includes('q-panel') && els['#quick'].innerHTML.includes('Bloods') && els['#quick'].innerHTML.includes('data-f5="open"'), 'menu F5 : panneau du menu rapide avec le groupe');
}

console.log(`\n${passed} réussis, ${failed} échoués`);
process.exit(failed ? 1 : 0);
