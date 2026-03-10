#[cfg(debug_assertions)]
use specta_typescript::Typescript;
use tauri_specta::{collect_commands, collect_events};
use theme::get_system_theme;
use titlebar::get_titlebar_layout;

use crate::serial::{get_serial_status, SerialStatus, serial_task, get_current_frame, receive_verification_messages, send_verification_message, send_channel_options, send_sample_rate, send_calibration_message, send_trigger_options};

pub mod theme;
pub mod titlebar;
pub mod serial;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let builder = tauri_specta::Builder::<tauri::Wry>::new()
        .commands(collect_commands![get_system_theme, get_titlebar_layout, get_serial_status, get_current_frame, receive_verification_messages, send_verification_message, send_channel_options, send_sample_rate, send_calibration_message, send_trigger_options])
        .events(collect_events![SerialStatus]);

    #[cfg(debug_assertions)] // <- Only export on non-release builds
    builder
        .export(Typescript::default(), "../frontend/src/bindings.ts")
        .expect("Failed to export typescript bindings");

    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_log::Builder::new().build())
        .plugin(tauri_plugin_os::init())
        .invoke_handler(builder.invoke_handler())
        .setup(move |app| {
            builder.mount_events(app);

            // Create main window in Rust so we can set decorations per platform
            // macOS decorations true (native titlebar overlay), others false
            let win_builder = tauri::WebviewWindowBuilder::new(
                app,
                "main",
                tauri::WebviewUrl::default(),
            )
            .title("oscope-tauri")
            .inner_size(800.0, 600.0)
            .min_inner_size(640.0, 480.0)
            .visible(false)
            .closable(true)
            .decorations(cfg!(target_os = "macos"));

            // On macOS, inset the traffic light buttons
            #[cfg(target_os = "macos")]
            let win_builder = win_builder
                .hidden_title(true)
                .title_bar_style(tauri::TitleBarStyle::Overlay)
                .traffic_light_position(tauri::LogicalPosition::new(18.0, 26.0));

            win_builder.build()?;

            let app_handle = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                serial_task(app_handle).await;
            });
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
