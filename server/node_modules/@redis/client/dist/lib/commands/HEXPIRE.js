"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.HASH_EXPIRATION = void 0;
exports.HASH_EXPIRATION = {
    /** The field does not exist */
    FIELD_NOT_EXISTS: -2,
    /** Specified NX | XX | GT | LT condition not met */
    CONDITION_NOT_MET: 0,
    /** Expiration time was set or updated */
    UPDATED: 1,
    /** Field deleted because the specified expiration time is in the past */
    DELETED: 2
};
exports.default = {
    parseCommand(parser, key, fields, seconds, mode) {
        parser.push('HEXPIRE');
        parser.pushKey(key);
        parser.push(seconds.toString());
        if (mode) {
            parser.push(mode);
        }
        parser.push('FIELDS');
        parser.pushVariadicWithLength(fields);
    },
    transformReply: undefined
};
//# sourceMappingURL=HEXPIRE.js.map