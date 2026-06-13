"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.parseClientAttributes = exports.noopFunction = exports.isRedirectionError = exports.getErrorInfo = void 0;
const types_1 = require("../types");
var error_util_1 = require("./error.util");
Object.defineProperty(exports, "getErrorInfo", { enumerable: true, get: function () { return error_util_1.getErrorInfo; } });
Object.defineProperty(exports, "isRedirectionError", { enumerable: true, get: function () { return error_util_1.isRedirectionError; } });
function noopFunction() { }
exports.noopFunction = noopFunction;
const parseClientAttributes = (clientAttributes) => {
    return {
        ...(clientAttributes?.db === undefined
            ? {}
            : {
                [types_1.OTEL_ATTRIBUTES.dbNamespace]: clientAttributes.db.toString(),
            }),
        ...(clientAttributes?.host && {
            [types_1.OTEL_ATTRIBUTES.serverAddress]: clientAttributes.host,
        }),
        ...(clientAttributes?.port && {
            [types_1.OTEL_ATTRIBUTES.serverPort]: clientAttributes.port.toString(),
        }),
        ...(clientAttributes?.clientId && {
            [types_1.OTEL_ATTRIBUTES.dbClientConnectionPoolName]: clientAttributes.clientId,
        }),
        ...(clientAttributes?.parentId && {
            [types_1.OTEL_ATTRIBUTES.redisClientParentId]: clientAttributes.parentId,
        }),
    };
};
exports.parseClientAttributes = parseClientAttributes;
//# sourceMappingURL=index.js.map