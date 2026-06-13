"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key, db) {
        parser.push('MOVE');
        parser.pushKey(key);
        parser.push(db.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=MOVE.js.map