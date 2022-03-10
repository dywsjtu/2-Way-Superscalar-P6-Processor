import re
import curses
import collections

with open("program.out") as file:
    out = file.readlines()
data = collections.defaultdict(list)
for line in out:
    print(line)
    match = re.match(r"DEBUG\s+(\d+).*", line)
    if not match: continue
    print(match)
    cycle = int(match.groups()[0])
    data[cycle].append(line)

def main(screen):
    cycle = 0
    while True:
        screen.clear()
        screen.addstr(f"Cycle {cycle}\n")
        for lines in data[cycle]:
            screen.addstr(lines)
        screen.refresh()
        offset = {"KEY_RIGHT": 1, "KEY_LEFT": -1}
        key = screen.getkey()
        print(key)
        cycle += offset[key]

print(data)

curses.wrapper(main)