import time
from typing import TypedDict

from fixedpoint import FixedPoint
from pyftdi.spi import SpiController


class FixedPointKwargs(TypedDict):
    signed: bool
    m: int
    n: int
    rounding: str


CLOCK_CONFIG_WIDTH = 4
SCALE_WIDTH = 6
COEFF_WIDTH = 12
SYM_COEFFS_WIDTH = 1

COEFF_CONFIG: FixedPointKwargs = {
    "signed": True,
    "m": 1,
    "n": 11,
    "rounding": "convergent",
}

HIGH_PASS_COEFFS = (
    (  # CutoffFreq=3000
        int(FixedPoint(-0.0043, **COEFF_CONFIG).bits),
        int(FixedPoint(-0.0222, **COEFF_CONFIG).bits),
        int(FixedPoint(-0.0806, **COEFF_CONFIG).bits),
        int(FixedPoint(-0.1569, **COEFF_CONFIG).bits),
        int(FixedPoint(0.8115, **COEFF_CONFIG).bits),
    ),
    22,
)
LOW_PASS_COEFFS = (
    (  # CutoffFreq=600
        int(FixedPoint(0.0180, **COEFF_CONFIG).bits),
        int(FixedPoint(0.0486, **COEFF_CONFIG).bits),
        int(FixedPoint(0.1226, **COEFF_CONFIG).bits),
        int(FixedPoint(0.1969, **COEFF_CONFIG).bits),
        int(FixedPoint(0.2277, **COEFF_CONFIG).bits),
    ),
    22,
)
BAND_PASS_COEFFS = (
    (  # CutoffFreq=[1000,1500]
        int(FixedPoint(0.0114, **COEFF_CONFIG).bits),
        int(FixedPoint(0.0419, **COEFF_CONFIG).bits),
        int(FixedPoint(0.1269, **COEFF_CONFIG).bits),
        int(FixedPoint(0.2250, **COEFF_CONFIG).bits),
        int(FixedPoint(0.2685, **COEFF_CONFIG).bits),
    ),
    22,
)

PASSTHROUGH_COEFFS = ((0, 0, 0, 0, 0x7FF), 26)

COEFFS, DAC_SCALE = PASSTHROUGH_COEFFS
COEFFS, DAC_SCALE = LOW_PASS_COEFFS
COEFFS, DAC_SCALE = BAND_PASS_COEFFS
COEFFS, DAC_SCALE = HIGH_PASS_COEFFS


CLOCK_CONFIG = 1  # Controls sampling rate
ADC_SCALE = 12
# DAC_SCALE = 23
SYM_COEFFS = 1


def generateConfig(clockConfig: int, adcScale: int, dacScale: int) -> bytes:
    data = 0
    offset = 0

    data |= clockConfig
    offset += CLOCK_CONFIG_WIDTH

    data |= adcScale << offset
    offset += SCALE_WIDTH

    data |= dacScale << offset
    offset += SCALE_WIDTH

    data |= SYM_COEFFS << offset
    offset += SYM_COEFFS_WIDTH

    for coeff in COEFFS:
        data |= coeff << offset
        offset += COEFF_WIDTH

    byteData = data.to_bytes(10, "big")
    return byteData


def main() -> None:
    spi = SpiController()
    spi.configure("ftdi://ftdi:232h:1/1")
    slave = spi.get_port(cs=0, freq=1e6, mode=0)

    slave.write(
        generateConfig(
            clockConfig=CLOCK_CONFIG, adcScale=ADC_SCALE, dacScale=DAC_SCALE
        ),
    )


def sweep() -> None:
    spi = SpiController()
    spi.configure("ftdi://ftdi:232h:1/1")
    slave = spi.get_port(cs=0, freq=1e6, mode=0)

    for i in range(12, 37):
        print(i)
        slave.write(
            generateConfig(clockConfig=CLOCK_CONFIG, adcScale=ADC_SCALE, dacScale=i)
        )
        time.sleep(1)


if __name__ == "__main__":
    main()
    # sweep()
