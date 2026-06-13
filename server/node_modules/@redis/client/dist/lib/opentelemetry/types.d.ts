type AttributePrimitive = string | number | boolean;
export type AttributeValue = AttributePrimitive | readonly AttributePrimitive[];
export type Attributes = Record<string, AttributeValue | undefined>;
type InstrumentOptions = {
    unit?: string;
    description?: string;
};
export interface Counter<TAttributes extends Attributes = Attributes> {
    add(value: number, attributes?: TAttributes, context?: unknown): void;
}
export interface Histogram<TAttributes extends Attributes = Attributes> {
    record(value: number, attributes?: TAttributes, context?: unknown): void;
}
export interface UpDownCounter<TAttributes extends Attributes = Attributes> {
    add(value: number, attributes?: TAttributes, context?: unknown): void;
}
export interface ObservableGauge<TAttributes extends Attributes = Attributes> {
    readonly _attributes?: TAttributes;
}
export interface BatchObservableResult {
    observe<TAttributes extends Attributes>(instrument: ObservableGauge<TAttributes>, value: number, attributes?: TAttributes, context?: unknown): void;
}
export interface Meter {
    createHistogram(name: string, options?: InstrumentOptions & {
        advice?: {
            explicitBucketBoundaries?: number[];
        };
    }): Histogram<Attributes>;
    createCounter(name: string, options?: InstrumentOptions): Counter<Attributes>;
    createUpDownCounter(name: string, options?: InstrumentOptions): UpDownCounter<Attributes>;
    createObservableGauge(name: string, options?: InstrumentOptions): ObservableGauge<Attributes>;
    addBatchObservableCallback(callback: (observableResult: BatchObservableResult) => void, observables: ObservableGauge[]): void;
}
export interface MeterProvider {
    getMeter(name: string, version?: string, options?: unknown): Meter;
}
export interface OpenTelemetryApiModule {
    metrics: Pick<MeterProvider, "getMeter">;
}
export declare const METRIC_GROUP: {
    readonly COMMAND: "command";
    readonly CONNECTION_BASIC: "connection-basic";
    readonly CONNECTION_ADVANCED: "connection-advanced";
    readonly RESILIENCY: "resiliency";
    readonly PUBSUB: "pubsub";
    readonly STREAMING: "streaming";
    readonly CLIENT_SIDE_CACHING: "client-side-caching";
};
export type MetricGroup = (typeof METRIC_GROUP)[keyof typeof METRIC_GROUP];
export interface MetricConfig {
    enabled?: boolean;
    meterProvider?: MeterProvider;
    includeCommands?: string[];
    excludeCommands?: string[];
    enabledMetricGroups?: MetricGroup[];
    hidePubSubChannelNames?: boolean;
    hideStreamNames?: boolean;
    bucketsOperationDuration?: number[];
    bucketsConnectionCreateTime?: number[];
    bucketsConnectionWaitTime?: number[];
    bucketsStreamProcessingDuration?: number[];
}
export interface OTelClientAttributes {
    host?: string;
    port?: string | number;
    db?: string | number;
    clientId?: string;
    parentId?: string;
    isPubSub?: boolean;
}
export interface ObservabilityConfig {
    metrics?: MetricConfig;
}
export interface MetricOptions extends Required<Omit<MetricConfig, "meterProvider" | "includeCommands" | "excludeCommands">> {
    attributes: Attributes;
    meterProvider?: MeterProvider;
    includeCommands: Record<string, true>;
    excludeCommands: Record<string, true>;
    hasIncludeCommands: boolean;
    hasExcludeCommands: boolean;
}
export type MetricInstruments = Readonly<{
    dbClientOperationDuration: Histogram<Attributes>;
    dbClientConnectionCount: UpDownCounter<Attributes>;
    dbClientConnectionCreateTime: Histogram<Attributes>;
    redisClientConnectionRelaxedTimeout: UpDownCounter<Attributes>;
    redisClientConnectionHandoff: Counter<Attributes>;
    dbClientConnectionPendingRequests: ObservableGauge<Attributes>;
    dbClientConnectionWaitTime: Histogram<Attributes>;
    redisClientConnectionClosed: Counter<Attributes>;
    redisClientErrors: Counter<Attributes>;
    redisClientMaintenanceNotifications: Counter<Attributes>;
    redisClientPubsubMessages: Counter<Attributes>;
    redisClientStreamLag: Histogram<Attributes>;
    redisClientCscRequests: Counter<Attributes>;
    redisClientCscItems: ObservableGauge<Attributes>;
    redisClientCscEvictions: Counter<Attributes>;
    redisClientCscNetworkSaved: Counter<Attributes>;
}>;
export declare const OTEL_ATTRIBUTES: {
    readonly dbSystemName: "db.system.name";
    readonly dbNamespace: "db.namespace";
    readonly dbOperationName: "db.operation.name";
    readonly dbResponseStatusCode: "db.response.status_code";
    readonly errorType: "error.type";
    readonly serverAddress: "server.address";
    readonly serverPort: "server.port";
    readonly networkPeerAddress: "network.peer.address";
    readonly networkPeerPort: "network.peer.port";
    readonly dbStoredProcedureName: "db.stored_procedure.name";
    readonly dbClientConnectionPoolName: "db.client.connection.pool.name";
    readonly dbClientConnectionState: "db.client.connection.state";
    readonly redisClientLibrary: "redis.client.library";
    readonly redisRedirectionKind: "redis.client.redirection.kind";
    readonly redisClientErrorsInternal: "redis.client.errors.internal";
    readonly redisClientErrorsCategory: "redis.client.errors.category";
    readonly redisClientConnectionCloseReason: "redis.client.connection.close.reason";
    readonly redisClientCscResult: "redis.client.csc.result";
    readonly redisClientCscReason: "redis.client.csc.reason";
    readonly redisClientPubSubChannel: "redis.client.pubsub.channel";
    readonly redisClientPubSubSharded: "redis.client.pubsub.sharded";
    readonly redisClientPubSubMessageDirection: "redis.client.pubsub.message.direction";
    readonly redisClientStreamName: "redis.client.stream.name";
    readonly redisClientConsumerGroup: "redis.client.stream.consumer_group";
    readonly redisClientOperationRetryAttempts: "redis.client.operation.retry_attempts";
    readonly redisClientOperationBlocking: "redis.client.operation.blocking";
    readonly redisClientConnectionNotification: "redis.client.connection.notification";
    readonly redisClientParentId: "redis.client.parent.id";
};
export declare const ERROR_CATEGORY: {
    readonly NETWORK: "network";
    readonly TLS: "tls";
    readonly AUTH: "auth";
    readonly SERVER: "server";
    readonly OTHER: "other";
};
export type ErrorCategory = (typeof ERROR_CATEGORY)[keyof typeof ERROR_CATEGORY];
export declare const CONNECTION_CLOSE_REASON: {
    readonly APPLICATION_CLOSE: "application_close";
    readonly POOL_EVICTION_IDLE: "pool_eviction_idle";
    readonly SERVER_CLOSE: "server_close";
    readonly ERROR: "error";
    readonly HEALTHCHECK_FAILED: "healthcheck_failed";
};
export declare const CSC_RESULT: {
    readonly HIT: "hit";
    readonly MISS: "miss";
};
export declare const CSC_EVICTION_REASON: {
    readonly FULL: "full";
    readonly INVALIDATION: "invalidation";
    readonly TTL: "ttl";
};
export declare const INSTRUMENTATION_SCOPE_NAME = "node-redis";
export declare const DEFAULT_OTEL_ATTRIBUTES: {
    readonly "redis.client.library": `node-redis:${string}`;
    readonly "db.system.name": "redis";
};
export declare const METRIC_NAMES: {
    readonly dbClientOperationDuration: "db.client.operation.duration";
    readonly dbClientConnectionCount: "db.client.connection.count";
    readonly dbClientConnectionCreateTime: "db.client.connection.create_time";
    readonly redisClientConnectionRelaxedTimeout: "redis.client.connection.relaxed_timeout";
    readonly redisClientConnectionHandoff: "redis.client.connection.handoff";
    readonly dbClientConnectionPendingRequests: "db.client.connection.pending_requests";
    readonly dbClientConnectionWaitTime: "db.client.connection.wait_time";
    readonly redisClientConnectionClosed: "redis.client.connection.closed";
    readonly redisClientErrors: "redis.client.errors";
    readonly redisClientMaintenanceNotifications: "redis.client.maintenance.notifications";
    readonly redisClientPubsubMessages: "redis.client.pubsub.messages";
    readonly redisClientStreamLag: "redis.client.stream.lag";
    readonly redisClientCscRequests: "redis.client.csc.requests";
    readonly redisClientCscItems: "redis.client.csc.items";
    readonly redisClientCscEvictions: "redis.client.csc.evictions";
    readonly redisClientCscNetworkSaved: "redis.client.csc.network_saved";
};
export type BaseInstrumentConfig = {
    name: string;
    unit: string;
    description: string;
    metricGroup: MetricGroup;
};
export type HistogramInstrumentConfig = BaseInstrumentConfig & {
    histogramBoundaries: number[];
};
export declare const DEFAULT_METRIC_GROUPS: MetricGroup[];
export declare const DEFAULT_HISTOGRAM_BUCKETS: {
    OPERATION_DURATION: number[];
    CONNECTION_CREATE_TIME: number[];
    CONNECTION_WAIT_TIME: number[];
    CONNECTION_USE_TIME: number[];
    STREAM_LAG: number[];
};
export declare const METRIC_ERROR_TYPE: {
    readonly MOVED: "MOVED";
    readonly ASK: "ASK";
    readonly HANDSHAKE_FAILED: "HANDSHAKE_FAILED";
};
export declare const METRIC_ERROR_ORIGIN: {
    readonly CLIENT: "client";
    readonly CLUSTER: "cluster";
};
export interface IOTelCommandMetrics {
    destroy(): void;
}
export {};
//# sourceMappingURL=types.d.ts.map