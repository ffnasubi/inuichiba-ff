// eslint.config.js
module.exports = [
  {
    files: ["**/*.js"],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module", // ← ここはそのままでOK（対象コードのJS構文レベル）
    },
    rules: {
      semi: "error",
      "no-unused-vars": "warn",
    },
  },
];
