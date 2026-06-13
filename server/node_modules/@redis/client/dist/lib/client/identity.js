"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateClusterClientId = exports.generateClientId = exports.ClientRole = void 0;
const node_crypto_1 = require("node:crypto");
/**
 * Maximum length for client identity IDs.
 * Keeps IDs reasonable for OpenTelemetry attributes and logging.
 * @internal
 */
const MAX_ID_LENGTH = 128;
/**
 * @internal
 */
var ClientRole;
(function (ClientRole) {
    ClientRole["STANDALONE"] = "standalone";
    ClientRole["CLUSTER"] = "cluster";
    ClientRole["CLUSTER_NODE"] = "clusterNode";
    ClientRole["POOL"] = "pool";
    ClientRole["POOL_MEMBER"] = "poolMember";
    ClientRole["SENTINEL"] = "sentinel";
    ClientRole["SENTINEL_CLIENT"] = "sentinelClient";
})(ClientRole || (exports.ClientRole = ClientRole = {}));
/**
 * Truncates a prefix string to fit within MAX_ID_LENGTH when combined with suffix.
 * Format when truncated: {truncated_prefix}...-{hash}
 * @internal
 */
const truncateId = (prefix, hash) => {
    const suffix = `-${hash}`;
    const fullId = `${prefix}${suffix}`;
    if (fullId.length <= MAX_ID_LENGTH) {
        return fullId;
    }
    // Reserve space for '...' and suffix
    const ellipsis = '...';
    const maxPrefixLength = MAX_ID_LENGTH - ellipsis.length - suffix.length;
    const truncatedPrefix = prefix.substring(0, maxPrefixLength);
    return `${truncatedPrefix}${ellipsis}${suffix}`;
};
/**
 * Generates a client identity ID in the format: $host:$port/$db-$hash
 * Truncated to MAX_ID_LENGTH if necessary.
 * @internal
 */
const generateClientId = (host, port, db) => {
    const hash = (0, node_crypto_1.randomBytes)(4).toString('hex');
    const prefix = `${host ?? 'unknown'}:${port ?? 'unknown'}/${db ?? 'unknown'}`;
    return truncateId(prefix, hash);
};
exports.generateClientId = generateClientId;
/**
 * Generates a cluster identity ID by concatenating all root nodes: $host1:$port1,$host2:$port2,...-$hash
 * Truncated to MAX_ID_LENGTH if necessary.
 * @internal
 */
const generateClusterClientId = (nodes) => {
    const hash = (0, node_crypto_1.randomBytes)(4).toString('hex');
    const prefix = nodes
        .map((n) => `${n?.socket?.host ?? 'unknown'}:${n?.socket?.port ?? 'unknown'}`)
        .join(',');
    return truncateId(prefix, hash);
};
exports.generateClusterClientId = generateClusterClientId;
//# sourceMappingURL=identity.js.map