"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, path) {
        parser.push('JSON.RESP');
        parser.pushKey(key);
        if (path !== undefined) {
            parser.push(path);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=RESP.js.map