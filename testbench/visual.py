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
        data[cycle].registers.extend([x.split(" = ")[1]] for x in line.split(", ")[:-1])
        continue
    entry_match = re.match(r"rob_entries\[\s+(\d+)\] = '{(.*)}", line)
    if not entry_match:
        continue
    idx, entry = entry_match.groups()
    entry.replace(" ", "")
    idx = int(idx)
    for kv in entry.split(","):
        key, value = kv.split(":")
        value = value[2:]
        #if key == "value":
            #value = value.rjust(10, " ")
        data[cycle].entries[key].append(value)

#tabulate.PRESERVE_WHITESPACE = True

OPTS = dict(tablefmt = "fancy_grid")

tabulate = functools.partial(tabulate.tabulate, **OPTS)

def main(screen):
    cycle = 0
    while True:
        screen.clear()
        screen.addstr(f"Cycle {cycle}"+" "*10 +"Press q to quit" + "\n")
        cnt = 0
        for line in data[cycle].lines:
            if cnt >= 0:
                break
            screen.addstr(line)
            cnt += 1
        NUM_REG = 10
        table1 = tabulate(data[cycle].registers[:NUM_REG], showindex="always", headers="firstrow").splitlines()
        table2 = tabulate(data[cycle].entries, showindex="always", headers="keys").splitlines()
        for idx in range(max(len(table1), len(table2))):
            max_len = max(map(len, table1))
            row1 = (table1[idx] if idx < len(table1) else "")
            row2 = (table2[idx] if idx < len(table2) else "")
            row1 = row1.ljust(max_len, " ")
            screen.addstr(row1+ " "*10 + row2 + "\n")
        screen.refresh()
        offset = {"KEY_RIGHT": 1, "KEY_LEFT": -1}
        key = screen.getkey()
        print(key)
        if key == "q":
            break
        cycle += offset[key]


#print(data[0].entries)


curses.wrapper(main)
