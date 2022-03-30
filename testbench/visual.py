import re
import curses
import collections
import tabulate
import functools

with open("program.out") as file:
    out = file.readlines()


class Info:
    def __init__(self):
        self.lines = []
        self.entries = collections.defaultdict(list)
        self.registers = [["reg", "value"]]


data = collections.defaultdict(Info)
for line in out:
    match = re.match(r"DEBUG\s+(\d+):\s+", line)
    if not match:
        continue
    cycle = int(match.groups()[0])
    data[cycle].lines.append(line)
    line = line[match.end() :]
    if line.startswith("registers"):
        data[cycle].registers.extend([x] for x in line.split(", ")[:-1])
        continue
    entry_match = re.match(r"rob_entries\[\s+(\d+)\] = '{(.*)}", line)
    if not entry_match:
        continue
    idx, entry = entry_match.groups()
    entry.replace(" ", "")
    idx = int(idx)
    for kv in entry.split(","):
        key, value = kv.split(":")
        data[cycle].entries[key].append(value)

OPTS = dict(tablefmt="simple")

tabulate = functools.partial(tabulate.tabulate, **OPTS)


def main(screen):
    cycle = 0
    while True:
        screen.clear()
        screen.addstr(f"Cycle {cycle}\n")
        cnt = 0
        for line in data[cycle].lines:
            screen.addstr(line)
            cnt += 1
            if cnt > 5:
                break
        NUM_REG = 10
        screen.addstr(
            tabulate(
                data[cycle].registers[:NUM_REG], showindex="always", headers="firstrow"
            )
            + "\n"
        )
        screen.addstr(
            tabulate(data[cycle].entries, showindex="always", headers="keys") + "\n"
        )
        screen.refresh()
        offset = {"KEY_RIGHT": 1, "KEY_LEFT": -1}
        key = screen.getkey()
        print(key)
        if key == "q":
            break
        cycle += offset[key]


# print(data[0].entries)


curses.wrapper(main)
