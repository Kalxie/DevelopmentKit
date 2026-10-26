import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// base './' keeps asset paths relative, which NUI requires.
export default defineConfig({ plugins: [react()], base: "./", build: { outDir: "dist", emptyOutDir: true } });
