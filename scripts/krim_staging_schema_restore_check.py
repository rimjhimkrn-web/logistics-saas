#!/usr/bin/env python3
"""Validate and sanitize a schema-only Supabase pg_dump before isolated restore."""
from __future__ import annotations
import hashlib
import json
import re
import sys
from pathlib import Path

def mask_sql(sql: str) -> str:
    out = list(sql)
    i, n = 0, len(sql)
    def blank(a: int, b: int) -> None:
        for k in range(a, b):
            if out[k] != "\n":
                out[k] = " "
    while i < n:
        if sql.startswith("--", i):
            j = sql.find("\n", i)
            j = n if j < 0 else j
            blank(i, j)
            i = j
            continue
        if sql.startswith("/*", i):
            start, depth = i, 1
            i += 2
            while i < n and depth:
                if sql.startswith("/*", i):
                    depth += 1
                    i += 2
                elif sql.startswith("*/", i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
            blank(start, i)
            continue
        if sql[i] == "'":
            start = i
            i += 1
            while i < n:
                if sql[i] == "'" and i + 1 < n and sql[i + 1] == "'":
                    i += 2
                elif sql[i] == "'":
                    i += 1
                    break
                elif sql[i] == "\\" and i + 1 < n:
                    i += 2
                else:
                    i += 1
            blank(start, i)
            continue
        if sql[i] == '"':
            start = i
            i += 1
            while i < n:
                if sql[i] == '"' and i + 1 < n and sql[i + 1] == '"':
                    i += 2
                elif sql[i] == '"':
                    i += 1
                    break
                else:
                    i += 1
            blank(start, i)
            continue
        if sql[i] == "$":
            match = re.match(r"\$[A-Za-z_][A-Za-z_0-9]*\$|\$\$", sql[i:])
            if match:
                tag = match.group(0)
                start = i
                i += len(tag)
                end = sql.find(tag, i)
                i = n if end < 0 else end + len(tag)
                blank(start, i)
                continue
        i += 1
    return "".join(out)

def main() -> int:
    if len(sys.argv) != 3:
        print("usage: krim_staging_schema_restore_check.py INPUT.sql OUTPUT.sql", file=sys.stderr)
        return 2
    source_path, output_path = map(Path, sys.argv[1:])
    sql = source_path.read_text(encoding="utf-8", errors="strict")
    if not sql.strip():
        raise SystemExit("Schema dump is empty.")
    cleaned = mask_sql(sql)
    data_pattern = r"(?im)^\s*(?:INSERT\s+INTO\b|COPY\s+.+?\s+FROM\s+stdin\s*;)"
    if re.search(data_pattern, cleaned):
        raise SystemExit("Refusing restore: executable INSERT/COPY data statements found.")
    credential_patterns = [
        r"rzp_live_[A-Za-z0-9]{10,}",
        r"whsec_[A-Za-z0-9]{10,}",
        r"sk_live_[A-Za-z0-9]{10,}",
        r"sb_secret_[A-Za-z0-9]{10,}",
        r"postgres(?:ql)?://[^\s'\"]+:[^\s'\"]+@",
        r"eyJhbGciOi[A-Za-z0-9._-]{20,}",
    ]
    for pattern in credential_patterns:
        if re.search(pattern, sql, re.I):
            raise SystemExit("Refusing restore: credential-like material found in schema dump.")
    lines = []
    removed = 0
    for line in sql.splitlines():
        if re.match(r"^\s*CREATE\s+SCHEMA\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:public|graphql_public)\s*;\s*$", line, re.I):
            removed += 1
            continue
        if re.match(r"^\s*COMMENT\s+ON\b", line, re.I):
            removed += 1
            continue
        if re.match(r"^\s*(?:ALTER\s+SCHEMA\s+graphql_public\b|GRANT\s+.*\s+ON\s+SCHEMA\s+graphql_public\b|REVOKE\s+.*\s+ON\s+SCHEMA\s+graphql_public\b)", line, re.I):
            removed += 1
            continue
        lines.append(line)
    output = "\n".join(lines) + "\n"
    output_path.write_text(output, encoding="utf-8")
    report = {
        "schema_dump_bytes": len(sql.encode("utf-8")),
        "sanitized_dump_bytes": len(output.encode("utf-8")),
        "sha256": hashlib.sha256(output.encode("utf-8")).hexdigest(),
        "data_statements_detected": False,
        "credential_patterns_detected": False,
        "managed_schema_metadata_lines_removed": removed,
        "raw_schema_uploaded": False,
    }
    print(json.dumps(report, sort_keys=True))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
