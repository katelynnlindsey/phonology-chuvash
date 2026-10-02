"""Steps 4-5. CrossRef bibliographic lookup (api.crossref.org, no key). Saves top hits per query to
crossref_hits.json / .csv; verification = title/author/year match judged in 04b."""
import json, os, sys, time, urllib.parse, urllib.request
OUT = "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/overnight_2026-10-01/typology_literature"
Q = json.load(open(os.path.join(OUT, "crossref_queries.json")))
hits = {}
for key, q in Q.items():
    url = "https://api.crossref.org/works?" + urllib.parse.urlencode({"query.bibliographic": q, "rows": 4,
          "select": "DOI,title,author,issued,container-title,type,publisher,page,volume,issue"})
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "phonology-bibliography-check/0.1"}), timeout=30) as r:
            items = json.load(r)["message"]["items"]
    except Exception as e:
        items = [{"error": str(e)}]
    hits[key] = items; time.sleep(0.3)
    print(key, "|", [(i.get("DOI"), (i.get("title") or [""])[0][:60], (i.get("issued", {}).get("date-parts") or [[None]])[0][0]) for i in items][:3], flush=True)
json.dump(hits, open(os.path.join(OUT, "crossref_hits.json"), "w"), ensure_ascii=False, indent=1)
