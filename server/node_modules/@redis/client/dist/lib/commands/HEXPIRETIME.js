"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.HASH_EXPIRATION_TIME = void 0;
exports.HASH_EXPIRATION_TIME = {
    /** The field does not exist */
    FIELD_NOT_EXISTS: -2,
    /** The field exists but has no associated expire */
    NO_EXPIRATION: -1,
};
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, fields) {
        parser.push('HEXPIRETIME');
        parser.pushKey(key);
        parser.push('FIELDS');
        parser.pushVariadicWithLength(fields);
    },
    transformReply: undefined
};
//# sourceMappingURL=HEXPIRETIME.js.map