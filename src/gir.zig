const std = @import("std");
const c = @import("c.zig");
const xml = @import("xml.zig");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;

const ns = struct {
    pub const core = "http://www.gtk.org/introspection/core/1.0";
    pub const c = "http://www.gtk.org/introspection/c/1.0";
    pub const glib = "http://www.gtk.org/introspection/glib/1.0";
};

pub const Repository = struct {
    includes: []const Include,
    namespaces: []const Namespace,
    arena: ArenaAllocator,

    pub fn parseFile(allocator: Allocator, file: [:0]const u8) !Repository {
        const doc = xml.parseFile(file) catch return error.InvalidGir;
        defer c.xmlFreeDoc(doc);
        return try parseDoc(allocator, doc);
    }

    pub fn deinit(self: *Repository) void {
        self.arena.deinit();
    }

    fn parseDoc(a: Allocator, doc: *c.xmlDoc) !Repository {
        var arena = ArenaAllocator.init(a);
        const allocator = arena.allocator();
        const node: *c.xmlNode = c.xmlDocGetRootElement(doc) orelse return error.InvalidGir;

        var includes = ArrayList(Include).init(allocator);
        var namespaces = ArrayList(Namespace).init(allocator);

        var maybe_child: ?*c.xmlNode = node.children;
        while (maybe_child) |child| : (maybe_child = child.next) {
            if (xml.nodeIs(child, ns.core, "include")) {
                try includes.append(try parseInclude(allocator, doc, child));
            } else if (xml.nodeIs(child, ns.core, "namespace")) {
                try namespaces.append(try parseNamespace(allocator, doc, child));
            }
        }

        return .{
            .includes = includes.items,
            .namespaces = namespaces.items,
            .arena = arena,
        };
    }
};

pub const Include = struct {
    name: []const u8,
    version: []const u8,
};

fn parseInclude(allocator: Allocator, doc: *c.xmlDoc, node: *const c.xmlNode) !Include {
    var name: ?[]const u8 = null;
    var version: ?[]const u8 = null;

    var maybe_attr: ?*c.xmlAttr = node.properties;
    while (maybe_attr) |attr| : (maybe_attr = attr.next) {
        if (xml.attrIs(attr, null, "name")) {
            name = try xml.attrContent(allocator, doc, attr);
        } else if (xml.attrIs(attr, null, "version")) {
            version = try xml.attrContent(allocator, doc, attr);
        }
    }

    return .{
        .name = name orelse return error.InvalidGir,
        .version = version orelse return error.InvalidGir,
    };
}

pub const Namespace = struct {
    name: []const u8,
    version: []const u8,
    aliases: []const Alias,
    classes: []const Class,
    interfaces: []const Interface,
    records: []const Record,
    unions: []const Union,
    bit_fields: []const BitField,
    enums: []const Enum,
    functions: []const Function,
    callbacks: []const Callback,
    constants: []const Constant,
};

fn parseNamespace(allocator: Allocator, doc: *c.xmlDoc, node: *const c.xmlNode) !Namespace {
    var name: ?[]const u8 = null;
    var version: ?[]const u8 = null;
    var aliases = ArrayList(Alias).init(allocator);
    var classes = ArrayList(Class).init(allocator);
    var interfaces = ArrayList(Interface).init(allocator);
    var records = ArrayList(Record).init(allocator);
    var unions = ArrayList(Union).init(allocator);
    var bit_fields = ArrayList(BitField).init(allocator);
    var enums = ArrayList(Enum).init(allocator);
    var functions = ArrayList(Function).init(allocator);
    var callbacks = ArrayList(Callback).init(allocator);
    var constants = ArrayList(Constant).init(allocator);

    var maybe_attr: ?*c.xmlAttr = node.properties;
    while (maybe_attr) |attr| : (maybe_attr = attr.next) {
        if (xml.attrIs(attr, null, "name")) {
            name = try xml.attrContent(allocator, doc, attr);
        } else if (xml.attrIs(attr, null, "version")) {
            version = try xml.attrContent(allocator, doc, attr);
        }
    }

    if (name == null) {
        return error.InvalidGir;
    }

    var maybe_child: ?*c.xmlNode = node.children;
    while (maybe_child) |child| : (maybe_child = child.next) {
        if (xml.nodeIs(child, ns.core, "alias")) {
            try aliases.append(try parseAlias(allocator, doc, child, name.?));
        } else if (xml.nodeIs(child, ns.core, "class")) {
            try classes.append(try parseClass(allocator, doc, child, name.?));
        } else if (xml.nodeIs(child, ns.core, "interface")) {
            try interfaces.append(try parseInterface(allocator, doc, child, name.?));
        } else if (xml.nodeIs(child, ns.core, "record")) {
            try records.append(try parseRecord(allocator, doc, child, name.?));
        } else if (xml.nodeIs(child, ns.core, "union")) {
            try unions.append(try parseUnion(allocator, doc, child, name.?));
        } else if (xml.nodeIs(child, ns.core, "bitfield")) {
            try bit_fields.append(try parseBitField(allocator, doc, child, name.?));
        } else if (xml.nodeIs(child, ns.core, "enumeration")) {
            try enums.append(try parseEnum(allocator, doc, child, name.?));
        } else if (xml.nodeIs(child, ns.core, "function")) {
            try functions.append(try parseFunction(allocator, doc, child, name.?));
        } else if (xml.nodeIs(child, ns.core, "callback")) {
            try callbacks.append(try parseCallback(allocator, doc, child, name.?));
        } else if (xml.nodeIs(child, ns.core, "constant")) {
            try constants.append(try parseConstant(allocator, doc, child, name.?));
        }
    }

    return .{
        .name = name.?,
        .version = version orelse return error.InvalidGir,
        .aliases = aliases.items,
        .classes = classes.items,
        .interfaces = interfaces.items,
        .records = records.items,
        .unions = unions.items,
        .bit_fields = bit_fields.items,
        .enums = enums.items,
        .functions = functions.items,
        .callbacks = callbacks.items,
        .constants = constants.items,
    };
}

pub const Alias = struct {
    name: []const u8,
    type: Type,
};

fn parseAlias(allocator: Allocator, doc: *c.xmlDoc, node: *const c.xmlNode, current_ns: []const u8) !Alias {
    var name: ?[]const u8 = null;
    var @"type": ?Type = null;

    var maybe_attr: ?*c.xmlAttr = node.properties;
    while (maybe_attr) |attr| : (maybe_attr = attr.next) {
        if (xml.attrIs(attr, null, "name")) {
            name = try xml.attrContent(allocator, doc, attr);
        }
    }

    var maybe_child: ?*c.xmlNode = node.children;
    while (maybe_child) |child| : (maybe_child = child.next) {
        if (xml.nodeIs(child, ns.core, "type")) {
            @"type" = try parseType(allocator, doc, child, current_ns);
        }
    }

    return .{
        .name = name orelse return error.InvalidGir,
        .type = @"type" orelse return error.InvalidGir,
    };
}

pub const Class = struct {
    name: []const u8,
    parent: ?Name,
    fields: []const Field,
    functions: []const Function,
    constructors: []const Constructor,
    methods: []const Method,
    signals: []const Signal,
    constants: []const Constant,
};

fn parseClass(allocator: Allocator, doc: *c.xmlDoc, node: *const c.xmlNode, current_ns: []const u8) !Class {
    var name: ?[]const u8 = null;
    var parent: ?Name = null;
    var fields = ArrayList(Field).init(allocator);
    var functions = ArrayList(Function).init(allocator);
    var constructors = ArrayList(Constructor).init(allocator);
    var methods = ArrayList(Method).init(allocator);
    var signals = ArrayList(Signal).init(allocator);
    var constants = ArrayList(Constant).init(allocator);

    var maybe_attr: ?*c.xmlAttr = node.properties;
    while (maybe_attr) |attr| : (maybe_attr = attr.next) {
        if (xml.attrIs(attr, null, "name")) {
            name = try xml.attrContent(allocator, doc, attr);
        } else if (xml.attrIs(attr, null, "parent")) {
            parent = parseName(try xml.attrContent(allocator, doc, attr), current_ns);
        }
    }

    var maybe_child: ?*c.xmlNode = node.children;
    while (maybe_child) |child| : (maybe_child = child.next) {
        if (xml.nodeIs(child, ns.core, "field")) {
            try fields.append(try parseField(allocator, doc, child, current_ns));
        } else if (xml.nodeIs(child, ns.core, "function")) {
            try functions.append(try parseFunction(allocator, doc, child, current_ns));
        } else if (xml.nodeIs(child, ns.core, "constructor")) {
            try constructors.append(try parseConstructor(allocator, doc, child, current_ns));
        } else if (xml.nodeIs(child, ns.core, "method")) {
            try methods.append(try parseMethod(allocator, doc, child, current_ns));
        } else if (xml.nodeIs(child, ns.glib, "signal")) {
            try signals.append(try parseSignal(allocator, doc, child, current_ns));
        } else if (xml.nodeIs(child, ns.core, "constant")) {
            try constants.append(try parseConstant(allocator, doc, child, current_ns));
        }
    }

    return .{
        .name = name orelse return error.InvalidGir,
        .parent = parent,
        .fields = fields.items,
        .functions = functions.items,
        .constructors = constructors.items,
        .methods = methods.items,
        .signals = signals.items,
        .constants = constants.items,
    };
}

pub const Interface = struct {
    name: []const u8,
    functions: []const Function,
    constructors: []const Constructor,
    methods: []const Method,
    signals: []const Signal,
    constants: []const Constant,
};

fn parseInterface(allocator: Allocator, doc: *c.xmlDoc, node: *const c.xmlNode, current_ns: []const u8) !Interface {
    var name: ?[]const u8 = null;
    var functions = ArrayList(Function).init(allocator);
    var constructors = ArrayList(Constructor).init(allocator);
    var methods = ArrayList(Method).init(allocator);
    var signals = ArrayList(Signal).init(allocator);
    var constants = ArrayList(Constant).init(allocator);

    var maybe_attr: ?*c.xmlAttr = node.properties;
    while (maybe_attr) |attr| : (maybe_attr = attr.next) {
        if (xml.attrIs(attr, null, "name")) {
            name = try xml.attrContent(allocator, doc, attr);
        }
    }

    var maybe_child: ?*c.xmlNode = node.children;
    while (maybe_child) |child| : (maybe_child = child.next) {
        if (xml.nodeIs(child, ns.core, "function")) {
            try functions.append(try parseFunction(allocator, doc, child, current_ns));
        } else if (xml.nodeIs(child, ns.core, "constructor")) {
            try constructors.append(try parseConstructor(allocator, doc, child, current_ns));
        } else if (xml.nodeIs(child, ns.core, "method")) {
            try methods.append(try parseMethod(allocator, doc, child, current_ns));
        } else if (xml.nodeIs(child, ns.glib, "signal")) {
            try signals.append(try parseSignal(allocator, doc, child, current_ns));
        } else if (xml.nodeIs(child, ns.core, "constant")) {
            try constants.append(try parseConstant(allocator, doc, child, current_ns));
        }
    }

    return .{
        .name = name orelse return error.InvalidGir,
        .functions = functions.items,
        .constructors = constructors.items,
        .methods = methods.items,
        .signals = signals.items,
        .constants = constants.items,
    };
}

pub const Record = struct {
    name: []const u8,
    fields: []const Field,
    functions: []const Function,
    constructors: []const Constructor,
    methods: []const Method,
};

fn parseRecord(allocator: Allocator, doc: *c.xmlDoc, node: *const c.xmlNode, current_ns: []const u8) !Record {
    var name: ?[]const u8 = null;
    var fields = ArrayList(Field).init(allocator);
    var functions = ArrayList(Function).init(allocator);
    var constructors = ArrayList(Constructor).init(allocator);
    var methods = ArrayList(Method).init(allocator);

    var maybe_attr: ?*c.xmlAttr = node.properties;
    while (maybe_attr) |attr| : (maybe_attr = attr.next) {
        if (xml.attrIs(attr, null, "name")) {
            name = try xml.attrContent(allocator, doc, attr);
        }
    }

    var maybe_child: ?*c.xmlNode = node.children;
    while (maybe_child) |child| : (maybe_child = child.next) {
        if (xml.nodeIs(child, ns.core, "field")) {
            try fields.append(try parseField(allocator, doc, child, current_ns));
        } else if (xml.nodeIs(child, ns.core, "function")) {
            try functions.append(try parseFunction(allocator, doc, child, current_ns));
        } else if (xml.nodeIs(child, ns.core, "constructor")) {
            try constructors.append(try parseConstructor(allocator, doc, child, current_ns));
        } else if (xml.nodeIs(child, ns.core, "method")) {
            try methods.append(try parseMethod(allocator, doc, child, current_ns));
        }
    }

    return .{
        .name = name orelse return error.InvalidGir,
        .fields = fields.items,
        .functions = functions.items,
        .constructors = constructors.items,
        .methods = methods.items,
    };
}

pub const Union = struct {
    name: []const u8,
    fields: []const Field,
    functions: []const Function,
    constructors: []const Constructor,
    methods: []const Method,
};

fn parseUnion(allocator: Allocator, doc: *c.xmlDoc, node: *const c.xmlNode, current_ns: []const u8) !Union {
    var name: ?[]const u8 = null;
    var fields = ArrayList(Field).init(allocator);
    var functions = ArrayList(Function).init(allocator);
    var constructors = ArrayList(Constructor).init(allocator);
    var methods = ArrayList(Method).init(allocator);

    var maybe_attr: ?*c.xmlAttr = node.properties;
    while (maybe_attr) |attr| : (maybe_attr = attr.next) {
        if (xml.attrIs(attr, null, "name")) {
            name = try xml.attrContent(allocator, doc, attr);
        }
    }

    var maybe_child: ?*c.xmlNode = node.children;
    while (maybe_child) |child| : (maybe_child = child.next) {
        if (xml.nodeIs(child, ns.core, "field")) {
            try fields.append(try parseField(allocator, doc, child, current_ns));
        } else if (xml.nodeIs(child, ns.core, "function")) {
            try functions.append(try parseFunction(allocator, doc, child, current_ns));
        } else if (xml.nodeIs(child, ns.core, "constructor")) {
            try constructors.append(try parseConstructor(allocator, doc, child, current_ns));
        } else if (xml.nodeIs(child, ns.core, "method")) {
            try methods.append(try parseMethod(allocator, doc, child, current_ns));
        }
    }

    return .{
        .name = name orelse return error.InvalidGir,
        .fields = fields.items,
        .functions = functions.items,
        .constructors = constructors.items,
        .methods = methods.items,
    };
}

pub const Field = struct {
    name: []const u8,
    type: FieldType,
};

pub const FieldType = union(enum) {
    simple: Type,
    array: ArrayType,
    callback: Callback,
};

fn parseField(allocator: Allocator, doc: *c.xmlDoc, node: *const c.xmlNode, current_ns: []const u8) !Field {
    var name: ?[]const u8 = null;
    var @"type": ?FieldType = null;

    var maybe_attr: ?*c.xmlAttr = node.properties;
    while (maybe_attr) |attr| : (maybe_attr = attr.next) {
        if (xml.attrIs(attr, null, "name")) {
            name = try xml.attrContent(allocator, doc, attr);
        }
    }

    var maybe_child: ?*c.xmlNode = node.children;
    while (maybe_child) |child| : (maybe_child = child.next) {
        if (xml.nodeIs(child, ns.core, "type")) {
            @"type" = .{ .simple = try parseType(allocator, doc, child, current_ns) };
        } else if (xml.nodeIs(child, ns.core, "array")) {
            @"type" = .{ .array = try parseArrayType(allocator, doc, child, current_ns) };
        } else if (xml.nodeIs(child, ns.core, "callback")) {
            @"type" = .{ .callback = try parseCallback(allocator, doc, child, current_ns) };
        }
    }

    return .{
        .name = name orelse return error.InvalidGir,
        .type = @"type" orelse return error.InvalidGir,
    };
}

pub const BitField = struct {
    name: []const u8,
    members: []const Member,
    functions: []const Function,
};

fn parseBitField(allocator: Allocator, doc: *c.xmlDoc, node: *const c.xmlNode, current_ns: []const u8) !BitField {
    var name: ?[]const u8 = null;
    var members = ArrayList(Member).init(allocator);
    var functions = ArrayList(Function).init(allocator);

    var maybe_attr: ?*c.xmlAttr = node.properties;
    while (maybe_attr) |attr| : (maybe_attr = attr.next) {
        if (xml.attrIs(attr, null, "name")) {
            name = try xml.attrContent(allocator, doc, attr);
        }
    }

    var maybe_child: ?*c.xmlNode = node.children;
    while (maybe_child) |child| : (maybe_child = child.next) {
        if (xml.nodeIs(child, ns.core, "member")) {
            try members.append(try parseMember(allocator, doc, child));
        } else if (xml.nodeIs(child, ns.core, "function")) {
            try functions.append(try parseFunction(allocator, doc, child, current_ns));
        }
    }

    return .{
        .name = name orelse return error.InvalidGir,
        .members = members.items,
        .functions = functions.items,
    };
}

pub const Enum = struct {
    name: []const u8,
    members: []const Member,
    functions: []const Function,
};

fn parseEnum(allocator: Allocator, doc: *c.xmlDoc, node: *const c.xmlNode, current_ns: []const u8) !Enum {
    var name: ?[]const u8 = null;
    var members = ArrayList(Member).init(allocator);
    var functions = ArrayList(Function).init(allocator);

    var maybe_attr: ?*c.xmlAttr = node.properties;
    while (maybe_attr) |attr| : (maybe_attr = attr.next) {
        if (xml.attrIs(attr, null, "name")) {
            name = try xml.attrContent(allocator, doc, attr);
        }
    }

    var maybe_child: ?*c.xmlNode = node.children;
    while (maybe_child) |child| : (maybe_child = child.next) {
        if (xml.nodeIs(child, ns.core, "member")) {
            try members.append(try parseMember(allocator, doc, child));
        } else if (xml.nodeIs(child, ns.core, "function")) {
            try functions.append(try parseFunction(allocator, doc, child, current_ns));
        }
    }

    return .{
        .name = name orelse return error.InvalidGir,
        .members = members.items,
        .functions = functions.items,
    };
}

pub const Member = struct {
    name: []const u8,
    value: i64,
};

fn parseMember(allocator: Allocator, doc: *c.xmlDoc, node: *const c.xmlNode) !Member {
    var name: ?[]const u8 = null;
    var value: ?i64 = null;

    var maybe_attr: ?*c.xmlAttr = node.properties;
    while (maybe_attr) |attr| : (maybe_attr = attr.next) {
        if (xml.attrIs(attr, null, "name")) {
            name = try xml.attrContent(allocator, doc, attr);
        } else if (xml.attrIs(attr, null, "value")) {
            value = fmt.parseInt(i64, try xml.attrContent(allocator, doc, attr), 10) catch return error.InvalidGir;
        }
    }

    return .{
        .name = name orelse return error.InvalidGir,
        .value = value orelse return error.InvalidGir,
    };
}

pub const Function = struct {
    name: []const u8,
    c_identifier: []const u8,
    moved_to: ?[]const u8,
    parameters: []const Parameter,
    return_value: ReturnValue,
};

fn parseFunction(allocator: Allocator, doc: *c.xmlDoc, node: *const c.xmlNode, current_ns: []const u8) !Function {
    var name: ?[]const u8 = null;
    var c_identifier: ?[]const u8 = null;
    var moved_to: ?[]const u8 = null;
    var parameters = ArrayList(Parameter).init(allocator);
    var return_value: ?ReturnValue = null;

    var maybe_attr: ?*c.xmlAttr = node.properties;
    while (maybe_attr) |attr| : (maybe_attr = attr.next) {
        if (xml.attrIs(attr, null, "name")) {
            name = try xml.attrContent(allocator, doc, attr);
        } else if (xml.attrIs(attr, ns.c, "identifier")) {
            c_identifier = try xml.attrContent(allocator, doc, attr);
        } else if (xml.attrIs(attr, null, "moved-to")) {
            moved_to = try xml.attrContent(allocator, doc, attr);
        }
    }

    var maybe_child: ?*c.xmlNode = node.children;
    while (maybe_child) |child| : (maybe_child = child.next) {
        if (xml.nodeIs(child, ns.core, "parameters")) {
            try parseParameters(allocator, &parameters, doc, child, current_ns);
        } else if (xml.nodeIs(child, ns.core, "return-value")) {
            return_value = try parseReturnValue(allocator, doc, child, current_ns);
        }
    }

    return .{
        .name = name orelse return error.InvalidGir,
        .c_identifier = c_identifier orelse return error.InvalidGir,
        .moved_to = moved_to,
        .parameters = parameters.items,
        .return_value = return_value orelse return error.InvalidGir,
    };
}

pub const Constructor = struct {
    name: []const u8,
    c_identifier: []const u8,
    moved_to: ?[]const u8,
    parameters: []const Parameter,
    return_value: ReturnValue,
};

fn parseConstructor(allocator: Allocator, doc: *c.xmlDoc, node: *const c.xmlNode, current_ns: []const u8) !Constructor {
    // Constructors currently have the same structure as functions
    const function = try parseFunction(allocator, doc, node, current_ns);
    return .{
        .name = function.name,
        .c_identifier = function.c_identifier,
        .moved_to = function.moved_to,
        .parameters = function.parameters,
        .return_value = function.return_value,
    };
}

pub const Method = struct {
    name: []const u8,
    c_identifier: []const u8,
    moved_to: ?[]const u8,
    parameters: []const Parameter,
    return_value: ReturnValue,
};

fn parseMethod(allocator: Allocator, doc: *c.xmlDoc, node: *const c.xmlNode, current_ns: []const u8) !Method {
    // Methods currently have the same structure as functions
    const function = try parseFunction(allocator, doc, node, current_ns);
    return .{
        .name = function.name,
        .c_identifier = function.c_identifier,
        .moved_to = function.moved_to,
        .parameters = function.parameters,
        .return_value = function.return_value,
    };
}

pub const Signal = struct {
    name: []const u8,
    parameters: []const Parameter,
    return_value: ReturnValue,
};

fn parseSignal(allocator: Allocator, doc: *c.xmlDoc, node: *const c.xmlNode, current_ns: []const u8) !Signal {
    var name: ?[]const u8 = null;
    var parameters = ArrayList(Parameter).init(allocator);
    var return_value: ?ReturnValue = null;

    var maybe_attr: ?*c.xmlAttr = node.properties;
    while (maybe_attr) |attr| : (maybe_attr = attr.next) {
        if (xml.attrIs(attr, null, "name")) {
            name = try xml.attrContent(allocator, doc, attr);
        }
    }

    var maybe_child: ?*c.xmlNode = node.children;
    while (maybe_child) |child| : (maybe_child = child.next) {
        if (xml.nodeIs(child, ns.core, "parameters")) {
            try parseParameters(allocator, &parameters, doc, child, current_ns);
        } else if (xml.nodeIs(child, ns.core, "return-value")) {
            return_value = try parseReturnValue(allocator, doc, child, current_ns);
        }
    }

    return .{
        .name = name orelse return error.InvalidGir,
        .parameters = parameters.items,
        .return_value = return_value orelse return error.InvalidGir,
    };
}

pub const Constant = struct {
    name: []const u8,
    value: []const u8,
    type: AnyType,
};

fn parseConstant(allocator: Allocator, doc: *c.xmlDoc, node: *const c.xmlNode, current_ns: []const u8) !Constant {
    var name: ?[]const u8 = null;
    var value: ?[]const u8 = null;
    var @"type": ?AnyType = null;

    var maybe_attr: ?*c.xmlAttr = node.properties;
    while (maybe_attr) |attr| : (maybe_attr = attr.next) {
        if (xml.attrIs(attr, null, "name")) {
            name = try xml.attrContent(allocator, doc, attr);
        } else if (xml.attrIs(attr, null, "value")) {
            value = try xml.attrContent(allocator, doc, attr);
        }
    }

    var maybe_child: ?*c.xmlNode = node.children;
    while (maybe_child) |child| : (maybe_child = child.next) {
        if (xml.nodeIs(child, ns.core, "type")) {
            @"type" = .{ .simple = try parseType(allocator, doc, child, current_ns) };
        } else if (xml.nodeIs(child, ns.core, "array")) {
            @"type" = .{ .array = try parseArrayType(allocator, doc, child, current_ns) };
        }
    }

    return .{
        .name = name orelse return error.InvalidGir,
        .value = value orelse return error.InvalidGir,
        .type = @"type" orelse return error.InvalidGir,
    };
}

pub const AnyType = union(enum) {
    simple: Type,
    array: ArrayType,
};

pub const Type = struct {
    name: ?Name,
    c_type: ?[]const u8,
};

fn parseType(allocator: Allocator, doc: *c.xmlDoc, node: *const c.xmlNode, current_ns: []const u8) !Type {
    var name: ?Name = null;
    var c_type: ?[]const u8 = null;

    var maybe_attr: ?*c.xmlAttr = node.properties;
    while (maybe_attr) |attr| : (maybe_attr = attr.next) {
        if (xml.attrIs(attr, null, "name")) {
            name = parseName(try xml.attrContent(allocator, doc, attr), current_ns);
        } else if (xml.attrIs(attr, ns.c, "type")) {
            c_type = try xml.attrContent(allocator, doc, attr);
        }
    }

    return .{
        .name = name,
        .c_type = c_type,
    };
}

pub const ArrayType = struct {
    element: *const AnyType,
    fixed_size: ?u32,
};

fn parseArrayType(allocator: Allocator, doc: *c.xmlDoc, node: *const c.xmlNode, current_ns: []const u8) !ArrayType {
    var element: ?AnyType = null;
    var fixed_size: ?[]const u8 = null;

    var maybe_attr: ?*c.xmlAttr = node.properties;
    while (maybe_attr) |attr| : (maybe_attr = attr.next) {
        if (xml.attrIs(attr, null, "fixed-size")) {
            fixed_size = try xml.attrContent(allocator, doc, attr);
        }
    }

    var maybe_child: ?*c.xmlNode = node.children;
    while (maybe_child) |child| : (maybe_child = child.next) {
        if (xml.nodeIs(child, ns.core, "type")) {
            element = .{ .simple = try parseType(allocator, doc, child, current_ns) };
        } else if (xml.nodeIs(child, ns.core, "array")) {
            element = .{ .array = try parseArrayType(allocator, doc, child, current_ns) };
        }
    }

    return .{
        .element = &(try allocator.dupe(AnyType, &.{element orelse return error.InvalidGir}))[0],
        .fixed_size = size: {
            if (fixed_size) |size| {
                break :size fmt.parseInt(u32, size, 10) catch return error.InvalidGir;
            } else {
                break :size null;
            }
        },
    };
}

pub const Callback = struct {
    name: []const u8,
    parameters: []const Parameter,
    return_value: ReturnValue,
};

fn parseCallback(allocator: Allocator, doc: *c.xmlDoc, node: *const c.xmlNode, current_ns: []const u8) !Callback {
    var name: ?[]const u8 = null;
    var parameters = ArrayList(Parameter).init(allocator);
    var return_value: ?ReturnValue = null;

    var maybe_attr: ?*c.xmlAttr = node.properties;
    while (maybe_attr) |attr| : (maybe_attr = attr.next) {
        if (xml.attrIs(attr, null, "name")) {
            name = try xml.attrContent(allocator, doc, attr);
        }
    }

    var maybe_child: ?*c.xmlNode = node.children;
    while (maybe_child) |child| : (maybe_child = child.next) {
        if (xml.nodeIs(child, ns.core, "parameters")) {
            try parseParameters(allocator, &parameters, doc, child, current_ns);
        } else if (xml.nodeIs(child, ns.core, "return-value")) {
            return_value = try parseReturnValue(allocator, doc, child, current_ns);
        }
    }

    return .{
        .name = name orelse return error.InvalidGir,
        .parameters = parameters.items,
        .return_value = return_value orelse return error.InvalidGir,
    };
}

pub const Parameter = struct {
    name: []const u8,
    nullable: bool,
    type: ParameterType,
    instance: bool,
};

pub const ParameterType = union(enum) {
    simple: Type,
    array: ArrayType,
    varargs,
};

fn parseParameters(allocator: Allocator, parameters: *ArrayList(Parameter), doc: *c.xmlDoc, node: *const c.xmlNode, current_ns: []const u8) !void {
    var maybe_param: ?*c.xmlNode = node.children;
    while (maybe_param) |param| : (maybe_param = param.next) {
        if (xml.nodeIs(param, ns.core, "parameter") or xml.nodeIs(param, ns.core, "instance-parameter")) {
            try parameters.append(try parseParameter(allocator, doc, param, current_ns, xml.nodeIs(param, ns.core, "instance-parameter")));
        }
    }
}

fn parseParameter(allocator: Allocator, doc: *c.xmlDoc, node: *const c.xmlNode, current_ns: []const u8, instance: bool) !Parameter {
    var name: ?[]const u8 = null;
    var nullable = false;
    var @"type": ?ParameterType = null;

    var maybe_attr: ?*c.xmlAttr = node.properties;
    while (maybe_attr) |attr| : (maybe_attr = attr.next) {
        if (xml.attrIs(attr, null, "name")) {
            name = try xml.attrContent(allocator, doc, attr);
        } else if (xml.attrIs(attr, null, "nullable")) {
            nullable = mem.eql(u8, try xml.attrContent(allocator, doc, attr), "1");
        }
    }

    var maybe_child: ?*c.xmlNode = node.children;
    while (maybe_child) |child| : (maybe_child = child.next) {
        if (xml.nodeIs(child, ns.core, "type")) {
            @"type" = .{ .simple = try parseType(allocator, doc, child, current_ns) };
        } else if (xml.nodeIs(child, ns.core, "array")) {
            @"type" = .{ .array = try parseArrayType(allocator, doc, child, current_ns) };
        } else if (xml.nodeIs(child, ns.core, "varargs")) {
            @"type" = .{ .varargs = {} };
        }
    }

    return .{
        .name = name orelse return error.InvalidGir,
        .nullable = nullable,
        .type = @"type" orelse return error.InvalidGir,
        .instance = instance,
    };
}

pub const ReturnValue = struct {
    nullable: bool,
    type: AnyType,
};

fn parseReturnValue(allocator: Allocator, doc: *c.xmlDoc, node: *const c.xmlNode, current_ns: []const u8) !ReturnValue {
    var nullable = false;
    var @"type": ?AnyType = null;

    var maybe_attr: ?*c.xmlAttr = node.properties;
    while (maybe_attr) |attr| : (maybe_attr = attr.next) {
        if (xml.attrIs(attr, null, "nullable")) {
            nullable = mem.eql(u8, try xml.attrContent(allocator, doc, attr), "1");
        }
    }

    var maybe_child: ?*c.xmlNode = node.children;
    while (maybe_child) |child| : (maybe_child = child.next) {
        if (xml.nodeIs(child, ns.core, "type")) {
            @"type" = .{ .simple = try parseType(allocator, doc, child, current_ns) };
        } else if (xml.nodeIs(child, ns.core, "array")) {
            @"type" = .{ .array = try parseArrayType(allocator, doc, child, current_ns) };
        }
    }

    return .{
        .nullable = nullable,
        .type = @"type" orelse return error.InvalidGir,
    };
}

pub const Name = struct {
    ns: ?[]const u8,
    local: []const u8,
};

fn parseName(raw: []const u8, current_ns: []const u8) Name {
    const sep_pos = std.mem.indexOfScalar(u8, raw, '.');
    if (sep_pos) |pos| {
        return .{
            .ns = raw[0..pos],
            .local = raw[pos + 1 .. raw.len],
        };
    } else {
        // There isn't really any way to distinguish between a name in the same
        // namespace and a non-namespaced name: based on convention, though, we can
        // use the heuristic of looking for an uppercase starting letter
        return .{
            .ns = if (raw.len > 0 and std.ascii.isUpper(raw[0])) current_ns else null,
            .local = raw,
        };
    }
}
