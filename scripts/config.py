import time

from pyftdi.spi import SpiController

CLOCK_CONFIG_WIDTH = 4
SCALE_WIDTH = 6
COEFF_WIDTH = 12

COEFFS = (25, 83, 243, 422, 502)
# COEFFS = (0x7FF, 0, 0, 0)
CLOCK_CONFIG = 1  # Controls sampling rate
# audio quality seems best when these are matched, i.e. 12 and 24
ADC_SCALE = 12
DAC_SCALE = 22


def generateConfig(clockConfig: int, adcScale: int, dacScale: int) -> bytes:
    data = 0
    data |= clockConfig
    data |= adcScale << CLOCK_CONFIG_WIDTH
    data |= dacScale << (SCALE_WIDTH + CLOCK_CONFIG_WIDTH)
    for i, coeff in enumerate(COEFFS):
        data |= coeff << ((SCALE_WIDTH * 2) + CLOCK_CONFIG_WIDTH + (i * COEFF_WIDTH))

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
