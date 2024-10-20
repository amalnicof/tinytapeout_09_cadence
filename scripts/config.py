from typing import TypedDict

from fixedpoint import FixedPoint
from pyftdi.spi import SpiController


class FixedPointKwargs(TypedDict):
    signed: bool
    m: int
    n: int
    rounding: str


CLOCK_CONFIG_WIDTH = 4
COEFF_WIDTH = 12
SYM_COEFFS_WIDTH = 1

COEFF_CONFIG: FixedPointKwargs = {
    "signed": True,
    "m": 1,
    "n": 11,
    "rounding": "convergent",
}

HIGH_PASS_COEFFS = (  # CutoffFreq=3000
    int(FixedPoint(0.0049, **COEFF_CONFIG).bits),
    int(FixedPoint(-0.0028, **COEFF_CONFIG).bits),
    int(FixedPoint(-0.0774, **COEFF_CONFIG).bits),
    int(FixedPoint(-0.2314, **COEFF_CONFIG).bits),
    int(FixedPoint(0.6766, **COEFF_CONFIG).bits),
)
LOW_PASS_COEFFS = (  # CutoffFreq=100
    int(FixedPoint(0.0182, **COEFF_CONFIG).bits),
    int(FixedPoint(0.0488, **COEFF_CONFIG).bits),
    int(FixedPoint(0.1227, **COEFF_CONFIG).bits),
    int(FixedPoint(0.1967, **COEFF_CONFIG).bits),
    int(FixedPoint(0.2273, **COEFF_CONFIG).bits),
)
BAND_PASS_COEFFS = (  # CutoffFreq=[1000,1500]
    int(FixedPoint(-0.0032, **COEFF_CONFIG).bits),
    int(FixedPoint(0.0217, **COEFF_CONFIG).bits),
    int(FixedPoint(0.1213, **COEFF_CONFIG).bits),
    int(FixedPoint(0.2669, **COEFF_CONFIG).bits),
    int(FixedPoint(0.3382, **COEFF_CONFIG).bits),
)

PASSTHROUGH_COEFFS = (0, 0, 0, 0, 0x7FF)

COEFFS = PASSTHROUGH_COEFFS
# COEFFS = LOW_PASS_COEFFS
# COEFFS = BAND_PASS_COEFFS
# COEFFS = HIGH_PASS_COEFFS


CLOCK_CONFIG = 1  # Controls sampling rate
SYM_COEFFS = 1


def generateConfig(clockConfig: int) -> bytes:
    data = 0
    offset = 0

    data |= clockConfig
    offset += CLOCK_CONFIG_WIDTH

    data |= SYM_COEFFS << offset
    offset += SYM_COEFFS_WIDTH

    for coeff in COEFFS:
        data |= coeff << offset
        offset += COEFF_WIDTH

    byteData = data.to_bytes(9, "big")
    return byteData


def main() -> None:
    spi = SpiController()
    spi.configure("ftdi://ftdi:232h:1/1")
    slave = spi.get_port(cs=0, freq=1e6, mode=0)

    slave.write(
        generateConfig(
            clockConfig=CLOCK_CONFIG,
        ),
    )


if __name__ == "__main__":
    main()
