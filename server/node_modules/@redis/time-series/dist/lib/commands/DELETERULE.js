"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, sourceKey, destinationKey) {
        parser.push('TS.DELETERULE');
        parser.pushKeys([sourceKey, destinationKey]);
    },
    transformReply: undefined
};
//# sourceMappingURL=DELETERULE.js.map