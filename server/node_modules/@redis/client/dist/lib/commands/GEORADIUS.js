"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.parseGeoRadiusArguments = void 0;
const GEOSEARCH_1 = require("./GEOSEARCH");
function parseGeoRadiusArguments(parser, key, from, radius, unit, options) {
    parser.pushKey(key);
    parser.push(from.longitude.toString(), from.latitude.toString(), radius.toString(), unit);
    (0, GEOSEARCH_1.parseGeoSearchOptions)(parser, options);
}
exports.parseGeoRadiusArguments = parseGeoRadiusArguments;
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(...args) {
        args[0].push('GEORADIUS');
        return parseGeoRadiusArguments(...args);
    },
    transformReply: undefined
};
//# sourceMappingURL=GEORADIUS.js.map