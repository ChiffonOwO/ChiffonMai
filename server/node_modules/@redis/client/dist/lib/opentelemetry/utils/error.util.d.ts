import { ErrorCategory } from "../types";
/**
 * Result of analyzing an error for OpenTelemetry attributes.
 */
export interface ErrorInfo {
    /**
     * The error type (class name or constructor name).
     * Maps to OTel attribute: error.type
     */
    errorType: string;
    /**
     * The error category for Redis client errors.
     * Maps to OTel attribute: redis.client.errors.category
     */
    category: ErrorCategory;
    /**
     * The Redis status code (error prefix) if this is a Redis ErrorReply.
     * Maps to OTel attribute: db.response.status_code
     * Examples: "ERR", "WRONGTYPE", "MOVED", "NOAUTH"
     */
    statusCode: string | undefined;
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
export declare function getErrorInfo(error: unknown): ErrorInfo;
export declare function isRedirectionError(statusCode?: string): boolean;
//# sourceMappingURL=error.util.d.ts.map