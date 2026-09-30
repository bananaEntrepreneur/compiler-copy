const Point = struct {
    x: f32 = 0,
    y: f32 = 0,

    pub fn length(self: Point) f32 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }
};

const Color = enum(u8) { red = 1, green, blue };

const Value = union(enum) {
    int: i64,
    float: f64,
    none,
};

const Tagged = union(Color) { red: void, green: u8, blue: u16 };

const Flags = packed struct(u8) { read: bool, write: bool, rest: u6 };

const Header = extern struct { type: u16, size: u32 };

const Handle = opaque {};

const FileError = error{ NotFound, AccessDenied };

const Inferred = union(enum(u8)) { a, b };
