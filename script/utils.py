import datetime

CC_RED = "91m"
CC_YELLOW = "93m"
CC_GREEN = "32m"
INDENT = " " * 4

def color_code_string(str, color_code):
    return f"\033[{color_code}{str}\033[0m"

def print_runtime(start_time, process_name='', guard_char=''):
    end_time = datetime.datetime.now()
    elapsed_time = end_time - start_time
    hours, remainder = divmod(elapsed_time.seconds, 3600)
    minutes, seconds = divmod(remainder+1, 60) # rounds down, correct +1 for sec
    print(
        f"{guard_char}" if guard_char else "",
        f"{process_name} runtime: " if process_name else "(",
        f"{hours}h" if hours else "",
        f"{minutes}m" if minutes else "",
        f"{seconds}s",
        "" if process_name else ")",
        f"{guard_char}" if guard_char else "",
        end="\n",
        sep=''
    )
