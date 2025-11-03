import { defineConfig } from 'eslint/config'

// Base Expo flat config (ESM requires the filename)
import expoConfig from 'eslint-config-expo/flat.js'
import jestPlugin from 'eslint-plugin-jest'
import prettierRecommended from 'eslint-plugin-prettier/recommended'
import tsPlugin from '@typescript-eslint/eslint-plugin'
import tsParser from '@typescript-eslint/parser'

const isCI = process.env.CI === "true";

export default defineConfig([
  expoConfig,
  prettierRecommended,
  {
    ignores: ["eslint.config.mjs", ".eslintrc.js", "example/**/*", "build/**/*"],
  },
  {
    plugins: {
      "@typescript-eslint": tsPlugin,
      jest: jestPlugin,
      // DO NOT re-declare { import: ..., prettier: ... } here —
      // expoConfig already provides them and re-defining will error.
    },
    languageOptions: {
      parser: tsParser,
      parserOptions: { project: "./tsconfig.json" },
    },
    rules: {
      "jest/no-focused-tests": isCI ? "error" : "off",
      "prettier/prettier": "error",
    },
  },
])
