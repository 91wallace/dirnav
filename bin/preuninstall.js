#!/usr/bin/env node
const { spawnSync } = require("child_process");
const path = require("path");

const cliPath = path.resolve(__dirname, "dirnav-cli.js");
const result = spawnSync(process.execPath, [cliPath, "--uninstall"], {
  stdio: "inherit",
});
if (result.error) {
  console.error(`Falha ao remover a integração do dirnav: ${result.error.message}`);
  process.exit(1);
}
if (result.status !== 0) {
  process.exit(result.status === null ? 1 : result.status);
}
