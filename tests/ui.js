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

    const click = (attr, data) => docListeners.click.forEach((fn) => fn({ target: target(attr, data), preventDefault() {} }));
    for (const fx of ['admin_bloods', 'admin_vagos']) {
        setData(load(fx));
        vm.runInContext('render()', ctx);
        for (const sub of ['info', 'members', 'grades', 'finances', 'ped', 'stash', 'orders', 'settings']) {
            click('data-ils', { ils: sub });
            clean(vm.runInContext('__html', ctx), `${fx} › ${sub}`);
        }
    }
    // ILLEGAL › Missions : accueil (niveaux, liste) puis chaque section de la page « Colis test »
    setData(load('admin_list'));
    vm.runInContext('render()', ctx);
    click('data-mt', { mt: 'missions' });
    let mh = vm.runInContext('__html', ctx);
    clean(mh, 'ILLEGAL › Missions');
    check(mh.includes('Colis test') && mh.includes('Niveaux des groupes') && mh.includes('data-mx="lvlSave"'), 'missions : liste et niveaux');
    click('data-mx', { mx: 'open', mid: 'colis_test' });
    for (const sec of ['general', 'groups', 'progression', 'locations', 'guards', 'weapons', 'crate', 'delivery', 'timer', 'rewards', 'phone', 'cooldown', 'security']) {
        click('data-msec', { msec: sec });
        clean(vm.runInContext('__html', ctx), `Colis test › ${sec}`);
    }
    click('data-msec', { msec: 'guards' });
    check((vm.runInContext('__html', ctx).match(/Garde \d+/g) || []).length === 6, 'page Gardes : 6 gardes réglables');
    click('data-msec', { msec: 'timer' });
    click('data-mx', { mx: 'preset', path: 'timer.minutes', v: '20' });
    click('data-mx', { mx: 'save', sec: 'timer' });
    const ms = ctx.sent[ctx.sent.length - 1];
    check(ms.data.name === 'missionSave' && ms.data.data.section === 'timer' && ms.data.data.data.minutes === 20, 'timer : enregistrement envoyé (20 min)');
    click('data-mx', { mx: 'close' });
    // « Le Fourgon Fantôme » : toutes les sections générées depuis le schéma du serveur
    const fdata = load('admin_list');
    const ftype = fdata.missions.types.fourgon;
    check(ftype && ftype.sections.length >= 20, 'fourgon : sections envoyées par le serveur');
    mh = vm.runInContext('__html', ctx);
    check(mh.includes('Le Fourgon Fantôme'), 'missions : « Le Fourgon Fantôme » listée');
    click('data-mx', { mx: 'open', mid: 'fourgon_fantome' });
    for (const sec of ftype.sections) {
        click('data-msec', { msec: sec });
        clean(vm.runInContext('__html', ctx), `Fourgon › ${sec}`);
    }
    click('data-msec', { msec: 'locations' });
    click('data-mx', { mx: 'toggle', path: 'locations.list.0' });
    let fh = vm.runInContext('__html', ctx);
    check(fh.includes('Définir à ma position') && fh.includes('data-mx="tpos"') && fh.includes('Carrière de Davis Quartz'), 'emplacements : X/Y/Z/H + « Définir à ma position »');
    check(!/mode placement/i.test(fh), 'aucun mode placement');
    click('data-mx', { mx: 'mypos', path: 'locations.list.0.van' });
    check(ctx.sent[ctx.sent.length - 1].data.name === 'missionMyPos', '« Définir à ma position » → action serveur missionMyPos');
    fdata.missions.myPos = { x: 11.5, y: 22.25, z: 33, h: 90, t: 12345 };
    setData(fdata);
    vm.runInContext('render()', ctx);
    click('data-mx', { mx: 'save', sec: 'locations' });
    const fs1 = ctx.sent[ctx.sent.length - 1];
    check(fs1.data.name === 'missionSave' && fs1.data.data.missionId === 'fourgon_fantome' && fs1.data.data.data.list[0].van.x === 11.5
        && fs1.data.data.data.list[0].van.h === 90, 'position du staff appliquée puis enregistrée');
    click('data-msec', { msec: 'scenarios' });
    fh = vm.runInContext('__html', ctx);
    for (const s2 of ['Fourgon abandonné', 'Accident', 'Fourgon surveillé', 'Faux fourgon', 'Fourgon déplacé']) check(fh.includes(s2), `scénario « ${s2} »`);
    click('data-mx', { mx: 'listAdd', path: 'scenarios.list' });
    click('data-mx', { mx: 'save', sec: 'scenarios' });
    const fs2 = ctx.sent[ctx.sent.length - 1];
    check(fs2.data.data.section === 'scenarios' && fs2.data.data.data.list.length === 6, 'scénario ajouté (6) et envoyé');
    click('data-msec', { msec: 'hud' });
    clean(vm.runInContext('__html', ctx), 'Fourgon › HUD');
    click('data-mx', { mx: 'close' });
    click('data-mt', { mt: 'groups' });
    const gh = vm.runInContext('__html', ctx);
    check(gh.includes('Progression des groupes') && gh.includes('data-op="setXp"'), 'groupes : progression et actions');

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
    for (const t of ['home', 'members', 'grades', 'finances', 'orders', 'missions', 'settings']) {
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
        els['#tabs'].listeners.click.forEach((fn) => fn({ target: { closest: () => ({ dataset: { tab: 'missions' } }) } }));
        const mh2 = els['#content'].innerHTML;
        check(mh2.includes('Colis test') && mh2.includes('Lancer la mission') && mh2.includes('Niveau'), 'tablette : onglet Missions (OG peut lancer)');
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
        console, JSON, Object, Array, Number, String, Date, Math, Promise, Set, setInterval: () => 0, setTimeout: () => 0, clearInterval: () => {}, clearTimeout: () => {},
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
    // HUD de mission (fourgon) : discret, informations persistantes, « utilisé », alerte
    send({ action: 'missionHud', show: true, label: 'Le Fourgon Fantôme', objective: 'Trouver des indices', remaining: 1500, alert: 2,
        cfg: { enabled: true, position: 'top-left', scale: 0.9, opacity: 0.8, showTimer: true, showCodes: true },
        info: [{ key: 'objective', label: 'Objectif', value: 'Trouver la vraie marchandise', cat: 'objective', order: 1 },
            { key: 'alert', label: 'Alerte', value: '2 — Alerte 2', cat: 'alert', order: 2 },
            { key: 'clue1', label: 'Plaque du fourgon', value: 'AB-472-CD', cat: 'plate', order: 11 },
            { key: 'code', label: 'Code caisse', value: '4729', cat: 'code', used: true, order: 13 },
            { key: 'tmp', label: 'Témoin', value: 'expiré', cat: 'info', remaining: 0, order: 20 }] });
    const hud = els['#missionhud'];
    check(hud.className.includes('compact') && hud.className.includes('pos-top-left'), 'HUD : compact, position configurable');
    check(hud.innerHTML.includes('Trouver la vraie marchandise') && hud.innerHTML.includes('AB-472-CD') && hud.innerHTML.includes('25:00'), 'HUD : objectif, plaque, timer');
    check(hud.innerHTML.includes('4729') && hud.innerHTML.includes('utilisé'), 'HUD : code conservé, marqué « utilisé »');
    check(hud.innerHTML.includes('alert a2') && !hud.innerHTML.includes('expiré'), 'HUD : niveau d\'alerte, information temporaire expirée retirée');
    clean(hud.innerHTML, 'HUD de mission');
    send({ action: 'missionHud', show: true, label: 'X', remaining: 60, cfg: { showCodes: false }, info: [{ key: 'code', label: 'Code', value: '9999', cat: 'code' }] });
    check(!hud.innerHTML.includes('9999'), 'HUD : catégorie masquable (codes)');
    send({ action: 'codeInput', crate: 3 });
    check(els['#modal-root'].innerHTML.includes('Caisse n°3') && els['#modal-root'].innerHTML.includes('data-cm="force"'), 'saisie du code : Valider / Forcer / Annuler');
}

console.log(`\n${passed} réussis, ${failed} échoués`);
process.exit(failed ? 1 : 0);
