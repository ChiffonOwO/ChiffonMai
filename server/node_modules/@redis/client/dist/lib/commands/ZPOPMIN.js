"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const ZPOPMAX_1 = __importDefault(require("./ZPOPMAX"));
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, key) {
        parser.push('ZPOPMIN');
        parser.pushKey(key);
    },
    transformReply: ZPOPMAX_1.default.transformReply
};
//# sourceMappingURL=ZPOPMIN.js.map