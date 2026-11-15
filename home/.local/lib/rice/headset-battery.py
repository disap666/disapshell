#!/usr/bin/env python3
"""Read HyperX 0951:1713 battery via read-only vendor status commands.

Protocol and voltage calibration: HyperBatteryMonitor,
Devices/CloudStingerCoreWirelessDevice.cs (davidsantanaalves on GitHub).
Validated on this Kingston receiver: FF 0C 05 connection, FF 12 05 battery.
No configuration commands are sent. Percentage is a voltage-based estimate.
"""
import fcntl
import json
import os
from pathlib import Path
import time

CONNECTION = bytes.fromhex('ff 07 00 fd 04 00 00 02 82 03 05 29 0f 00 00 03 68 10 00 00')
BATTERY = bytes.fromhex('ff 07 00 fd 04 0c f1 02 01 04 f0 0c')
DISCHARGING = (3517.4, 3650.8, 3699.8, 3738.1, 3763.3, 3784.7, 3838.1, 3905.2, 3954.2, 4042.3, 4120.5)
CHARGING = (3400, 3830.9, 3870.7, 3916.2, 3929.9, 3945.6, 3967.4, 4000, 4049.7, 4090, 4130)


def exchange(fd, command, header):
    packet = bytearray(command.ljust(64, b'\0'))
    fcntl.ioctl(fd, 0xC0404806, packet, True)  # HIDIOCSFEATURE(64)
    for _ in range(10):
        time.sleep(.025)
        reply = bytearray([255] + [0] * 63)
        fcntl.ioctl(fd, 0xC0404807, reply, True)  # HIDIOCGFEATURE(64)
        if reply[:3] == header:
            return reply
    return None


def percentage(millivolts, charge):
    if charge == 6:
        return 1.0
    knots = CHARGING if charge == 5 else DISCHARGING
    if millivolts >= knots[-1]:
        return 1.0
    for i, (low, high) in enumerate(zip(knots, knots[1:])):
        if low <= millivolts <= high:
            return int(i * 10 + (millivolts - low) / (high - low) * 10) / 100
    return 0.0


def query():
    for device in Path('/sys/class/hidraw').glob('hidraw*'):
        try:
            if 'HID_ID=0003:00000951:00001713' not in (device / 'device/uevent').read_text():
                continue
            result = {'model': 'HyperX Cloud Stinger Core Wireless', 'percentage': None,
                      'state': 0, 'isLaptopBattery': False, 'isPresent': True,
                      'kind': 'headset', 'status': 'no-response',
                      'statusText': 'Наушники не ответили · проверьте питание'}
            fd = os.open('/dev/' + device.name, os.O_RDWR | os.O_NONBLOCK)
            try:
                connection = exchange(fd, CONNECTION, b'\xff\x0c\x05')
                if connection is None or connection[11] != 1:
                    result.update(status='offline', statusText='Наушники выключены или вне зоны приёма')
                    return result
                reply = exchange(fd, BATTERY, b'\xff\x12\x05')
                if reply is None or reply[9] not in (3, 5, 6):
                    return result
                mv = int.from_bytes(reply[11:13], 'little')
                if not 3000 <= mv <= 4500:
                    return result
                result.update(percentage=percentage(mv, reply[9]),
                              state=1 if reply[9] == 5 else 4 if reply[9] == 6 else 2,
                              status='ok', voltageMv=mv, estimated=True,
                              statusText=f'Примерный заряд по напряжению батареи · {mv / 1000:.3f} В')
                return result
            finally:
                os.close(fd)
        except PermissionError:
            result.update(status='permission-denied', statusText='Нет доступа к USB-приёмнику наушников')
            return result
        except OSError:
            if 'result' in locals():
                return result
    return None


if __name__ == '__main__':
    print(json.dumps(query()))
