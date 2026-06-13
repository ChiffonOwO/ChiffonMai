"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, key, group, id, options) {
        parser.push('XGROUP', 'SETID');
        parser.pushKey(key);
        parser.push(group, id);
        if (options?.ENTRIESREAD) {
            parser.push('ENTRIESREAD', options.ENTRIESREAD.toString());
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=XGROUP_SETID.js.map