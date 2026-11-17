import { test } from "node:test";
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

// Chữ tiếng Việt / emoji bị mã hoá 2 lần (UTF-8 đọc nhầm thành ANSI) trông như "Ä‚n uá»‘ng", "ðŸœ".
const MOJIBAKE = /Ã|Ä‚|á»|ðŸ/;

test("migration và script khởi tạo DB không có chữ bị vỡ encoding", () => {
  for (const dir of ["migrations", "db-init"]) {
    const root = join(import.meta.dirname, "..", dir);
    for (const f of readdirSync(root)) {
      const lines = readFileSync(join(root, f), "utf8").split("\n");
      const bad = lines.findIndex((l) => MOJIBAKE.test(l));
      assert.equal(bad, -1, `${dir}/${f}:${bad + 1} có chữ vỡ encoding: ${lines[bad]}`);
    }
  }
});
