"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const GEORADIUS_WITH_1 = require("./GEORADIUS_WITH");
const GEORADIUS_WITH_2 = __importDefault(require("./GEORADIUS_WITH"));
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(...args) {
        args[0].push('GEORADIUS_RO');
        (0, GEORADIUS_WITH_1.parseGeoRadiusWithArguments)(...args);
    },
    transformReply: GEORADIUS_WITH_2.default.transformReply
};
//# sourceMappingURL=GEORADIUS_RO_WITH.js.map