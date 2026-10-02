"""Steps 4-5. (a) Direct DOI lookups (api.crossref.org/works/{doi}) for candidate DOIs; (b) second round of
bibliographic queries. Writes crossref_verified.csv (one row per DOI with CrossRef metadata) and crossref_hits2.json."""
import json, os, time, urllib.parse, urllib.request, csv
OUT = "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/overnight_2026-10-01/typology_literature"
UA = {"User-Agent": "phonology-bibliography-check/0.1"}
def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30) as r: return json.load(r)["message"]
DOIS = json.load(open(os.path.join(OUT, "candidate_dois.json")))
rows = []
for key, doi in DOIS.items():
    try:
        m = get("https://api.crossref.org/works/" + urllib.parse.quote(doi))
        au = "; ".join(f"{a.get('family','')}, {a.get('given','')}" for a in m.get("author", []) or m.get("editor", []))
        rows.append(dict(key=key, doi=m["DOI"], status="found", title=(m.get("title") or [""])[0], authors=au,
                         year=(m.get("issued", {}).get("date-parts") or [[None]])[0][0], container=(m.get("container-title") or [""])[0],
                         volume=m.get("volume", ""), issue=m.get("issue", ""), page=m.get("page", ""), type=m.get("type", ""), publisher=m.get("publisher", "")))
    except Exception as e:
        rows.append(dict(key=key, doi=doi, status="NOT FOUND: " + str(e)[:60]))
    time.sleep(0.25)
with open(os.path.join(OUT, "crossref_verified.csv"), "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=["key", "doi", "status", "title", "authors", "year", "container", "volume", "issue", "page", "type", "publisher"]); w.writeheader(); w.writerows(rows)
for r in rows: print(r["key"], "|", r["status"], "|", r.get("year"), "|", str(r.get("authors"))[:50], "|", str(r.get("title"))[:70], "|", str(r.get("container"))[:40], r.get("volume"), r.get("page"))
Q = json.load(open(os.path.join(OUT, "crossref_queries2.json"))); hits = {}
for key, q in Q.items():
    try:
        items = get("https://api.crossref.org/works?" + urllib.parse.urlencode({"query.bibliographic": q, "rows": 4, "select": "DOI,title,author,issued,container-title,type"}))["items"]
    except Exception as e: items = [{"error": str(e)}]
    hits[key] = items; time.sleep(0.3)
    print("Q", key, "|", [(i.get("DOI"), (i.get("title") or [""])[0][:55], (i.get("issued", {}).get("date-parts") or [[None]])[0][0], ((i.get("author") or [{}])[0]).get("family")) for i in items][:3])
json.dump(hits, open(os.path.join(OUT, "crossref_hits2.json"), "w"), ensure_ascii=False, indent=1)
