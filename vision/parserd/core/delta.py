import copy
import jsonpatch


class DeltaEngine:
    def __init__(self):
        self._last = {}

    def patch(self, pane: str, current: dict) -> list:
        before = self._last.get(pane, {})
        patch = jsonpatch.make_patch(before, current)
        ops = patch.patch
        if ops:
            self._last[pane] = copy.deepcopy(current)
        return ops

