"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, source, destination, sourceSide, destinationSide) {
        parser.push('LMOVE');
        parser.pushKeys([source, destination]);
        parser.push(sourceSide, destinationSide);
    },
    transformReply: undefined
};
//# sourceMappingURL=LMOVE.js.map