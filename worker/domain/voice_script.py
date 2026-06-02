"""Voice-script text shaping for Korean TTS.

The visible message should keep normal Korean spacing. The voice script is
slightly different: Typecast can sound more natural when short auxiliary verb
phrases are glued into one spoken chunk.
"""

from __future__ import annotations

import re


_PHRASE_REPLACEMENTS: tuple[tuple[re.Pattern[str], str], ...] = (
    # Conversational time chunks.
    (re.compile(r"조금\s+있다가\s+봐"), "조금있다가봐"),
    (re.compile(r"조금\s+있다가"), "조금있다가"),
    (re.compile(r"좀\s+있다가\s+봐"), "좀있다가봐"),
    (re.compile(r"좀\s+있다가"), "좀있다가"),
    (re.compile(r"이따가\s+봐"), "이따가봐"),
    (re.compile(r"나중에\s+봐"), "나중에봐"),
    # Go-out / carry / check chunks.
    (re.compile(r"챙겨\s+가"), "챙겨가"),
    (re.compile(r"챙기고\s+가"), "챙기고가"),
    (re.compile(r"들고\s+가"), "들고가"),
    (re.compile(r"갖고\s+가"), "갖고가"),
    (re.compile(r"가지고\s+가"), "가지고가"),
    (re.compile(r"입고\s+나가"), "입고나가"),
    (re.compile(r"신고\s+나가"), "신고나가"),
    (re.compile(r"보고\s+나가"), "보고나가"),
    (re.compile(r"확인하고\s+나가"), "확인하고나가"),
    # Auxiliary verb chunks that TTS often over-pauses.
    (re.compile(r"([가-힣]+)\s+수\s+있"), r"\1수있"),
    (re.compile(r"([가-힣]+)\s+수도\s+있"), r"\1수도있"),
    (re.compile(r"([가-힣]+)\s+것\s+같"), r"\1것같"),
    (re.compile(r"([가-힣]+)\s+거\s+같"), r"\1거같"),
    (re.compile(r"([가-힣]+)\s+(거야|거지|거라|거네|거든|걸)"), r"\1\2"),
    (re.compile(r"([가-힣]+야)\s+해"), r"\1해"),
    (re.compile(r"([가-힣]+지)\s+마"), r"\1마"),
    (re.compile(r"([가-힣]+)\s+줘"), r"\1줘"),
    (re.compile(r"([가-힣]+)\s+둬"), r"\1둬"),
    (re.compile(r"([가-힣]+는)\s+게"), r"\1게"),
)


def normalize_voice_script_for_tts(text: str) -> str:
    """Return a TTS-friendly Korean voice script.

    This intentionally does not remove all spaces. It only glues short Korean
    auxiliary phrases that tend to sound choppy when read with strict written
    spacing.
    """

    normalized = re.sub(r"\s+", " ", text).strip()
    normalized = re.sub(r"\s+([,.!?])", r"\1", normalized)
    for pattern, replacement in _PHRASE_REPLACEMENTS:
        normalized = pattern.sub(replacement, normalized)
    return normalized
