"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const GEOSEARCH_1 = require("./GEOSEARCH");
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, destination, source, from, by, options) {
        parser.push('GEOSEARCHSTORE');
        if (destination !== undefined) {
            parser.pushKey(destination);
        }
        (0, GEOSEARCH_1.parseGeoSearchArguments)(parser, source, from, by, options);
        if (options?.STOREDIST) {
            parser.push('STOREDIST');
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=GEOSEARCHSTORE.js.map