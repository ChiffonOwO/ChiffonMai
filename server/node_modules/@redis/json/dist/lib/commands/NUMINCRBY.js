"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, key, path, by) {
        parser.push('JSON.NUMINCRBY');
        parser.pushKey(key);
        parser.push(path, by.toString());
    },
    transformReply: {
        2: (reply) => {
            return JSON.parse(reply.toString());
        },
        3: undefined
    }
};
//# sourceMappingURL=NUMINCRBY.js.map