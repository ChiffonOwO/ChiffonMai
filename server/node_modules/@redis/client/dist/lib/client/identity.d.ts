import { RedisClusterClientOptions } from '../cluster';
/**
 * @internal
 */
export declare enum ClientRole {
    STANDALONE = "standalone",
    CLUSTER = "cluster",
    CLUSTER_NODE = "clusterNode",
    POOL = "pool",
    POOL_MEMBER = "poolMember",
    SENTINEL = "sentinel",
    SENTINEL_CLIENT = "sentinelClient"
}
/**
 * Identity for all Redis clients.
 * Contains only the stable identity info (id, role, parentId).
 * Use dynamic methods to get current host/port/db to avoid drift.
 * @internal
 */
export interface ClientIdentity {
    readonly id: string;
    role: ClientRole;
    parentId?: string;
}
/**
 * Generates a client identity ID in the format: $host:$port/$db-$hash
 * Truncated to MAX_ID_LENGTH if necessary.
 * @internal
 */
export declare const generateClientId: (host?: string, port?: number, db?: number) => string;
/**
 * Generates a cluster identity ID by concatenating all root nodes: $host1:$port1,$host2:$port2,...-$hash
 * Truncated to MAX_ID_LENGTH if necessary.
 * @internal
 */
export declare const generateClusterClientId: (nodes: Array<RedisClusterClientOptions>) => string;
//# sourceMappingURL=identity.d.ts.map