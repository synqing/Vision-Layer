from dataclasses import dataclass
from typing import List, Any
from rapidfuzz.distance.Levenshtein import distance


@dataclass
class FieldVote:
    values: List[Any]

    def majority(self):
        if not self.values:
            return None
        # Exact majority
        counts = {}
        for v in self.values:
            counts[v] = counts.get(v, 0) + 1
        best = max(counts.items(), key=lambda kv: kv[1])
        # Tolerate small edit distance among strings
        if isinstance(best[0], str) and best[1] < len(self.values):
            for cand in counts:
                if cand == best[0]:
                    continue
                if isinstance(cand, str) and distance(cand, best[0]) <= 1:
                    best = (best[0], best[1] + counts[cand])
        return best[0]

