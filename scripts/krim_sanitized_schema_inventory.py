#!/usr/bin/env python3
"""Produce a sanitized inventory from a decrypted KRIM schema dump.
Never prints SQL text, object definitions, literal values, or credentials.
"""
from pathlib import Path
import json, re, sys

src = Path(sys.argv[1])
sql = src.read_text(errors="replace")
checks = {
    "tables": r"(?im)^CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?",
    "views": r"(?im)^CREATE\s+(?:OR\s+REPLACE\s+)?(?:MATERIALIZED\s+)?VIEW\s+",
    "functions": r"(?im)^CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+",
    "procedures": r"(?im)^CREATE\s+(?:OR\s+REPLACE\s+)?PROCEDURE\s+",
    "policies": r"(?im)^CREATE\s+POLICY\s+",
    "triggers": r"(?im)^CREATE\s+(?:CONSTRAINT\s+)?TRIGGER\s+",
    "indexes": r"(?im)^CREATE\s+(?:UNIQUE\s+)?INDEX\s+",
    "extensions": r"(?im)^CREATE\s+EXTENSION\s+",
    "security_definer": r"(?is)\bSECURITY\s+DEFINER\b",
    "row_level_security_enable": r"(?im)^ALTER\s+TABLE\s+.+?ENABLE\s+ROW\s+LEVEL\s+SECURITY",
    "row_level_security_force": r"(?im)^ALTER\s+TABLE\s+.+?FORCE\s+ROW\s+LEVEL\s+SECURITY",
    "grant_statements": r"(?im)^GRANT\s+",
    "revoke_statements": r"(?im)^REVOKE\s+",
}
counts = {name: len(re.findall(pattern, sql)) for name, pattern in checks.items()}

patterns = {
    "provider_key_markers": r"rzp_live_[A-Za-z0-9]{10,}|whsec_[A-Za-z0-9]{10,}|sk_live_[A-Za-z0-9]{10,}|sb_secret_[A-Za-z0-9]{10,}",
    "jwt_like_literals": r"eyJhbGciOi[A-Za-z0-9._-]{20,}",
    "private_key_headers": r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----",
    "credential_assignment_literals": r"(?i)(?:password|passwd|secret|api[_-]?key|access[_-]?token|refresh[_-]?token)\s*[:=]\s*\x27[^\x27]{8,}\x27",
}
risk_counts = {name: len(re.findall(pattern, sql)) for name, pattern in patterns.items()}

report = {
    "report_type": "sanitized_schema_inventory",
    "source_file": src.name,
    "source_bytes": src.stat().st_size,
    "object_and_control_counts": counts,
    "potential_embedded_credential_marker_counts": risk_counts,
    "limitations": [
        "Pattern-based inventory only; not a complete SQL parser or security audit.",
        "A zero marker count does not prove that secrets or sensitive literals are absent.",
        "Function search_path review is approximate and requires manual inspection.",
        "No SQL definitions, object names, literal values, or database rows are included."
    ]
}
Path("sanitized-schema-review.json").write_text(json.dumps(report, indent=2) + "\n")
print("Sanitized schema inventory generated.")
print("Object/control counts:", json.dumps(counts, sort_keys=True))
print("Potential embedded credential marker counts:", json.dumps(risk_counts, sort_keys=True))