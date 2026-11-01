import { readFileSync } from "node:fs";

const [templatePath, mode] = process.argv.slice(2);
const html = readFileSync(templatePath, "utf8");
const script = html.match(/<script>([\s\S]*)<\/script>/)[1]
  .replace("/*DATA*/null", JSON.stringify({ pack: "testland", displayName: "Testland", leaders: [{ key: "alpha", name: "Alpha", role: "General", round: 1, seeds: [1, 2, 3, 4], previous: null, credit: "", creditUrl: "", photo: "", colour: "", candidates: [1, 2, 3, 4].map(seed => ({ seed, likeness: 0.3, game: "g", view: "v" })) }] }));

const created = [];
function element(tag) {
  const el = {
    tag, children: [], attributes: {}, style: { setProperty() {} }, classList: { toggle() {} },
    appendChild(child) { this.children.push(child); return child; },
    append(...items) { this.children.push(...items); },
    replaceChildren() { this.children = []; },
    setAttribute(name, value) { this.attributes[name] = value; },
    removeAttribute(name) { delete this.attributes[name]; },
    addEventListener() {},
    focus() {}, close() {}, showModal() {}
  };
  created.push(el);
  return el;
}
const byId = {};
globalThis.document = {
  getElementById(id) { return byId[id] || (byId[id] = element("#" + id)); },
  createElement: element,
  documentElement: element("html"),
  body: element("body")
};
globalThis.navigator = {};
const store = {
  collection() {
    return {
      onSnapshot(onData, onError) {
        if (mode === "error") setTimeout(() => onError(new Error("refused")), 20);
        if (mode === "ok") setTimeout(() => onData({ metadata: { fromCache: false }, docs: [] }), 20);
      },
      doc() { return { set: async () => {} }; }
    };
  }
};
globalThis.window = { claude: { use: async name => name === "user" ? { isOwner: async () => true } : store } };
const realSetTimeout = setTimeout;
globalThis.setTimeout = (fn, ms) => realSetTimeout(fn, Math.min(ms, 50));

new Function(script)();
await new Promise(resolve => realSetTimeout(resolve, 300));
const picks = created.filter(el => el.tag === "button" && el.textContent === "Pick");
const latest = picks.slice(-4);
console.log(JSON.stringify({ mode, store: byId.storeState.textContent, pickEnabled: latest.every(button => button.disabled === false) }));
