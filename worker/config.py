"""Application configuration.

Cities served, alarm hours, character roster.
Briefing semantics — only alarm slots get TTS audio; other hours are text-only.
"""

# Supported cities (MVP: Seoul only)
CITIES = ["seoul"]

# Fixed notification slot (KST). Clients push-notify morning only.
# 6시 = audio + push / 21시 = text-only in-app message (no push)
MORNING_HOUR = 6
EVENING_HOUR = 21
ALARM_HOURS = (MORNING_HOUR,)

# Active hours in the daily cycle (KST). User is asleep 22~05시,
# so we skip those — no point generating briefings the user can't see.
# 6시 (morning) only gets TTS audio + push. 21시 (evening) is text-only.
# 9~20시 are text-only in-app briefings (no push).
ALL_HOURS = (6,) + tuple(range(9, 22))  # = (6, 9, 10, ..., 20, 21)

# Briefing semantics by time-of-day
# - morning  (6시):  forecast for the upcoming day  (+ TTS audio + push)
# - evening  (21시): compare today actual + tomorrow forecast  (text only, no push)
# - hourly   (9~20): current-weather snapshot, text only, no push
