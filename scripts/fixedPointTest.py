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
        FixedPoint(0xfff, **SAMPLE_CONFIG),
        FixedPoint(0xfff, **SAMPLE_CONFIG),
        FixedPoint(0xfff, **SAMPLE_CONFIG),
        FixedPoint(0xfff, **SAMPLE_CONFIG),
        FixedPoint(0xfff, **SAMPLE_CONFIG),
        FixedPoint(0xfff, **SAMPLE_CONFIG),
        FixedPoint(0xfff, **SAMPLE_CONFIG),
        FixedPoint(0xfff, **SAMPLE_CONFIG),
    )

    acc = FixedPoint(0, signed=False, m=1, n=0, rounding="convergent")
    for i in range(4):
        acc += coeffs[i] * (samples[i] + samples[7 - i])  # 4 + 4

    print(f"\nacc, Q-Format: {acc:q}, Hex: {acc:x}, Float: {acc:f}")

    pass


if __name__ == "__main__":
    main()
