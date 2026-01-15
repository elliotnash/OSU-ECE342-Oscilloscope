use specta::Type;
use serde::{Deserialize, Serialize};
 
// The `specta::Type` macro allows us to understand your types
// We implement `specta::Type` on primitive types for you.
// If you want to use a type from an external crate you may need to enable the feature on Specta.
#[derive(Serialize, Type)]
pub struct MyCustomReturnType {
    pub some_field: String,
}
 
#[derive(Deserialize, Type)]
pub struct MyCustomArgumentType {
    pub foo: String,
    pub bar: i32,
}

#[tauri::command]
#[specta::specta] // <-- This bit here
fn greet3() -> MyCustomReturnType {
    MyCustomReturnType {
        some_field: "Hello World".into(),
    }
}