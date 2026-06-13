"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key, operations) {
        parser.push('BITFIELD_RO');
        parser.pushKey(key);
        for (const operation of operations) {
            parser.push('GET');
            parser.push(operation.encoding);
            parser.push(operation.offset.toString());
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=BITFIELD_RO.js.map