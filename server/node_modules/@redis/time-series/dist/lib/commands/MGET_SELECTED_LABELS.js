"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const MGET_1 = require("./MGET");
const helpers_1 = require("./helpers");
const MGET_WITHLABELS_1 = require("./MGET_WITHLABELS");
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, filter, selectedLabels, options) {
        parser.push('TS.MGET');
        (0, MGET_1.parseLatestArgument)(parser, options?.LATEST);
        (0, helpers_1.parseSelectedLabelsArguments)(parser, selectedLabels);
        (0, MGET_1.parseFilterArgument)(parser, filter);
    },
    transformReply: (0, MGET_WITHLABELS_1.createTransformMGetLabelsReply)(),
};
//# sourceMappingURL=MGET_SELECTED_LABELS.js.map