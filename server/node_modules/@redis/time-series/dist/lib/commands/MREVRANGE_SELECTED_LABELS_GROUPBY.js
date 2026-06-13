"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
const MRANGE_SELECTED_LABELS_GROUPBY_1 = __importStar(require("./MRANGE_SELECTED_LABELS_GROUPBY"));
exports.default = {
    IS_READ_ONLY: MRANGE_SELECTED_LABELS_GROUPBY_1.default.IS_READ_ONLY,
    parseCommand: (0, MRANGE_SELECTED_LABELS_GROUPBY_1.createMRangeSelectedLabelsGroupByTransformArguments)('TS.MREVRANGE'),
    transformReply: MRANGE_SELECTED_LABELS_GROUPBY_1.default.transformReply,
};
//# sourceMappingURL=MREVRANGE_SELECTED_LABELS_GROUPBY.js.map