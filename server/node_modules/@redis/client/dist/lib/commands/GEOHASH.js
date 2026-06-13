"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key, member) {
        parser.push('GEOHASH');
        parser.pushKey(key);
        parser.pushVariadic(member);
    },
    transformReply: undefined
};
//# sourceMappingURL=GEOHASH.js.map