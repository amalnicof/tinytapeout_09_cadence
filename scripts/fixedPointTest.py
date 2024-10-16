from fixedpoint import FixedPoint

COEFF_CONFIG = {"signed": True, "m": 1, "n": 11, "rounding": "convergent"}
SAMPLE_CONFIG = {"signed": False, "m": 12, "n": 0, "rounding": "convergent"}


def main() -> None:
    coeffs = (
        # FixedPoint(0x7ff / (1<<11), **COEFF_CONFIG),
        # FixedPoint(0x7ff / (1<<11), **COEFF_CONFIG),
        # FixedPoint(0x7ff / (1<<11), **COEFF_CONFIG),
        # FixedPoint(0x7ff / (1<<11), **COEFF_CONFIG),
        FixedPoint(-1, **COEFF_CONFIG),
        FixedPoint(-1, **COEFF_CONFIG),
        FixedPoint(-1, **COEFF_CONFIG),
        FixedPoint(-1, **COEFF_CONFIG),
    )
    samples = (
        FixedPoint(0xFFF, **SAMPLE_CONFIG),
        FixedPoint(0xFFF, **SAMPLE_CONFIG),
        FixedPoint(0xFFF, **SAMPLE_CONFIG),
        FixedPoint(0xFFF, **SAMPLE_CONFIG),
        FixedPoint(0xFFF, **SAMPLE_CONFIG),
        FixedPoint(0xFFF, **SAMPLE_CONFIG),
        FixedPoint(0xFFF, **SAMPLE_CONFIG),
        FixedPoint(0xFFF, **SAMPLE_CONFIG),
    )

    acc = FixedPoint(0, signed=False, m=1, n=0, rounding="convergent")
    for i in range(4):
        acc += coeffs[i] * (samples[i] + samples[7 - i])  # 4 + 4

    print(f"\nacc, Q-Format: {acc:q}, Hex: {acc:x}, Float: {acc:f}")
    pass


def test() -> None:
    samples = (
        FixedPoint(0x1, **SAMPLE_CONFIG),
        FixedPoint(0x1, **SAMPLE_CONFIG),
        FixedPoint(0xFFF, **SAMPLE_CONFIG),
        FixedPoint(0x0, **SAMPLE_CONFIG),
        FixedPoint(0x0, **SAMPLE_CONFIG),
        FixedPoint(0xFFF, **SAMPLE_CONFIG),
        FixedPoint(0xFFE, **SAMPLE_CONFIG),
        FixedPoint(0xFFE, **SAMPLE_CONFIG),
    )
    coeffs = (
        FixedPoint(0.0202, **COEFF_CONFIG),
        FixedPoint(0.0649, **COEFF_CONFIG),
        FixedPoint(0.1664, **COEFF_CONFIG),
        FixedPoint(0.2484, **COEFF_CONFIG),
    )

    acc = FixedPoint(0, signed=False, m=1, n=0, rounding="convergent")
    for i in range(4):
        acc += coeffs[i] * (samples[i] + samples[7 - i])  # 4 + 4

    print(f"\nacc, Q-Format: {acc:q}, Hex: {acc:x}, Float: {acc:f}")
    dacOutput = hex(int(acc.bits) >> 11)
    print(f"Dac output, {dacOutput}")

    for c in coeffs:
        print(f"\ncoeff, Q-Format: {c:q}, Hex: {c:x}, Float: {c:f}")

    pass


if __name__ == "__main__":
    # main()
    test()
