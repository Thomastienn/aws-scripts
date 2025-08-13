import json
import sys
from datetime import datetime
import pytz


data = json.load(sys.stdin)
# Beautiful, eye-friendly color palette for LIGHT THEME
timestamp_color = (75, 85, 99)       # Dark slate gray for timestamps
info_color = (22, 101, 52)           # Forest green for info messages
error_color = (185, 28, 28)          # Bold red for errors
debug_color = (29, 78, 216)          # Rich blue for debug
warning_color = (217, 119, 6)        # Dark amber for warnings
success_color = (21, 128, 61)        # Deep green for success messages
highlight_color = (126, 34, 206)     # Deep purple for important highlights

def convert_utc_to_calgary(utc_timestamp_str):
    """Convert UTC timestamp string to Calgary time (Mountain Time)"""
    try:
        # Handle various AWS timestamp formats
        timestamp_str = utc_timestamp_str.strip()
        
        # Try different parsing approaches
        utc_dt = None
        
        # Format 1: ISO format with Z (2024-01-15T10:30:45.123Z)
        if timestamp_str.endswith('Z'):
            utc_dt = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
        # Format 2: ISO format without Z (2024-01-15T10:30:45.123)
        elif 'T' in timestamp_str:
            utc_dt = datetime.fromisoformat(timestamp_str)
            utc_dt = utc_dt.replace(tzinfo=pytz.UTC)
        # Format 3: Space-separated format (2024-01-15 10:30:45.123)
        else:
            utc_dt = datetime.strptime(timestamp_str, '%Y-%m-%d %H:%M:%S.%f')
            utc_dt = utc_dt.replace(tzinfo=pytz.UTC)
        
        # Convert to Calgary timezone (Mountain Time)
        calgary_tz = pytz.timezone('America/Edmonton')  # Calgary uses Edmonton timezone
        calgary_dt = utc_dt.astimezone(calgary_tz)
        
        # Format with timezone abbreviation
        tz_abbrev = calgary_dt.strftime('%Z')  # MST or MDT
        return f"{calgary_dt.strftime('%Y-%m-%d %H:%M:%S')} {tz_abbrev} (UTC: {utc_timestamp_str})"
    except Exception as e:
        # If conversion fails, return original timestamp
        return f"{utc_timestamp_str} (UTC)"

def print_color(text, color, end='\n'):
    r, g, b = color
    print(f'\033[38;2;{r};{g};{b}m{text}\033[0m', end=end)

for result in reversed(data["results"]):
    result: list[dict[str, str]]
    n = len(result)
    for i, res in enumerate(result):
        if res["field"] == "@timestamp":
            if i+1 < n and result[i + 1]["field"] == "@message" and "HealthCheck" in result[i + 1]["value"]:
                continue
            calgary_timestamp = convert_utc_to_calgary(res["value"])
            print_color(calgary_timestamp, timestamp_color)
        elif res["field"] == "@message":
            message = res["value"]
            if "HealthCheck" in message:
                continue
            if "ERROR" in message or "FATAL" in message:
                print_color(message, error_color)
            elif "WARN" in message or "WARNING" in message:
                print_color(message, warning_color)
            elif "INFO" in message:
                print_color(message, info_color)
            elif "SUCCESS" in message or "COMPLETED" in message:
                print_color(message, success_color)
            elif "DEBUG" in message or "TRACE" in message:
                print_color(message, debug_color)
            elif "IMPORTANT" in message or "CRITICAL" in message:
                print_color(message, highlight_color)
            else:
                # Default dark gray for other messages (light theme friendly)
                print_color(message, (55, 65, 81))
            print()
