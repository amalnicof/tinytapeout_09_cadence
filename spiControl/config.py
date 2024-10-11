from pyftdi.spi import SpiController
import time

CLOCK_CONFIG_WIDTH = 4
SCALE_WIDTH = 6

CLOCK_CONFIG = 8 # Controls sampling rate
ADC_SCALE = 12
DAC_SCALE = 18 # Controls volume


def generateConfig(clockConfig: int, adcScale: int, dacScale: int) -> bytes:
    data = 0
    data |= clockConfig
    data |= adcScale << CLOCK_CONFIG_WIDTH
    data |= dacScale << (SCALE_WIDTH + CLOCK_CONFIG_WIDTH)
    byteData = data.to_bytes(2, "big")
    return byteData


def main() -> None:
    spi = SpiController()
    spi.configure("ftdi://ftdi:232h:1/1")
    slave = spi.get_port(cs=0, freq=1e6, mode=0)

    slave.write(
        generateConfig(clockConfig=CLOCK_CONFIG, adcScale=ADC_SCALE, dacScale=DAC_SCALE)
    )

def sweep() -> None:
    spi = SpiController()
    spi.configure("ftdi://ftdi:232h:1/1")
    slave = spi.get_port(cs=0, freq=1e6, mode=0)

    for i in range(0, 15):
        print(i)
        slave.write(
            generateConfig(clockConfig=i, adcScale=ADC_SCALE, dacScale=DAC_SCALE)
        )
        time.sleep(1)


if __name__ == "__main__":
    main()
    # sweep()
