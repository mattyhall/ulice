const std = @import("std");
const simargs = @import("simargs");

/// epsilon is the maximum difference between floats before we consider them different values, i.e. if
/// abs(x - y) <= epsilon then we consider them the same value.
const epsilon = 0.005;

/// compositeChars are the characters that a unit must have in to trigger a check to see if it is a composite;
const compositeChars = "p/";

/// AmountAndUnit packages an amount and a unit together.
const AmountAndUnit = struct { a: f64, u: Unit };

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
    gigabytes,
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

    auto,

    /// count returns the number of variants in BaseUnit.
    pub fn count() usize {
        return @enumToInt(BaseUnit.auto) + 1;
    }

    /// metric returns the metric that a BaseUnit measures. E.g. bytes measures data size.
    pub fn metric(self: BaseUnit) Metric {
        return switch (self) {
            .bits, .bytes, .kilobytes, .kibibytes, .megabytes, .mebibytes, .gigabytes, .gibibytes, .terabytes, .tebibytes => .data_size,
            .nanoseconds, .microseconds, .miliseconds, .seconds, .minutes, .hours, .days, .weeks, .years => .time,
            .auto => unreachable,
        };
    }

    /// toSIMult returns the multiplier one has to apply to turn a value from the given unit to the SI unit for that
    /// metric.
    pub fn toSIMult(self: BaseUnit) f64 {
        return switch (self) {
            .bits => 1.0 / 8.0,
            .bytes => 1,
            .kilobytes => 1e3,
            .kibibytes => 1024,
            .megabytes => 1e6,
            .mebibytes => 1024 * 1024,
            .gigabytes => 1e9,
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

            .auto => unreachable,
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
    pub fn metric(self: Unit) ?Metric {
        return switch (self) {
            .basic => |b| b.metric(),
            .composite => |c| {
                if (c.num.metric() == .data_size and c.den.metric() == .time) return .bandwidth;
                return null;
            },
        };
    }

    /// toString turns the unit into a user readable string.
    pub fn toString(self: Unit, a: std.mem.Allocator) ![]const u8 {
        return switch (self) {
            .basic => |b| try a.dupe(u8, b.toString()),
            .composite => |c| try std.fmt.allocPrint(a, "{s}/{s}", .{ c.num.toString(), c.den.toString() }),
        };
    }

    /// toSI convers n in the unit into the SI unit for that metric.
    pub fn toSI(self: Unit, n: f64) f64 {
        return switch (self) {
            .basic => |b| b.toSI(n),
            .composite => |c| c.num.toSI(n) / c.den.toSI(1),
        };
    }

    /// fromSI converts n in the SI unit for the metric into the given unit.
    pub fn fromSI(self: Unit, n: f64) f64 {
        return switch (self) {
            .basic => |b| b.fromSI(n),
            .composite => |c| c.num.fromSI(n) * c.den.toSI(1),
        };
    }
};

/// baseUnitNames contains a row for every BaseUnit (in order of the tag's declariation) and the row contains synonyms
/// for the unit.
const baseUnitNames = b: {
    var res: [BaseUnit.count()][]const []const u8 = undefined;

    res[@enumToInt(BaseUnit.bits)] = &[_][]const u8{ "bits", "bit", "bi", "b", "" };
    res[@enumToInt(BaseUnit.bytes)] = &[_][]const u8{ "bytes", "byte", "B", "" };
    res[@enumToInt(BaseUnit.kilobytes)] = &[_][]const u8{ "KB", "kilobytes", "kb", "" };
    res[@enumToInt(BaseUnit.kibibytes)] = &[_][]const u8{ "KiB", "kibibytes", "kib", "" };
    res[@enumToInt(BaseUnit.megabytes)] = &[_][]const u8{ "MB", "megabytes", "mb", "" };
    res[@enumToInt(BaseUnit.mebibytes)] = &[_][]const u8{ "MiB", "mebibytes", "mib", "" };
    res[@enumToInt(BaseUnit.gigabytes)] = &[_][]const u8{ "GB", "gigabytes", "gb", "" };
    res[@enumToInt(BaseUnit.gibibytes)] = &[_][]const u8{ "GiB", "gibibytes", "gib", "" };
    res[@enumToInt(BaseUnit.terabytes)] = &[_][]const u8{ "TB", "terabytes", "tb", "" };
    res[@enumToInt(BaseUnit.tebibytes)] = &[_][]const u8{ "TiB", "tibibytes", "tib", "" };

    res[@enumToInt(BaseUnit.nanoseconds)] = &[_][]const u8{ "ns", "nanoseconds", "nanosecond", "" };
    res[@enumToInt(BaseUnit.microseconds)] = &[_][]const u8{ "us", "microseconds", "microsecond", "" };
    res[@enumToInt(BaseUnit.miliseconds)] = &[_][]const u8{ "ms", "miliseconds", "milisecond", "" };
    res[@enumToInt(BaseUnit.seconds)] = &[_][]const u8{ "s", "seconds", "second", "sec", "secs", "" };
    res[@enumToInt(BaseUnit.minutes)] = &[_][]const u8{ "mins", "minutes", "min", "" };
    res[@enumToInt(BaseUnit.hours)] = &[_][]const u8{ "hr", "hours", "hour", "hrs", "h", "" };
    res[@enumToInt(BaseUnit.days)] = &[_][]const u8{ "days", "day", "d", "ds", "" };
    res[@enumToInt(BaseUnit.weeks)] = &[_][]const u8{ "wk", "weeks", "week", "wks", "w", "" };
    res[@enumToInt(BaseUnit.years)] = &[_][]const u8{ "yr", "years", "year", "yrs", "y", "" };

    res[@enumToInt(BaseUnit.auto)] = &[_][]const u8{ "auto", "?" };

    break :b res;
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

/// parseAmountAndUnit takes an amount string and a unit string and parses both.
fn parseAmountAndUnit(amount: []const u8, unit: []const u8) !AmountAndUnit {
    return AmountAndUnit{
        .a = std.fmt.parseFloat(f64, amount) catch return error.CouldNotParseAmount,
        .u = try parseUnit(unit),
    };
}

/// convertAuto converts num into the largest possible unit in the metric that unit has, and assigns that unit to
/// res_unit.
fn convertAuto(num: f64, unit: Unit, res_unit: *Unit) !f64 {
    var target_unit: ?Unit = null;

    for (0..@enumToInt(BaseUnit.auto)) |i| {
        var u = Unit{ .basic = @intToEnum(BaseUnit, i) };
        if (u.metric() != unit.metric()) continue;

        if (target_unit == null) target_unit = u;

        const val = try convert(num, unit, &u);

        if (val < 1) break;

        if (val >= 1.0) target_unit = u;
    }

    res_unit.* = target_unit orelse unreachable;

    return convert(num, unit, res_unit);
}

/// convert converts src_num (in src_units) to an amount in target_unit's.
///
/// NOTE: If target_unit is auto then the highest possible unit for src_unit's metric is chosen and target_unit is set
/// to it.
fn convert(src_num: f64, src_unit: Unit, target_unit: *Unit) !f64 {
    if (target_unit.* == .basic and target_unit.basic == .auto) return convertAuto(src_num, src_unit, target_unit);

    if (target_unit.metric() != src_unit.metric()) return error.MismatchedMetrics;

    return target_unit.fromSI(src_unit.toSI(src_num));
}

/// runUnitConversion converts the first argument into the unit specified by the second argument, and outputs it with
/// precision decimal places.
fn runUnitConversion(a: std.mem.Allocator, args: [][]const u8, precision: u4) !void {
    if (args.len != 2) return error.NotEnoughArgs;

    const s = try splitAmountAndUnit(args[0]);
    const src = try parseAmountAndUnit(s.amount, s.unit);

    var target_unit = try parseUnit(args[1]);
    const res_num = try convert(src.a, src.u, &target_unit);

    std.debug.print("{d:.[2]} {s}\n", .{ res_num, try target_unit.toString(a), precision });
}

/// runTimeCalculator takes three arguments - speed, distance and time. Two of which need an amount and the other is a
// unit that we solve for.
fn runTimeCalculator(a: std.mem.Allocator, args: [][]const u8, precision: u4) !void {
    if (args.len != 3) return error.NotEnoughArgs;

    const f = try splitAmountAndUnit(args[0]);
    const s = try splitAmountAndUnit(args[1]);
    const fst = try parseAmountAndUnit(f.amount, f.unit);
    const snd = try parseAmountAndUnit(s.amount, s.unit);

    var target_unit = try parseUnit(args[2]);

    var speed: ?AmountAndUnit = null;
    var data_size: ?AmountAndUnit = null;
    var time: ?AmountAndUnit = null;

    var metrics: [3]Metric = undefined;

    for (&[_]Unit{ fst.u, snd.u, target_unit }, 0..) |u, i| {
        const m = u.metric() orelse return error.UnknownMetric;
        metrics[i] = m;
        switch (m) {
            .time => time = if (i == 0) fst else if (i == 1) snd else null,
            .data_size => data_size = if (i == 0) fst else if (i == 1) snd else null,
            .bandwidth => speed = if (i == 0) fst else if (i == 1) snd else null,
        }
    }

    for (&[_]Metric{ .time, .bandwidth, .data_size }) |m|
        if (std.mem.indexOf(Metric, &metrics, &.{m}) == null) return error.WrongUnits;

    // metrics[2] is that of target_unit, i.e. switch on what we are solving for.
    const res = switch (metrics[2]) {
        .bandwidth => target_unit.fromSI(data_size.?.u.toSI(data_size.?.a) / time.?.u.toSI(time.?.a)),
        .time => target_unit.fromSI(speed.?.u.toSI(speed.?.a) / data_size.?.u.toSI(data_size.?.a)),
        .data_size => target_unit.fromSI(speed.?.u.toSI(speed.?.a) * time.?.u.toSI(time.?.a)),
    };
    std.debug.print("{d:.[2]} {s}\n", .{ res, try target_unit.toString(a), precision });
}

/// run is the real main of the program - it takes the command line arguments and tries to convert them.
fn run() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var a = arena.allocator();

    var opt = try simargs.parse(a, struct {
        precision: u4 = 2,
        time: bool = false,
        help: bool = false,

        pub const __shorts__ = .{
            .precision = .p,
            .time = .t,
            .help = .h,
        };
    }, "from [other] to");

    if (opt.args.help) {
        const stdout = std.io.getStdOut();
        try opt.print_help(stdout.writer());
        std.os.exit(0);
    }

    if (opt.args.time)
        try runTimeCalculator(a, opt.positional_args.items, opt.args.precision)
    else
        try runUnitConversion(a, opt.positional_args.items, opt.args.precision);
}

pub fn main() !void {
    run() catch |e| {
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
    var to_unit = .{ .basic = to };
    return convert(n, .{ .basic = from }, &to_unit);
}

fn testConvertAuto(n: f64, from: BaseUnit, res_num: f64, res_unit: BaseUnit) !void {
    var to = Unit{ .basic = .auto };

    const res = try convert(n, .{ .basic = from }, &to);

    try testing.expectEqual(res_unit, to.basic);
    try testing.expectApproxEqAbs(res_num, res, epsilon);
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

test "convert auto" {
    try testConvertAuto(147 * 1024, .bytes, 147, .kibibytes);

    try testConvertAuto(7, .bits, 7, .bits);

    try testConvertAuto(24 * 60 * 60, .seconds, 1, .days);
}

test "convert composite" {
    var to: Unit = .{ .composite = .{ .num = .kibibytes, .den = .seconds } };
    try testing.expectApproxEqAbs(
        @as(f64, 147),
        try convert(147 * 1024, .{ .composite = .{ .num = .bytes, .den = .seconds } }, &to),
        epsilon,
    );

    to = .{ .composite = .{ .num = .bytes, .den = .seconds } };
    try testing.expectApproxEqAbs(
        @as(f64, 147 * 1024),
        try convert(147, .{ .composite = .{ .num = .kibibytes, .den = .seconds } }, &to),
        epsilon,
    );

    to = .{ .composite = .{ .num = .kibibytes, .den = .minutes } };
    try testing.expectApproxEqAbs(
        @as(f64, 147),
        try convert((147.0 * 1024.0) / 60.0, .{ .composite = .{ .num = .bytes, .den = .seconds } }, &to),
        epsilon,
    );

    to = .{ .composite = .{ .num = .bytes, .den = .seconds } };
    try testing.expectApproxEqAbs(
        @as(f64, (147.0 * 1024.0) / 60.0),
        try convert(147, .{ .composite = .{ .num = .kibibytes, .den = .minutes } }, &to),
        epsilon,
    );

    to = .{ .composite = .{ .num = .kibibytes, .den = .minutes } };
    try testing.expectApproxEqAbs(
        @as(f64, 147 * 60),
        try convert(147 * 1024, .{ .composite = .{ .num = .bytes, .den = .seconds } }, &to),
        epsilon,
    );
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
    try testing.expectEqual(Unit{ .basic = .auto }, try parseUnit("auto"));

    try testing.expectEqual(Unit{ .composite = .{ .num = .bytes, .den = .seconds } }, try parseUnit("B/s"));
    try testing.expectEqual(Unit{ .composite = .{ .num = .bytes, .den = .seconds } }, try parseUnit("Bps"));
}
