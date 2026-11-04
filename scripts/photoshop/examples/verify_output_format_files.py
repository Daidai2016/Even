"""Inspect native-test artifacts: python .../verify_output_format_files.py work/format_v21_v30_<id>"""
from pathlib import Path
import struct
import sys

from PIL import Image
import tifffile


def jpeg_sof(data):
    assert data[:2] == b'\xff\xd8'
    offset = 2
    while offset < len(data):
        assert data[offset] == 255
        while data[offset] == 255:
            offset += 1
        marker = data[offset]
        offset += 1
        if marker in (0xC0, 0xC1, 0xC2):
            return marker
        assert marker not in (0xDA, 0xD9), 'No JPEG frame header'
        size = int.from_bytes(data[offset:offset + 2], 'big')
        offset += size
    raise AssertionError('No JPEG frame header')


root = Path(sys.argv[1])
tiffs = sorted(root.rglob('batch.tif'))
jpegs = sorted(root.rglob('batch.jpg'))
assert len(tiffs) == 4 and len(jpegs) == 2
for batch_path in tiffs:
    single_path = next(batch_path.parent.glob('*_制作文件/*_定稿.tif'))
    source_path = next(p for p in batch_path.parent.iterdir() if p.suffix.lower() in ('.tif', '.tiff') and p != batch_path)
    with tifffile.TiffFile(source_path) as original:
        expected_depth = original.pages[0].bitspersample
        expected_samples = original.pages[0].extrasamples
        expected_profile = original.pages[0].tags[34675].value
    for output in (single_path, batch_path):
        with tifffile.TiffFile(output) as result:
            page = result.pages[0]
            assert len(result.pages) == 1
            assert page.compression == 5, 'TIFF must use lossless LZW'
            assert page.bitspersample == expected_depth
            assert page.extrasamples == expected_samples, 'Alpha sample metadata changed'
            assert page.tags[34675].value == expected_profile, 'ICC bytes changed'
            assert 37724 not in page.tags, 'Unexpected Photoshop layer data'
            assert (page.imagewidth, page.imagelength) == (40, 60)
    # Alpha pixel counts (including partial alpha) are verified by the Photoshop native test.
    print('PASS TIFF:', batch_path.parent.name, '| LZW | no layer payload | original bit depth/alpha/ICC')

for batch_path in jpegs:
    single_path = next(batch_path.parent.glob('*_制作文件/*_定稿.jpg'))
    for output in (single_path, batch_path):
        assert jpeg_sof(output.read_bytes()) == 0xC0, 'JPEG must use baseline sequential encoding'
        with Image.open(output) as result:
            quality_record = result.info['photoshop'][1030]
            quality, format_code = struct.unpack('>hH', quality_record[:4])
            assert quality == 8, 'Photoshop quality resource must represent quality 12'
            assert format_code == 0, 'Photoshop format resource must represent standard baseline'
            assert result.size == (40, 60)
    print('PASS JPG:', batch_path.parent.name, '| quality 12 resource | standard baseline resource + SOF0')
