"""Application configuration.

Cities served, alarm hours, character roster.
Briefing semantics — only alarm slots get TTS audio; other hours are text-only.
"""

# Supported cities (MVP: Seoul only)
CITIES = ["seoul"]

# Fixed notification slots (KST). Clients push-notify on these two hours only.
MORNING_HOUR = 5
EVENING_HOUR = 21
ALARM_HOURS = (MORNING_HOUR, EVENING_HOUR)

# All hours generate text briefings; only ALARM_HOURS additionally generate audio
ALL_HOURS = tuple(range(24))

# Briefing semantics by time-of-day
# - morning  (5시):  forecast for the upcoming day  (+ TTS audio)
# - evening  (21시): compare today actual + tomorrow forecast  (+ TTS audio)
# - other:   hourly current-weather snapshot, text only, no push
