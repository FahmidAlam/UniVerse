"""Room identity keys and explicitly supplied per-run usage policy.

No historical room-purpose or semester rule is a permanent default.
"""


def room_key(label, aliases=None):
    def normalize(value):
        return ' '.join(str(value).upper().split())
    key = normalize(label)
    mapping = {normalize(k): normalize(v) for k, v in (aliases or {}).items()}
    seen = set()
    while key in mapping and mapping[key] != key:
        if key in seen:
            raise ValueError('Cyclic room aliases')
        seen.add(key)
        key = mapping[key]
    return key
