#!/usr/bin/env python3
"""
ddconvert.py - build dd_descent_assets.pk3 from your own Descent 1 data files.

Doomscent does not ship any Descent data.  This tool reads DESCENT.HOG and
DESCENT.PIG (registered 1.4/1.5, or shareware) and writes a GZDoom resource
archive holding the cockpit, gauges, weapon/powerup sprites, weapon models
and sounds the mod uses.

Usage:
    python ddconvert.py <descent dir or DESCENT.PIG> [-o dd_descent_assets.pk3]

Only the Python 3 standard library is needed.

File formats follow the Descent 1 source release (PIGGY.C, BM.C, INTERP.ASM),
(c) 1993-1998 Parallax Software, used under its non-commercial licence.
"""

import argparse
import io
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
    # powerups
    'DP18': 18, 'DP19': 19, 'DP20': 20, 'DP24': 24, 'DP25': 25,
    'DP26': 26, 'DP34': 34, 'DP35': 35, 'DP36': 36, 'DP37': 37,
    'DP38': 38, 'DP39': 39, 'DP40': 40, 'DP41': 41, 'DP42': 42,
    'DP43': 43, 'DP44': 44, 'DP45': 45, 'DP46': 46, 'DP47': 47,
    'DP49': 49, 'DP51': 51,
}

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
        for i in range(VCLIP_MAXNUM):
            play_time, nframes, frame_time, flags, snd = struct.unpack_from('<iiiih', d, o)
            frames = struct.unpack_from('<30H', d, o + 18)
            light = struct.unpack_from('<i', d, o + 78)[0]
            self.vclips.append((max(nframes, 0), fix(frame_time), frames[:max(nframes, 0)], fix(light)))
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


def wav(pcm, rate=11025):
    hdr = b'RIFF' + struct.pack('<I', 36 + len(pcm)) + b'WAVE'
    hdr += b'fmt ' + struct.pack('<IHHIIHH', 16, 1, 1, rate, rate, 1, 8)
    hdr += b'data' + struct.pack('<I', len(pcm))
    return hdr + pcm


# --------------------------------------------------------------------------

class Converter:
    def __init__(self, hog, pig, out):
        self.hog = read_hog(hog)
        self.pig = Pig(pig)
        self.gd = self.pig.gamedata
        pal = self.hog.get('palette.256')
        if pal is None:
            raise DescentError('palette.256 missing from HOG')
        self.palette = [(min(255, pal[i * 3] * 255 // 63),
                         min(255, pal[i * 3 + 1] * 255 // 63),
                         min(255, pal[i * 3 + 2] * 255 // 63)) for i in range(256)]
        self.zip = zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED)
        self.sndinfo = []
        self.modeldef = []
        self.converted_models = set()
        self.report = []

    # -- images ------------------------------------------------------------

    def rgba(self, index, keep_black=False):
        w, h, flags, px = self.pig.pixels(index)
        out = bytearray(w * h * 4)
        transparent = flags & (BM_FLAG_TRANSPARENT | BM_FLAG_SUPER_TRANSPARENT)
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

    def bitmap_index(self, name):
        return self.pig.by_name.get(name.lower())

    # -- parts ---------------------------------------------------------------

    def convert_hud(self):
        gd = self.gd
        cockpit = gd.cockpits[0] if gd else self.bitmap_index('cockpit')
        if cockpit:
            self.write_graphic('graphics/DDCOCKPT.png', cockpit)
        status = gd.cockpits[2] if gd else self.bitmap_index('status')
        if status:
            self.write_graphic('graphics/DDSTATUS.png', status)
        if gd:
            for gi, name in GAUGE_NAMES.items():
                idx = gd.gauges[gi]
                if idx:
                    self.write_graphic('graphics/%s.png' % name, idx)
            for wi, name in WEAPON_PICTURES.items():
                pic = gd.weapons[wi][43]
                if pic:
                    self.write_graphic('graphics/%s.png' % name, pic)
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
        for pigname, sprite in BITMAP_SPRITES.items():
            idx = self.bitmap_index(pigname) or self.bitmap_index(pigname + '#0')
            if idx:
                b = self.pig.bitmaps[idx]
                self.write_graphic('sprites/%sA0.png' % sprite, idx, (b.width // 2, b.height // 2))
        self.report.append('sprites')

    def convert_sounds(self):
        for s in self.pig.sounds:
            self.zip.writestr('sounds/dd/%s.wav' % s.name, wav(self.pig.sound_pcm(s)))
            self.sndinfo.append('dd/%s "sounds/dd/%s.wav"' % (s.name, s.name))
        if self.gd:
            # Logical aliases by Descent sound number so the mod can use the
            # numbers from the weapon tables.
            for num, idx in enumerate(self.gd.sound_map):
                if idx != 255 and idx < len(self.pig.sounds):
                    self.sndinfo.append('$alias ddsnd/%d dd/%s' % (num, self.pig.sounds[idx].name))
        self.report.append('%d sounds' % len(self.pig.sounds))

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
        for wi, name in WEAPON_MODELS.items():
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
        for actor, name in MODEL_ACTORS.items():
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

    def finish(self):
        self.zip.writestr('sndinfo.ddassets', '\n'.join(self.sndinfo) + '\n')
        if self.modeldef:
            self.zip.writestr('modeldef.ddassets', '\n\n'.join(self.modeldef) + '\n')
        self.zip.writestr('ddassets.txt',
                          'Doomscent asset pack generated by ddconvert.py.\n'
                          'Contains data from your own copy of Descent; do not redistribute.\n')
        self.zip.close()


def find_file(directory, name):
    for f in os.listdir(directory):
        if f.lower() == name.lower():
            return os.path.join(directory, f)
    return None


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('source', help='Descent directory, or path to DESCENT.PIG')
    ap.add_argument('--hog', help='path to DESCENT.HOG (default: next to the PIG)')
    ap.add_argument('-o', '--output', default='dd_descent_assets.pk3')
    args = ap.parse_args(argv)

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

    try:
        c = Converter(hog, pig, args.output)
        c.convert_hud()
        c.convert_sprites()
        c.convert_sounds()
        c.convert_models()
        c.write_modeldef()
        c.finish()
    except DescentError as e:
        sys.exit('error: %s' % e)
    print('wrote %s (%s)' % (args.output, ', '.join(c.report)))
    if not c.gd:
        print('note: this PIG has no embedded game tables (shareware?); '
              'weapon models were not converted, sprites are used instead.')


if __name__ == '__main__':
    main()
