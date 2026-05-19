import { createRouter, createWebHashHistory } from "vue-router";
import { flatNav } from "./nav.js";

const routes = [
  { path: "/", redirect: "/welcome" },
  ...flatNav.map((item) => ({ path: `/${item.id}`, component: item.view })),
];

export default createRouter({
  history: createWebHashHistory(),
  routes,
});
