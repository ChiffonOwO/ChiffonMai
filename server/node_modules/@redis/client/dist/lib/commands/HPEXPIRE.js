"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key, fields, ms, mode) {
        parser.push('HPEXPIRE');
        parser.pushKey(key);
        parser.push(ms.toString());
        if (mode) {
            parser.push(mode);
        }
        parser.push('FIELDS');
        parser.pushVariadicWithLength(fields);
    },
    transformReply: undefined
};
//# sourceMappingURL=HPEXPIRE.js.map