#!/usr/bin/env node
const { spawnSync } = require("child_process");
const path = require("path");

const cliPath = path.resolve(__dirname, "dirnav-cli.js");
spawnSync(process.execPath, [cliPath, "--setup"], { stdio: "inherit" });
