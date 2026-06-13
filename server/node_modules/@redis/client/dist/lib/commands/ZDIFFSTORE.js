"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, destination, inputKeys) {
        parser.push('ZDIFFSTORE');
        parser.pushKey(destination);
        parser.pushKeysLength(inputKeys);
    },
    transformReply: undefined
};
//# sourceMappingURL=ZDIFFSTORE.js.map