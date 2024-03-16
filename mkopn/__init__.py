import hashlib
import math
import pathlib
import shutil
import sys


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} COMPRESSED_ROOT_IMAGE_FILE OPN_OUTPUT_FILE")
        sys.exit(1)

    installer_file = pathlib.Path(__file__).parent / "installer.sh"
    root_image_file = pathlib.Path(sys.argv[1])
    opn_file = pathlib.Path(sys.argv[2])

    installer_file_size = installer_file.stat().st_size
    root_image_file_size = root_image_file.stat().st_size

    header_size = 4096
    alignment = 4096
    padded_installer_file_size = math.ceil(installer_file_size / alignment) * alignment
    installer_padding_size = padded_installer_file_size - installer_file_size
    padded_root_image_file_size = math.ceil(root_image_file_size / alignment) * alignment
    root_image_padding_size = padded_root_image_file_size - root_image_file_size
    root_image_offset = math.ceil((header_size + padded_installer_file_size) / alignment) * alignment

    with opn_file.open(mode="w+b", buffering=0) as opn:
        # write empty header (is populated later)
        opn.write(b"\x00" * header_size)

        # write installer
        with installer_file.open(mode="rb") as installer:
            shutil.copyfileobj(installer, opn)

        # write installer padding
        opn.write(b"\n" * installer_padding_size)

        # write root image
        opn.seek(root_image_offset)
        with root_image_file.open(mode="rb") as root_image:
            shutil.copyfileobj(root_image, opn)

        # write root image padding
        opn.write(b"\x00" * root_image_padding_size)

        # magic prefix
        opn.seek(0)
        opn.write(b"ALDIMAGE")

        # installer size
        opn.seek(96)
        opn.write(padded_installer_file_size.to_bytes(8, byteorder="big"))

        # installer checksum
        installer_checksum = hashlib.sha256()
        opn.seek(header_size)
        for _ in range(int(padded_installer_file_size / alignment)):
            installer_checksum.update(opn.read(alignment))
        opn.seek(104)
        opn.write(installer_checksum.digest())

        # version e.g. 2.8.5.11: 00 02 00 08 00 05 00 0B
        opn.seek(192)
        opn.write(b"\x00\x02\x00\x08\x00\x05\x00\x0B")

        # root image checksum
        rootfs_checksum = sha256sum_from_position_to_end(opn, root_image_offset)
        opn.seek(136)
        opn.write(rootfs_checksum.digest())

        # header checksum
        opn.seek(56)
        header_checksum = hashlib.sha256(opn.read(4040))
        opn.seek(24)
        opn.write(header_checksum.digest())

        # print checksums
        print(f"Installer checksum: {installer_checksum.hexdigest()}")
        print(f"Header checksum: {header_checksum.hexdigest()}")
        print(f"Root image checksum: {rootfs_checksum.hexdigest()}")

def sha256sum_from_position_to_end(file, position):
    file.seek(position)
    checksum_hash = hashlib.sha256()
    buffer = bytearray(4096)
    memory_view = memoryview(buffer)
    for amount in iter(lambda: file.readinto(memory_view), 0):
        checksum_hash.update(memory_view[:amount])
    return checksum_hash
