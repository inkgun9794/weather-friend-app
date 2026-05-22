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

# Active hours in the daily cycle (KST). User is asleep 22~04시 and waking
# 06~08시, so we skip those — no point generating briefings the user can't see.
# 5시 (morning) and 21시 (evening) are alarm slots with audio + push.
# 9~20시 are text-only hourly briefings.
ALL_HOURS = (5,) + tuple(range(9, 22))  # = (5, 9, 10, ..., 20, 21)

# Briefing semantics by time-of-day
# - morning  (5시):  forecast for the upcoming day  (+ TTS audio + push)
# - evening  (21시): compare today actual + tomorrow forecast  (+ TTS audio + push)
# - hourly   (9~20): current-weather snapshot, text only, no push
