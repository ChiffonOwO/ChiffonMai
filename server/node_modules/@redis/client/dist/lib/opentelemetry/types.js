"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.METRIC_ERROR_ORIGIN = exports.METRIC_ERROR_TYPE = exports.DEFAULT_HISTOGRAM_BUCKETS = exports.DEFAULT_METRIC_GROUPS = exports.METRIC_NAMES = exports.DEFAULT_OTEL_ATTRIBUTES = exports.INSTRUMENTATION_SCOPE_NAME = exports.CSC_EVICTION_REASON = exports.CSC_RESULT = exports.CONNECTION_CLOSE_REASON = exports.ERROR_CATEGORY = exports.OTEL_ATTRIBUTES = exports.METRIC_GROUP = void 0;
const package_json_1 = require("../../package.json");
exports.METRIC_GROUP = {
    COMMAND: "command",
    CONNECTION_BASIC: "connection-basic",
    CONNECTION_ADVANCED: "connection-advanced",
    RESILIENCY: "resiliency",
    PUBSUB: "pubsub",
    STREAMING: "streaming",
    CLIENT_SIDE_CACHING: "client-side-caching",
};
exports.OTEL_ATTRIBUTES = {
    // Database & network
    dbSystemName: "db.system.name",
    dbNamespace: "db.namespace",
    dbOperationName: "db.operation.name",
    dbResponseStatusCode: "db.response.status_code",
    errorType: "error.type",
    serverAddress: "server.address",
    serverPort: "server.port",
    networkPeerAddress: "network.peer.address",
    networkPeerPort: "network.peer.port",
    dbStoredProcedureName: "db.stored_procedure.name",
    dbClientConnectionPoolName: "db.client.connection.pool.name",
    dbClientConnectionState: "db.client.connection.state",
    // Redis-specific extensions
    redisClientLibrary: "redis.client.library",
    redisRedirectionKind: "redis.client.redirection.kind",
    redisClientErrorsInternal: "redis.client.errors.internal",
    redisClientErrorsCategory: "redis.client.errors.category",
    redisClientConnectionCloseReason: "redis.client.connection.close.reason",
    redisClientCscResult: "redis.client.csc.result",
    redisClientCscReason: "redis.client.csc.reason",
    redisClientPubSubChannel: "redis.client.pubsub.channel",
    redisClientPubSubSharded: "redis.client.pubsub.sharded",
    redisClientPubSubMessageDirection: "redis.client.pubsub.message.direction",
    redisClientStreamName: "redis.client.stream.name",
    redisClientConsumerGroup: "redis.client.stream.consumer_group",
    redisClientOperationRetryAttempts: "redis.client.operation.retry_attempts",
    redisClientOperationBlocking: "redis.client.operation.blocking",
    redisClientConnectionNotification: "redis.client.connection.notification",
    redisClientParentId: "redis.client.parent.id",
};
exports.ERROR_CATEGORY = {
    NETWORK: "network",
    TLS: "tls",
    AUTH: "auth",
    SERVER: "server",
    OTHER: "other",
};
exports.CONNECTION_CLOSE_REASON = {
    APPLICATION_CLOSE: "application_close",
    POOL_EVICTION_IDLE: "pool_eviction_idle",
    SERVER_CLOSE: "server_close",
    ERROR: "error",
    HEALTHCHECK_FAILED: "healthcheck_failed",
};
exports.CSC_RESULT = {
    HIT: "hit",
    MISS: "miss",
};
exports.CSC_EVICTION_REASON = {
    FULL: "full",
    INVALIDATION: "invalidation",
    TTL: "ttl",
};
exports.INSTRUMENTATION_SCOPE_NAME = "node-redis";
exports.DEFAULT_OTEL_ATTRIBUTES = {
    [exports.OTEL_ATTRIBUTES.redisClientLibrary]: `node-redis:${package_json_1.version}`,
    [exports.OTEL_ATTRIBUTES.dbSystemName]: "redis",
};
exports.METRIC_NAMES = {
    // Command metrics
    dbClientOperationDuration: "db.client.operation.duration",
    // Connection metrics
    dbClientConnectionCount: "db.client.connection.count",
    dbClientConnectionCreateTime: "db.client.connection.create_time",
    redisClientConnectionRelaxedTimeout: "redis.client.connection.relaxed_timeout",
    redisClientConnectionHandoff: "redis.client.connection.handoff",
    // Connection Advanced metrics
    dbClientConnectionPendingRequests: "db.client.connection.pending_requests",
    dbClientConnectionWaitTime: "db.client.connection.wait_time",
    redisClientConnectionClosed: "redis.client.connection.closed",
    // Resiliency metrics
    redisClientErrors: "redis.client.errors",
    redisClientMaintenanceNotifications: "redis.client.maintenance.notifications",
    // PubSub metrics
    redisClientPubsubMessages: "redis.client.pubsub.messages",
    // Stream metrics
    redisClientStreamLag: "redis.client.stream.lag",
    // Client-Side Caching metrics
    redisClientCscRequests: "redis.client.csc.requests",
    redisClientCscItems: "redis.client.csc.items",
    redisClientCscEvictions: "redis.client.csc.evictions",
    redisClientCscNetworkSaved: "redis.client.csc.network_saved",
};
exports.DEFAULT_METRIC_GROUPS = [
    "connection-basic",
    "resiliency",
];
const DEFAULT_HISTOGRAM_BUCKET = [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5, 10];
exports.DEFAULT_HISTOGRAM_BUCKETS = {
    OPERATION_DURATION: DEFAULT_HISTOGRAM_BUCKET,
    CONNECTION_CREATE_TIME: DEFAULT_HISTOGRAM_BUCKET,
    CONNECTION_WAIT_TIME: DEFAULT_HISTOGRAM_BUCKET,
    CONNECTION_USE_TIME: DEFAULT_HISTOGRAM_BUCKET,
    STREAM_LAG: DEFAULT_HISTOGRAM_BUCKET,
};
exports.METRIC_ERROR_TYPE = {
    MOVED: "MOVED",
    ASK: "ASK",
    HANDSHAKE_FAILED: "HANDSHAKE_FAILED",
};
exports.METRIC_ERROR_ORIGIN = {
    CLIENT: "client",
    CLUSTER: "cluster",
};
//# sourceMappingURL=types.js.map