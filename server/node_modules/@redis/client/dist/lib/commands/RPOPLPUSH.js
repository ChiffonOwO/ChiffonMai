"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, source, destination) {
        parser.push('RPOPLPUSH');
        parser.pushKeys([source, destination]);
    },
    transformReply: undefined
};
//# sourceMappingURL=RPOPLPUSH.js.map