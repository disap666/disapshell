#!/usr/bin/env python3
"""Read battery status from the 379a:3901 Compx receiver; never change settings.

Query framing reference: HeyOkay/HaloBattery providers/pulsar.py (Compx 0x04).
This device is validated by its report descriptor and the response checksum.
"""
import json
import os
from pathlib import Path
import select
import time


def query():
    for device in Path('/sys/class/hidraw').glob('hidraw*'):
        try:
            info = (device / 'device/uevent').read_text()
            if 'HID_ID=0003:0000379A:00003901' not in info:
                continue
            descriptor = (device / 'device/report_descriptor').read_bytes()
            if bytes.fromhex('06 02 ff 09 02 a1 01 85 08') not in descriptor:
                continue
            result = {'model': 'Pulsar 3 Ultra Wireless', 'percentage': None, 'state': 0,
                      'isLaptopBattery': False, 'isPresent': True, 'device': '/dev/' + device.name}
            try:
                fd = os.open(result['device'], os.O_RDWR | os.O_NONBLOCK)
            except PermissionError:
                result['status'] = 'permission-denied'
                return result
            try:
                for _ in range(8):
                    if not select.select([fd], [], [], 0)[0]:
                        break
                    os.read(fd, 256)
                # Report 8, command 4: read power details; all arguments zero.
                os.write(fd, bytes([8, 4] + [0] * 14 + [0x49]))
                deadline = time.monotonic() + 1.2
                while time.monotonic() < deadline:
                    if not select.select([fd], [], [], max(0, deadline - time.monotonic()))[0]:
                        break
                    reply = os.read(fd, 256)
                    if len(reply) != 17 or reply[:2] != b'\x08\x04':
                        continue
                    if sum(reply) % 256 != 0x55 or reply[6] > 100 or reply[7] not in (0, 1):
                        continue
                    result.update(percentage=reply[6] / 100, state=1 if reply[7] else 2,
                                  status='ok', voltageMv=int.from_bytes(reply[8:10], 'big'))
                    return result
                result['status'] = 'no-response'
            finally:
                os.close(fd)
            return result
        except OSError:
            continue
    return None


if __name__ == '__main__':
    print(json.dumps(query()))
