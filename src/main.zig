const std = @import("std");

/// epsilon is the maximum difference between floats before we consider them different values, i.e. if
/// abs(x - y) <= epsilon then we consider them the same value.
const epsilon = 0.005;

/// compositeChars are the characters that a unit must have in to trigger a check to see if it is a composite;
const compositeChars = "p/";

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
            .bandiwdth => .{ .composite = .{ .num = .bits, .den = .seconds } },
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
        return switch (self) {
            .bits, .bytes, .kilobytes, .kibibytes, .megabytes, .mebibytes, .giagabytes, .gibibytes, .terabytes, .tebibytes => .data_size,
            .nanoseconds, .microseconds, .miliseconds, .seconds, .minutes, .hours, .days, .weeks, .years => .time,
        };
    }

    /// toSIMult returns the multiplier one has to apply to turn a value from the given unit to the SI unit for that
    /// metric.
    pub fn toSIMult(self: BaseUnit) f64 {
        return switch (self) {
            .bits => 8,
            .bytes => 1,
            .kilobytes => 1e3,
            .kibibytes => 1024,
            .megabytes => 1e6,
            .mebibytes => 1024 * 1024,
            .giagabytes => 1e9,
            .gibibytes => 1024 * 1024 * 1024,
            .terabytes => 1e12,
            .tebibytes => 1024 * 1024 * 1024 * 1024,

            .nanoseconds => 1.0 / 1e9,
            .microseconds => 1.0 / 1e6,
            .miliseconds => 1.0 / 1e3,
            .seconds => 1.0,
            .minutes => 60,
            .hours => 60 * 60,
            .days => 60 * 60 * 24,
            .weeks => 60 * 60 * 24 * 7,
            .years => 60 * 60 * 24 * 365,
        };
    }

    /// toSI convers n in the unit into the SI unit for that metric.
    pub fn toSI(self: BaseUnit, n: f64) f64 {
        return n * self.toSIMult();
    }

    /// fromSI converts n in the SI unit for the metric into the given unit.
    pub fn fromSI(self: BaseUnit, n: f64) f64 {
        return n / self.toSIMult();
    }

    /// toString returns a canonical string for the given base unit, suitable for user feedback.
    pub fn toString(self: BaseUnit) []const u8 {
        return baseUnitNames[@enumToInt(self)][0];
    }
};

/// Unit is a unit of an amount. It can either by a simple unit (basic) or a composite one (e.g Mb/s).
const Unit = union(enum) {
    basic: BaseUnit,
    composite: struct { num: BaseUnit, den: BaseUnit },

    /// metric returns the metric that the Unit measures.
    pub fn metric(self: Unit) Metric {
        return switch (self) {
            .basic => |b| b.metric(),
            else => unreachable,
        };
    }

    /// toString turns the unit into a user readable string.
    pub fn toString(self: Unit) []const u8 {
        return switch (self) {
            .basic => |b| b.toString(),
            else => unreachable,
        };
    }

    /// toSI convers n in the unit into the SI unit for that metric.
    pub fn toSI(self: Unit, n: f64) f64 {
        return switch (self) {
            .basic => |b| b.toSI(n),
            else => unreachable,
        };
    }

    /// fromSI converts n in the SI unit for the metric into the given unit.
    pub fn fromSI(self: Unit, n: f64) f64 {
        return switch (self) {
            .basic => |b| b.fromSI(n),
            else => unreachable,
        };
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
        if (!std.ascii.isDigit(c)) {
            if (i == 0) return error.AmountAndUnitRequired;

            return .{ .amount = s[0..i], .unit = s[i..] };
        }
    }

    return error.AmountAndUnitRequired;
}

/// parseBaseUnit takes a string and turns it into a BaseUnit.
///
/// NOTE: This is done by matching the string against the values in baseUnitNames.
fn parseBaseUnit(s: []const u8) !BaseUnit {
    for (baseUnitNames, 0..) |names, i| {
        for (names) |name| {
            if (std.mem.eql(u8, s, name)) return try std.meta.intToEnum(BaseUnit, i);
        }
    }

    return error.UnitNotFound;
}

/// splitComposite splits s into the numerator and deominator strings of the unit - e.g. mb/s returns "mb" and "s".
fn splitComposite(s: []const u8) !struct { num: []const u8, den: []const u8 } {
    if (s.len <= 1) return error.NotComposite;

    for (s, 0..) |c, i| {
        if (i == s.len - 1) return error.NotComposite;

        if (std.mem.indexOf(u8, compositeChars, &.{c}) != null) return .{ .num = s[0..i], .den = s[i + 1 ..] };
    }

    return error.NotComposite;
}

/// parseUnit takes a string and turns it into a Unit.
fn parseUnit(s: []const u8) !Unit {
    const composite = b: {
        inline for (compositeChars) |c| {
            if (std.mem.indexOf(u8, s, &.{c}) != null) break :b true;
        }

        break :b false;
    };

    if (!composite) return Unit{ .basic = try parseBaseUnit(s) };

    const comp = splitComposite(s) catch {
        return Unit{ .basic = try parseBaseUnit(s) };
    };

    return .{ .composite = .{ .num = try parseBaseUnit(comp.num), .den = try parseBaseUnit(comp.den) } };
}

/// convert converts src_num (in src_units) to an amount in target_unit's.
fn convert(src_num: f64, src_unit: Unit, target_unit: Unit) !f64 {
    if (target_unit.metric() != src_unit.metric()) return error.MismatchedMetrics;
    return target_unit.fromSI(src_unit.toSI(src_num));
}

/// run is the real main of the program - it takes the command line arguments and tries to convert them.
fn run(args: [][:0]const u8) !void {
    if (args.len != 3) return error.NotEnoughArgs;

    const src = try splitAmountAndUnit(args[1]);

    const src_num = std.fmt.parseFloat(f64, src.amount) catch return error.CouldNotParseAmount;
    const src_unit = try parseUnit(src.unit);

    const target_unit = try parseUnit(args[2]);

    const res_num = try convert(src_num, src_unit, target_unit);

    if (std.math.approxEqAbs(f64, res_num, std.math.round(res_num), epsilon)) {
        std.debug.print("{} {s}\n", .{ @floatToInt(u64, res_num), target_unit.toString() });
        return;
    }

    std.debug.print("{d:.2} {s}\n", .{ res_num, target_unit.toString() });
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
            error.MismatchedMetrics => std.debug.print("Both units must be of the same metric (e.g. data size, time)\n", .{}),
            else => std.debug.print("Unknown error: {}\n", .{e}),
        }

        std.os.exit(1);
    };
}

const testing = std.testing;

fn convertBasic(n: f64, from: BaseUnit, to: BaseUnit) !f64 {
    return convert(n, .{ .basic = from }, .{ .basic = to });
}

fn testSplit(s: []const u8, num: []const u8, unit: []const u8) !void {
    const res = try splitAmountAndUnit(s);

    try testing.expectEqualStrings(num, res.amount);
    try testing.expectEqualStrings(unit, res.unit);
}

fn testSplitComposite(s: []const u8, num: []const u8, den: []const u8) !void {
    const comp = try splitComposite(s);

    try testing.expectEqualStrings(num, comp.num);
    try testing.expectEqualStrings(den, comp.den);
}

test "split" {
    try testSplit("147bytes", "147", "bytes");
    try testSplit("147mib", "147", "mib");
}

test "split amount and unit required" {
    try testing.expectError(error.AmountAndUnitRequired, splitAmountAndUnit("147"));
    try testing.expectError(error.AmountAndUnitRequired, splitAmountAndUnit("bytes"));
}

test "convert basic" {
    try testing.expectApproxEqAbs(@as(f64, 147), try convertBasic(147 * 1024, .bytes, .kibibytes), epsilon);
    try testing.expectApproxEqAbs(@as(f64, 147), try convertBasic(147 * 1024, .kibibytes, .mebibytes), epsilon);

    try testing.expectApproxEqAbs(@as(f64, 147), try convertBasic(147 * 24 * 60 * 60, .seconds, .days), epsilon);
    try testing.expectApproxEqAbs(@as(f64, 2.45), try convertBasic(147 * 1e9, .nanoseconds, .minutes), epsilon);
}

test "convert mismatched metrics" {
    try testing.expectError(error.MismatchedMetrics, convertBasic(1, .bytes, .seconds));
    try testing.expectError(error.MismatchedMetrics, convertBasic(1, .nanoseconds, .terabytes));
}

test "split composite" {
    try testSplitComposite("B/s", "B", "s");
    try testSplitComposite("MiB/min", "MiB", "min");
    try testSplitComposite("Bps", "B", "s");
    try testSplitComposite("MiBpmin", "MiB", "min");
}

test "parse unit" {
    try testing.expectEqual(Unit{ .composite = .{ .num = .bytes, .den = .seconds } }, try parseUnit("B/s"));
    try testing.expectEqual(Unit{ .composite = .{ .num = .bytes, .den = .seconds } }, try parseUnit("Bps"));
}
