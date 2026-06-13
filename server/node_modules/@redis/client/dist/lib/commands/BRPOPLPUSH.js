"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, source, destination, timeout) {
        parser.push('BRPOPLPUSH');
        parser.pushKeys([source, destination]);
        parser.push(timeout.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=BRPOPLPUSH.js.map