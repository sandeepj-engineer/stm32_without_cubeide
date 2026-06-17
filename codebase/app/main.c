#include <stdint.h>

/* RCC */
#define RCC_AHB1ENR   (*(volatile uint32_t*)0x40023830)

/* GPIOA (button) */
#define GPIOA_MODER   (*(volatile uint32_t*)0x40020000)
#define GPIOA_IDR     (*(volatile uint32_t*)0x40020010)

/* GPIOD (LEDs) */
#define GPIOD_MODER   (*(volatile uint32_t*)0x40020C00)
#define GPIOD_ODR     (*(volatile uint32_t*)0x40020C14)

#define BTN (1U << 0)
#define LEDS (0xF << 12)

static void delay(volatile uint32_t t)
{
    while (t--) __asm__("nop");
}

/* simple LFSR pseudo-random generator */
static uint32_t rnd = 0x12345678;

static uint32_t rand32(void)
{
    rnd ^= rnd << 13;
    rnd ^= rnd >> 17;
    rnd ^= rnd << 5;
    return rnd;
}

static void gpio_init(void)
{
    RCC_AHB1ENR |= (1 << 0); // GPIOA
    RCC_AHB1ENR |= (1 << 3); // GPIOD

    GPIOA_MODER &= ~(3U << (0 * 2)); // PA0 input

    for (int i = 12; i <= 15; i++)
    {
        GPIOD_MODER &= ~(3U << (i * 2));
        GPIOD_MODER |=  (1U << (i * 2));
    }
}

static void set_leds(uint8_t v)
{
    GPIOD_ODR &= ~LEDS;
    GPIOD_ODR |= ((v & 0xF) << 12);
}

int main(void)
{
    gpio_init();

    int mode = 0;
    int last_btn = 0;

    /* knight rider state */
    int pos = 0;
    int dir = 1;

    while (1)
    {
        /* =========================
           Button (mode switch)
        ========================= */
        int btn = (GPIOA_IDR & BTN) ? 1 : 0;

        if (btn && !last_btn)
        {
            delay(60000); // debounce
            mode = (mode + 1) % 4;
        }

        last_btn = btn;

        /* =========================
           MODES
        ========================= */

        switch (mode)
        {
            /* -------------------------
               MODE 0: Knight Rider
            ------------------------- */
            case 0:
                set_leds(1 << pos);

                pos += dir;
                if (pos == 3) dir = -1;
                if (pos == 0) dir = 1;

                delay(90000);
                break;

            /* -------------------------
               MODE 1: Binary counter
            ------------------------- */
            case 1:
                for (int i = 0; i < 16; i++)
                {
                    set_leds(i);
                    delay(120000);
                }
                break;

            /* -------------------------
               MODE 2: Breathing illusion
            ------------------------- */
            case 2:
                for (int i = 0; i < 200000; i += 5000)
                {
                    set_leds(0xF);
                    delay(i);
                    set_leds(0x0);
                    delay(200000 - i);
                }
                break;

            /* -------------------------
               MODE 3: Chaos / glitch mode
            ------------------------- */
            case 3:
                set_leds(rand32());
                delay(80000);
                break;
        }
    }
}