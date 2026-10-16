#!/usr/bin/env python3
"""
ddconvert.py - build dd_descent_assets.pk3 from your own Descent 1 data files.

Doomscent does not ship any Descent data.  This tool reads DESCENT.HOG and
DESCENT.PIG (registered 1.4/1.5, or shareware) and writes a GZDoom resource
archive holding the cockpit, gauges, weapon/powerup sprites, weapon models,
sounds and music the mod uses.  With --descent2 it reads Descent II's
DESCENT2.HOG, DESCENT2.HAM, GROUPA.PIG and DESCENT2.S22 instead and writes
dd_descent2_assets.pk3 for Descent II mode.

Usage:
    python ddconvert.py <descent dir or DESCENT.PIG> [-o dd_descent_assets.pk3]
    python ddconvert.py --descent2 <descent ii dir> [-o dd_descent2_assets.pk3]

Only the Python 3 standard library is needed.

File formats follow the Descent 1 and Descent 2 source releases (PIGGY.C,
BM.C, INTERP.ASM), (c) 1993-1998 Parallax Software, used under its
non-commercial licence.
"""

import argparse
import io
import math
import os
import struct
import sys
import zipfile
import zlib

# --------------------------------------------------------------------------
# Constants mirrored from the Descent 1 source (BM.H, PIGGY.C, ...).

MAX_TEXTURES = 800
MAX_SOUNDS = 250
VCLIP_MAXNUM = 70
MAX_EFFECTS = 60
MAX_WALL_ANIMS = 30
MAX_ROBOT_TYPES = 30
MAX_ROBOT_JOINTS = 600
MAX_WEAPON_TYPES = 30
MAX_POWERUP_TYPES = 29
MAX_GAUGE_BMS = 80
MAX_POLYGON_MODELS = 85
MAX_OBJ_BITMAPS = 210

BM_FLAG_TRANSPARENT = 1
BM_FLAG_SUPER_TRANSPARENT = 2
BM_FLAG_RLE = 8

DBM_FLAG_ABM = 64
DBM_FLAG_LARGE = 128

# The structures are byte packed; sizes verified against the 0xabcd marker
# at the end of robot_info.
SIZE_TMAP_INFO = 26
SIZE_VCLIP = 82
SIZE_ECLIP = 130
SIZE_WCLIP = 66
SIZE_ROBOT_INFO = 486
SIZE_JOINTPOS = 8
WEAPON_FMT = '<' + 'bbbb' + 'bhbh' + 'bhbb' + 'bbbb' + 'bbbb' + 'iiH' + 'iii' + '5i5i' + '7i' + 'H'
SIZE_WEAPON_INFO = struct.calcsize(WEAPON_FMT)  # 115
SIZE_POWERUP_INFO = 16
POLYMODEL_FMT = '<iiI10i' + '30i' * 3 + '10i10B' + '30i' * 2 + '6iiBHB'
SIZE_POLYMODEL = struct.calcsize(POLYMODEL_FMT)  # 734

# Gauges[] indices (GAUGES.C) and the names the mod looks them up by.
GAUGE_NAMES = {}
for i in range(10):
    GAUGE_NAMES[i] = 'DDSHLD%d' % i          # shield ring, 0 = full
for i in range(10):
    GAUGE_NAMES[10 + i] = 'DDINVU%d' % i     # invulnerable ring
GAUGE_NAMES.update({
    21: 'DDENRGL', 22: 'DDENRGR', 23: 'DDNUMER',
    24: 'DDKEYB', 25: 'DDKEYY', 26: 'DDKEYR',
    27: 'DDKEYB0', 28: 'DDKEYY0', 29: 'DDKEYR0',
    38: 'DDSHIP',
    46: 'DDRCRS0', 47: 'DDRCRS1',
    48: 'DDRPRI0', 49: 'DDRPRI1', 50: 'DDRPRI2',
    51: 'DDRSEC0', 52: 'DDRSEC1', 53: 'DDRSEC2', 54: 'DDRSEC3', 55: 'DDRSEC4',
    56: 'DDHOMON', 57: 'DDHOMOF',
    68: 'DDKICB', 69: 'DDKICY', 70: 'DDKICR',
})

# Weapon_info ids whose cockpit picture the HUD shows.
WEAPON_PICTURES = {0: 'DDWLASR', 11: 'DDWVULC', 12: 'DDWSPRD', 13: 'DDWPLAS',
                   14: 'DDWFUSN', 8: 'DDWCONC', 15: 'DDWHOMG', 16: 'DDWPROX',
                   17: 'DDWSMRT', 18: 'DDWMEGA'}

# Weapon_info id -> polygon model name used by MODELDEF (generated below).
WEAPON_MODELS = {0: 'laser1', 1: 'laser2', 2: 'laser3', 3: 'laser4',
                 14: 'fusion', 8: 'concussion', 15: 'homing',
                 17: 'smart', 18: 'mega', 9: 'flare'}

# Mod actor class -> converted model name.  Inner models (the bright core of
# lasers and the fusion bolt) are drawn as a second model on the same frame.
MODEL_ACTORS = {'DDLaserBolt1': 'laser1', 'DDLaserBolt2': 'laser2',
                'DDLaserBolt3': 'laser3', 'DDLaserBolt4': 'laser4',
                'DDFusionBolt': 'fusion', 'DDConcussionMissile': 'concussion',
                'DDHomingMissile': 'homing', 'DDSmartMissile': 'smart',
                'DDMegaMissile': 'mega', 'DDFlare': 'flare', 'DDShip': 'pyro'}

# Doom map units per Descent unit (DD.SCALE in the mod).
WORLD_SCALE = 4.0

# Vclips turned into sprites.  4-letter sprite name -> vclip number.
VCLIP_SPRITES = {
    'DX00': 0, 'DX01': 1, 'DX02': 2, 'DX03': 3, 'DX05': 5, 'DX07': 7,
    'DX09': 9, 'DX11': 11, 'DX12': 12, 'DX14': 14, 'DX15': 15,
    'DX21': 21, 'DX22': 22, 'DX23': 23, 'DX30': 30, 'DX31': 31,
    'DX32': 32, 'DX53': 53, 'DX54': 54, 'DX55': 55, 'DX56': 56,
    'DX58': 58, 'DX59': 59, 'DX60': 60, 'DX63': 63, 'DX64': 64,
    'DX65': 65,
    'DX61': 61,     # player appearance (Ick Mode's warp-out)
    # powerups
    'DP18': 18, 'DP19': 19, 'DP20': 20, 'DP24': 24, 'DP25': 25,
    'DP26': 26, 'DP34': 34, 'DP35': 35, 'DP36': 36, 'DP37': 37,
    'DP38': 38, 'DP39': 39, 'DP40': 40, 'DP41': 41, 'DP42': 42,
    'DP43': 43, 'DP44': 44, 'DP45': 45, 'DP46': 46, 'DP47': 47,
    'DP49': 49, 'DP51': 51,
}

# Descent II extras (same names as above where D1 has the thing).
D2_GAUGE_NAMES = {20: 'DDAFTBRN'}
D2_WEAPON_PICTURES = {30: 'DDWSLSR', 32: 'DDWGAUS', 33: 'DDWHELX', 34: 'DDWPHNX',
                      35: 'DDWOMEG', 36: 'DDWFLSH', 37: 'DDWGUID', 38: 'DDWSMIN',
                      39: 'DDWMERC', 40: 'DDWSHAK'}
D2_WEAPON_MODELS = {30: 'laser5', 31: 'laser6', 36: 'flash', 37: 'guided',
                    39: 'mercury', 40: 'shaker', 54: 'shakerkid'}
D2_MODEL_ACTORS = {'DDLaserBolt5': 'laser5', 'DDLaserBolt6': 'laser6',
                   'DDFlashMissile': 'flash', 'DDGuidedMissile': 'guided',
                   'DDMercuryMissile': 'mercury', 'DDEarthshaker': 'shaker',
                   'DDShakerChild': 'shakerkid'}
# Weapon, impact and explosion vclips, and powerup vclips.
D2_EFFECT_VCLIPS = [68, 80, 85, 86, 87, 88, 92, 95, 98, 103, 104, 105, 106]
D2_POWERUP_VCLIPS = [69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 81, 82, 83, 89, 90, 91, 102]


def vclip_sprite(prefix, vc):
    """Sprite name for a vclip: DX05, ..., DX99 then DY00 for 100 (DP/DQ
    for powerups)."""
    if vc < 100:
        return '%s%02d' % (prefix, vc)
    return '%s%s%02d' % (prefix[0], chr(ord(prefix[1]) + 1), vc - 100)


# Single bitmaps used as sprites (name in PIG -> 4-letter sprite).
BITMAP_SPRITES = {'sprdblob': 'DBSP', 'blob01': 'DBVU'}

FRAME_LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'


def fix(v):
    return v / 65536.0


class DescentError(Exception):
    pass


# --------------------------------------------------------------------------
# HOG

def read_hog(path):
    data = open(path, 'rb').read()
    if data[:3] != b'DHF':
        raise DescentError('%s is not a Descent HOG file' % path)
    files = {}
    p = 3
    while p + 17 <= len(data):
        name = data[p:p + 13].split(b'\0')[0].decode('latin-1').lower()
        size = struct.unpack_from('<i', data, p + 13)[0]
        files[name] = data[p + 17:p + 17 + size]
        p += 17 + size
    return files


# --------------------------------------------------------------------------
# PIG

class Bitmap:
    __slots__ = ('name', 'width', 'height', 'flags', 'offset')


class Sound:
    __slots__ = ('name', 'length', 'offset')


class Pig:
    def __init__(self, path):
        self.data = open(path, 'rb').read()
        self.gamedata = None
        start = struct.unpack_from('<i', self.data, 0)[0]
        if 0 < start < len(self.data):
            self.data_start = start
            try:
                self.gamedata = GameData(self.data, 4)
            except (struct.error, DescentError) as e:
                print('warning: could not read game tables from PIG (%s); '
                      'models and some sprites will be skipped' % e)
        else:
            # Shareware / old PIGs have no embedded game data.
            self.data_start = 0
        self._read_directory()

    def _read_directory(self):
        d = self.data
        q = self.data_start
        nbm, nsnd = struct.unpack_from('<ii', d, q)
        q += 8
        header_size = nbm * 17 + nsnd * 20
        base = self.data_start + 8 + header_size
        self.bitmaps = [None]           # bitmap index 0 is the "bogus" bitmap
        self.by_name = {}
        for _ in range(nbm):
            name, dflags, w, h, flags, avg, off = struct.unpack_from('<8sBBBBBi', d, q)
            q += 17
            b = Bitmap()
            b.name = name.split(b'\0')[0].decode('latin-1').lower()
            if dflags & DBM_FLAG_ABM:
                b.name += '#%d' % (dflags & 63)
            if dflags & DBM_FLAG_LARGE:
                w += 256
            b.width, b.height, b.flags, b.offset = w, h, flags, base + off
            self.bitmaps.append(b)
            self.by_name.setdefault(b.name, len(self.bitmaps) - 1)
        self.sounds = []
        for _ in range(nsnd):
            name, length, dlen, off = struct.unpack_from('<8siii', d, q)
            q += 20
            s = Sound()
            s.name = name.split(b'\0')[0].decode('latin-1').lower()
            s.length, s.offset = length, base + off
            self.sounds.append(s)

    def pixels(self, index):
        """Return (w, h, flags, bytes of palette indices)."""
        b = self.bitmaps[index]
        w, h = b.width, b.height
        d = self.data
        if not b.flags & BM_FLAG_RLE:
            return w, h, b.flags, d[b.offset:b.offset + w * h]
        p = b.offset + 4
        line_sizes = d[p:p + h]
        p += h
        out = bytearray()
        for y in range(h):
            row = bytearray()
            q = p
            end = p + line_sizes[y]
            while q < end:
                c = d[q]
                q += 1
                if (c & 0xE0) == 0xE0:
                    n = c & 0x1F
                    if n == 0:
                        break
                    row += bytes([d[q]]) * n
                    q += 1
                else:
                    row.append(c)
            row = row[:w]
            row += b'\0' * (w - len(row))
            out += row
            p = end
        return w, h, b.flags, bytes(out)

    def sound_pcm(self, s):
        return self.data[s.offset:s.offset + s.length]


class GameData:
    """The bitmaps.bin tables that registered PIGs carry (bm_read_all)."""

    def __init__(self, d, o):
        def i32():
            nonlocal o
            v = struct.unpack_from('<i', d, o)[0]
            o += 4
            return v

        i32()                                           # NumTextures
        o += MAX_TEXTURES * 2 + MAX_TEXTURES * SIZE_TMAP_INFO
        self.sound_map = list(d[o:o + MAX_SOUNDS])
        o += MAX_SOUNDS * 2                             # Sounds, AltSounds
        i32()                                           # Num_vclips
        self.vclips = []
        self.vclip_sounds = []
        for i in range(VCLIP_MAXNUM):
            play_time, nframes, frame_time, flags, snd = struct.unpack_from('<iiiih', d, o)
            frames = struct.unpack_from('<30H', d, o + 18)
            light = struct.unpack_from('<i', d, o + 78)[0]
            self.vclips.append((max(nframes, 0), fix(frame_time), frames[:max(nframes, 0)], fix(light)))
            self.vclip_sounds.append(snd)
            o += SIZE_VCLIP
        i32()
        o += MAX_EFFECTS * SIZE_ECLIP
        i32()
        o += MAX_WALL_ANIMS * SIZE_WCLIP
        i32()
        robots = o
        o += MAX_ROBOT_TYPES * SIZE_ROBOT_INFO
        if struct.unpack_from('<i', d, robots + SIZE_ROBOT_INFO - 4)[0] != 0xabcd:
            raise DescentError('robot table marker mismatch')
        i32()
        o += MAX_ROBOT_JOINTS * SIZE_JOINTPOS
        self.n_weapons = i32()
        self.weapons = [struct.unpack_from(WEAPON_FMT, d, o + i * SIZE_WEAPON_INFO)
                        for i in range(MAX_WEAPON_TYPES)]
        o += MAX_WEAPON_TYPES * SIZE_WEAPON_INFO
        i32()
        self.powerups = [struct.unpack_from('<iiii', d, o + i * SIZE_POWERUP_INFO)
                         for i in range(MAX_POWERUP_TYPES)]
        o += MAX_POWERUP_TYPES * SIZE_POWERUP_INFO
        n_models = i32()
        if not 0 < n_models <= 300:
            raise DescentError('bad polygon model count %d' % n_models)
        self.models = []
        for i in range(n_models):
            self.models.append(struct.unpack_from(POLYMODEL_FMT, d, o))
            o += SIZE_POLYMODEL
        self.model_data = []
        for m in self.models:
            self.model_data.append(d[o:o + m[1]])
            o += m[1]
        self.gauges = struct.unpack_from('<%dH' % MAX_GAUGE_BMS, d, o)
        o += MAX_GAUGE_BMS * 2
        o += MAX_POLYGON_MODELS * 4 * 2                 # Dying/Dead_modelnums
        self.obj_bitmaps = struct.unpack_from('<%dH' % MAX_OBJ_BITMAPS, d, o)
        o += MAX_OBJ_BITMAPS * 2
        self.obj_bitmap_ptrs = struct.unpack_from('<%dH' % MAX_OBJ_BITMAPS, d, o)
        o += MAX_OBJ_BITMAPS * 2
        ship = struct.unpack_from('<ii7i24i', d, o)
        o += 132
        self.ship = ship
        i32()                                           # Num_cockpits
        self.cockpits = struct.unpack_from('<4H', d, o)
        o += 8



# --------------------------------------------------------------------------
# Descent II: DESCENT2.HAM (game tables), *.PIG (bitmaps), DESCENT2.S22
# (sounds).  Layouts follow the Descent 2 source (PIGGY.C, BM.C).

BM_FLAG_RLE_BIG = 32

D2_SIZE_TMAP_INFO = 20
D2_SIZE_ECLIP = 130
D2_SIZE_WCLIP = 126
D2_SIZE_ROBOT_INFO = 480
D2_WEAPON_FMT = '<bbhh' + 'bbh' + 'bbh' + 'bbh' + 'bbbb' + 'BBbbb' + 'iii' + 'H' + 'iii' + '5i5i' + '7i' + 'HH'
D2_SIZE_WEAPON_INFO = struct.calcsize(D2_WEAPON_FMT)   # 125
D2_SIZE_REACTOR = 200


class Pig2(Pig):
    def __init__(self, path, sound_path=None):
        self.data = open(path, 'rb').read()
        self.gamedata = None
        if self.data[:4] != b'PPIG':
            raise DescentError('%s is not a Descent II PIG file' % path)
        nbm = struct.unpack_from('<i', self.data, 8)[0]
        q = 12
        base = q + nbm * 18
        self.bitmaps = [None]
        self.by_name = {}
        for _ in range(nbm):
            name, dflags, w, h, whx, flags, avg, off = struct.unpack_from('<8sBBBBBBi', self.data, q)
            q += 18
            b = Bitmap()
            b.name = name.split(b'\0')[0].decode('latin-1').lower()
            if dflags & DBM_FLAG_ABM:
                b.name += '#%d' % (dflags & 63)
            b.width = w + ((whx & 0x0f) << 8)
            b.height = h + ((whx & 0xf0) << 4)
            b.flags, b.offset = flags, base + off
            self.bitmaps.append(b)
            self.by_name.setdefault(b.name, len(self.bitmaps) - 1)
        self.sounds = []
        self.sound_data = b''
        if sound_path:
            d = open(sound_path, 'rb').read()
            if d[:4] != b'DSND':
                raise DescentError('%s is not a Descent II sound file' % sound_path)
            self.sound_data = d
            n = struct.unpack_from('<i', d, 8)[0]
            q = 12
            base = q + n * 20
            for _ in range(n):
                name, length, dlen, off = struct.unpack_from('<8siii', d, q)
                q += 20
                snd = Sound()
                snd.name = name.split(b'\0')[0].decode('latin-1').lower()
                snd.length, snd.offset = length, base + off
                self.sounds.append(snd)

    def pixels(self, index):
        b = self.bitmaps[index]
        if not b.flags & BM_FLAG_RLE_BIG:
            return Pig.pixels(self, index)
        # Big RLE: 16-bit row sizes (cockpits and other wide bitmaps).
        w, h, d = b.width, b.height, self.data
        p = b.offset + 4
        sizes = struct.unpack_from('<%dH' % h, d, p)
        p += h * 2
        out = bytearray()
        for y in range(h):
            row = bytearray()
            q, end = p, p + sizes[y]
            while q < end:
                c = d[q]
                q += 1
                if (c & 0xE0) == 0xE0:
                    n = c & 0x1F
                    if n == 0:
                        break
                    row += bytes([d[q]]) * n
                    q += 1
                else:
                    row.append(c)
            row = row[:w]
            row += b'\0' * (w - len(row))
            out += row
            p = end
        return w, h, b.flags, bytes(out)

    def sound_pcm(self, s):
        return self.sound_data[s.offset:s.offset + s.length]


class GameData2:
    """DESCENT2.HAM (bm_read_all), with the fields GameData has.  Weapon
    tuples are rearranged into Descent 1's layout (see WEAPON_FMT) so the
    rest of the converter can treat both games alike."""

    def __init__(self, d):
        if d[:4] != b'HAM!':
            raise DescentError('not a Descent II HAM file')
        o = 4
        version = struct.unpack_from('<i', d, o)[0]
        o += 4
        if version < 3:
            o += 4                                      # sound offset

        def i32():
            nonlocal o
            v = struct.unpack_from('<i', d, o)[0]
            o += 4
            return v

        n = i32()                                       # textures
        o += n * 2 + n * D2_SIZE_TMAP_INFO
        n = i32()
        self.sound_map = list(d[o:o + n])
        o += n * 2
        n = i32()
        self.vclips = []
        self.vclip_sounds = []
        for i in range(n):
            play_time, nframes, frame_time, flags, snd = struct.unpack_from('<iiiih', d, o)
            frames = struct.unpack_from('<30H', d, o + 18)
            light = struct.unpack_from('<i', d, o + 78)[0]
            self.vclips.append((max(nframes, 0), fix(frame_time), frames[:max(nframes, 0)], fix(light)))
            self.vclip_sounds.append(snd)
            o += SIZE_VCLIP
        self.vclips += [(0, 0, (), 0)] * max(0, 120 - n)
        self.vclip_sounds += [-1] * max(0, 120 - n)
        n = i32()
        o += n * D2_SIZE_ECLIP
        n = i32()
        o += n * D2_SIZE_WCLIP
        n = i32()
        if n and struct.unpack_from('<i', d, o + D2_SIZE_ROBOT_INFO - 4)[0] != 0xabcd:
            raise DescentError('robot table marker mismatch')
        o += n * D2_SIZE_ROBOT_INFO
        n = i32()
        o += n * SIZE_JOINTPOS
        self.n_weapons = i32()
        self.weapons = []
        self.weapons2 = []
        for i in range(self.n_weapons):
            w = struct.unpack_from(D2_WEAPON_FMT, d, o)
            o += D2_SIZE_WEAPON_INFO
            self.weapons2.append(w)
            # -> D1 order: render, model, inner, persistent, flash vclip,
            # flash sound, robot hit vclip/sound, wall hit vclip/sound,
            # fire count, ammo usage, weapon vclip, destroyable, matter,
            # bounce, homing, 3 x pad, energy, fire wait, bitmap, blob,
            # flash, impact sizes, strength[5], speed[5], 7 fixes, picture.
            self.weapons.append((w[0], w[2], w[3], w[1], w[4], w[6], w[5], w[9], w[7], w[12],
                                 w[8], w[10], w[11], w[13], w[14], w[15], w[16], 0, 0, 0,
                                 w[22], w[23], w[25], w[26], w[27], w[28]) + w[29:46] + (w[46],))
        n = i32()
        self.powerups = [struct.unpack_from('<iiii', d, o + i * SIZE_POWERUP_INFO) for i in range(n)]
        o += n * SIZE_POWERUP_INFO
        n = i32()
        self.models = []
        for i in range(n):
            self.models.append(struct.unpack_from(POLYMODEL_FMT, d, o))
            o += SIZE_POLYMODEL
        self.model_data = []
        for m in self.models:
            self.model_data.append(d[o:o + m[1]])
            o += m[1]
        o += n * 4 * 2                                  # Dying/Dead_modelnums
        n = i32()
        self.gauges = struct.unpack_from('<%dH' % n, d, o)
        self.gauges_hires = struct.unpack_from('<%dH' % n, d, o + n * 2)
        o += n * 4
        n = i32()
        self.obj_bitmaps = struct.unpack_from('<%dH' % n, d, o)
        self.obj_bitmap_ptrs = struct.unpack_from('<%dH' % n, d, o + n * 2)
        o += n * 4
        self.ship = struct.unpack_from('<ii7i24i', d, o)
        o += 132
        n = i32()
        self.cockpits = struct.unpack_from('<%dH' % n, d, o)
        o += n * 2
        i32()                                           # First_multi_bitmap_num
        n = i32()
        o += n * D2_SIZE_REACTOR
        i32()                                           # Marker_model_num
        self.trailing = len(d) - o                      # (extra data, unused)

# --------------------------------------------------------------------------
# PNG / WAV writers

def png(width, height, rgba, offsets=None):
    def chunk(tag, payload):
        c = struct.pack('>I', len(payload)) + tag + payload
        return c + struct.pack('>I', zlib.crc32(tag + payload) & 0xffffffff)

    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        raw += rgba[y * stride:(y + 1) * stride]
    out = b'\x89PNG\r\n\x1a\n'
    out += chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
    if offsets is not None:
        # grAb: ZDoom's sprite/graphic offset chunk.
        out += chunk(b'grAb', struct.pack('>ii', offsets[0], offsets[1]))
    out += chunk(b'IDAT', zlib.compress(bytes(raw), 9))
    out += chunk(b'IEND', b'')
    return out


def read_png(data):
    """Minimal PNG reader (8-bit, non-interlaced) -> (width, height, RGBA)."""
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('not a PNG file')
    o = 8
    idat = b''
    plte = trns = None
    while o < len(data):
        n, tag = struct.unpack_from('>I4s', data, o)
        body = data[o + 8:o + 8 + n]
        o += 12 + n
        if tag == b'IHDR':
            w, h, depth, ctype, _, _, interlace = struct.unpack('>IIBBBBB', body)
        elif tag == b'PLTE':
            plte = body
        elif tag == b'tRNS':
            trns = body
        elif tag == b'IDAT':
            idat += body
        elif tag == b'IEND':
            break
    if depth != 8 or interlace:
        raise ValueError('only 8-bit, non-interlaced PNGs are supported')
    bpp = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    raw = zlib.decompress(idat)
    stride = w * bpp
    prev = bytearray(stride)
    rgba = bytearray(w * h * 4)
    p = 0
    for y in range(h):
        ft = raw[p]
        line = bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            if ft == 1:
                line[i] = (line[i] + a) & 255
            elif ft == 2:
                line[i] = (line[i] + b) & 255
            elif ft == 3:
                line[i] = (line[i] + ((a + b) >> 1)) & 255
            elif ft == 4:
                c = prev[i - bpp] if i >= bpp else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        prev = line
        for x in range(w):
            q = (y * w + x) * 4
            v = line[x * bpp:x * bpp + bpp]
            if ctype == 6:
                rgba[q:q + 4] = v
            elif ctype == 2:
                rgba[q:q + 4] = bytes(v) + b'\xff'
            elif ctype == 0:
                rgba[q:q + 4] = bytes((v[0], v[0], v[0], 255))
            elif ctype == 4:
                rgba[q:q + 4] = bytes((v[0], v[0], v[0], v[1]))
            else:
                k = v[0]
                al = trns[k] if trns and k < len(trns) else 255
                rgba[q:q + 4] = plte[k * 3:k * 3 + 3] + bytes((al,))
    return w, h, rgba


def fit_image(w, h, rgba, target_h):
    """Crop to the opaque area and box-filter down to target_h pixels tall."""
    xs = [x for x in range(w) if any(rgba[(y * w + x) * 4 + 3] > 16 for y in range(0, h, max(1, h // 128)))]
    ys = [y for y in range(h) if any(rgba[(y * w + x) * 4 + 3] > 16 for x in range(0, w, max(1, w // 128)))]
    if not xs or not ys:
        raise ValueError('the image is fully transparent')
    x0, x1, y0, y1 = xs[0], xs[-1] + 1, ys[0], ys[-1] + 1
    k = (y1 - y0) / float(target_h)
    nw = max(1, int(round((x1 - x0) / k)))
    out = bytearray(nw * target_h * 4)
    for ty in range(target_h):
        sy0, sy1 = y0 + int(ty * k), max(y0 + int(ty * k) + 1, y0 + int((ty + 1) * k))
        for tx in range(nw):
            sx0, sx1 = x0 + int(tx * k), max(x0 + int(tx * k) + 1, x0 + int((tx + 1) * k))
            r = g = b = a = n = 0
            for sy in range(sy0, min(sy1, h)):
                for sx in range(sx0, min(sx1, w)):
                    q = (sy * w + sx) * 4
                    al = rgba[q + 3]
                    r += rgba[q] * al
                    g += rgba[q + 1] * al
                    b += rgba[q + 2] * al
                    a += al
                    n += 1
            q = (ty * nw + tx) * 4
            if a and a >= n * 64:   # mostly opaque: keep, with hard edges
                out[q:q + 4] = bytes((r // a, g // a, b // a, 255))
    return nw, target_h, out


def default_face(size=64):
    """A simple cartoon face for Ick Mode when data/ickface.png is absent."""
    out = bytearray(size * size * 4)
    c = size / 2.0

    def put(x, y, col):
        q = (y * size + x) * 4
        out[q:q + 4] = bytes(col) + b'\xff'

    for y in range(size):
        for x in range(size):
            u, v = (x + 0.5 - c) / (c * 0.86), (y + 0.5 - c * 1.04) / (c * 0.96)
            if u * u + v * v > 1:
                continue
            shade = 1.0 - 0.25 * max(0.0, u)
            put(x, y, [int(ch * shade) for ch in (120, 200, 90)])
            if v < -0.35:                                   # beanie
                put(x, y, [int(ch * shade) for ch in (60, 40, 90)])
            for ex in (-0.38, 0.38):                        # eyes
                du, dv = u - ex, v + 0.05
                if du * du + dv * dv < 0.045:
                    put(x, y, (240, 240, 240))
                if (du - 0.04) ** 2 + (dv - 0.03) ** 2 < 0.012:
                    put(x, y, (20, 20, 20))
            for ex in (-0.38, 0.38):                        # black-framed glasses
                du, dv = abs(u - ex), abs(v + 0.05)
                if du < 0.28 and dv < 0.26 and (du > 0.21 or dv > 0.19):
                    put(x, y, (15, 15, 15))
            if abs(u) < 0.12 and abs(v + 0.1) < 0.04:       # bridge
                put(x, y, (15, 15, 15))
            if abs(u) > 0.64 and abs(v + 0.1) < 0.04:       # arms
                put(x, y, (15, 15, 15))
            du, dv = u / 0.28, (v - 0.5) / 0.2              # open mouth
            if du * du + dv * dv < 1:
                put(x, y, (90, 20, 30))
    return size, size, out


def face_rotations(w, h, rgba):
    """Fake the eight sprite rotations from one front view by wrapping each
    row of the face round a cylinder; the back of the head takes the colour
    of the row's edges.  Returns {angle: rgba} for 0, 45, 90, 135, 180."""
    rows = []
    for y in range(h):
        xs = [x for x in range(w) if rgba[(y * w + x) * 4 + 3] > 128]
        if not xs:
            rows.append(None)
            continue
        l, r = xs[0], xs[-1]
        edge = [x for x in xs if x <= l + 2 or x >= r - 2]
        back = [sum(rgba[(y * w + x) * 4 + i] for x in edge) // len(edge) for i in range(3)]
        rows.append((l, r, back))
    # Smooth the back colours vertically so single rows don't streak.
    backs = [row[2] if row else None for row in rows]
    for y, row in enumerate(rows):
        if row:
            near = [b for b in backs[max(0, y - 5):y + 6] if b]
            rows[y] = (row[0], row[1], [sum(b[i] for b in near) // len(near) for i in range(3)])
    out = {}
    for ang in (0, 45, 90, 135, 180):
        t = math.radians(ang)
        img = bytearray(w * h * 4)
        for y, row in enumerate(rows):
            if row is None:
                continue
            l, r, back = row
            c, rad = (l + r + 1) / 2.0, (r - l + 1) / 2.0
            for x in range(l, r + 1):
                u = max(-1.0, min(1.0, (x + 0.5 - c) / rad))
                phi = math.asin(u) - t
                q = (y * w + x) * 4
                if math.cos(phi) >= 0:
                    sx = min(r, max(l, int(c + math.sin(phi) * rad)))
                    sq = (y * w + sx) * 4
                    if rgba[sq + 3] <= 128:
                        continue
                    shade = 0.7 + 0.3 * math.cos(phi)
                    img[q:q + 4] = bytes(int(rgba[sq + i] * shade) for i in range(3)) + b'\xff'
                else:
                    shade = 0.7 + 0.15 * -math.cos(phi)
                    img[q:q + 4] = bytes(int(v * shade) for v in back) + b'\xff'
        out[ang] = img
    return out


def wav(pcm, rate=11025):
    hdr = b'RIFF' + struct.pack('<I', 36 + len(pcm)) + b'WAVE'
    hdr += b'fmt ' + struct.pack('<IHHIIHH', 16, 1, 1, rate, rate, 1, 8)
    hdr += b'data' + struct.pack('<I', len(pcm))
    return hdr + pcm


# --------------------------------------------------------------------------

class Converter:
    def __init__(self, hog, pig, out, ham=None, sounds=None):
        self.hog = read_hog(hog)
        self.d2 = ham is not None
        if self.d2:
            self.pig = Pig2(pig, sounds)
            with open(ham, 'rb') as f:
                self.gd = GameData2(f.read())
            palname = 'groupa.256'
        else:
            self.pig = Pig(pig)
            self.gd = self.pig.gamedata
            palname = 'palette.256'
        pal = self.hog.get(palname)
        if pal is None:
            raise DescentError('%s missing from HOG' % palname)
        self.textures = []
        self.palette = [(min(255, pal[i * 3] * 255 // 63),
                         min(255, pal[i * 3 + 1] * 255 // 63),
                         min(255, pal[i * 3 + 2] * 255 // 63)) for i in range(256)]
        self.zip = zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED)
        self.sndinfo = []
        self.modeldef = []
        self.converted_models = set()
        self.report = []

    # -- images ------------------------------------------------------------

    def rgba(self, index, keep_black=False, transparent=False):
        w, h, flags, px = self.pig.pixels(index)
        out = bytearray(w * h * 4)
        transparent = transparent or flags & (BM_FLAG_TRANSPARENT | BM_FLAG_SUPER_TRANSPARENT)
        for i, c in enumerate(px):
            if transparent and c >= 254:
                continue
            r, g, b = self.palette[c]
            out[i * 4:i * 4 + 4] = bytes((r, g, b, 255))
        return w, h, out

    def write_graphic(self, path, index, offsets=None):
        w, h, data = self.rgba(index)
        self.zip.writestr(path, png(w, h, data, offsets))
        return w, h

    def write_hud(self, name, index, hires=0, transparent=False):
        """A HUD graphic.  Descent II's 640x480 versions are used when there
        are some, scaled down by a TEXTURES entry to the 320x200 layout the
        HUD is drawn in (sharper on today's screens)."""
        if not hires:
            return self.write_graphic('graphics/%s.png' % name, index)
        w, h, data = self.rgba(hires, transparent=transparent)
        path = 'hud/%s.png' % name.lower()
        self.zip.writestr(path, png(w, h, data))
        self.textures.append('Graphic "%s", %d, %d\n{\n\tXScale 2.0\n\tYScale 2.4\n'
                             '\tPatch "%s", 0, 0\n}' % (name, w, h, path))

    def bitmap_index(self, name):
        return self.pig.by_name.get(name.lower())

    # -- parts ---------------------------------------------------------------

    def convert_hud(self):
        gd = self.gd
        cockpit = gd.cockpits[0] if gd else self.bitmap_index('cockpit')
        if cockpit:
            self.write_hud('DDCOCKPT', cockpit, gd.cockpits[3] if self.d2 else 0, True)
        rear = gd.cockpits[1] if gd else self.bitmap_index('rearview')
        if rear:
            self.write_hud('DDREARVW', rear, gd.cockpits[4] if self.d2 else 0, True)
        status = gd.cockpits[2] if gd else self.bitmap_index('status')
        if status:
            self.write_graphic('graphics/DDSTATUS.png', status)
        if gd:
            gauges = dict(GAUGE_NAMES)
            pictures = dict(WEAPON_PICTURES)
            if self.d2:
                gauges.update(D2_GAUGE_NAMES)
                pictures.update(D2_WEAPON_PICTURES)
            for gi, name in gauges.items():
                idx = gd.gauges[gi]
                if idx:
                    self.write_hud(name, idx, gd.gauges_hires[gi] if self.d2 else 0)
            for wi, name in pictures.items():
                pic = gd.weapons[wi][43]
                if pic:
                    self.write_hud(name, pic, gd.weapons2[wi][47] if self.d2 else 0)
        self.report.append('HUD graphics')

    def convert_sprites(self):
        if self.gd:
            for sprite, vc in VCLIP_SPRITES.items():
                nframes, ftime, frames, light = self.gd.vclips[vc]
                frames = [f for f in frames if f]
                if not frames:
                    continue
                # Sprites have 26 frame letters; drop frames evenly if needed.
                if len(frames) > 26:
                    step = len(frames) / 26.0
                    frames = [frames[int(i * step)] for i in range(26)]
                for k, f in enumerate(frames):
                    b = self.pig.bitmaps[f]
                    self.write_graphic('sprites/%s%s0.png' % (sprite, FRAME_LETTERS[k]), f,
                                       (b.width // 2, b.height // 2))
        if self.d2:
            for vcs, prefix in ((D2_EFFECT_VCLIPS, 'DX'), (D2_POWERUP_VCLIPS, 'DP')):
                for vc in vcs:
                    frames = [f for f in self.gd.vclips[vc][2] if f][:26]
                    for k, f in enumerate(frames):
                        b = self.pig.bitmaps[f]
                        self.write_graphic('sprites/%s%s0.png' % (vclip_sprite(prefix, vc), FRAME_LETTERS[k]),
                                           f, (b.width // 2, b.height // 2))
        for pigname, sprite in BITMAP_SPRITES.items():
            idx = self.bitmap_index(pigname) or self.bitmap_index(pigname + '#0')
            if idx:
                b = self.pig.bitmaps[idx]
                self.write_graphic('sprites/%sA0.png' % sprite, idx, (b.width // 2, b.height // 2))
        self.report.append('sprites')

    def convert_sounds(self):
        for s in self.pig.sounds:
            self.zip.writestr('sounds/dd/%s.wav' % s.name,
                              wav(self.pig.sound_pcm(s), 22050 if self.d2 else 11025))
            self.sndinfo.append('dd/%s "sounds/dd/%s.wav"' % (s.name, s.name))
        if self.gd:
            # Logical aliases by Descent sound number so the mod can use the
            # numbers from the weapon tables.
            for num, idx in enumerate(self.gd.sound_map):
                if idx != 255 and idx < len(self.pig.sounds):
                    self.sndinfo.append('$alias ddsnd/%d dd/%s' % (num, self.pig.sounds[idx].name))
            # Vclip sounds (ddvclip/N), e.g. the warp-in effect's.
            for vc, snd in enumerate(self.gd.vclip_sounds):
                if 0 <= snd < len(self.gd.sound_map):
                    idx = self.gd.sound_map[snd]
                    if idx != 255 and idx < len(self.pig.sounds):
                        self.sndinfo.append('$alias ddvclip/%d dd/%s' % (vc, self.pig.sounds[idx].name))
        # The ship's "player sounds": no Doomguy grunts.  Death is an
        # explosion, everything else is silent (the mod plays Descent's
        # hit sound itself).
        self.zip.writestr('sounds/dd/silence.wav', wav(b'\x80' * 32))
        death = None
        if self.gd and self.gd.sound_map[41] != 255:
            death = self.pig.sounds[self.gd.sound_map[41]].name
        for snd in ('*pain100', '*pain75', '*pain50', '*pain25', '*grunt', '*land',
                    '*usefail', '*jump', '*fist', '*poison', '*taunt', '*splash', '*puzzfail'):
            self.sndinfo.append('$playersound ddship male %s "sounds/dd/silence.wav"' % snd)
        for snd in ('*death', '*xdeath', '*gibbed', '*wimpydeath', '*crazydeath'):
            lump = 'sounds/dd/%s.wav' % death if death else 'sounds/dd/silence.wav'
            self.sndinfo.append('$playersound ddship male %s "%s"' % (snd, lump))
        self.report.append('%d sounds' % len(self.pig.sounds))

    # -- fonts ---------------------------------------------------------------

    def convert_font(self, hogname, fontname):
        """Descent .fnt (gr_init_font) -> a GZDoom font folder, one PNG per
        character named by its code point."""
        d = self.hog.get(hogname)
        if d is None or d[:4] != b'PSFN':
            return False
        datasize = struct.unpack_from('<i', d, 4)[0]
        f = 8
        w, h, flags, baseline, minc, maxc, bytewidth, data_ofs, _, widths_ofs, kern_ofs = \
            struct.unpack_from('<hhhhBBhIIII', d, f)
        nchars = maxc - minc + 1
        color = flags & 1
        prop = flags & 2
        if color:
            pal = d[8 + datasize:8 + datasize + 768]
            palette = [(pal[i * 3] * 255 // 63, pal[i * 3 + 1] * 255 // 63, pal[i * 3 + 2] * 255 // 63)
                       for i in range(256)]
        widths = (struct.unpack_from('<%dh' % nchars, d, f + widths_ofs) if prop else [w] * nchars)
        ptr = f + (data_ofs if prop else 28)
        for i in range(nchars):
            cw = widths[i]
            rgba = bytearray(cw * h * 4)
            if color:
                for y in range(h):
                    for x in range(cw):
                        c = d[ptr + y * cw + x]
                        if c != 255:
                            rgba[(y * cw + x) * 4:(y * cw + x) * 4 + 4] = bytes(palette[c] + (255,))
                ptr += cw * h
            else:
                bw = (cw + 7) // 8 if prop else bytewidth
                for y in range(h):
                    for x in range(cw):
                        if d[ptr + y * bw + x // 8] & (0x80 >> (x % 8)):
                            rgba[(y * cw + x) * 4:(y * cw + x) * 4 + 4] = b'\xff\xff\xff\xff'
                ptr += bw * h
            code = minc + i
            if code > 126 or cw <= 0:
                continue          # Descent puts its own symbols above 126
            self.zip.writestr('fonts/%s/%04X.png' % (fontname, code), png(cw, h, rgba))
        # Lower-case letters fall back to upper case if missing, so leave
        # them; spacing comes from the glyph widths.
        self.zip.writestr('fonts/%s/font.inf' % fontname,
                          'Kerning 0\nSpaceWidth %d\nFontHeight %d\n' % (widths[0] if nchars else w, h + 1))
        return True

    def convert_fonts(self):
        done = [n for hogname, n in (('font3-1.fnt', 'ddsmall'), ('font2-1.fnt', 'ddmedium'))
                if self.convert_font(hogname, n)]
        self.report.append('fonts: ' + ', '.join(done))

    # -- polygon models ----------------------------------------------------

    def model_to_obj(self, mnum, name):
        gd = self.gd
        m = gd.models[mnum]
        data = gd.model_data[mnum]
        n_textures, first_texture = m[-3], m[-2]
        textures = []
        for i in range(n_textures):
            textures.append(gd.obj_bitmaps[gd.obj_bitmap_ptrs[first_texture + i]])

        points = {}
        faces = []          # (material, [(x,y,z)], [(u,v)])
        colors = []

        def walk(p, ofs):
            while True:
                op = struct.unpack_from('<H', data, p)[0]
                if op == 0:
                    return
                if op == 1:
                    n = struct.unpack_from('<H', data, p + 2)[0]
                    for i in range(n):
                        v = struct.unpack_from('<3i', data, p + 4 + i * 12)
                        points[i] = tuple(fix(v[k]) + ofs[k] for k in range(3))
                    p += 4 + n * 12
                elif op == 7:
                    n, start = struct.unpack_from('<HH', data, p + 2)
                    for i in range(n):
                        v = struct.unpack_from('<3i', data, p + 8 + i * 12)
                        points[start + i] = tuple(fix(v[k]) + ofs[k] for k in range(3))
                    p += 8 + n * 12
                elif op == 2:
                    n = struct.unpack_from('<H', data, p + 2)[0]
                    color = struct.unpack_from('<H', data, p + 28)[0]
                    idx = struct.unpack_from('<%dH' % n, data, p + 30)
                    if color not in colors:
                        colors.append(color)
                    faces.append(('c', colors.index(color), [points[i] for i in idx], None))
                    p += 30 + ((n & ~1) + 1) * 2
                elif op == 3:
                    n = struct.unpack_from('<H', data, p + 2)[0]
                    bm = struct.unpack_from('<H', data, p + 28)[0]
                    idx = struct.unpack_from('<%dH' % n, data, p + 30)
                    uvp = p + 30 + ((n & ~1) + 1) * 2
                    uvs = [struct.unpack_from('<3i', data, uvp + i * 12)[:2] for i in range(n)]
                    faces.append(('t', bm, [points[i] for i in idx], [(fix(u), fix(v)) for u, v in uvs]))
                    p = uvp + n * 12
                elif op == 4:
                    front, back = struct.unpack_from('<HH', data, p + 28)
                    walk(p + front, ofs)
                    walk(p + back, ofs)
                    p += 32
                elif op == 5:
                    p += 36
                elif op == 6:
                    pos = struct.unpack_from('<3i', data, p + 4)
                    sub = struct.unpack_from('<H', data, p + 16)[0]
                    walk(p + sub, tuple(ofs[k] + fix(pos[k]) for k in range(3)))
                    p += 20
                elif op == 8:
                    p += 4
                else:
                    raise DescentError('unknown model opcode %d in model %d' % (op, mnum))

        walk(0, (0.0, 0.0, 0.0))

        base = 'models/dd/%s' % name
        # Flat colours go into a small strip texture.
        if colors:
            strip = bytearray()
            for c in colors:
                # bitmaps.bin was saved after g3_init_polygon_model() had
                # already turned the 15-bit colours into palette indices.
                if c < 256:
                    r, g, b = self.palette[c]
                else:
                    r, g, b = (((c >> 10) & 31) * 255 // 31, ((c >> 5) & 31) * 255 // 31,
                               (c & 31) * 255 // 31)
                strip += bytes((r, g, b, 255))
            self.zip.writestr(base + '_c.png', png(len(colors), 1, strip))
        for i, bm in enumerate(textures):
            if bm and any(f[0] == 't' and f[1] == i for f in faces):
                w, h, rgba = self.rgba(bm)
                self.zip.writestr('%s_t%d.png' % (base, i), png(w, h, rgba))

        # Descent: x right, y up, z forward.  GZDoom's OBJ loader negates z
        # and treats -x as the front, so write (-z, y, -x).
        lines = ['# converted from Descent polygon model %d' % mnum]
        vt = []
        out_faces = {}
        vi = 1
        for kind, mat, verts, uvs in faces:
            key = ('%s_c.png' % name) if kind == 'c' else ('%s_t%d.png' % (name, mat))
            fl = out_faces.setdefault(key, [])
            refs = []
            for k, (x, y, z) in enumerate(verts):
                lines.append('v %.5f %.5f %.5f' % (-z, y, -x))
                if kind == 'c':
                    vt.append(((mat + 0.5) / len(colors), 0.5))
                else:
                    u, v = uvs[k]
                    vt.append((u, 1.0 - v))
                refs.append(vi)
                vi += 1
            # Descent winds clockwise seen from the front; reverse.
            fl.append(list(reversed(refs)))
        for u, v in vt:
            lines.append('vt %.5f %.5f' % (u, v))
        for key, fl in out_faces.items():
            lines.append('usemtl %s' % key)
            for refs in fl:
                lines.append('f ' + ' '.join('%d/%d' % (r, r) for r in refs))
        self.zip.writestr(base + '.obj', '\n'.join(lines) + '\n')

    def convert_models(self):
        if not self.gd:
            return
        done = 0
        models = dict(WEAPON_MODELS)
        if self.d2:
            models.update(D2_WEAPON_MODELS)
        for wi, name in models.items():
            w = self.gd.weapons[wi]
            if w[0] != 2 or w[1] < 0:
                continue
            try:
                self.model_to_obj(w[1], name)
                self.converted_models.add(name)
                done += 1
                if w[2] >= 0:
                    self.model_to_obj(w[2], name + '_in')
                    self.converted_models.add(name + '_in')
            except (struct.error, KeyError, DescentError) as e:
                print('warning: model for weapon %d skipped: %s' % (wi, e))
        # The Pyro-GX itself, for the chase camera and multiplayer.
        try:
            self.model_to_obj(self.gd.ship[0], 'pyro')
            self.converted_models.add('pyro')
        except (struct.error, KeyError, DescentError) as e:
            print('warning: ship model skipped: %s' % e)
        self.report.append('%d weapon models' % done)

    def write_modeldef(self):
        actors = dict(MODEL_ACTORS)
        if self.d2:
            actors.update(D2_MODEL_ACTORS)
        for actor, name in actors.items():
            if name not in self.converted_models:
                continue
            lines = ['Model %s' % actor, '{', '\tPath "models/dd"',
                     '\tModel 0 "%s.obj"' % name]
            has_inner = name + '_in' in self.converted_models
            if has_inner:
                lines.append('\tModel 1 "%s_in.obj"' % name)
            lines += ['\tScale %.1f %.1f %.1f' % ((WORLD_SCALE,) * 3),
                      '\tUSEACTORPITCH', '\tUSEACTORROLL',
                      '\tFrameIndex DMDL A 0 0']
            if has_inner:
                lines.append('\tFrameIndex DMDL A 1 0')
            lines.append('}')
            self.modeldef.append('\n'.join(lines))

    def convert_music(self):
        """Descent's songs for the mod's dd_music option: DDGAMEnn (level
        music), DDTITLE, DDBRIEF, DDENDLEV and DDCREDIT.  MIDI versions
        (Descent II) are preferred over HMP; GZDoom plays both."""
        names = {'descent': 'DDTITLE', 'briefing': 'DDBRIEF', 'endlevel': 'DDENDLEV',
                 'credits': 'DDCREDIT'}
        for i in range(1, 100):
            names['game%02d' % i] = 'DDGAME%02d' % i
        n = 0
        for src, lump in names.items():
            data = self.hog.get(src + '.mid') or self.hog.get(src + '.hmp')
            if data:
                self.zip.writestr('music/%s.mid' % lump.lower(), data)
                n += 1
        if n:
            self.report.append('%d songs' % n)

    def convert_ickface(self, path):
        """Ick Mode's monster face: data/ickface.png if there is one, else
        tools/ickface.png, else a built-in cartoon face; written as sprite
        ICKF with all eight rotations."""
        face = None
        used = 'built-in'
        if path:
            try:
                with open(path, 'rb') as f:
                    face = fit_image(*read_png(f.read()), target_h=64)
                used = os.path.basename(path)
            except (OSError, ValueError, KeyError, zlib.error) as e:
                print('warning: %s: %s; using the built-in face' % (path, e))
        if face is None:
            face = default_face()
        w, h, rgba = face
        rots = face_rotations(w, h, rgba)
        names = {0: 'ICKFA1', 45: 'ICKFA2A8', 90: 'ICKFA3A7', 135: 'ICKFA4A6', 180: 'ICKFA5'}
        for ang, name in names.items():
            self.zip.writestr('sprites/%s.png' % name, png(w, h, rots[ang], (w // 2, h - 1)))
        self.report.append('Ick Mode face (%s)' % used)

    def finish(self):
        self.zip.writestr('sndinfo.ddassets', '\n'.join(self.sndinfo) + '\n')
        if self.modeldef:
            self.zip.writestr('modeldef.ddassets', '\n\n'.join(self.modeldef) + '\n')
        if self.textures:
            self.zip.writestr('textures.ddassets', '\n\n'.join(self.textures) + '\n')
        if self.d2:
            # The mod checks for this lump to switch to Descent II mode.
            self.zip.writestr('ddescent2.txt', 'Descent II assets\n')
        self.zip.writestr('ddassets.txt',
                          'Doomscent asset pack generated by ddconvert.py.\n'
                          'Contains data from your own copy of Descent; do not redistribute.\n')
        self.zip.close()


def default_ickface():
    """The face Doomscent ships (tools/ickface.png, next to this script or
    to ddconvert.exe)."""
    here = os.path.dirname(os.path.abspath(sys.executable if getattr(sys, 'frozen', False) else __file__))
    path = os.path.join(here, 'ickface.png')
    return path if os.path.exists(path) else None


def find_file(directory, name):
    for f in os.listdir(directory):
        if f.lower() == name.lower():
            return os.path.join(directory, f)
    return None


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('source', help='Descent directory, or path to DESCENT.PIG')
    ap.add_argument('--hog', help='path to DESCENT.HOG (default: next to the PIG)')
    ap.add_argument('--descent2', action='store_true',
                    help='convert Descent II (DESCENT2.HOG, DESCENT2.HAM, GROUPA.PIG, '
                         'DESCENT2.S22) instead of Descent 1')
    ap.add_argument('-o', '--output')
    args = ap.parse_args(argv)

    ham = sounds = None
    if args.descent2:
        d = args.source if os.path.isdir(args.source) else os.path.dirname(os.path.abspath(args.source))
        hog = args.hog or find_file(d, 'descent2.hog')
        ham = find_file(d, 'descent2.ham')
        pig = find_file(d, 'groupa.pig')
        sounds = find_file(d, 'descent2.s22') or find_file(d, 'descent2.s11')
        for f, name in ((hog, 'DESCENT2.HOG'), (ham, 'DESCENT2.HAM'), (pig, 'GROUPA.PIG'),
                        (sounds, 'DESCENT2.S22')):
            if not f:
                sys.exit('error: %s not found in %s' % (name, d))
        output = args.output or 'dd_descent2_assets.pk3'
    else:
        if os.path.isdir(args.source):
            pig = find_file(args.source, 'descent.pig')
            hog = args.hog or find_file(args.source, 'descent.hog')
        else:
            pig = args.source
            hog = args.hog or find_file(os.path.dirname(os.path.abspath(pig)) or '.', 'descent.hog')
        if not pig or not os.path.exists(pig):
            sys.exit('error: DESCENT.PIG not found')
        if not hog or not os.path.exists(hog):
            sys.exit('error: DESCENT.HOG not found (pass --hog)')
        output = args.output or 'dd_descent_assets.pk3'

    try:
        c = Converter(hog, pig, output, ham, sounds)
        c.convert_hud()
        c.convert_sprites()
        c.convert_sounds()
        c.convert_music()
        c.convert_ickface(find_file(os.path.dirname(os.path.abspath(pig)), 'ickface.png') or default_ickface())
        c.convert_fonts()
        c.convert_models()
        c.write_modeldef()
        c.finish()
    except DescentError as e:
        sys.exit('error: %s' % e)
    print('wrote %s (%s)' % (output, ', '.join(c.report)))
    if not c.gd:
        print('note: this PIG has no embedded game tables (shareware?); '
              'weapon models were not converted, sprites are used instead.')

if __name__ == '__main__':
    main()
