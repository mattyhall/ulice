const std = @import("std");

/// epsilon is the maximum difference between floats before we consider them different values, i.e. if
/// abs(x - y) <= epsilon then we consider them the same value.
const epsilon = 0.005;

/// Metric is something that can be measured, e.g. time, file size etc.
const Metric = enum {
    data_size,
    time,
    bandwidth,

    /// si is the SI Unit for this metric. E.g. for time it is seconds, data size is bytes.
    fn si(self: Metric) Unit {
        switch (self) {
            .data_size => .bytes,
            .time => .seconds,
            .bandiwdth => .{ .composite = .{ .quot = .bits, .div = .seconds } },
        }
    }
};

/// BaseUnit is an enum of units.
const BaseUnit = enum {
    bits,
    bytes,
    kilobytes,
    kibibytes,
    megabytes,
    mebibytes,
    giagabytes,
    gibibytes,
    terabytes,
    tebibytes,

    nanoseconds,
    microseconds,
    miliseconds,
    seconds,
    minutes,
    hours,
    days,
    weeks,
    years,

    /// metric returns the metric that a BaseUnit measures. E.g. bytes measures data size.
    pub fn metric(self: BaseUnit) Metric {
        switch (self) {
            .bits, .bytes, .kilobytes, .kibibytes, .megabytes, .mebibytes, .giagabytes, .gibibytes, .terabytes, .tebibytes => .data_size,
            .nanoseconds, .microseconds, .miliseconds, .seconds, .minutes, .hours, .days, .weeks, .years => .time,
        }
    }

    /// toString returns a canonical string for the given base unit, suitable for user feedback.
    pub fn toString(self: BaseUnit) []const u8 {
        return baseUnitNames[@enumToInt(self)][0];
    }
};

/// Unit is a unit of an amount. It can either by a simple unit (basic) or a composite one (e.g Mb/s).
const Unit = union(enum) {
    basic: BaseUnit,
    composite: struct { quot: BaseUnit, div: BaseUnit },

    /// metric returns the metric that the Unit measures.
    pub fn metric(self: Unit) Metric {
        switch (self) {
            .basic => |b| b.metric(),
            else => unreachable,
        }
    }
};

/// baseUnitNames contains a row for every BaseUnit (in order of the tag's declariation) and the row contains synonyms
/// for the unit.
const baseUnitNames = [_][]const []const u8{
    &[_][]const u8{ "bits", "bit", "bi", "b", "" },
    &[_][]const u8{ "bytes", "byte", "B", "" },
    &[_][]const u8{ "KB", "kilobytes", "kb", "" },
    &[_][]const u8{ "KiB", "kibibytes", "kib", "" },
    &[_][]const u8{ "MB", "megabytes", "mb", "" },
    &[_][]const u8{ "MiB", "mebibytes", "mib", "" },
    &[_][]const u8{ "GB", "gigabytes", "gb", "" },
    &[_][]const u8{ "GiB", "gibibytes", "gib", "" },
    &[_][]const u8{ "TB", "terabytes", "tb", "" },
    &[_][]const u8{ "TiB", "tibibytes", "tib", "" },

    &[_][]const u8{ "ns", "nanoseconds", "nanosecond", "" },
    &[_][]const u8{ "us", "microseconds", "microsecond", "" },
    &[_][]const u8{ "ms", "miliseconds", "milisecond", "" },
    &[_][]const u8{ "s", "seconds", "second", "sec", "secs", "" },
    &[_][]const u8{ "days", "day", "d", "ds", "" },
    &[_][]const u8{ "hr", "hours", "hour", "hrs", "h", "" },
    &[_][]const u8{ "wk", "weeks", "week", "wks", "w", "" },
    &[_][]const u8{ "yr", "years", "year", "yrs", "y", "" },
};

/// splitAmountAndUnit takes a string like "7bits" and splits it into two substrings - the amount and the unit.
fn splitAmountAndUnit(s: []const u8) !struct { amount: []const u8, unit: []const u8 } {
    if (s.len <= 1) return error.AmountAndUnitRequired;

    for (s, 0..) |c, i| {
        if (!std.ascii.isDigit(c)) return .{ .amount = s[0..i], .unit = s[i..] };
    }

    return error.AmountAndUnitRequired;
}

/// parseUnit takes a string and turns it into a BaseUnit.
///
/// NOTE: This is done by matching the string against the values in baseUnitNames.
fn parseUnit(s: []const u8) !BaseUnit {
    for (baseUnitNames, 0..) |names, i| {
        for (names) |name| {
            if (std.mem.eql(u8, s, name)) return try std.meta.intToEnum(BaseUnit, i);
        }
    }

    return error.UnitNotFound;
}

/// run is the real main of the program - it takes the command line arguments and tries to convert them.
fn run(args: [][:0]const u8) !void {
    if (args.len != 3) return error.NotEnoughArgs;

    const src = try splitAmountAndUnit(args[1]);

    const src_num = std.fmt.parseFloat(f64, src.amount) catch return error.CouldNotParseAmount;
    const unit = try parseUnit(src.unit);

    if (std.math.approxEqAbs(f64, src_num, std.math.round(src_num), epsilon)) {
        std.debug.print("{} {s}\n", .{ @floatToInt(u64, src_num), unit.toString() });
        return;
    }

    std.debug.print("{d:.2} {s}\n", .{ src_num, unit.toString() });
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var a = arena.allocator();

    var args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);

    run(args) catch |e| {
        switch (e) {
            error.NotEnoughArgs => std.debug.print(
                \\You must pass two arguments to ulice: <number><source unit> <target unit>, e.g
                \\ulice 1024MiB GiB
                \\
            , .{}),
            error.AmountAndUnitRequired => std.debug.print(
                "An amount and a unit - with no space - are required, e.g. 7bits\n",
                .{},
            ),
            error.CouldNotParseAmount => std.debug.print("Amount must be a valid float\n", .{}),
            error.UnitNotFound => std.debug.print("Unrecognised unit\n", .{}),
            else => std.debug.print("Unknown error: {}\n", .{e}),
        }

        std.os.exit(1);
    };
}
