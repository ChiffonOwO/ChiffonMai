"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.isRedirectionError = exports.getErrorInfo = void 0;
const types_1 = require("../types");
const errors_1 = require("../../errors");
// Regex pattern for extracting Redis error prefixes
const REDIS_ERROR_PREFIX_REGEX = /^([A-Z][A-Z0-9_]*)\s/;
/**
 * Extracts the Redis status code (error prefix) from an ErrorReply.
 *
 * Redis errors follow the format "PREFIX message" where PREFIX is an uppercase
 * word like ERR, WRONGTYPE, MOVED, ASK, CLUSTERDOWN, NOSCRIPT, etc.
 *
 * @param error - The error to extract the status code from
 * @returns The error prefix (e.g., "ERR", "WRONGTYPE") or undefined if not an ErrorReply
 *          or if the message doesn't match the expected format
 */
function extractRedisStatusCode(error) {
    if (!(error instanceof errors_1.ErrorReply)) {
        return undefined;
    }
    // Redis error messages start with an uppercase prefix followed by a space
    // Examples: "ERR unknown command", "WRONGTYPE Operation against a key...", "MOVED 3999 127.0.0.1:6381"
    const match = REDIS_ERROR_PREFIX_REGEX.exec(error.message);
    return match?.[1];
}
// Network error codes that indicate connection/network issues
const NETWORK_ERROR_CODES = new Set([
    'ECONNREFUSED',
    'ECONNRESET',
    'ETIMEDOUT',
    'ENOTFOUND',
    'ENETUNREACH',
    'EHOSTUNREACH',
    'EPIPE',
    'ECONNABORTED',
    'EAI_AGAIN',
]);
// TLS-related error codes
const TLS_ERROR_CODES = new Set([
    'UNABLE_TO_VERIFY_LEAF_SIGNATURE',
    'CERT_HAS_EXPIRED',
    'DEPTH_ZERO_SELF_SIGNED_CERT',
    'SELF_SIGNED_CERT_IN_CHAIN',
    'ERR_TLS_CERT_ALTNAME_INVALID',
    'CERT_SIGNATURE_FAILURE',
    'ERR_SSL_WRONG_VERSION_NUMBER',
]);
// Redis error prefixes that indicate auth errors
const AUTH_ERROR_PREFIXES = new Set([
    'NOAUTH',
    'WRONGPASS',
    'NOPERM',
]);
// Redis error prefixes that indicate server errors
const SERVER_ERROR_PREFIXES = new Set([
    'ASK',
    'BUSY',
    'BUSYGROUP',
    'BUSYKEY',
    'CLUSTERDOWN',
    'CROSSSLOT',
    'DENIED',
    'ERR',
    'EXECABORT',
    'INPROG',
    'INVALIDOBJ',
    'IOERR',
    'LOADING',
    'MASTERDOWN',
    'MISCONF',
    'MOVED',
    'NOAUTH',
    'NOGROUP',
    'NOGOODSLAVE',
    'NOMASTERLINK',
    'NOPERM',
    'NOPROTO',
    'NOQUORUM',
    'NOREPLICAS',
    'NOSCRIPT',
    'NOTBUSY',
    'NOTREADY',
    'OOM',
    'READONLY',
    'TRYAGAIN',
    'UNBLOCKED',
    'UNKILLABLE',
    'WRONGPASS',
    'WRONGTYPE',
]);
/**
 * Checks if an error is a known node-redis network error type.
 */
function isNodeRedisNetworkError(error) {
    return (error instanceof errors_1.ConnectionTimeoutError ||
        error instanceof errors_1.SocketTimeoutError ||
        error instanceof errors_1.SocketClosedUnexpectedlyError ||
        error instanceof errors_1.SocketTimeoutDuringMaintenanceError ||
        error instanceof errors_1.CommandTimeoutDuringMaintenanceError);
}
/**
 * Checks if a message contains TLS-related keywords.
 */
function isTlsErrorMessage(message) {
    const lowerMessage = message.toLowerCase();
    return (lowerMessage.includes('certificate') ||
        lowerMessage.includes('handshake') ||
        lowerMessage.includes('ssl') ||
        lowerMessage.includes('tls'));
}
/**
 * Categorizes an Error based on its Redis error prefix.
 * Returns undefined if the error is not an ErrorReply or doesn't have a known prefix.
 */
function categorizeRedisError(error) {
    const prefix = extractRedisStatusCode(error);
    if (!prefix) {
        return undefined;
    }
    if (AUTH_ERROR_PREFIXES.has(prefix)) {
        return types_1.ERROR_CATEGORY.AUTH;
    }
    if (SERVER_ERROR_PREFIXES.has(prefix)) {
        return types_1.ERROR_CATEGORY.SERVER;
    }
    return undefined;
}
/**
 * Determines the error category for an Error.
 */
function getCategory(error) {
    // Check for known node-redis error types first
    if (isNodeRedisNetworkError(error)) {
        return types_1.ERROR_CATEGORY.NETWORK;
    }
    // Check error.code for network/TLS errors (Node.js system errors)
    const errorCode = error.code;
    if (errorCode) {
        if (NETWORK_ERROR_CODES.has(errorCode)) {
            return types_1.ERROR_CATEGORY.NETWORK;
        }
        if (TLS_ERROR_CODES.has(errorCode)) {
            return types_1.ERROR_CATEGORY.TLS;
        }
    }
    // Check for TLS errors by message patterns
    if (isTlsErrorMessage(error.message)) {
        return types_1.ERROR_CATEGORY.TLS;
    }
    // Check Redis error prefixes
    const category = categorizeRedisError(error);
    if (category) {
        return category;
    }
    return types_1.ERROR_CATEGORY.OTHER;
}
/**
 * Analyzes an error and extracts OpenTelemetry-relevant information.
 *
 * Returns an object with:
 * - errorType: The error class name (maps to error.type)
 * - category: network, tls, auth, server, or other (maps to redis.client.errors.category)
 * - statusCode: Redis error prefix like "ERR", "MOVED" (maps to db.response.status_code)
 *
 * Note: `redis.client.errors.internal` is NOT included here because it depends on
 * context (whether the error was handled internally or surfaced to the user),
 * which must be determined by the caller.
 *
 * @param error - The error to analyze (accepts unknown for safety)
 * @returns ErrorInfo object with all relevant error information
 */
function getErrorInfo(error) {
    // Handle non-Error values
    if (!(error instanceof Error)) {
        return {
            errorType: 'unknown',
            category: types_1.ERROR_CATEGORY.OTHER,
            statusCode: undefined,
        };
    }
    // Handle ReconnectStrategyError by unwrapping to original error
    const actualError = error instanceof errors_1.ReconnectStrategyError
        ? error.originalError
        : error;
    return {
        errorType: actualError.constructor.name,
        category: getCategory(actualError),
        statusCode: extractRedisStatusCode(actualError),
    };
}
exports.getErrorInfo = getErrorInfo;
function isRedirectionError(statusCode) {
    return (statusCode !== undefined &&
        (statusCode.startsWith(types_1.METRIC_ERROR_TYPE.ASK) ||
            statusCode.startsWith(types_1.METRIC_ERROR_TYPE.MOVED)));
}
exports.isRedirectionError = isRedirectionError;
//# sourceMappingURL=error.util.js.map