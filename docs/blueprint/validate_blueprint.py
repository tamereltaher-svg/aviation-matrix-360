#!/usr/bin/env python3
"""Offline validation of Aviation Matrix's versioned Master Blueprint. No DB access or mutation."""
import hashlib
import json
import pathlib
import re
import sys

ROOT=pathlib.Path(__file__).resolve().parents[2]
MANIFEST=ROOT/"master_platform_architecture_v1.json"
GRAPH=ROOT/"docs/blueprint/master-blueprint.json"
PRINT=ROOT/"docs/blueprint/master-blueprint-print.html"
SEED=ROOT/"supabase/blueprint/seed_master_blueprint_20261025_v1.sql"
MIGRATION=ROOT/"supabase/migrations/20261025_master_blueprint_registry_v1.sql"

def check(condition, message):
    if not condition: raise AssertionError(message)

def run():
    original=json.loads(MANIFEST.read_text(encoding="utf-8"))
    doc=GRAPH.read_text(encoding="utf-8")
    g=json.loads(doc)
    check(g.get("state")=="draft_for_review","Blueprint must remain a draft until human approval")
    check(g["canonical_truth"]["code"].startswith("GitHub"),"Code authority must remain GitHub")
    check(g["architecture"]["frozen_version"]=="AM-ARCH-1.0","Frozen original architecture changed")
    check(g["principles"]==original["principles"],"Original architecture principles changed")
    nodes=g["nodes"]; edges=g["edges"]; ev=g["evidence"]
    keys=[n["key"] for n in nodes]; unique=set(keys)
    check(len(unique)==len(keys),"Duplicate graph node key")
    check(all(n.get("parent") is None or n["parent"] in unique for n in nodes),"Orphan parent link")
    original_modules={x["code"] for d in original["domains"] for x in d["modules"]}
    graph_modules={n["key"].split(":",1)[1] for n in nodes if n["kind"]=="module"}
    check(original_modules==graph_modules,"Module registry diverges from frozen 46-module baseline")
    check({x["code"] for x in original["domains"]}=={n["domain"] for n in nodes if n["kind"]=="domain"},"Domain set changed")
    checks={"domain":6,"module":46,"flow":6,"role":9,"screen":22}
    for kind,expected in checks.items():
        check(sum(n["kind"]==kind for n in nodes)==expected,f"Expected {expected} {kind} nodes")
    check(len(nodes)==118 and len(edges)==47 and len(ev)==58,"V1 graph count drift without version bump")
    check(len({x["key"] for x in edges})==len(edges),"Duplicate edge key")
    check(all(x["from"] in unique and x["to"] in unique and x["from"]!=x["to"] for x in edges),"Invalid edge endpoint")
    check(all(x["node"] in unique for x in ev),"Evidence orphan")
    check(g["locale_policy"]["visible"]==["en"] and g["locale_policy"]["arabic_content_retained"],"English-first/Arabic hidden policy changed")
    check(g["learning_snapshot"]["published_lessons"]==0 and g["learning_snapshot"]["published_courses"]==0,"Publication status must not be promoted without audit")
    check(g["architecture"]["domain_count"]==6 and g["architecture"]["module_count"]==46,"Incorrect registered architecture counts")
    check(len(g.get("gates",[]))==8,"Missing release gate")
    old_codes={x["code"] for d in original["domains"] for x in d["modules"]}
    check(set(x["code"] for x in g["architecture"]["historical_manifest_status_vs_live"])==old_codes,"Original history crosswalk incomplete")

    html=PRINT.read_text(encoding="utf-8")
    match=re.search(r"const MAPS=(\[[^;]+\]);\s*const esc=",html,re.S)
    check(match is not None,"Embedded offline 21-map data missing")
    maps=json.loads(match.group(1))
    check(len(maps)==21 and len({x["id"] for x in maps})==21,"Expected 21 unique independent maps")
    check(all(x.get("branches") for x in maps),"Empty print map")
    check("@page {size:A4 landscape;" in html,"A4 landscape print stylesheet missing")
    check("Print selected" in html and "Print all 21" in html,"Independent print controls missing")

    seed=SEED.read_text(encoding="utf-8")
    git_blob=hashlib.sha1(("blob "+str(len(doc.encode("utf-8")))+"\0").encode("ascii")+doc.encode("utf-8")).hexdigest()
    check(git_blob in seed,"DB snapshot seed references a different graph blob SHA")
    check("ON CONFLICT (snapshot_code,node_key) DO NOTHING" in seed,"Seed is not duplicate-safe")
    migration=MIGRATION.read_text(encoding="utf-8").lower()
    check(migration.count("create table if not exists am_blueprint.")==4,"Wrong private registry table count")
    check(migration.count("enable row level security;")==4,"Every blueprint table needs RLS")
    check("revoke all on all tables in schema am_blueprint from public, anon, authenticated" in migration,
          "Client grants must be explicitly denied")
    check(not re.search(r"\b(drop table|truncate table|drop schema)\b",migration),"Destructive migration detected")
    check(not re.search(r"(?i)(sb_secret_[a-z0-9]{15,}|ghp_[a-z0-9]{20,})",doc),"Potential secret found in graph")
    print(f"PASS: {len(nodes)} nodes, {len(edges)} edges, {len(ev)} evidence entries, {len(maps)} printable maps.")
    print("PASS: 6 domains, 46 original modules, 22 screens, 6 flows, 9 roles; original architecture preserved.")
    print("PASS: one immutable GitHub seed blob, private RLS schema, English-first, draft-only release.")

if __name__=="__main__":
    try: run()
    except Exception as e:
        print("BLUEPRINT VALIDATION FAILED:",str(e),file=sys.stderr)
        sys.exit(1)
