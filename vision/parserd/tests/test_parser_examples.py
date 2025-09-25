from rapidfuzz import fuzz


def normalize_ci_banner(s: str) -> str:
    variants = [
        "All checks passed",
        "All checks have passed",
        "✓ All checks have passed",
    ]
    best = max(variants, key=lambda v: fuzz.ratio(v, s))
    return "passing" if fuzz.ratio(best, s) >= 92 else "unknown"


def test_banner_variants_normalize_to_passing():
    samples = [
        "All checks passed",
        "All checks have passed",
        "✓  All  checks   have  passed ",
    ]
    for s in samples:
        assert normalize_ci_banner(s) == "passing"

