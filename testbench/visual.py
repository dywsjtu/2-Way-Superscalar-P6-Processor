import re
import curses
import collections
import tabulate
import functools
import numpy

with open("program.out") as file:
    out = file.readlines()


class Info:
    def __init__(self):
        self.lines = []
        self.rob_entries = collections.defaultdict(list)
        self.rs_entries = collections.defaultdict(list)
        self.mt_entries = collections.defaultdict(list)
        self.cdb = {}
        self.registers = [["reg", "value"]]


data = collections.defaultdict(Info)
for line in out:
    match = re.match(r"DEBUG\s+(\d+):\s+", line)
    if not match:
        continue
    cycle = int(match.groups()[0])
    cur_data = data[cycle]
    cur_data.lines.append(line)
    line = line[match.end() :]
    CDB = "cdb_out"
    LEN_RS = 6
    LEN_MT = 6
    if line.startswith("registers"):
        cur_data.registers.extend([x.split(" = ")[1]] for x in line.split(", ")[:-1])

    if line.startswith(CDB):
        for x in line.split(", "):
            if x.startswith(CDB):
                key, val = x.split(" = ")
                key = key[len(CDB) + 1 :]
                if key == "value":
                    val = val.rjust(10, " ")
                cur_data.cdb[key] = [val]

    if line.startswith("rs_entries"):
        line = line.strip()
        line = line.split(":")[1]
        for x in line.split(", "):
            key, value = x.split(" = ")
            entries = cur_data.rs_entries[key]
            if len(entries) < LEN_RS:
                entries.append(value)

    if line.startswith("mt_tag"):
        for x in line.split(", ")[:-1]:
            key, value = x.split(" = ")
            key = key.split("[")[0]
            entries = cur_data.mt_entries[key]
            if len(entries) < LEN_MT:
                entries.append(value)

    if line.startswith("rob_entries"):
        entry_match = re.match(r"rob_entries\[\s+(\d+)\] = '{(.*)}", line)
        idx, entry = entry_match.groups()
        entry.replace(" ", "")
        idx = int(idx)
        for kv in entry.split(","):
            key, value = kv.split(":")
            value = value[2:]
            # if key == "value":
            # value = value.rjust(10, " ")
            cur_data.rob_entries[key].append(value)
    if line.startswith("rob_head"):
        for x in line.split(", "):
            key, value = x.split(" = ")
            if key in ("rob_head", "rob_tail"):
                l = cur_data.rob_entries["pos"]
                idx = int(value)
                while idx >= len(l):
                    l.append(" ")
                l[idx] += key[len("rob_")]

tabulate.PRESERVE_WHITESPACE = True

OPTS = dict(tablefmt="fancy_grid", disable_numparse=True, stralign="right")

tabulate = functools.partial(tabulate.tabulate, **OPTS)


def horizontal_stack(*tables):
    tables = [table.splitlines() for table in tables]
    max_lens = [max(map(len, table)) for table in tables]
    num_lines = max(map(len, tables))
    SPACES = " " * 10
    return (
        "\n".join(
            SPACES.join(
                (table[j] if j < len(table) else "").ljust(max_len, " ")
                for max_len, table in zip(max_lens, tables)
            )
            for j in range(num_lines)
        )
        + "\n"
    )


def diff(screen, old_text, text):
    assert len(old_text) == len(text)
    for old, new in zip(old_text, text):
        curses.use_default_colors()
        curses.init_pair(1, curses.COLOR_MAGENTA, -1)
        color = 0 if old == new else 1
        screen.addstr(new, curses.color_pair(color))


def main(screen):
    cycle = 0
    old_text = None
    while True:
        screen.clear()
        screen.addstr(
            f"Cycle {cycle:<14}"
            + "Press q to quit, ←, →, Home, Page Up, Page Down, End to navigate"
            + "\n" * 2
        )
        cnt = 0
        for line in data[cycle].lines:
            if cnt >= 0:
                break
            screen.addstr(line)
            cnt += 1
        NUM_REG = 10
        reg_table = " Regfile\n" + tabulate(
            data[cycle].registers[:NUM_REG], showindex="always", headers="firstrow"
        )
        rob_table = " ROB\n" + tabulate(
            data[cycle].rob_entries, showindex="always", headers="keys"
        )
        rs_table = " RS\n" + tabulate(
            data[cycle].rs_entries, showindex="always", headers="keys"
        )
        mt_table = " MT\n" + tabulate(
            data[cycle].mt_entries, showindex="always", headers="keys"
        )
        cdb_table = " CDB\n" + tabulate(data[cycle].cdb, headers="keys")
        text = horizontal_stack(rob_table, reg_table, cdb_table) + horizontal_stack(
            rs_table, mt_table
        )
        if old_text is None:
            old_text = text
        diff(screen, old_text, text)
        old_text = text
        next_cycle = {
            "KEY_RIGHT": cycle + 1,
            "KEY_LEFT": cycle - 1,
            "KEY_PPAGE": cycle - 10,
            "KEY_NPAGE": cycle + 10,
            "KEY_HOME": 0,
            "KEY_END": len(data) - 1,
        }
        key = screen.getkey()
        if key == "q":
            break
        cycle = numpy.clip(next_cycle[key], 0, len(data) - 1)
        screen.refresh()


curses.wrapper(main)
