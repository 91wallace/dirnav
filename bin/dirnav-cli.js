#!/usr/bin/env node
const { spawnSync } = require("child_process");
const path = require("path");

function findPython() {
  const candidates = process.platform === "win32" ? ["py", "python3", "python"] : ["python3", "python"];
  for (const cmd of candidates) {
    const res = spawnSync(cmd, ["--version"], { encoding: "utf8", stdio: "pipe" });
    if (res.status === 0 && (res.stdout + res.stderr).includes("Python 3")) {
      return cmd;
    }
  }
  return null;
}

const py = findPython();
if (!py) {
  console.error("Erro: Python 3 nao foi encontrado no PATH. Instale o Python 3 para usar o dirnav.");
  process.exit(1);
}

const scriptPath = path.resolve(__dirname, "..", "dirnav");
const args = [scriptPath, ...process.argv.slice(2)];

const child = spawnSync(py, args, { stdio: "inherit" });
process.exit(child.status !== null ? child.status : 1);
