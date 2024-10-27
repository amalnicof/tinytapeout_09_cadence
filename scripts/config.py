from typing import TypedDict

from fixedpoint import FixedPoint
from pyftdi.spi import SpiController


class FixedPointKwargs(TypedDict):
    signed: bool
    m: int
    n: int
    rounding: str


CLOCK_CONFIG_WIDTH = 4
COEFF_WIDTH = 8
SYM_COEFFS_WIDTH = 1

COEFF_CONFIG: FixedPointKwargs = {
    "signed": True,
    "m": 1,
    "n": COEFF_WIDTH - 1,
    "rounding": "convergent",
}

LOW_PASS_COEFFS = (  # CutoffFreq=100
    int(FixedPoint(0.0122, **COEFF_CONFIG).bits),
    int(FixedPoint(0.0216, **COEFF_CONFIG).bits),
    int(FixedPoint(0.0472, **COEFF_CONFIG).bits),
    int(FixedPoint(0.0823, **COEFF_CONFIG).bits),
    int(FixedPoint(0.1174, **COEFF_CONFIG).bits),
    int(FixedPoint(0.1431, **COEFF_CONFIG).bits),
    int(FixedPoint(0.1525, **COEFF_CONFIG).bits),
)
BAND_PASS_COEFFS = (  # CutoffFreq=[1000,1100]
    int(FixedPoint(0.0094, **COEFF_CONFIG).bits),
    int(FixedPoint(0.0188, **COEFF_CONFIG).bits),
    int(FixedPoint(0.0451, **COEFF_CONFIG).bits),
    int(FixedPoint(0.0843, **COEFF_CONFIG).bits),
    int(FixedPoint(0.1260, **COEFF_CONFIG).bits),
    int(FixedPoint(0.1579, **COEFF_CONFIG).bits),
    int(FixedPoint(0.1698, **COEFF_CONFIG).bits),
)
HIGH_PASS_COEFFS = (  # CutoffFreq=3000
    int(FixedPoint(-0.0031, **COEFF_CONFIG).bits),
    int(FixedPoint(-0.0085, **COEFF_CONFIG).bits),
    int(FixedPoint(-0.0247, **COEFF_CONFIG).bits),
    int(FixedPoint(-0.0526, **COEFF_CONFIG).bits),
    int(FixedPoint(-0.0857, **COEFF_CONFIG).bits),
    int(FixedPoint(-0.1128, **COEFF_CONFIG).bits),
    int(FixedPoint(0.8794, **COEFF_CONFIG).bits),
)

PASSTHROUGH_COEFFS = (0, 0, 0, 0, (1 << (COEFF_WIDTH - 1)) - 1)

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
