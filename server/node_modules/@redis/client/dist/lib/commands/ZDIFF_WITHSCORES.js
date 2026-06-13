"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const generic_transformers_1 = require("./generic-transformers");
const ZDIFF_1 = __importDefault(require("./ZDIFF"));
exports.default = {
    IS_READ_ONLY: ZDIFF_1.default.IS_READ_ONLY,
    parseCommand(parser, keys) {
        ZDIFF_1.default.parseCommand(parser, keys);
        parser.push('WITHSCORES');
    },
    transformReply: generic_transformers_1.transformSortedSetReply
};
//# sourceMappingURL=ZDIFF_WITHSCORES.js.map