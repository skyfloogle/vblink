const std = @import("std");
const simargs = @import("simargs");

var chk: i32 = 0;
fn writeBlock(writer: std.net.Stream.Writer, bytes: []const u8) std.net.Stream.WriteError!usize {
    std.log.debug("writing {} bytes", .{bytes.len});
    try writer.writeInt(i32, @intCast(bytes.len), .little);
    try writer.writeAll(bytes);
    for (bytes) |value| {
        chk += value;
    }
    std.log.debug("checksum {}", .{chk});
    return bytes.len;
}
const DataWriter = std.io.GenericWriter(std.net.Stream.Writer, std.net.Stream.WriteError, writeBlock);

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // read args
    var opt = try simargs.parse(allocator, struct {
        address: []const u8,
        file: []const u8,
        help: bool = false,
        pub const __messages__ = .{ .file = "File to send", .address = "IP address to send to" };
    }, "[file]", null);
    defer opt.deinit();

    // load file
    const file = try std.fs.cwd().openFile(opt.args.file, .{ .mode = .read_only });
    defer file.close();
    const fileSize: i32 = @intCast(try file.getEndPos());
    const basename = std.fs.path.basename(opt.args.file);

    // connect to 3ds
    const address = try std.net.Ip4Address.resolveIp(opt.args.address, 22082);
    const socket = try std.net.tcpConnectToAddress(.{ .in = address });
    defer socket.close();

    // write header info
    const netWriter = socket.writer();
    try netWriter.writeInt(i32, @intCast(basename.len), .little);
    try netWriter.writeAll(basename);
    try netWriter.writeInt(i32, fileSize, .little);
    const netReader = socket.reader();
    var response = try netReader.readInt(i32, .little);
    if (response != 0) {
        return switch (response) {
            -1 => error.BadFilenameLength,
            -2 => error.BadFilename,
            -3 => error.BadRomSize,
            else => error.Other,
        };
    }

    std.log.info("Sending {s}, {} bytes", .{ opt.args.file, fileSize });

    // write compressed data
    var dataWriter = std.io.BufferedWriter(16384, DataWriter){ .unbuffered_writer = .{ .context = netWriter } };
    try std.compress.flate.deflate.compress(.zlib, file.reader(), dataWriter.writer(), .{});
    try dataWriter.flush();

    response = try netReader.readInt(i32, .little);
    if (response != 0) {
        return error.FailedToSend;
    }
}
