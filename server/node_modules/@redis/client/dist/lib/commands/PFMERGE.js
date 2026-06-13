"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, destination, sources) {
        parser.push('PFMERGE');
        parser.pushKey(destination);
        if (sources) {
            parser.pushKeys(sources);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=PFMERGE.js.map