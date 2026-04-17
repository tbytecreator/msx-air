#!/usr/bin/env python3
"""
create-nextor-hdd.py - Cria uma imagem de HDD com partições FAT16 compatível
com Nextor/Sunrise IDE para uso no OpenMSX.

A imagem gerada contém:
  - MBR com tabela de partições padrão (compatível com Nextor)
  - Partição 1: 32MB FAT16 (boot, com arquivos Nextor)
  - Partição 2: 32MB FAT16 (uso geral)
  - Partição 3: 32MB FAT16 (uso geral)

Uso:
  python3 create-nextor-hdd.py [caminho-saida] [diretorio-nextor-files]
"""

import os
import sys
import struct
import time
import math

# --- Constantes ---
SECTOR_SIZE = 512
SECTORS_PER_TRACK = 63
HEADS = 16
PARTITION_SIZE_MB = 32
NUM_PARTITIONS = 3

# FAT16 parameters para partição de 32MB
SECTORS_PER_CLUSTER = 32  # 16KB clusters
RESERVED_SECTORS = 1
NUM_FATS = 2
ROOT_DIR_ENTRIES = 512
FAT16_MEDIA_BYTE = 0xF8


def lba_to_chs(lba):
    """Converte LBA para CHS (para o MBR)."""
    c = lba // (HEADS * SECTORS_PER_TRACK)
    h = (lba // SECTORS_PER_TRACK) % HEADS
    s = (lba % SECTORS_PER_TRACK) + 1
    if c > 1023:
        c = 1023
        h = 254
        s = 63
    return h, (((c >> 8) & 0x3) << 6) | (s & 0x3F), c & 0xFF


def create_fat16_boot_sector(total_sectors, volume_label="MSX AIR   ", is_boot=False):
    """Cria um boot sector FAT16 compatível com Nextor."""
    sectors_per_fat = math.ceil(
        (total_sectors - RESERVED_SECTORS - (ROOT_DIR_ENTRIES * 32 // SECTOR_SIZE))
        * 2 / (SECTORS_PER_CLUSTER * SECTOR_SIZE + NUM_FATS * 2)
    )
    # Ajuste: garante pelo menos o mínimo necessário
    data_sectors = total_sectors - RESERVED_SECTORS - (NUM_FATS * sectors_per_fat) - (ROOT_DIR_ENTRIES * 32 // SECTOR_SIZE)
    total_clusters = data_sectors // SECTORS_PER_CLUSTER

    # Recalcula sectors_per_fat
    fat_entries = total_clusters + 2  # +2 para as entradas reservadas
    sectors_per_fat = math.ceil(fat_entries * 2 / SECTOR_SIZE)

    boot = bytearray(SECTOR_SIZE)

    # Jump instruction
    boot[0] = 0xEB
    boot[1] = 0x3C
    boot[2] = 0x90

    # OEM name (Nextor style)
    oem = b"NEXTOR20"
    boot[3:3 + len(oem)] = oem

    # BPB (BIOS Parameter Block)
    struct.pack_into('<H', boot, 11, SECTOR_SIZE)           # Bytes per sector
    boot[13] = SECTORS_PER_CLUSTER                           # Sectors per cluster
    struct.pack_into('<H', boot, 14, RESERVED_SECTORS)       # Reserved sectors
    boot[16] = NUM_FATS                                      # Number of FATs
    struct.pack_into('<H', boot, 17, ROOT_DIR_ENTRIES)       # Root directory entries
    if total_sectors <= 0xFFFF:
        struct.pack_into('<H', boot, 19, total_sectors)      # Total sectors (16-bit)
    else:
        struct.pack_into('<H', boot, 19, 0)
        struct.pack_into('<I', boot, 32, total_sectors)      # Total sectors (32-bit)
    boot[21] = FAT16_MEDIA_BYTE                              # Media descriptor
    struct.pack_into('<H', boot, 22, sectors_per_fat)        # Sectors per FAT
    struct.pack_into('<H', boot, 24, SECTORS_PER_TRACK)      # Sectors per track
    struct.pack_into('<H', boot, 26, HEADS)                  # Number of heads
    struct.pack_into('<I', boot, 28, 0)                      # Hidden sectors

    # Extended BPB
    boot[36] = 0x80                                          # Drive number
    boot[37] = 0x00                                          # Reserved
    boot[38] = 0x29                                          # Extended boot signature
    struct.pack_into('<I', boot, 39, 0x12345678)             # Volume serial number

    # Volume label
    label = volume_label.encode('ascii')[:11].ljust(11)
    boot[43:54] = label

    # File system type
    boot[54:62] = b"FAT16   "

    # Boot signature
    boot[510] = 0x55
    boot[511] = 0xAA

    return boot, sectors_per_fat


def create_fat16_table(sectors_per_fat, media_byte=FAT16_MEDIA_BYTE):
    """Cria uma tabela FAT16 inicializada."""
    fat = bytearray(sectors_per_fat * SECTOR_SIZE)
    # Entrada 0: media byte + 0xFF
    struct.pack_into('<H', fat, 0, 0xFF00 | media_byte)
    # Entrada 1: end-of-chain
    struct.pack_into('<H', fat, 2, 0xFFFF)
    return fat


def create_root_directory(files=None):
    """Cria o diretório raiz com entradas de arquivo opcionais."""
    root = bytearray(ROOT_DIR_ENTRIES * 32)

    if not files:
        return root

    entry_idx = 0
    for fname, fdata in files:
        if entry_idx >= ROOT_DIR_ENTRIES:
            break

        # Converte nome para formato 8.3
        name_parts = fname.upper().split('.', 1)
        base = name_parts[0][:8].ljust(8)
        ext = (name_parts[1][:3] if len(name_parts) > 1 else '').ljust(3)

        offset = entry_idx * 32
        root[offset:offset + 8] = base.encode('ascii')
        root[offset + 8:offset + 11] = ext.encode('ascii')
        root[offset + 11] = 0x20  # Archive attribute

        # Timestamp
        now = time.localtime()
        fat_time = (now.tm_hour << 11) | (now.tm_min << 5) | (now.tm_sec // 2)
        fat_date = ((now.tm_year - 1980) << 9) | (now.tm_mon << 5) | now.tm_mday
        struct.pack_into('<H', root, offset + 14, fat_time)  # Creation time
        struct.pack_into('<H', root, offset + 16, fat_date)  # Creation date
        struct.pack_into('<H', root, offset + 22, fat_time)  # Write time
        struct.pack_into('<H', root, offset + 24, fat_date)  # Write date

        # Cluster e tamanho serão preenchidos depois
        entry_idx += 1

    return root


def create_directory_entry(name, ext, cluster, size, is_dir=False):
    """Cria uma entrada de diretório FAT16."""
    entry = bytearray(32)
    entry[0:8] = name.upper().ljust(8).encode('ascii')[:8]
    entry[8:11] = ext.upper().ljust(3).encode('ascii')[:3]
    entry[11] = 0x10 if is_dir else 0x20  # Attribute

    now = time.localtime()
    fat_time = (now.tm_hour << 11) | (now.tm_min << 5) | (now.tm_sec // 2)
    fat_date = ((now.tm_year - 1980) << 9) | (now.tm_mon << 5) | now.tm_mday
    struct.pack_into('<H', entry, 14, fat_time)
    struct.pack_into('<H', entry, 16, fat_date)
    struct.pack_into('<H', entry, 22, fat_time)
    struct.pack_into('<H', entry, 24, fat_date)
    struct.pack_into('<H', entry, 26, cluster)
    struct.pack_into('<I', entry, 28, size)

    return entry


def create_mbr(partitions):
    """
    Cria um MBR com tabela de partições padrão (compatível com Nextor).
    partitions: lista de (start_lba, size_sectors, fs_type)
    """
    mbr = bytearray(SECTOR_SIZE)

    # MBR boot code stub (jump to boot signature)
    mbr[0] = 0xEB
    mbr[1] = 0xFE
    mbr[2] = 0x90

    for i, (start_lba, size_sectors, fs_type) in enumerate(partitions):
        if i >= 4:
            break

        offset = 446 + i * 16

        # Status byte (0x80 = bootable para a primeira)
        mbr[offset] = 0x80 if i == 0 else 0x00

        # CHS do primeiro setor
        h, cs, cl = lba_to_chs(start_lba)
        mbr[offset + 1] = h
        mbr[offset + 2] = cs
        mbr[offset + 3] = cl

        # Tipo de partição
        mbr[offset + 4] = fs_type

        # CHS do último setor
        h, cs, cl = lba_to_chs(start_lba + size_sectors - 1)
        mbr[offset + 5] = h
        mbr[offset + 6] = cs
        mbr[offset + 7] = cl

        # LBA do primeiro setor
        struct.pack_into('<I', mbr, offset + 8, start_lba)

        # Número de setores
        struct.pack_into('<I', mbr, offset + 12, size_sectors)

    # Boot signature
    mbr[510] = 0x55
    mbr[511] = 0xAA

    return mbr


def write_file_to_partition(partition_data, boot_sector, fat, root_dir, file_data_list):
    """
    Escreve arquivos na partição FAT16.
    Retorna a partição modificada.
    """
    bps = struct.unpack_from('<H', boot_sector, 11)[0]
    spc = boot_sector[13]
    reserved = struct.unpack_from('<H', boot_sector, 14)[0]
    nfats = boot_sector[16]
    root_entries = struct.unpack_from('<H', boot_sector, 17)[0]
    spf = struct.unpack_from('<H', boot_sector, 22)[0]

    fat_offset = reserved * bps
    root_offset = fat_offset + nfats * spf * bps
    data_offset = root_offset + root_entries * 32
    cluster_size = spc * bps

    next_cluster = 2  # Primeiro cluster disponível
    dir_entry_idx = 0

    # Processa cada arquivo
    for fname, fdata, is_subdir in file_data_list:
        if dir_entry_idx >= root_entries:
            break

        name_parts = fname.upper().split('.', 1)
        base_name = name_parts[0][:8]
        ext_name = name_parts[1][:3] if len(name_parts) > 1 else ''

        if is_subdir:
            # Cria entrada de diretório
            entry = create_directory_entry(base_name, ext_name, next_cluster, 0, is_dir=True)

            # Cria o cluster do diretório (com entradas . e ..)
            dir_cluster = bytearray(cluster_size)
            # Entrada .
            dot = create_directory_entry('.', '', next_cluster, 0, is_dir=True)
            dir_cluster[0:32] = dot
            # Entrada ..
            dotdot = create_directory_entry('..', '', 0, 0, is_dir=True)
            dir_cluster[32:64] = dotdot

            # Escreve o subdiretório nos arquivos
            sub_entry_idx = 2  # Começa após . e ..
            first_sub_cluster = next_cluster

            # Marca o cluster do diretório no FAT
            struct.pack_into('<H', fat, next_cluster * 2, 0xFFFF)
            offset = data_offset + (next_cluster - 2) * cluster_size
            partition_data[offset:offset + cluster_size] = dir_cluster
            next_cluster += 1

            # Escreve os arquivos do subdiretório
            for sub_fname, sub_fdata in fdata:
                if sub_entry_idx >= cluster_size // 32:
                    break

                sub_parts = sub_fname.upper().split('.', 1)
                sub_base = sub_parts[0][:8]
                sub_ext = sub_parts[1][:3] if len(sub_parts) > 1 else ''

                file_cluster = next_cluster
                remaining = len(sub_fdata)
                pos = 0
                prev_cluster = None

                while remaining > 0:
                    chunk = min(remaining, cluster_size)
                    offset = data_offset + (next_cluster - 2) * cluster_size
                    partition_data[offset:offset + chunk] = sub_fdata[pos:pos + chunk]

                    if prev_cluster is not None:
                        struct.pack_into('<H', fat, prev_cluster * 2, next_cluster)

                    prev_cluster = next_cluster
                    next_cluster += 1
                    pos += chunk
                    remaining -= chunk

                if prev_cluster is not None:
                    struct.pack_into('<H', fat, prev_cluster * 2, 0xFFFF)

                sub_entry = create_directory_entry(sub_base, sub_ext, file_cluster, len(sub_fdata))
                sub_offset = data_offset + (first_sub_cluster - 2) * cluster_size + sub_entry_idx * 32
                partition_data[sub_offset:sub_offset + 32] = sub_entry
                sub_entry_idx += 1

        else:
            # Arquivo normal no root
            first_cluster = next_cluster
            remaining = len(fdata)
            pos = 0
            prev_cluster = None

            while remaining > 0:
                chunk = min(remaining, cluster_size)
                offset = data_offset + (next_cluster - 2) * cluster_size
                partition_data[offset:offset + chunk] = fdata[pos:pos + chunk]

                if prev_cluster is not None:
                    struct.pack_into('<H', fat, prev_cluster * 2, next_cluster)

                prev_cluster = next_cluster
                next_cluster += 1
                pos += chunk
                remaining -= chunk

            if prev_cluster is not None:
                struct.pack_into('<H', fat, prev_cluster * 2, 0xFFFF)

            entry = create_directory_entry(base_name, ext_name, first_cluster, len(fdata))

        # Escreve a entrada no root directory
        root_entry_offset = root_offset + dir_entry_idx * 32
        partition_data[root_entry_offset:root_entry_offset + 32] = entry
        dir_entry_idx += 1

    # Escreve o boot sector
    partition_data[0:bps] = boot_sector

    # Escreve as FATs
    for i in range(nfats):
        foff = fat_offset + i * spf * bps
        partition_data[foff:foff + len(fat)] = fat

    return partition_data


def create_hdd_image(output_path, nextor_files_dir=None):
    """Cria a imagem HDD completa com partições Nextor."""

    partition_sectors = PARTITION_SIZE_MB * 1024 * 1024 // SECTOR_SIZE
    # Alinha ao cilindro
    sectors_per_cylinder = HEADS * SECTORS_PER_TRACK
    partition_sectors = (partition_sectors // sectors_per_cylinder) * sectors_per_cylinder

    # O primeiro setor é o MBR; partições começam no próximo cilindro
    partition_start_offset = sectors_per_cylinder  # Primeiro cilindro para MBR

    partitions_info = []
    for i in range(NUM_PARTITIONS):
        start = partition_start_offset + i * partition_sectors
        partitions_info.append((start, partition_sectors, 0x06))  # 0x06 = FAT16 > 32MB

    total_sectors = partitions_info[-1][0] + partitions_info[-1][1]
    total_size = total_sectors * SECTOR_SIZE

    print(f"  Tamanho total da imagem: {total_size // (1024*1024)} MB")
    print(f"  Setores por particao: {partition_sectors}")
    print(f"  Total de setores: {total_sectors}")

    # Cria o buffer da imagem
    image = bytearray(total_size)

    # Cria o MBR
    print("  Criando MBR...")
    mbr = create_mbr(partitions_info)
    image[0:SECTOR_SIZE] = mbr

    # Cria cada partição
    for i, (start_lba, size_sectors, _) in enumerate(partitions_info):
        part_num = i + 1
        label = f"MSXAIR P{part_num} ".ljust(11)
        print(f"  Formatando particao {part_num} ({PARTITION_SIZE_MB}MB, FAT16, label='{label.strip()}')")

        boot_sector, spf = create_fat16_boot_sector(size_sectors, volume_label=label)

        # Hidden sectors = setores antes desta partição
        struct.pack_into('<I', boot_sector, 28, start_lba)

        fat = create_fat16_table(spf)
        partition_data = bytearray(size_sectors * SECTOR_SIZE)

        # Boot sector
        partition_data[0:SECTOR_SIZE] = boot_sector

        # FATs
        fat_offset_in_part = RESERVED_SECTORS * SECTOR_SIZE
        for j in range(NUM_FATS):
            off = fat_offset_in_part + j * spf * SECTOR_SIZE
            partition_data[off:off + len(fat)] = fat

        # Para a partição 1, importa arquivos Nextor
        if part_num == 1 and nextor_files_dir and os.path.isdir(nextor_files_dir):
            print(f"  Importando arquivos Nextor para particao {part_num}...")

            # Arquivos de boot (vão na raiz)
            boot_files = ['NEXTOR.SYS', 'COMMAND2.COM', 'MSXDOS.SYS', 'COMMAND.COM']
            tool_files = [
                'DELALL.COM', 'DEVINFO.COM', 'DRIVERS.COM', 'DRVINFO.COM',
                'FASTOUT.COM', 'LOCK.COM', 'MAPDRV.COM', 'EMUFILE.COM',
                'RALLOC.COM', 'Z80MODE.COM', 'NSYSVER.COM', 'NEXBOOT.COM',
                'CONCLUS.COM'
            ]

            file_data_list = []

            # Carrega arquivos de boot
            for fname in boot_files:
                fpath = os.path.join(nextor_files_dir, fname)
                if os.path.exists(fpath):
                    with open(fpath, 'rb') as f:
                        data = f.read()
                    file_data_list.append((fname, data, False))
                    print(f"    -> {fname} ({len(data)} bytes)")

            # AUTOEXEC.BAT
            autoexec = b"ECHO.\r\nECHO  ** MSX Air - Nextor 2.1.0 **\r\nECHO  ** Disco rigido virtual **\r\nECHO.\r\nSET PATH=A:\\TOOLS\r\n"
            file_data_list.append(('AUTOEXEC.BAT', autoexec, False))
            print(f"    -> AUTOEXEC.BAT ({len(autoexec)} bytes)")

            # Subdiretório TOOLS com ferramentas
            tools_data = []
            for fname in tool_files:
                fpath = os.path.join(nextor_files_dir, fname)
                if os.path.exists(fpath):
                    with open(fpath, 'rb') as f:
                        data = f.read()
                    tools_data.append((fname, data))
                    print(f"    -> TOOLS/{fname} ({len(data)} bytes)")

            if tools_data:
                file_data_list.append(('TOOLS', tools_data, True))

            partition_data = write_file_to_partition(
                partition_data, boot_sector, fat,
                bytearray(ROOT_DIR_ENTRIES * 32), file_data_list
            )

        # Escreve a partição na imagem
        start_offset = start_lba * SECTOR_SIZE
        image[start_offset:start_offset + len(partition_data)] = partition_data

    # Salva a imagem
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    with open(output_path, 'wb') as f:
        f.write(image)

    return total_size


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))

    output_path = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser('~/MSX/media/msxair-hdd.dsk')
    nextor_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(script_dir, 'nextor-boot-files')

    print()
    print("╔══════════════════════════════════════════╗")
    print("║  MSX Air - Criador de Imagem HDD Nextor ║")
    print("╠══════════════════════════════════════════╣")
    print("║ Nextor 2.1.0 + Sunrise IDE (FAT16)      ║")
    print("║ 3 particoes x 32MB = 96MB                ║")
    print("╚══════════════════════════════════════════╝")
    print()
    print(f"Saida: {output_path}")
    print(f"Nextor files: {nextor_dir}")
    print()

    if os.path.exists(output_path):
        resp = input(f"A imagem ja existe: {output_path}\nSobrescrever? (s/N): ")
        if resp.lower() != 's':
            print("Operacao cancelada.")
            return

    total_size = create_hdd_image(output_path, nextor_dir)

    print()
    print("=" * 50)
    print(f"  Imagem HDD criada com sucesso!")
    print(f"  Arquivo: {output_path}")
    print(f"  Tamanho: {total_size // (1024*1024)} MB")
    print()
    print("  Estrutura:")
    print("    Particao 1 (32MB): NEXTOR.SYS + COMMAND2.COM + TOOLS/")
    print("    Particao 2 (32MB): vazia (uso geral)")
    print("    Particao 3 (32MB): vazia (uso geral)")
    print()
    print("  Para usar com openMSX:")
    print(f"    openmsx -machine Panasonic_FS-A1GT -ext ide -hda {output_path}")
    print()
    print("  Ou via MSX Air:")
    print("    ./launch-msxair.sh")
    print("=" * 50)
    print()


if __name__ == '__main__':
    main()
