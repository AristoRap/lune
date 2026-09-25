import assert from "node:assert/strict";
import vm from "node:vm";
import { readFileSync } from "node:fs";
const scripts = JSON.parse(readFileSync(0, "utf8"));

// Minimal DOM doubles: the test executes Lune's actual injected listener.
// matches/getPropertyValue supply browser-owned selector/style results.
class Element {
  constructor({ value = "", selectors = [], parent = null } = {}) {
    this.parentElement = parent;
    this.selectors = selectors;
    this.style = {
      getPropertyValue: (name) => (name === "--test-drag" ? value : ""),
    };
  }
  matches(selector) {
    return selector
      .split(",")
      .some((item) => this.selectors.includes(item.trim()));
  }
}
class HTMLElement extends Element {
  clientLeft = 0;
  clientTop = 0;
  clientWidth = 100;
  clientHeight = 100;
  scrollWidth = 200;
  scrollHeight = 200;
  offsetWidth = 115;
  offsetHeight = 115;
  getBoundingClientRect() {
    return { left: 10, top: 20 };
  }
}
function setup(script) {
  let listener;
  let calls = 0;
  vm.runInNewContext(script, {
    Element,
    HTMLElement,
    document: {
      addEventListener(name, fn, capture) {
        assert.equal(name, "mousedown");
        assert.equal(capture, true);
        listener = fn;
      },
    },
    window: { "Lune.Plugins.Window.startDrag": () => calls++ },
  });
  return function press(target, options = {}, expected = false) {
    const before = calls;
    let prevented = false;
    const path = [];
    for (let el = target; el; el = el.parentElement) path.push(el);
    listener({
      target,
      button: 0,
      clientX: 50,
      clientY: 50,
      composedPath: () => path,
      preventDefault: () => {
        prevented = true;
      },
      ...options,
    });
    assert.equal(calls - before, expected ? 1 : 0);
    assert.equal(prevented, expected);
  };
}
const press = setup(scripts.default_script);
const root = new HTMLElement({ value: "true" });
const child = new HTMLElement({ parent: root });
press(root, {}, true);
press(child, {}, true);
press(new HTMLElement());
press(new HTMLElement({ value: "custom-value" }), {}, true);
for (const value of ["false", "0", "no-drag", " FALSE "]) {
  const excluded = new HTMLElement({ value, parent: root });
  press(excluded);
  press(new HTMLElement({ value: "true", parent: excluded }));
}
// An empty marker inherits the ancestor's drag region.
press(new HTMLElement({ value: " ", parent: root }), {}, true);
for (const selector of [
  "a",
  "button",
  "input",
  "select",
  "textarea",
  "label",
  "summary",
  "[contenteditable]:not([contenteditable='false'])",
  "[tabindex]",
  "[role='button']",
  "[role='link']",
  "[role='slider']",
  "[role='checkbox']",
  "[role='switch']",
  "[role='tab']",
  "[role='menuitem']",
  "[role='combobox']",
  "[draggable='true']",
  "[data-lune-no-drag]",
  "dialog",
  "svg",
  "canvas",
]) {
  const control = new HTMLElement({ selectors: [selector], parent: root });
  press(control);
  press(new Element({ parent: control })); // Icon or other nested content.
  press(new HTMLElement({ value: "true", parent: control }));
}
for (const options of [
  { button: 1 },
  { button: 2 },
  { ctrlKey: true },
  { metaKey: true },
  { shiftKey: true },
  { altKey: true },
  { defaultPrevented: true },
  { clientX: 110 },
  { clientY: 120 },
  { clientX: 9 },
  { clientY: 19 },
])
  press(child, options);
// Content within the scrollbar boundaries still drags.
press(child, { clientX: 109, clientY: 119 }, true);
// Inline text has zero client dimensions but must remain draggable.
const inline = new HTMLElement({ parent: root });
inline.clientWidth = inline.clientHeight = inline.scrollWidth = inline.scrollHeight = 0;
press(inline, {}, true);
// Use the composed path rather than parentElement for shadow DOM descendants.
const shadowChild = new HTMLElement();
press(root, { composedPath: () => [shadowChild, {}, root] }, true);
const shadowButton = new HTMLElement({ selectors: ["button"] });
press(root, { composedPath: () => [shadowChild, shadowButton, {}, root] });
// Custom selectors replace defaults; explicit false always wins.
const custom = setup(scripts.custom_script);
custom(new HTMLElement({ selectors: [".custom-control"], parent: root }));
custom(new HTMLElement({ selectors: ["button"], parent: root }), {}, true);
custom(new HTMLElement({ value: "false", parent: root }));
const unrestricted = setup(scripts.unrestricted_script);
unrestricted(
  new HTMLElement({ selectors: ["button"], parent: root }),
  {},
  true,
);
unrestricted(new HTMLElement({ value: "no-drag", parent: root }));
console.log("Window drag behavior passed");
