#!/usr/bin/env python3
"""
create-nextor-hdd.py - Cria uma imagem de HDD com partições FAT16 compatível
com Nextor/Sunrise IDE para uso no OpenMSX.

A imagem gerada contém:
  - MBR com tabela de partições padrão (compatível com Nextor)
  - Partição 1: FAT16 (mínimo 32MB, cresce para caber as mídias) com os
    arquivos Nextor e, se informado, o diretório ROMS/ com todo o conteúdo
    do diretório de mídias (recursivo)
  - Partição 2: 32MB FAT16 (uso geral)
  - Partição 3: 32MB FAT16 (uso geral)

Uso:
  python3 create-nextor-hdd.py [saida] [diretorio-nextor-files] [diretorio-midias] [diretorio-software]
"""

import math
import mmap
import os
import re
import struct
import sys
import time

SECTOR_SIZE = 512
SECTORS_PER_TRACK = 63
HEADS = 16
PARTITION_SIZE_MB = 32
NUM_PARTITIONS = 3

RESERVED_SECTORS = 1
NUM_FATS = 2
ROOT_DIR_ENTRIES = 512
FAT16_MEDIA_BYTE = 0xF8
MAX_CLUSTERS = 65000  # FAT16: entre 4085 e 65524 clusters
MAX_SPC = 64          # clusters de até 32KB -> partição de até ~2GB

BOOT_FILES = ['NEXTOR.SYS', 'COMMAND2.COM', 'MSXDOS.SYS', 'COMMAND.COM']
TOOL_FILES = [
    'DELALL.COM', 'DEVINFO.COM', 'DRIVERS.COM', 'DRVINFO.COM',
    'FASTOUT.COM', 'LOCK.COM', 'MAPDRV.COM', 'EMUFILE.COM',
    'RALLOC.COM', 'Z80MODE.COM', 'NSYSVER.COM', 'NEXBOOT.COM',
    'CONCLUS.COM', 'EPTCFT.COM',
]
AUTOEXEC = (
    b"ECHO.\r\n"
    b"ECHO  MSX Air - Nextor 2.1.4\r\n"
    b"ECHO.\r\n"
    b"SET PATH=A:\\TOOLS;A:\\TED;A:\\SOFARUN\r\n"
    b"A:\\TOOLS\\NSYSVER\r\n"
    b"ECHO.\r\n"
)


def lba_to_chs(lba):
    """Converte LBA para CHS (para o MBR)."""
    c = lba // (HEADS * SECTORS_PER_TRACK)
    h = (lba // SECTORS_PER_TRACK) % HEADS
    s = (lba % SECTORS_PER_TRACK) + 1
    if c > 1023:
        c, h, s = 1023, 254, 63
    return h, (((c >> 8) & 0x3) << 6) | (s & 0x3F), c & 0xFF


def create_fat16_boot_sector(total_sectors, spc, volume_label="MSX AIR   "):
    """Cria um boot sector FAT16 compatível com Nextor."""
    root_sectors = ROOT_DIR_ENTRIES * 32 // SECTOR_SIZE
    spf = 1
    while True:
        data_sectors = total_sectors - RESERVED_SECTORS - NUM_FATS * spf - root_sectors
        clusters = data_sectors // spc
        needed = math.ceil((clusters + 2) * 2 / SECTOR_SIZE)
        if needed <= spf:
            break
        spf = needed

    boot = bytearray(SECTOR_SIZE)
    boot[0:3] = b"\xEB\x3C\x90"
    boot[3:11] = b"NEXTOR20"

    struct.pack_into('<H', boot, 11, SECTOR_SIZE)
    boot[13] = spc
    struct.pack_into('<H', boot, 14, RESERVED_SECTORS)
    boot[16] = NUM_FATS
    struct.pack_into('<H', boot, 17, ROOT_DIR_ENTRIES)
    if total_sectors <= 0xFFFF:
        struct.pack_into('<H', boot, 19, total_sectors)
    else:
        struct.pack_into('<I', boot, 32, total_sectors)
    boot[21] = FAT16_MEDIA_BYTE
    struct.pack_into('<H', boot, 22, spf)
    struct.pack_into('<H', boot, 24, SECTORS_PER_TRACK)
    struct.pack_into('<H', boot, 26, HEADS)

    boot[36] = 0x80
    boot[38] = 0x29
    struct.pack_into('<I', boot, 39, 0x12345678)
    boot[43:54] = volume_label.encode('ascii')[:11].ljust(11)
    boot[54:62] = b"FAT16   "
    boot[510] = 0x55
    boot[511] = 0xAA
    return boot, spf


def create_mbr(partitions):
    """MBR com tabela de partições: lista de (start_lba, size_sectors, fs_type)."""
    mbr = bytearray(SECTOR_SIZE)
    mbr[0:3] = b"\xEB\xFE\x90"

    for i, (start_lba, size_sectors, fs_type) in enumerate(partitions[:4]):
        offset = 446 + i * 16
        mbr[offset] = 0x80 if i == 0 else 0x00
        h, cs, cl = lba_to_chs(start_lba)
        mbr[offset + 1:offset + 4] = bytes([h, cs, cl])
        mbr[offset + 4] = fs_type
        h, cs, cl = lba_to_chs(start_lba + size_sectors - 1)
        mbr[offset + 5:offset + 8] = bytes([h, cs, cl])
        struct.pack_into('<I', mbr, offset + 8, start_lba)
        struct.pack_into('<I', mbr, offset + 12, size_sectors)

    mbr[510] = 0x55
    mbr[511] = 0xAA
    return mbr


# --- Árvore de arquivos a gravar ---

class Node:
    """Arquivo (data/path) ou diretório (children) a ser gravado."""

    def __init__(self, name, path=None, data=None, children=None):
        self.name = name          # nome 8.3 já resolvido
        self.path = path
        self.data = data
        self.children = children  # None para arquivo
        self.size = len(data) if data is not None else (
            os.path.getsize(path) if path else 0)

    @property
    def is_dir(self):
        return self.children is not None


def to_83(name, used):
    """Converte um nome qualquer para 8.3 único dentro do diretório."""
    base, dot, ext = name.upper().rpartition('.')
    if not dot:
        base, ext = ext, ''
    clean = lambda s: re.sub(r'[^A-Z0-9_$%\'\-@!#&()^{}`~]', '', s)
    base, ext = clean(base), clean(ext)[:3]
    if not base:
        base = 'FILE'
    candidate = base[:8]
    n = 0
    while (candidate, ext) in used:
        n += 1
        suffix = f'~{n}'
        candidate = base[:8 - len(suffix)] + suffix
    used.add((candidate, ext))
    return candidate, ext


def scan_dir(path):
    """Lê um diretório do host de forma recursiva, ignorando o que não é regular."""
    used = set()
    children = []
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if os.path.islink(full):
            continue
        if os.path.isdir(full):
            b, _ = to_83(entry.replace('.', '_'), used)
            children.append(Node(b, children=scan_dir(full)))
        elif os.path.isfile(full):
            b, e = to_83(entry, used)
            children.append(Node(f'{b}.{e}' if e else b, path=full))
    return children


def flat_name(node_name):
    base, _, ext = node_name.partition('.')
    return base, ext


def read_node(node):
    if node.data is not None:
        return node.data
    with open(node.path, 'rb') as f:
        return f.read()


def estimate_clusters(nodes, cluster_size):
    """Clusters necessários para a árvore (arquivos + diretórios)."""
    total = 0
    for n in nodes:
        if n.is_dir:
            dir_bytes = (len(n.children) + 2) * 32
            total += max(1, math.ceil(dir_bytes / cluster_size))
            total += estimate_clusters(n.children, cluster_size)
        else:
            total += math.ceil(n.size / cluster_size)
    return total


def choose_geometry(root_nodes, min_sectors):
    """Escolhe sectors-per-cluster e tamanho da partição 1 para caber o conteúdo."""
    for spc in (4, 8, 16, 32, 64):
        needed = estimate_clusters(root_nodes, spc * SECTOR_SIZE)
        needed = int(needed * 1.05) + 64
        if needed <= MAX_CLUSTERS:
            spf = math.ceil((needed + 2) * 2 / SECTOR_SIZE)
            sectors = (RESERVED_SECTORS + NUM_FATS * spf +
                       ROOT_DIR_ENTRIES * 32 // SECTOR_SIZE + needed * spc)
            return spc, max(sectors, min_sectors)
    return MAX_SPC, MAX_CLUSTERS * MAX_SPC


class Fat16Writer:
    """Grava arquivos/diretórios numa partição FAT16 já com boot sector."""

    def __init__(self, buf, base, boot_sector):
        bps = struct.unpack_from('<H', boot_sector, 11)[0]
        self.spc = boot_sector[13]
        reserved = struct.unpack_from('<H', boot_sector, 14)[0]
        nfats = boot_sector[16]
        self.root_entries = struct.unpack_from('<H', boot_sector, 17)[0]
        self.spf = struct.unpack_from('<H', boot_sector, 22)[0]
        total = struct.unpack_from('<H', boot_sector, 19)[0] or \
            struct.unpack_from('<I', boot_sector, 32)[0]
        self.bps = bps
        self.buf = buf
        self.base = base
        self.nfats = nfats
        self.fat_offset = base + reserved * bps
        self.root_offset = self.fat_offset + nfats * self.spf * bps
        self.data_offset = self.root_offset + self.root_entries * 32
        self.cluster_size = self.spc * bps
        data_sectors = total - reserved - nfats * self.spf - self.root_entries * 32 // bps
        self.max_cluster = data_sectors // self.spc + 1  # último cluster válido
        self.fat = bytearray(self.spf * bps)
        struct.pack_into('<H', self.fat, 0, 0xFF00 | FAT16_MEDIA_BYTE)
        struct.pack_into('<H', self.fat, 2, 0xFFFF)
        self.next_cluster = 2
        self.skipped = []

    def free_clusters(self):
        return self.max_cluster - self.next_cluster + 1

    def _alloc_chain(self, count):
        first = self.next_cluster
        for i in range(count):
            c = first + i
            nxt = c + 1 if i < count - 1 else 0xFFFF
            struct.pack_into('<H', self.fat, c * 2, nxt)
        self.next_cluster += count
        return first

    def _write_clusters(self, first, data):
        off = self.data_offset + (first - 2) * self.cluster_size
        self.buf[off:off + len(data)] = data

    @staticmethod
    def _entry(name, ext, cluster, size, is_dir):
        now = time.localtime()
        t = (now.tm_hour << 11) | (now.tm_min << 5) | (now.tm_sec // 2)
        d = (max(now.tm_year, 1980) - 1980) << 9 | (now.tm_mon << 5) | now.tm_mday
        e = bytearray(32)
        e[0:8] = name.ljust(8).encode('ascii')
        e[8:11] = ext.ljust(3).encode('ascii')
        e[11] = 0x10 if is_dir else 0x20
        struct.pack_into('<HHHH', e, 14, t, d, 0, 0)
        struct.pack_into('<HH', e, 22, t, d)
        struct.pack_into('<H', e, 26, cluster)
        struct.pack_into('<I', e, 28, size)
        return e

    def write_tree(self, nodes, parent_cluster, is_root=False):
        """Grava os nós; retorna os bytes das entradas de diretório."""
        entries = bytearray()
        for n in nodes:
            name, ext = flat_name(n.name)
            if n.is_dir:
                dir_bytes = (len(n.children) + 2) * 32
                count = max(1, math.ceil(dir_bytes / self.cluster_size))
                if count > self.free_clusters():
                    self.skipped.append(n.name)
                    continue
                first = self._alloc_chain(count)
                sub = bytearray()
                sub += self._entry('.', '', first, 0, True)
                sub += self._entry('..', '', parent_cluster, 0, True)
                sub += self.write_tree(n.children, first)
                self._write_clusters(first, sub)
                entries += self._entry(name, ext, first, 0, True)
            else:
                data = read_node(n)
                count = math.ceil(len(data) / self.cluster_size)
                if count > self.free_clusters():
                    self.skipped.append(n.path or n.name)
                    continue
                first = self._alloc_chain(count) if count else 0
                if count:
                    self._write_clusters(first, data)
                entries += self._entry(name, ext, first, len(data), False)
        return entries

    def finish(self, root_entries):
        if len(root_entries) > self.root_entries * 32:
            raise RuntimeError("Diretorio raiz excede o limite de entradas")
        self.buf[self.root_offset:self.root_offset + len(root_entries)] = root_entries
        for i in range(self.nfats):
            off = self.fat_offset + i * self.spf * self.bps
            self.buf[off:off + len(self.fat)] = self.fat


def build_partition1_tree(nextor_dir, media_dir, software_dir=None):
    """Monta a árvore da partição 1: arquivos de boot, AUTOEXEC, TOOLS e ROMS."""
    nodes = []
    for fname in BOOT_FILES:
        fpath = os.path.join(nextor_dir, fname)
        if os.path.exists(fpath):
            nodes.append(Node(fname, path=fpath))
    nodes.append(Node('AUTOEXEC.BAT', data=AUTOEXEC))

    tools = [Node(f, path=os.path.join(nextor_dir, f)) for f in TOOL_FILES
             if os.path.exists(os.path.join(nextor_dir, f))]
    if tools:
        nodes.append(Node('TOOLS', children=tools))

    # Cada subdiretório de software_dir (TED, SOFARUN) vai para a raiz do HD
    if software_dir and os.path.isdir(software_dir):
        used = {(n.name.partition('.')[0], n.name.partition('.')[2]) for n in nodes}
        for entry in sorted(os.listdir(software_dir)):
            full = os.path.join(software_dir, entry)
            if os.path.isdir(full):
                b, _ = to_83(entry.replace('.', '_'), used)
                nodes.append(Node(b, children=scan_dir(full)))

    if media_dir and os.path.isdir(media_dir):
        nodes.append(Node('ROMS', children=scan_dir(media_dir)))
    return nodes


def create_hdd_image(output_path, nextor_files_dir=None, media_dir=None, software_dir=None):
    """Cria a imagem HDD completa com partições Nextor."""
    cyl = HEADS * SECTORS_PER_TRACK
    min_sectors = PARTITION_SIZE_MB * 1024 * 1024 // SECTOR_SIZE

    p1_tree = []
    if nextor_files_dir and os.path.isdir(nextor_files_dir):
        p1_tree = build_partition1_tree(nextor_files_dir, media_dir, software_dir)

    spc1, p1_sectors = choose_geometry(p1_tree, min_sectors)
    sizes = [p1_sectors] + [min_sectors] * (NUM_PARTITIONS - 1)
    sizes = [(s // cyl) * cyl for s in sizes]
    spcs = [spc1] + [4] * (NUM_PARTITIONS - 1)

    partitions_info = []
    start = cyl  # primeiro cilindro reservado ao MBR
    for s in sizes:
        partitions_info.append((start, s, 0x06))
        start += s
    total_sectors = start
    total_size = total_sectors * SECTOR_SIZE

    print(f"  Tamanho total da imagem: {total_size / (1024 * 1024):.1f} MB")
    print(f"  Setores por particao: {sizes}")

    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    with open(output_path, 'w+b') as f:
        f.truncate(total_size)
        image = mmap.mmap(f.fileno(), total_size)
        try:
            image[0:SECTOR_SIZE] = create_mbr(partitions_info)

            for i, (start_lba, size_sectors, _) in enumerate(partitions_info):
                part_num = i + 1
                label = f"MSXAIR P{part_num} ".ljust(11)
                print(f"  Formatando particao {part_num} "
                      f"({size_sectors * SECTOR_SIZE // (1024 * 1024)}MB, FAT16, "
                      f"cluster {spcs[i] * SECTOR_SIZE}B)")

                boot, _ = create_fat16_boot_sector(size_sectors, spcs[i], label)
                struct.pack_into('<I', boot, 28, start_lba)  # hidden sectors
                base = start_lba * SECTOR_SIZE
                image[base:base + SECTOR_SIZE] = boot

                writer = Fat16Writer(image, base, boot)
                root = bytearray()
                if part_num == 1 and p1_tree:
                    print("  Importando arquivos para a particao 1...")
                    root = writer.write_tree(p1_tree, 0, is_root=True)
                    if writer.skipped:
                        print(f"  [AVISO] {len(writer.skipped)} item(ns) nao couberam:")
                        for s in writer.skipped[:20]:
                            print(f"    - {s}")
                writer.finish(root)
            image.flush()
        finally:
            image.close()

    return total_size


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))

    output_path = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser('~/MSX/media/msxair-hdd.dsk')
    nextor_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(script_dir, 'nextor-boot-files')
    media_dir = sys.argv[3] if len(sys.argv) > 3 else None
    software_dir = sys.argv[4] if len(sys.argv) > 4 else os.path.join(script_dir, 'hdd-software')

    print()
    print("MSX Air - Criador de Imagem HDD Nextor (FAT16)")
    print(f"Saida: {output_path}")
    print(f"Nextor files: {nextor_dir}")
    print(f"Midias (ROMS): {media_dir or '(nenhuma)'}")
    print()

    if os.path.exists(output_path):
        resp = input(f"A imagem ja existe: {output_path}\nSobrescrever? (s/N): ")
        if resp.lower() != 's':
            print("Operacao cancelada.")
            return

    total_size = create_hdd_image(output_path, nextor_dir, media_dir, software_dir)

    print()
    print("=" * 50)
    print("  Imagem HDD criada com sucesso!")
    print(f"  Arquivo: {output_path}")
    print(f"  Tamanho: {total_size / (1024 * 1024):.1f} MB")
    print("  Particao 1: NEXTOR.SYS + COMMAND2.COM + TOOLS/ + TED/ + SOFARUN/ + ROMS/")
    print("  Particao 2 e 3: vazias (uso geral)")
    print("=" * 50)
    print()


if __name__ == '__main__':
    main()
