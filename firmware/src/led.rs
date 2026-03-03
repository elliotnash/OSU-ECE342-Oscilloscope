use defmt::info;
use embassy_rp::peripherals;
use embassy_rp::pio_programs::ws2812::{Grb, PioWs2812};
use embassy_sync::blocking_mutex::raw::ThreadModeRawMutex;
use embassy_sync::watch::Watch;
use embassy_time::Timer;
use smart_leds::RGB8;

pub static LED_RX: Watch<ThreadModeRawMutex, LedPattern, 1> = Watch::new();
pub const NUM_LEDS: usize = 1;

#[derive(Debug, Clone, PartialEq)]
pub enum LedPattern {
    Pulse(RGB8, u32),
    Blink(RGB8, u32),
    Solid(RGB8),
}

impl defmt::Format for LedPattern {
    fn format(&self, fmt: defmt::Formatter) {
        match self {
            LedPattern::Pulse(color, duration_ms) => {
                defmt::write!(
                    fmt,
                    "Pulse({}, {}, {}, duration={}ms)",
                    color.r,
                    color.g,
                    color.b,
                    duration_ms
                )
            }
            LedPattern::Solid(color) => {
                defmt::write!(fmt, "Solid({}, {}, {})", color.r, color.g, color.b)
            }
            LedPattern::Blink(color, duration_ms) => {
                defmt::write!(
                    fmt,
                    "Blink({}, {}, {}, duration={}ms)",
                    color.r,
                    color.g,
                    color.b,
                    duration_ms
                )
            }
        }
    }
}

type ScopeLed = PioWs2812<'static, peripherals::PIO0, 0, NUM_LEDS, Grb>;

#[embassy_executor::task]
pub async fn led_color_task(mut ws2812: ScopeLed) -> ! {
    let mut led_receiver = LED_RX.receiver().expect("Failed to get LED receiver");

    loop {
        let pattern = led_receiver.get().await;
        match pattern {
            LedPattern::Pulse(color, duration_ms) => {
                pulse_led(&mut ws2812, color, duration_ms).await;
            }
            LedPattern::Solid(color) => {
                ws2812.write(&[color]).await;
                led_receiver.changed().await;
            }
            LedPattern::Blink(color, duration_ms) => {
                blink_led(&mut ws2812, color, duration_ms).await;
            }
        }
    }
}

async fn pulse_led(ws2812: &mut ScopeLed, color: RGB8, duration_ms: u32) {
    // LED refresh rate
    let update_interval_ms: u64 = 10;

    // Total number of brightness steps for the full pulse.
    let mut steps = duration_ms / update_interval_ms as u32;
    if steps < 2 {
        steps = 2;
    }
    let half_steps = steps / 2;

    let mut data = [RGB8::new(0, 0, 0)];

    for step in 0..steps {
        let level = if step <= half_steps {
            step
        } else {
            steps - step
        } as u32;

        let max_level = half_steps.max(1) as u32;

        data[0].r = (color.r as u32 * level / max_level) as u8;
        data[0].g = (color.g as u32 * level / max_level) as u8;
        data[0].b = (color.b as u32 * level / max_level) as u8;

        ws2812.write(&data).await;
        Timer::after_millis(update_interval_ms).await;
    }

    // Turn LED off at the end of the pulse.
    data[0] = RGB8::new(0, 0, 0);
    ws2812.write(&data).await;
}

async fn blink_led(ws2812: &mut ScopeLed, color: RGB8, duration_ms: u32) {
    let half_duration = (duration_ms / 2) as u64;

    ws2812.write(&[color]).await;
    Timer::after_millis(half_duration).await;
    ws2812.write(&[RGB8::new(0, 0, 0)]).await;
    Timer::after_millis(half_duration).await;
}
