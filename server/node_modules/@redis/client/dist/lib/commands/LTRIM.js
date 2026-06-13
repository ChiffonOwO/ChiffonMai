"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key, start, stop) {
        parser.push('LTRIM');
        parser.pushKey(key);
        parser.push(start.toString(), stop.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=LTRIM.js.map