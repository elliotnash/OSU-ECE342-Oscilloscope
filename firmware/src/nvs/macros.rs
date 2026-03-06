macro_rules! nvs_layout {
    // Main entry point - generate struct, then build static with accumulator
    { $($name:ident : $ty:tt)* } => {
        nvs_layout!(@build_struct $($name)*);
        nvs_layout!(@build_static [] 0u32; $($name : $ty)*);
    };

    // Generate the struct with all u32 fields, plus length
    (@build_struct $($name:ident)*) => {
        #[allow(unused)]
        pub struct NvsLayout {
            $(pub $name: u32,)*
            pub length: u32,
        }
    };

    // Build static - base case: emit the accumulated fields, with length = final offset
    (@build_static [$($acc:tt)*] $offset:expr;) => {
        #[allow(unused)]
        pub static NVS_LAYOUT: NvsLayout = NvsLayout {
            $($acc)*
            length: $offset,
        };
    };

    // Build static - recursive: accumulate field initializers
    (@build_static [$($acc:tt)*] $offset:expr; $name:ident : $ty:tt $($rest:tt)*) => {
        nvs_layout!(@build_static
            [$($acc)* $name: $offset,]
            ($offset + ::core::mem::size_of::<$ty>() as u32);
            $($rest)*
        );
    };
}

macro_rules! read_u32 {
    ($buffer:expr, $field:ident) => {
        u32::from_ne_bytes(
            $buffer[(NVS_LAYOUT.$field as usize)..(NVS_LAYOUT.$field as usize + 4)]
                .try_into()
                .unwrap(),
        )
    };
}

macro_rules! read_u16 {
    ($buffer:expr, $field:ident) => {
        u16::from_ne_bytes(
            $buffer[(NVS_LAYOUT.$field as usize)..(NVS_LAYOUT.$field as usize + 2)]
                .try_into()
                .unwrap(),
        )
    };
}

macro_rules! read_u8 {
    ($buffer:expr, $field:ident) => {
        $buffer[NVS_LAYOUT.$field as usize]
    };
}

macro_rules! write_u32 {
    ($buffer:expr, $field:ident, $value:expr) => {
        $buffer[(NVS_LAYOUT.$field as usize)..(NVS_LAYOUT.$field as usize + 4)]
            .copy_from_slice(&$value.to_ne_bytes())
    };
}

macro_rules! write_u16 {
    ($buffer:expr, $field:ident, $value:expr) => {
        $buffer[(NVS_LAYOUT.$field as usize)..(NVS_LAYOUT.$field as usize + 2)]
            .copy_from_slice(&$value.to_ne_bytes())
    };
}

macro_rules! write_u8 {
    ($buffer:expr, $field:ident, $value:expr) => {
        $buffer[NVS_LAYOUT.$field as usize] = $value
    };
}
