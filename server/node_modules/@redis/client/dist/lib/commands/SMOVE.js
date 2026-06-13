"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, source, destination, member) {
        parser.push('SMOVE');
        parser.pushKeys([source, destination]);
        parser.push(member);
    },
    transformReply: undefined
};
//# sourceMappingURL=SMOVE.js.map