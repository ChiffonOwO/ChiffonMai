"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, key, path, start, stop) {
        parser.push('JSON.ARRTRIM');
        parser.pushKey(key);
        parser.push(path, start.toString(), stop.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=ARRTRIM.js.map