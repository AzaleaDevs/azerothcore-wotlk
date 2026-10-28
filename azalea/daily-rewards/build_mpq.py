#!/usr/bin/env python3
"""Build a daily-rewards UI patch from the user's own effective FrameXML MPQ."""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from azaleacore_mpq_studio.mpq import MPQArchive
from azaleacore_mpq_studio.packer import build_mpq

TOC_PATH = r'Interface\FrameXML\FrameXML.toc'
LUA_PATH = r'Interface\FrameXML\AzaleaDailyRewards.lua'

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--base-mpq', required=True, type=Path,
                    help='Existing effective locale patch containing FrameXML.toc')
parser.add_argument('--client-lua', required=True, type=Path,
                    help='The MPQ edition of AzaleaDailyRewards.lua')
parser.add_argument('--output', required=True, type=Path,
                    help='New output MPQ outside the live client')
args = parser.parse_args()
if args.output.exists():
    parser.error('The output already exists; refusing to overwrite it')
if not args.output.parent.is_dir():
    parser.error('The output directory does not exist')
with MPQArchive(args.base_mpq) as source:
    toc = source.read_file(TOC_PATH)
if not toc:
    parser.error('The selected base MPQ does not contain FrameXML.toc')
if b'AzaleaDailyRewards.lua' in toc:
    parser.error('The base TOC already references AzaleaDailyRewards.lua')
toc = toc.rstrip(b'\r\n') + b'\r\nAzaleaDailyRewards.lua\r\n'
lua = args.client_lua.read_bytes()
build_mpq([(TOC_PATH, toc), (LUA_PATH, lua)], args.output, include_listfile=True)
with MPQArchive(args.output) as result:
    if result.read_file(TOC_PATH) != toc or result.read_file(LUA_PATH) != lua:
        raise SystemExit('MPQ content verification failed')
print('MPQ:', args.output)
print('SHA-256:', hashlib.sha256(args.output.read_bytes()).hexdigest())
