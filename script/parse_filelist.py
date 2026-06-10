#!/usr/bin/env python3
"""Parse a Vivado-style -prj filelist (e.g. filelist/sources_sim.f) for Make

Usage: parse_filelist.py <design|verif|include-dirs|defines|worklib> <filelist>
"""

import os
import shlex
import sys

MODES = ('design', 'verif', 'include-dirs', 'defines', 'worklib')

def main():
    if len(sys.argv) != 3:
        sys.exit(f'usage: {sys.argv[0]} <{"|".join(MODES)}> <filelist>')

    mode, filelist = sys.argv[1], sys.argv[2]
    if mode not in MODES:
        sys.exit(f'unknown mode: {mode} (expected one of: {", ".join(MODES)})')
    if not os.path.isfile(filelist):
        sys.exit(f'no such file: {filelist}')

    content = open(filelist).read().replace('\\\n', ' ')
    tokens = shlex.split(content)
    _file_type, worklib, *rest = tokens

    design, verif, include_dirs, defines = [], [], [], []
    i = 0
    while i < len(rest):
        tok = rest[i]
        if tok in ('-d', '--define'):
            defines.append(rest[i + 1])
            i += 2
        elif tok in ('-i', '--include'):
            include_dirs.append(os.path.expandvars(rest[i + 1]))
            i += 2
        else:
            p = os.path.expandvars(tok)
            # relies on project structure where `src` is the RTL sources dir
            # everything else by default falls under verification sources
            (design if '/src/' in p else verif).append(p)
            i += 1

    if mode == 'design':
        print(' '.join(design))
    elif mode == 'verif':
        print(' '.join(verif))
    elif mode == 'include-dirs':
        print(' '.join(include_dirs))
    elif mode == 'defines':
        print(' '.join(defines))
    elif mode == 'worklib':
        print(worklib)

if __name__ == '__main__':
    main()
