"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OTelMetrics = void 0;
const client_registry_1 = require("./client-registry");
const types_1 = require("./types");
const utils_1 = require("./utils");
const errors_1 = require("../errors");
const tracing_1 = require("../client/tracing");
function resolveClientAttributes(clientId) {
    return clientId
        ? client_registry_1.ClientRegistry.instance.getById(clientId)?.getAttributes()
        : undefined;
}
function subscribeTC(tc, handlers) {
    const h = handlers;
    tc.subscribe(h);
    return () => tc.unsubscribe(h);
}
class OTelCommandMetrics {
    #instruments;
    #options;
    #metricsState = new WeakMap();
    #unsubscribers = [];
    constructor(options, instruments) {
        this.#options = options;
        this.#instruments = instruments;
        this.#subscribeToTracingChannel();
    }
    #subscribeToTracingChannel() {
        const commandTC = (0, tracing_1.getTracingChannel)(tracing_1.CHANNELS.TRACE_COMMAND);
        const batchTC = (0, tracing_1.getTracingChannel)(tracing_1.CHANNELS.TRACE_BATCH);
        if (!commandTC || !batchTC)
            return;
        const onStart = (ctx) => {
            const commandName = ctx.command?.toString() || "UNKNOWN";
            if (this.#isCommandExcluded(commandName))
                return;
            this.#metricsState.set(ctx, {
                startTime: performance.now(),
                clientAttributes: resolveClientAttributes(ctx.clientId),
                commandName,
            });
        };
        const onAsyncEnd = (ctx) => {
            const state = this.#metricsState.get(ctx);
            if (!state)
                return;
            this.#metricsState.delete(ctx);
            this.#instruments.dbClientOperationDuration.record((performance.now() - state.startTime) / 1000, {
                ...this.#options.attributes,
                [types_1.OTEL_ATTRIBUTES.dbNamespace]: state.clientAttributes?.db?.toString(),
                [types_1.OTEL_ATTRIBUTES.serverAddress]: state.clientAttributes?.host,
                [types_1.OTEL_ATTRIBUTES.serverPort]: state.clientAttributes?.port?.toString(),
                [types_1.OTEL_ATTRIBUTES.dbOperationName]: state.commandName,
            });
        };
        const onError = (ctx) => {
            const state = this.#metricsState.get(ctx);
            if (!state)
                return;
            this.#metricsState.delete(ctx);
            const errorInfo = (0, utils_1.getErrorInfo)(ctx.error);
            this.#instruments.dbClientOperationDuration.record((performance.now() - state.startTime) / 1000, {
                ...this.#options.attributes,
                [types_1.OTEL_ATTRIBUTES.dbNamespace]: state.clientAttributes?.db?.toString(),
                [types_1.OTEL_ATTRIBUTES.serverAddress]: state.clientAttributes?.host,
                [types_1.OTEL_ATTRIBUTES.serverPort]: state.clientAttributes?.port?.toString(),
                [types_1.OTEL_ATTRIBUTES.dbOperationName]: state.commandName,
                [types_1.OTEL_ATTRIBUTES.errorType]: errorInfo.errorType,
                [types_1.OTEL_ATTRIBUTES.redisClientErrorsCategory]: errorInfo.category,
                ...(errorInfo.statusCode !== undefined
                    ? { [types_1.OTEL_ATTRIBUTES.dbResponseStatusCode]: errorInfo.statusCode }
                    : {}),
            });
        };
        const onBatchStart = (ctx) => {
            this.#metricsState.set(ctx, {
                startTime: performance.now(),
                clientAttributes: resolveClientAttributes(ctx.clientId),
                commandName: ctx.batchMode,
            });
        };
        const onBatchAsyncEnd = (ctx) => {
            const state = this.#metricsState.get(ctx);
            if (!state)
                return;
            this.#metricsState.delete(ctx);
            this.#instruments.dbClientOperationDuration.record((performance.now() - state.startTime) / 1000, {
                ...this.#options.attributes,
                [types_1.OTEL_ATTRIBUTES.dbNamespace]: state.clientAttributes?.db?.toString(),
                [types_1.OTEL_ATTRIBUTES.serverAddress]: state.clientAttributes?.host,
                [types_1.OTEL_ATTRIBUTES.serverPort]: state.clientAttributes?.port?.toString(),
                [types_1.OTEL_ATTRIBUTES.dbOperationName]: state.commandName,
            });
        };
        const onBatchError = (ctx) => {
            const state = this.#metricsState.get(ctx);
            if (!state)
                return;
            this.#metricsState.delete(ctx);
            const errorInfo = (0, utils_1.getErrorInfo)(ctx.error);
            this.#instruments.dbClientOperationDuration.record((performance.now() - state.startTime) / 1000, {
                ...this.#options.attributes,
                [types_1.OTEL_ATTRIBUTES.dbNamespace]: state.clientAttributes?.db?.toString(),
                [types_1.OTEL_ATTRIBUTES.serverAddress]: state.clientAttributes?.host,
                [types_1.OTEL_ATTRIBUTES.serverPort]: state.clientAttributes?.port?.toString(),
                [types_1.OTEL_ATTRIBUTES.dbOperationName]: state.commandName,
                [types_1.OTEL_ATTRIBUTES.errorType]: errorInfo.errorType,
                [types_1.OTEL_ATTRIBUTES.redisClientErrorsCategory]: errorInfo.category,
                ...(errorInfo.statusCode !== undefined
                    ? { [types_1.OTEL_ATTRIBUTES.dbResponseStatusCode]: errorInfo.statusCode }
                    : {}),
            });
        };
        this.#unsubscribers.push(subscribeTC(commandTC, { start: onStart, asyncEnd: onAsyncEnd, error: onError }), subscribeTC(batchTC, { start: onBatchStart, asyncEnd: onBatchAsyncEnd, error: onBatchError }));
    }
    destroy() {
        this.#unsubscribers.forEach(fn => fn());
    }
    #isCommandExcluded(commandName) {
        return ((this.#options.hasIncludeCommands &&
            !this.#options.includeCommands[commandName]) ||
            this.#options.excludeCommands[commandName]);
    }
}
// ---------------------------------------------------------------------------
// Channel subscribers: record OTel metrics from diagnostics_channel events.
// ---------------------------------------------------------------------------
class OTelChannelSubscribers {
    #instruments;
    #options;
    #unsubscribers = [];
    constructor(options, instruments, enabledGroups) {
        this.#options = options;
        this.#instruments = instruments;
        const hasBasic = enabledGroups.includes(types_1.METRIC_GROUP.CONNECTION_BASIC);
        const hasAdvanced = enabledGroups.includes(types_1.METRIC_GROUP.CONNECTION_ADVANCED);
        if (hasBasic) {
            this.#subscribeConnectionBasic();
        }
        if (hasAdvanced) {
            this.#subscribeConnectionAdvanced();
        }
        if (hasBasic || hasAdvanced) {
            this.#subscribeConnectionClosed(hasBasic, hasAdvanced);
        }
        if (enabledGroups.includes(types_1.METRIC_GROUP.RESILIENCY)) {
            this.#subscribeResiliency();
        }
        if (enabledGroups.includes(types_1.METRIC_GROUP.CLIENT_SIDE_CACHING)) {
            this.#subscribeClientSideCache();
        }
        if (enabledGroups.includes(types_1.METRIC_GROUP.PUBSUB)) {
            this.#subscribePubSub();
        }
        if (enabledGroups.includes(types_1.METRIC_GROUP.PUBSUB) || enabledGroups.includes(types_1.METRIC_GROUP.STREAMING)) {
            this.#subscribeCommandReply(enabledGroups);
        }
    }
    #sub(name, handler) {
        const ch = (0, tracing_1.getChannel)(name);
        if (!ch)
            return;
        ch.subscribe(handler);
        this.#unsubscribers.push(() => ch.unsubscribe(handler));
    }
    destroy() {
        this.#unsubscribers.forEach(fn => fn());
    }
    // -- Connection Basic --
    #subscribeConnectionBasic() {
        this.#sub(tracing_1.CHANNELS.CONNECTION_READY, (ctx) => {
            const clientAttributes = resolveClientAttributes(ctx.clientId);
            this.#instruments.dbClientConnectionCreateTime.record(ctx.createTimeMs / 1000, {
                ...this.#options.attributes,
                ...(0, utils_1.parseClientAttributes)(clientAttributes),
            });
            this.#instruments.dbClientConnectionCount.add(1, {
                ...this.#options.attributes,
                ...(0, utils_1.parseClientAttributes)(clientAttributes),
                [types_1.OTEL_ATTRIBUTES.dbClientConnectionState]: "used",
            });
        });
        this.#sub(tracing_1.CHANNELS.CONNECTION_RELAXED_TIMEOUT, (ctx) => {
            const clientAttributes = resolveClientAttributes(ctx.clientId);
            this.#instruments.redisClientConnectionRelaxedTimeout.add(ctx.value, {
                ...this.#options.attributes,
                ...(0, utils_1.parseClientAttributes)(clientAttributes),
            });
        });
        this.#sub(tracing_1.CHANNELS.CONNECTION_HANDOFF, (ctx) => {
            const clientAttributes = resolveClientAttributes(ctx.clientId);
            this.#instruments.redisClientConnectionHandoff.add(1, {
                ...this.#options.attributes,
                ...(0, utils_1.parseClientAttributes)(clientAttributes),
            });
        });
    }
    // -- Connection Closed (shared by basic + advanced) --
    #subscribeConnectionClosed(hasBasic, hasAdvanced) {
        this.#sub(tracing_1.CHANNELS.CONNECTION_CLOSED, (ctx) => {
            const clientAttributes = resolveClientAttributes(ctx.clientId);
            if (hasBasic && ctx.wasConnected) {
                this.#instruments.dbClientConnectionCount.add(-1, {
                    ...this.#options.attributes,
                    ...(0, utils_1.parseClientAttributes)(clientAttributes),
                    [types_1.OTEL_ATTRIBUTES.dbClientConnectionState]: "used",
                });
            }
            if (hasAdvanced) {
                this.#instruments.redisClientConnectionClosed.add(1, {
                    ...this.#options.attributes,
                    ...(0, utils_1.parseClientAttributes)(clientAttributes),
                    [types_1.OTEL_ATTRIBUTES.redisClientConnectionCloseReason]: ctx.reason,
                });
            }
        });
    }
    // -- Connection Advanced --
    #subscribeConnectionAdvanced() {
        this.#sub(tracing_1.CHANNELS.POOL_CONNECTION_WAIT, (ctx) => {
            if (!ctx.waitStartTimestamp)
                return;
            const clientAttributes = resolveClientAttributes(ctx.clientId);
            this.#instruments.dbClientConnectionWaitTime.record((performance.now() - ctx.waitStartTimestamp) / 1000, {
                ...this.#options.attributes,
                ...(0, utils_1.parseClientAttributes)(clientAttributes),
            });
        });
    }
    #recordError(error, clientId, extra) {
        const clientAttributes = resolveClientAttributes(clientId);
        const errorInfo = (0, utils_1.getErrorInfo)(error);
        this.#instruments.redisClientErrors.add(1, {
            ...this.#options.attributes,
            ...(0, utils_1.parseClientAttributes)(clientAttributes),
            [types_1.OTEL_ATTRIBUTES.errorType]: errorInfo.errorType,
            [types_1.OTEL_ATTRIBUTES.redisClientErrorsCategory]: errorInfo.category,
            ...(errorInfo.statusCode !== undefined && {
                [types_1.OTEL_ATTRIBUTES.dbResponseStatusCode]: errorInfo.statusCode,
            }),
            ...extra,
        });
    }
    // -- Resiliency --
    #subscribeResiliency() {
        // Cluster/internal errors via point-event channel
        // Skip client-origin redirections (MOVED/ASK) — these are retried
        // transparently by the cluster client and are not real errors.
        // Cluster-origin redirections are recorded as they indicate slot migration.
        this.#sub(tracing_1.CHANNELS.ERROR, (ctx) => {
            if (ctx.origin === 'client' && (0, utils_1.isRedirectionError)((0, utils_1.getErrorInfo)(ctx.error).statusCode))
                return;
            this.#recordError(ctx.error, ctx.clientId, {
                [types_1.OTEL_ATTRIBUTES.redisClientErrorsInternal]: ctx.internal,
                ...(ctx.retryCount !== undefined && {
                    [types_1.OTEL_ATTRIBUTES.redisClientOperationRetryAttempts]: ctx.retryCount,
                }),
            });
        });
        // Command-level errors via TracingChannel
        const commandTC = (0, tracing_1.getTracingChannel)(tracing_1.CHANNELS.TRACE_COMMAND);
        if (commandTC) {
            const onError = (ctx) => {
                // Command TC errors are always client-origin — skip redirections
                if ((0, utils_1.isRedirectionError)((0, utils_1.getErrorInfo)(ctx.error).statusCode))
                    return;
                this.#recordError(ctx.error, ctx.clientId, {
                    [types_1.OTEL_ATTRIBUTES.redisClientErrorsInternal]: false,
                });
            };
            this.#unsubscribers.push(subscribeTC(commandTC, { error: onError }));
        }
        this.#sub(tracing_1.CHANNELS.MAINTENANCE, (ctx) => {
            const clientAttributes = resolveClientAttributes(ctx.clientId);
            this.#instruments.redisClientMaintenanceNotifications.add(1, {
                ...this.#options.attributes,
                ...(0, utils_1.parseClientAttributes)(clientAttributes),
                [types_1.OTEL_ATTRIBUTES.redisClientConnectionNotification]: ctx.notification,
            });
        });
    }
    // -- Client-Side Cache --
    #subscribeClientSideCache() {
        this.#sub(tracing_1.CHANNELS.CACHE_REQUEST, (ctx) => {
            const clientAttributes = resolveClientAttributes(ctx.clientId);
            this.#instruments.redisClientCscRequests.add(1, {
                ...this.#options.attributes,
                [types_1.OTEL_ATTRIBUTES.serverAddress]: clientAttributes?.host,
                [types_1.OTEL_ATTRIBUTES.serverPort]: clientAttributes?.port?.toString(),
                [types_1.OTEL_ATTRIBUTES.dbClientConnectionPoolName]: clientAttributes?.clientId,
                [types_1.OTEL_ATTRIBUTES.redisClientCscResult]: ctx.result,
            });
        });
        this.#sub(tracing_1.CHANNELS.CACHE_EVICTION, (ctx) => {
            const clientAttributes = resolveClientAttributes(ctx.clientId);
            this.#instruments.redisClientCscEvictions.add(ctx.count ?? 1, {
                ...this.#options.attributes,
                [types_1.OTEL_ATTRIBUTES.serverAddress]: clientAttributes?.host,
                [types_1.OTEL_ATTRIBUTES.serverPort]: clientAttributes?.port?.toString(),
                [types_1.OTEL_ATTRIBUTES.dbClientConnectionPoolName]: clientAttributes?.clientId,
                [types_1.OTEL_ATTRIBUTES.redisClientCscReason]: ctx.reason,
            });
        });
    }
    // -- PubSub --
    #subscribePubSub() {
        this.#sub(tracing_1.CHANNELS.PUBSUB, (ctx) => {
            const clientAttributes = resolveClientAttributes(ctx.clientId);
            this.#instruments.redisClientPubsubMessages.add(1, {
                ...this.#options.attributes,
                ...(0, utils_1.parseClientAttributes)(clientAttributes),
                [types_1.OTEL_ATTRIBUTES.redisClientPubSubMessageDirection]: ctx.direction,
                [types_1.OTEL_ATTRIBUTES.redisClientPubSubSharded]: ctx.sharded ?? false,
                ...(ctx.channel !== undefined && !this.#options.hidePubSubChannelNames
                    ? { [types_1.OTEL_ATTRIBUTES.redisClientPubSubChannel]: ctx.channel.toString() }
                    : {}),
            });
        });
    }
    // -- Command Reply (shared by PubSub out + Streaming) --
    #subscribeCommandReply(enabledGroups) {
        const hasPubSub = enabledGroups.includes(types_1.METRIC_GROUP.PUBSUB);
        const hasStreaming = enabledGroups.includes(types_1.METRIC_GROUP.STREAMING);
        this.#sub(tracing_1.CHANNELS.COMMAND_REPLY, (ctx) => {
            const commandName = ctx.args[0]?.toString().toUpperCase();
            if (hasPubSub && (commandName === 'PUBLISH' || commandName === 'SPUBLISH')) {
                const clientAttributes = resolveClientAttributes(ctx.clientId);
                this.#instruments.redisClientPubsubMessages.add(1, {
                    ...this.#options.attributes,
                    ...(0, utils_1.parseClientAttributes)(clientAttributes),
                    [types_1.OTEL_ATTRIBUTES.redisClientPubSubMessageDirection]: 'out',
                    [types_1.OTEL_ATTRIBUTES.redisClientPubSubSharded]: commandName === 'SPUBLISH',
                    ...(ctx.args[1] !== undefined && !this.#options.hidePubSubChannelNames
                        ? { [types_1.OTEL_ATTRIBUTES.redisClientPubSubChannel]: ctx.args[1].toString() }
                        : {}),
                });
                return;
            }
            if (hasStreaming && (commandName === 'XREAD' || commandName === 'XREADGROUP')) {
                const reply = ctx.reply;
                if (!reply || !Array.isArray(reply) || reply.length === 0)
                    return;
                const now = Date.now();
                const clientAttributes = resolveClientAttributes(ctx.clientId);
                const isXReadGroup = commandName === 'XREADGROUP' &&
                    ctx.args[1]?.toString().toUpperCase() === 'GROUP';
                const consumerGroup = isXReadGroup ? ctx.args[2]?.toString() : undefined;
                for (const streamData of reply) {
                    if (!streamData || typeof streamData !== 'object')
                        continue;
                    const { name: stream, messages } = streamData;
                    if (!messages || !Array.isArray(messages) || messages.length === 0)
                        continue;
                    const streamAttributes = {
                        ...this.#options.attributes,
                        ...(0, utils_1.parseClientAttributes)(clientAttributes),
                        ...(!this.#options.hideStreamNames
                            ? { [types_1.OTEL_ATTRIBUTES.redisClientStreamName]: stream }
                            : {}),
                        ...(consumerGroup !== undefined
                            ? { [types_1.OTEL_ATTRIBUTES.redisClientConsumerGroup]: consumerGroup }
                            : {}),
                    };
                    for (const message of messages) {
                        if (!message?.id)
                            continue;
                        const [tsPart] = message.id.split('-');
                        const messageTimestamp = Number.parseInt(tsPart, 10);
                        if (!Number.isFinite(messageTimestamp))
                            continue;
                        this.#instruments.redisClientStreamLag.record((now - messageTimestamp) / 1000, streamAttributes);
                    }
                }
            }
        });
    }
}
class OTelMetrics {
    // Create a noop instance by default
    static #instance;
    static #initialized = false;
    commandMetrics;
    #channelSubscribers;
    #instruments;
    #options;
    constructor(api, config) {
        this.#options = this.parseOptions(config);
        if (!this.#options.enabled) {
            // No-op: don't register any instruments or subscribers
            this.commandMetrics = { destroy() { } };
            this.#channelSubscribers = { destroy() { } };
            this.#instruments = undefined;
            return;
        }
        const meter = this.#getMeter(api, this.#options);
        this.#instruments = this.registerInstruments(meter, this.#options);
        if (this.#options.enabledMetricGroups.includes(types_1.METRIC_GROUP.COMMAND)) {
            this.commandMetrics = new OTelCommandMetrics(this.#options, this.#instruments);
        }
        else {
            this.commandMetrics = { destroy() { } };
        }
        this.#channelSubscribers = new OTelChannelSubscribers(this.#options, this.#instruments, this.#options.enabledMetricGroups);
    }
    static init({ api, config, }) {
        if (OTelMetrics.#initialized) {
            throw new errors_1.OpenTelemetryError("OTelMetrics already initialized");
        }
        const instance = new OTelMetrics(api, config);
        OTelMetrics.#instance = instance;
        OTelMetrics.#initialized = true;
    }
    /**
     * Reset the instance to noop. Used for testing.
     *
     * @internal
     */
    static reset() {
        if (!OTelMetrics.#initialized)
            return;
        OTelMetrics.#instance.commandMetrics.destroy();
        OTelMetrics.#instance.#channelSubscribers.destroy();
        OTelMetrics.#initialized = false;
    }
    static isInitialized() {
        return OTelMetrics.#initialized;
    }
    static get instance() {
        return OTelMetrics.#instance;
    }
    #getMeter(api, options) {
        if (options.meterProvider) {
            return options.meterProvider.getMeter(types_1.INSTRUMENTATION_SCOPE_NAME);
        }
        return api.metrics.getMeter(types_1.INSTRUMENTATION_SCOPE_NAME);
    }
    parseOptions(config) {
        return {
            enabled: !!config?.metrics?.enabled,
            attributes: {
                ...types_1.DEFAULT_OTEL_ATTRIBUTES,
            },
            meterProvider: config?.metrics?.meterProvider,
            includeCommands: (config?.metrics?.includeCommands ?? []).reduce((acc, c) => {
                acc[c.toUpperCase()] = true;
                return acc;
            }, {}),
            hasIncludeCommands: !!config?.metrics?.includeCommands?.length,
            excludeCommands: (config?.metrics?.excludeCommands ?? []).reduce((acc, c) => {
                acc[c.toUpperCase()] = true;
                return acc;
            }, {}),
            hasExcludeCommands: !!config?.metrics?.excludeCommands?.length,
            enabledMetricGroups: config?.metrics?.enabledMetricGroups ?? types_1.DEFAULT_METRIC_GROUPS,
            hidePubSubChannelNames: config?.metrics?.hidePubSubChannelNames ?? false,
            hideStreamNames: config?.metrics?.hideStreamNames ?? false,
            bucketsOperationDuration: config?.metrics?.bucketsOperationDuration ??
                types_1.DEFAULT_HISTOGRAM_BUCKETS.OPERATION_DURATION,
            bucketsConnectionCreateTime: config?.metrics?.bucketsConnectionCreateTime ??
                types_1.DEFAULT_HISTOGRAM_BUCKETS.CONNECTION_CREATE_TIME,
            bucketsConnectionWaitTime: config?.metrics?.bucketsConnectionWaitTime ??
                types_1.DEFAULT_HISTOGRAM_BUCKETS.CONNECTION_WAIT_TIME,
            bucketsStreamProcessingDuration: config?.metrics?.bucketsStreamProcessingDuration ??
                types_1.DEFAULT_HISTOGRAM_BUCKETS.STREAM_LAG,
        };
    }
    createHistogram(meter, instrumentConfig) {
        return meter.createHistogram(instrumentConfig.name, {
            unit: instrumentConfig.unit,
            description: instrumentConfig.description,
            ...(instrumentConfig?.histogramBoundaries?.length
                ? {
                    advice: {
                        explicitBucketBoundaries: instrumentConfig.histogramBoundaries,
                    },
                }
                : {}),
        });
    }
    createCounter(meter, instrumentConfig) {
        return meter.createCounter(instrumentConfig.name, {
            unit: instrumentConfig.unit,
            description: instrumentConfig.description,
        });
    }
    createUpDownCounter(meter, instrumentConfig) {
        return meter.createUpDownCounter(instrumentConfig.name, {
            unit: instrumentConfig.unit,
            description: instrumentConfig.description,
        });
    }
    createObservableGaugeWithCallback(meter, instrumentConfig, options, callback) {
        const gauge = meter.createObservableGauge(instrumentConfig.name, {
            unit: instrumentConfig.unit,
            description: instrumentConfig.description,
        });
        if (options.enabledMetricGroups.includes(instrumentConfig.metricGroup)) {
            meter.addBatchObservableCallback((observableResult) => callback(observableResult, options), [gauge]);
        }
        return gauge;
    }
    registerInstruments(meter, options) {
        return {
            // Command
            dbClientOperationDuration: this.createHistogram(meter, {
                name: types_1.METRIC_NAMES.dbClientOperationDuration,
                unit: "s",
                description: "Duration of a Redis client operation (includes retries)",
                metricGroup: types_1.METRIC_GROUP.COMMAND,
                histogramBoundaries: options.bucketsOperationDuration,
            }),
            // Basic connection
            dbClientConnectionCount: this.createUpDownCounter(meter, {
                name: types_1.METRIC_NAMES.dbClientConnectionCount,
                unit: "{connection}",
                description: "Current number of active connections",
                metricGroup: types_1.METRIC_GROUP.CONNECTION_BASIC,
            }),
            dbClientConnectionCreateTime: this.createHistogram(meter, {
                name: types_1.METRIC_NAMES.dbClientConnectionCreateTime,
                unit: "s",
                description: "Time taken to create a new connection to the Redis server",
                metricGroup: types_1.METRIC_GROUP.CONNECTION_BASIC,
                histogramBoundaries: options.bucketsConnectionCreateTime,
            }),
            redisClientConnectionRelaxedTimeout: this.createUpDownCounter(meter, {
                name: types_1.METRIC_NAMES.redisClientConnectionRelaxedTimeout,
                unit: "{relaxation}",
                description: `How many times the connection timeout has been increased/decreased (after a server maintenance notification).
           Counts up for relaxed timeout, counts down for unrelaxed timeout`,
                metricGroup: types_1.METRIC_GROUP.CONNECTION_BASIC,
            }),
            redisClientConnectionHandoff: this.createCounter(meter, {
                name: types_1.METRIC_NAMES.redisClientConnectionHandoff,
                unit: "{handoff}",
                description: "Connections that have been handed off to another node (e.g after a MOVING notification)",
                metricGroup: types_1.METRIC_GROUP.CONNECTION_BASIC,
            }),
            // Advanced connection
            dbClientConnectionWaitTime: this.createHistogram(meter, {
                name: types_1.METRIC_NAMES.dbClientConnectionWaitTime,
                unit: "s",
                description: "Time spent waiting for an available connection from the pool",
                metricGroup: types_1.METRIC_GROUP.CONNECTION_ADVANCED,
                histogramBoundaries: options.bucketsConnectionWaitTime,
            }),
            // The DB semconv models pending requests as an UpDownCounter on pooled
            // connections. That does not map cleanly to node-redis today, so we keep
            // this disabled for now and may reintroduce it later as an async gauge
            // with a client-specific name.
            // See: https://opentelemetry.io/docs/specs/semconv/db/database-metrics/#connection-pools
            // dbClientConnectionPendingRequests: this.createObservableGaugeWithCallback(
            //   meter,
            //   options.enabledMetricGroups,
            //   {
            //     name: METRIC_NAMES.dbClientConnectionPendingRequests,
            //     unit: "{request}",
            //     description: "Current number of pending requests per connection",
            //     metricGroup: METRIC_GROUP.CONNECTION_ADVANCED,
            //   },
            //   options,
            //   (observableResult, opts) => {
            //     for (const handle of ClientRegistry.instance.getAll()) {
            //       observableResult.observe(
            //         this.#instruments.dbClientConnectionPendingRequests,
            //         handle.getPendingRequests(),
            //         {
            //           ...opts.attributes,
            //           ...parseClientAttributes(handle.getAttributes()),
            //         },
            //       );
            //     }
            //   },
            // ),
            dbClientConnectionPendingRequests: meter.createObservableGauge(types_1.METRIC_NAMES.dbClientConnectionPendingRequests),
            redisClientConnectionClosed: this.createCounter(meter, {
                name: types_1.METRIC_NAMES.redisClientConnectionClosed,
                unit: "{connection}",
                description: "Total number of closed connections",
                metricGroup: types_1.METRIC_GROUP.CONNECTION_ADVANCED,
            }),
            // Resiliency
            redisClientErrors: this.createCounter(meter, {
                name: types_1.METRIC_NAMES.redisClientErrors,
                unit: "{error}",
                description: "A counter of all errors (both returned and handled internally)",
                metricGroup: types_1.METRIC_GROUP.RESILIENCY,
            }),
            redisClientMaintenanceNotifications: this.createCounter(meter, {
                name: types_1.METRIC_NAMES.redisClientMaintenanceNotifications,
                unit: "{notification}",
                description: "Number of maintenance notifications received",
                metricGroup: types_1.METRIC_GROUP.RESILIENCY,
            }),
            // PubSub
            redisClientPubsubMessages: this.createCounter(meter, {
                name: types_1.METRIC_NAMES.redisClientPubsubMessages,
                unit: "{message}",
                description: "Number of pub/sub messages processed",
                metricGroup: types_1.METRIC_GROUP.PUBSUB,
            }),
            // Streams
            redisClientStreamLag: this.createHistogram(meter, {
                name: types_1.METRIC_NAMES.redisClientStreamLag,
                unit: "s",
                description: "End-to-end lag per message",
                metricGroup: types_1.METRIC_GROUP.STREAMING,
                histogramBoundaries: options.bucketsStreamProcessingDuration,
            }),
            // Client-Side Caching
            redisClientCscRequests: this.createCounter(meter, {
                name: types_1.METRIC_NAMES.redisClientCscRequests,
                unit: "{request}",
                description: "Number of client-side cache requests (hits and misses)",
                metricGroup: types_1.METRIC_GROUP.CLIENT_SIDE_CACHING,
            }),
            redisClientCscItems: this.createObservableGaugeWithCallback(meter, {
                name: types_1.METRIC_NAMES.redisClientCscItems,
                unit: "{item}",
                description: "Current number of items in the client-side cache",
                metricGroup: types_1.METRIC_GROUP.CLIENT_SIDE_CACHING,
            }, options, (observableResult, opts) => {
                for (const handle of client_registry_1.ClientRegistry.instance.getAll()) {
                    observableResult.observe(this.#instruments.redisClientCscItems, handle.getCacheItemCount(), {
                        ...opts.attributes,
                        ...(0, utils_1.parseClientAttributes)(handle.getAttributes()),
                    });
                }
            }),
            redisClientCscEvictions: this.createCounter(meter, {
                name: types_1.METRIC_NAMES.redisClientCscEvictions,
                unit: "{eviction}",
                description: "Number of items evicted from the client-side cache",
                metricGroup: types_1.METRIC_GROUP.CLIENT_SIDE_CACHING,
            }),
            redisClientCscNetworkSaved: this.createCounter(meter, {
                name: types_1.METRIC_NAMES.redisClientCscNetworkSaved,
                unit: "By",
                description: "Estimated bytes saved by client-side cache hits",
                metricGroup: types_1.METRIC_GROUP.CLIENT_SIDE_CACHING,
            }),
        };
    }
}
exports.OTelMetrics = OTelMetrics;
//# sourceMappingURL=metrics.js.map