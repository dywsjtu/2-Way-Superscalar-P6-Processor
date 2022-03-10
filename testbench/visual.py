import re
import curses
import collections
import tabulate

with open("program.out") as file:
    out = file.readlines()

class Info:
    def __init__(self):
        self.lines = []
        self.entries = collections.defaultdict(list)

data = collections.defaultdict(Info)
for line in out:
    match = re.match(r"DEBUG\s+(\d+):\s+", line)
    if not match: continue
    cycle = int(match.groups()[0])
    data[cycle].lines.append(line)
    entry_match = re.match(r"rob_entries\[\s+(\d+)\] = '{(.*)}", line[match.end():])
    if not entry_match: continue
    idx, entry = entry_match.groups()
    entry.replace(" ","")
    idx = int(idx)
    for kv in entry.split(","):
        key, value = kv.split(":")
        data[cycle].entries[key].append(value)

def main(screen):
    cycle = 0
    while True:
        screen.clear()
        screen.addstr(f"Cycle {cycle}\n")
        for line in data[cycle].lines:
            screen.addstr(line)
        screen.addstr(tabulate.tabulate(data[cycle].entries, showindex="always", headers="keys")+"\n")
        screen.refresh()
        offset = {"KEY_RIGHT": 1, "KEY_LEFT": -1}
        key = screen.getkey()
        print(key)
        cycle += offset[key]

#print(data[0].entries)


curses.wrapper(main)