const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const assets = @import("assets.zig").embedded_files_map;

const BitmapFont = struct {
    /// All values are in px
    const ImageOptions = struct {
        texture: rl.Texture,
        w: u32,
        h: u32,
    };
    /// All values are in px
    const CharOptions = struct {
        w: u32,
        h: u32,
        pt: u32,
        pb: u32,
        pl: u32,
        pr: u32,
        sequence: []const u8,

        fn get_full_width(self: *const CharOptions) u32 {
            return self.w + self.pl + self.pr;
        }
        fn get_full_height(self: *const CharOptions) u32 {
            return self.h + self.pt + self.pb;
        }
    };
    const Options = struct {
        img: ImageOptions,
        char: CharOptions,
    };

    options: Options,
    img_w_chars: u32,
    img_h_chars: u32,
    char_map: std.AutoHashMap(u8, u32),

    const Self = @This();
    fn init(options: Options, allocator: Allocator) !Self {
        const char_w = options.char.get_full_width();
        const char_h = options.char.get_full_height();
        const img_w_chars: u32 = @divFloor(options.img.w, char_w);
        const img_h_chars: u32 = @divFloor(options.img.h, char_h);
        var char_map = std.AutoHashMap(u8, u32).init(allocator);
        // TODO: calculate max ascii value within `options.chars`
        for (options.char.sequence, 0..) |char, i| {
            _ = try char_map.fetchPut(char, @intCast(i));
        }
        return Self{
            .options = options,
            .img_w_chars = img_w_chars,
            .img_h_chars = img_h_chars,
            .char_map = char_map,
        };
    }

    fn deinit(self: *Self) void {
        self.char_map.deinit();
    }

    fn draw_text(self: *Self, text: []const u8, rect: rl.Rectangle) void {
        rl.drawRectanglePro(rect, .{ .x = 0, .y = 0 }, 0, rl.Color.blue);
        const num_chars: f32 = @as(f32, @floatFromInt(text.len));
        const c_size: f32 = @divFloor(rect.width, num_chars * 1.2);
        const excess_width: f32 = rect.width - (c_size * num_chars);
        const center_y: f32 = rect.y + ((rect.height / 2.0) - (c_size / 2.0));
        const start_x: f32 = rect.x + (excess_width / 2.0);
        for (text, 0..) |c, i| {
            self.draw_char(c, .{
                .x = start_x + @as(f32, @floatFromInt(i)) * c_size,
                .y = center_y,
                .width = c_size * (1.0 / 1.2),
                .height = c_size * (1.0 / 1.2),
            });
        }
    }

    fn draw_char(self: *Self, char: u8, rect: rl.Rectangle) void {
        const idx = self.char_map.get(char);
        if (idx) |i| {
            const x_tiles: u32 = @mod(i, self.img_w_chars);
            const y_tiles: u32 = @divFloor(i, self.img_w_chars);
            const x_px: u32 = x_tiles * self.options.char.get_full_width();
            const y_px: u32 = y_tiles * self.options.char.get_full_height();
            // 1. The full texture file (e.g., a spritesheet)
            // +---------------------------------+
            // |          (texture)              |
            // |                                 |
            // |   // 2. The 'source' rectangle selects a piece
            // |   // +-------+                  |
            // |   // | sprite|                  |
            // |   // +-------+                  |
            // |                                 |
            // +---------------------------------+
            // --------------------------------------------------------------------
            // The Screen
            // +-------------------------------------------------------------------+
            // |                                                                   |
            // |       // 3. The 'dest' rectangle defines where to draw on screen
            // |       // and how big it should be.
            // |       //
            // |       // +-----------------+
            // |       // | (dest)          |
            // |       // |                 |
            // |       // |   // 4. The 'origin' is a point *inside* dest
            // |       // |   // for rotation. Let's say center.
            // |       // |   //      + (origin)
            // |       // |                 |
            // |       // +-----------------+
            // |                                                                   |
            // |       // The sprite from 'source' is scaled to fit 'dest'
            // |       // and then rotated by 'rotation' degrees around 'origin',
            // |       // and finally colored with 'tint'.
            // |                                                                   |
            // +-------------------------------------------------------------------+
            rl.drawTexturePro(
                self.options.img.texture,
                .{
                    .x = @floatFromInt(x_px),
                    .y = @floatFromInt(y_px),
                    .height = @floatFromInt(self.options.char.get_full_height()),
                    .width = @floatFromInt(self.options.char.get_full_width()),
                },
                rect,
                .{ .x = 0, .y = 0 },
                0,
                rl.Color.red,
            );
        }
    }
};

const Window = struct {
    const WIDTH = 1400;
    const HEIGHT = 1080;
};

const BitmapFontSource = struct {
    path: []const u8,
    char_options: BitmapFont.CharOptions,

    fn get_path_ftype(self: *const BitmapFontSource, allocator: std.mem.Allocator) ![:0]u8 {
        const ftype_len: ?usize = blk: {
            var path_iter = std.mem.splitBackwardsScalar(
                u8,
                self.path,
                '.',
            );
            while (path_iter.next()) |split| {
                break :blk split.len;
            }
            break :blk null;
        };
        if (ftype_len == null) {
            @panic("failed to load font file type!");
        }
        const ftype_offset = self.path.len - 1 - ftype_len.?;
        const ftype = try std.mem.Allocator.dupeZ(
            allocator,
            u8,
            self.path[ftype_offset..][0 .. ftype_len.? + 1],
        );
        return ftype;
    }
};

pub fn main() !void {
    const sources = [_]BitmapFontSource{
        BitmapFontSource{
            .path = "minogram_6x10.png",
            .char_options = .{
                .h = 7,
                .w = 5,
                .pr = 1,
                .pl = 0,
                .pb = 2,
                .pt = 1,
                .sequence = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+-=()[]{}<>/*:#%!?.,'\"@&$",
            },
        },
        BitmapFontSource{
            .path = "thick_8x8.png",
            .char_options = .{
                .h = 7,
                .w = 7,
                .pr = 1,
                .pl = 0,
                .pb = 1,
                .pt = 0,
                .sequence = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+-=()[]{}<>/*:#%!?.,'\"@&$",
            },
        },
        BitmapFontSource{
            .path = "round_6x6.png",
            .char_options = .{
                .h = 5,
                .w = 5,
                .pr = 1,
                .pl = 0,
                .pb = 1,
                .pt = 0,
                .sequence = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+-=()[]{}<>/*:#%!?.,'\"@&$",
            },
        },
        BitmapFontSource{
            .path = "square_6x6.png",
            .char_options = .{
                .h = 5,
                .w = 5,
                .pr = 1,
                .pl = 0,
                .pb = 1,
                .pt = 0,
                .sequence = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+-=()[]{}<>/*:#%!?.,'\"@&$",
            },
        },
    };
    const source = sources[3];

    // Load font data in bytes + font filetype
    const font_data = assets.get(source.path);
    if (font_data == null) {
        @panic("failed to load font file!");
    }
    var ftype_buf: [16]u8 = undefined;
    var ftype_alloc = std.heap.FixedBufferAllocator.init(ftype_buf[0..]);
    const ftype = try source.get_path_ftype(ftype_alloc.allocator());

    // Window setup
    rl.initWindow(
        Window.WIDTH,
        Window.HEIGHT,
        "bitfont",
    );
    // Close window and OpenGL context
    defer rl.closeWindow();

    // Load font image + texture
    const font_img = rl.loadImageFromMemory(ftype, font_data.?) catch unreachable;
    defer font_img.unload();
    const font_texture = rl.loadTextureFromImage(font_img) catch |e| {
        std.debug.panic("error loading texture from image: {any}\n", .{e});
    };
    defer font_texture.unload();

    var chars: [4096]u8 = undefined;
    var font_allocator = std.heap.FixedBufferAllocator.init(chars[0..]);
    var font = BitmapFont.init(
        .{
            .img = .{
                .texture = font_texture,
                .w = @intCast(font_img.width),
                .h = @intCast(font_img.height),
            },
            .char = source.char_options,
        },
        font_allocator.allocator(),
    ) catch unreachable;
    defer font.deinit();

    const text = "BITMAP FONT RENDERER IN ZIG!";
    while (!rl.windowShouldClose()) {
        if (rl.isKeyPressed(.q)) {
            break;
        }
        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.black);

        font.draw_text(text, .{
            .x = (Window.WIDTH / 2) - 300,
            .y = (Window.HEIGHT / 2) - 200,
            .width = 600,
            .height = 200,
        });
    }
}
