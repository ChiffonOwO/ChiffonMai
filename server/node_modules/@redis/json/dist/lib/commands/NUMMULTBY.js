"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const NUMINCRBY_1 = __importDefault(require("./NUMINCRBY"));
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, key, path, by) {
        parser.push('JSON.NUMMULTBY');
        parser.pushKey(key);
        parser.push(path, by.toString());
    },
    transformReply: NUMINCRBY_1.default.transformReply
};
//# sourceMappingURL=NUMMULTBY.js.map