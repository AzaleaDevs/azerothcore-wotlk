#!/usr/bin/env python3
"""Build the daily-rewards client patch (MPQ) from your own effective FrameXML.toc.

The patch adds Interface\\FrameXML\\AzaleaDailyRewards.lua and a copy of your FrameXML.toc with one
extra line that loads it. Requires AzaleaCore-MPQ-Studio (https://github.com/AzaleaDevs/AzaleaCore-MPQ-Studio).

Example (esES client, effective TOC in patch-esES-3.MPQ):
    python build_mpq.py --base-mpq "D:/World of Warcraft 3.3.5a/Data/esES/patch-esES-3.MPQ" --output dist/patch-daily-rewards.MPQ
Then copy the result to Data/<locale>/ with a free patch name that loads after the base, e.g. patch-esES-C.MPQ.
"""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from azaleacore_mpq_studio.mpq import MPQArchive
from azaleacore_mpq_studio.packer import build_mpq

HERE = Path(__file__).resolve().parent
TOC_PATH = r'Interface\FrameXML\FrameXML.toc'
LUA_PATH = r'Interface\FrameXML\AzaleaDailyRewards.lua'
LUA_LINE = b'AzaleaDailyRewards.lua'

parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
parser.add_argument('--base-mpq', required=True, type=Path, help='Your MPQ that holds the effective FrameXML.toc')
parser.add_argument('--client-lua', type=Path, default=HERE / 'Interface' / 'FrameXML' / 'AzaleaDailyRewards.lua')
parser.add_argument('--output', required=True, type=Path, help='New MPQ (never inside your live client)')
args = parser.parse_args()

if args.output.exists():
    parser.error('the output already exists; refusing to overwrite it')
args.output.parent.mkdir(parents=True, exist_ok=True)

with MPQArchive(args.base_mpq) as source:
    toc = source.read_file(TOC_PATH)
if not toc:
    parser.error('the base MPQ does not contain Interface\\FrameXML\\FrameXML.toc')
if LUA_LINE in toc:
    parser.error('the base FrameXML.toc already loads AzaleaDailyRewards.lua')

toc = toc.rstrip(b'\r\n') + b'\r\n' + LUA_LINE + b'\r\n'
lua = args.client_lua.read_bytes()
build_mpq([(TOC_PATH, toc), (LUA_PATH, lua)], args.output, include_listfile=True)

with MPQArchive(args.output) as result:
    if result.read_file(TOC_PATH) != toc or result.read_file(LUA_PATH) != lua:
        raise SystemExit('MPQ content verification failed')
print('MPQ:', args.output)
print('SHA-256:', hashlib.sha256(args.output.read_bytes()).hexdigest())
