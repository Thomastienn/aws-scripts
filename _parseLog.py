import json
import sys


data = json.load(sys.stdin)
# Beautiful, eye-friendly color palette for LIGHT THEME
timestamp_color = (75, 85, 99)       # Dark slate gray for timestamps
info_color = (22, 101, 52)           # Forest green for info messages
error_color = (185, 28, 28)          # Bold red for errors
debug_color = (29, 78, 216)          # Rich blue for debug
warning_color = (217, 119, 6)        # Dark amber for warnings
success_color = (21, 128, 61)        # Deep green for success messages
highlight_color = (126, 34, 206)     # Deep purple for important highlights

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
            print_color(res["value"], timestamp_color)
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
