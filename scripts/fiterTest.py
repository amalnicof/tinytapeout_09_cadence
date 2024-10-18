import pathlib
from typing import TypedDict

import numpy as np
import sounddevice as sd
from fixedpoint import FixedPoint


class FixedPointKwargs(TypedDict):
    signed: bool
    m: int
    n: int
    rounding: str


SAMPLING_FREQ = 44100
DURATION = 5

WORK_DIR = pathlib.Path(__file__).parent
SONG_PATH = WORK_DIR / "data/example.raw"

COEFF_CONFIG: FixedPointKwargs = {
    "signed": True,
    "m": 1,
    "n": 11,
    "rounding": "convergent",
}
SAMPLE_CONFIG: FixedPointKwargs = {
    "signed": False,
    "m": 12,
    "n": 0,
    "rounding": "convergent",
}

COEFFS_LOW_PASS = (
    0.0122,
    0.0407,
    0.1184,
    0.2062,
    0.2449,
    0.2062,
    0.1184,
    0.0407,
    0.0122,
)
COEFFS_HIGH_PASS = (
    0.0049,
    -0.0028,
    -0.0774,
    -0.2314,
    0.6766,
    -0.2314,
    -0.0774,
    -0.0028,
    0.0049,
)
COEFFS = COEFFS_HIGH_PASS


def main() -> None:
    data = np.fromfile(SONG_PATH, dtype=np.int16, count=SAMPLING_FREQ * DURATION)

    # Convert to unsigned
    data = data.view(np.uint16)
    data += 32768

    # Convert to uint12
    data >>= 4

    # Convert to float
    data = data.astype(float)

    # Pass through filter
    firData: list[float] = []
    taps: list[float] = [0.0 for _ in range(9)]
    for sample in data:
        taps[8:1] = taps[7:0]
        taps[0] = sample

        acc = 0.0
        for i, c in enumerate(COEFFS):
            acc += taps[i] * c
        firData.append(acc)

    # Remove fractional bits
    data = np.array(firData)
    data = np.trunc(data)
    data = data.astype(int)
    print(min(data))

    # Convert to int to uint
    data += 2048

    # Keep 12 bits
    data &= 0xFFF

    # Convert to uint16
    data <<= 4

    # Convert to signed
    data = data.astype(int)
    data -= 32768
    data = data.astype(np.int16)

    sd.play(data, samplerate=SAMPLING_FREQ)
    sd.wait()
    pass


if __name__ == "__main__":
    main()
