import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  base: "/admin/",
  build: {
    outDir: "dist",
  },
  server: {
    host: "0.0.0.0",
    proxy: {
      "/admin/login":            "http://app:3000",
      "/admin/config":           "http://app:3000",
      "/admin/spend":            "http://app:3000",
      "/admin/quota-products":   "http://app:3000",
      "/admin/whitelist":        "http://app:3000",
    },
  },
});
