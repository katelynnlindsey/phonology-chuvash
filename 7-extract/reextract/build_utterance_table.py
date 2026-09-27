#!/usr/bin/env python3
"""One row per recording: transcript, sentence type, and interrogative marking.

Sentence type is read off the transcript's final punctuation, which is the only
sentence-type label either corpus carries.  Both corpora are read text (Chuvash
Voice is one speaker reading prose, Common Voice is read sentences), so a "?"
marks a sentence the speaker was reading as a question — not a spontaneous one.
State that when reporting: this is read-speech question intonation.

Chuvash marks polar questions with the enclitic -и / -ши and content questions
with an interrogative word.  Both are recorded here so intonation can be tested
separately from morphological marking: a question that is *only* punctuated has
to carry its questionhood prosodically.

Usage: python build_utterance_table.py --repo <path> [--out <csv>]
"""
import argparse, csv, glob, os, re, sys

# Chuvash interrogative words.  Matched as whole tokens after stripping
# case/possessive suffixes is not attempted — these are the bare stems plus the
# frequent inflected forms, which is enough to separate content from polar.
WH = {
    "мӗн", "мӗне", "мӗнпе", "мӗнтен", "мӗнре", "мӗншӗн", "мӗнле", "мӗнлерех",
    "кам", "кама", "камӑн", "кампа", "камран", "камра",
    "ӑҫта", "ӑҫтан", "ӑҫталла", "ӑҫтине",
    "хӑҫан", "хӑҫанччен", "епле", "еплерех", "миҫе", "миҫемӗш",
    "хӑш", "хӑшӗ", "хӑшне", "мӗнчул", "мӗнешкел", "ӑҫтине",
}
# Polar-question enclitic, written joined or hyphenated.
# WARNING: this cannot distinguish the polar enclitic -и from the homophonous
# third-person possessive -и (пулли 'its fish').  `has_polar_clitic` is
# therefore over-inclusive and must not be reported as a count of polar
# questions.  `final_token_i` is the tighter version — the *last* token of the
# sentence ends in -и/-ши, which is where the enclitic normally sits — and is
# the column the intonation comparison uses.
POLAR_RE = re.compile(r"(?:^|\s)\S+?-?(?:ши|и)(?=[\s?.!,;:…»]|$)")
FINAL_I_RE = re.compile(r"([^\W\d_]+)[\s?.!,;:…»\"'—–-]*$", re.UNICODE)

TOKEN_RE = re.compile(r"[^\W\d_]+", re.UNICODE)


def classify(text):
    t = text.strip()
    # trailing quote marks / dashes sit outside the sentence punctuation
    core = t.rstrip(" »\"'—–-")
    final = core[-1] if core else ""
    if final == "?":
        stype = "question"
    elif final == "!":
        stype = "exclamation"
    elif final in ".…":
        stype = "statement"
    elif final == ":":
        stype = "colon"
    else:
        stype = "other"
    toks = [x.lower() for x in TOKEN_RE.findall(t)]
    has_wh = any(x in WH for x in toks)
    has_polar = bool(POLAR_RE.search(t))
    m = FINAL_I_RE.search(t)
    final_i = bool(m and (m.group(1).lower().endswith("ши") or
                          m.group(1).lower().endswith("и")))
    qsub = ("content" if stype == "question" and has_wh else
            "clitic_final" if stype == "question" and final_i else
            "no_marking" if stype == "question" else "")
    return stype, int(has_wh), int(has_polar), int(final_i), qsub, len(toks)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--out", default=None)
    a = ap.parse_args()
    out = a.out or os.path.join(a.repo, "7-extract/reextract",
                                "utterances_sentence_type.csv")
    rows = []

    # ── Chuvash Voice: one .lab per recording ────────────────────────────
    labdir = os.path.join(a.repo, "1-raw_data/chuvash_voice/audio_transcripts")
    for p in sorted(glob.glob(os.path.join(labdir, "*.lab"))):
        txt = open(p, encoding="utf-8").read().strip()
        st, wh, pol, fi, qs, nt = classify(txt)
        rows.append(["chuvash_voice", os.path.basename(p)[:-4], "",
                     st, wh, pol, fi, qs, nt, txt])

    # ── Common Voice: sentences in the metadata TSV ──────────────────────
    for tsv in glob.glob(os.path.join(
            a.repo, "1-raw_data/common_voice_chuvash/audio_metadata_Mozilla",
            "*.tsv")):
        with open(tsv, encoding="utf-8") as fh:
            rd = csv.DictReader(fh, delimiter="\t")
            for r in rd:
                path = r.get("path") or r.get("audio") or ""
                sent = (r.get("sentence") or "").strip()
                if not path or not sent:
                    continue
                st, wh, pol, fi, qs, nt = classify(sent)
                rows.append(["common_voice_chuvash",
                             os.path.splitext(os.path.basename(path))[0],
                             r.get("client_id", ""),
                             st, wh, pol, fi, qs, nt, sent])

    with open(out, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["corpus", "file_name", "client_id", "sentence_type",
                    "has_wh", "has_polar_clitic", "final_token_i",
                    "question_subtype", "n_tokens", "transcript"])
        w.writerows(rows)
    print(f"wrote {len(rows)} rows -> {out}")


if __name__ == "__main__":
    sys.exit(main())
