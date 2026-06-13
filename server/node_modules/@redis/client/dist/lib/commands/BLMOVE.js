"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, source, destination, sourceSide, destinationSide, timeout) {
        parser.push('BLMOVE');
        parser.pushKeys([source, destination]);
        parser.push(sourceSide, destinationSide, timeout.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=BLMOVE.js.map