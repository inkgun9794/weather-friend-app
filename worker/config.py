"""Application configuration.

Cities served, alarm hours, character roster.
Briefing semantics — only alarm slots get TTS audio; other hours are text-only.
"""

# Supported cities (MVP: Seoul only)
CITIES = ["seoul"]

# Alarm hour options users can choose from
MORNING_ALARM_HOURS = (5, 6)
EVENING_ALARM_HOURS = (21, 22)
ALARM_HOURS = MORNING_ALARM_HOURS + EVENING_ALARM_HOURS

# All hours generate text briefings; only ALARM_HOURS additionally generate audio
ALL_HOURS = tuple(range(24))

# Briefing semantics by time-of-day
# - morning  (5/6시): forecast for the upcoming day
# - evening  (21/22시): compare today actual + tomorrow forecast
# - other:   hourly current-weather snapshot (text only)
