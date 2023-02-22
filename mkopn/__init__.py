import hashlib
import math
import pathlib
import shutil
import sys


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} OPN_OUTPUT_FILE")
        sys.exit(1)

    installer_file = pathlib.Path(__file__).parent / "installer.sh"
    opn_file = pathlib.Path(sys.argv[1])

    installer_file_size = installer_file.stat().st_size

    header_size = 4096
    alignment = 4096
    padded_installer_file_size = math.ceil(installer_file_size / alignment) * alignment
    installer_padding_size = padded_installer_file_size - installer_file_size
    root_image_offset = (
        math.ceil((header_size + padded_installer_file_size) / alignment) * alignment
    )

    with opn_file.open(mode="w+b", buffering=0) as opn:
        # write empty header (is populated later)
        opn.write(b"\x00" * header_size)

        # write installer
        with installer_file.open(mode="rb") as installer:
            shutil.copyfileobj(installer, opn)

        # write installer padding
        opn.write(b"\n" * installer_padding_size)

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

        # root image offset
        opn.seek(136)
        opn.write(root_image_offset.to_bytes(8, byteorder="big"))

        # header checksum
        opn.seek(56)
        header_checksum = hashlib.sha256(opn.read(4040))
        opn.seek(24)
        opn.write(header_checksum.digest())

        # print checksums
        print(f"Installer checksum: {installer_checksum.hexdigest()}")
        print(f"Header checksum: {header_checksum.hexdigest()}")
        print(f"Root image offset: {root_image_offset}")
