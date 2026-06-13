"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, key, group, id, options) {
        parser.push('XGROUP', 'CREATE');
        parser.pushKey(key);
        parser.push(group, id);
        if (options?.MKSTREAM) {
            parser.push('MKSTREAM');
        }
        if (options?.ENTRIESREAD) {
            parser.push('ENTRIESREAD', options.ENTRIESREAD.toString());
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=XGROUP_CREATE.js.map