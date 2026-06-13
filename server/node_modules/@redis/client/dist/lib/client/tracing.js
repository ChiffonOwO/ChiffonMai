"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.publish = exports.getChannel = exports.trace = exports.getTracingChannel = exports.sanitizeArgs = exports.CHANNELS = void 0;
const dc = (() => {
    try {
        return ('getBuiltinModule' in process)
            ? process.getBuiltinModule('node:diagnostics_channel')
            : require('node:diagnostics_channel');
    }
    catch {
        return undefined;
    }
})();
const hasTracingChannel = typeof dc?.tracingChannel === 'function';
exports.CHANNELS = {
    // TracingChannel (async lifecycle)
    TRACE_COMMAND: 'node-redis:command',
    TRACE_BATCH: 'node-redis:batch',
    TRACE_CONNECT: 'node-redis:connect',
    // Point events (fire-and-forget)
    CONNECTION_READY: 'node-redis:connection:ready',
    CONNECTION_CLOSED: 'node-redis:connection:closed',
    CONNECTION_RELAXED_TIMEOUT: 'node-redis:connection:relaxed-timeout',
    CONNECTION_HANDOFF: 'node-redis:connection:handoff',
    ERROR: 'node-redis:error',
    MAINTENANCE: 'node-redis:maintenance',
    PUBSUB: 'node-redis:pubsub',
    CACHE_REQUEST: 'node-redis:cache:request',
    CACHE_EVICTION: 'node-redis:cache:eviction',
    COMMAND_REPLY: 'node-redis:command:reply',
    POOL_CONNECTION_WAIT: 'node-redis:pool:connection-wait',
};
/**
 * Argument sanitization rules adapted from @opentelemetry/redis-common (Apache 2.0).
 * Controls how many arguments after the command name are included in trace context.
 * https://github.com/open-telemetry/opentelemetry-js-contrib/blob/main/packages/redis-common/src/index.ts
 */
const SERIALIZATION_SUBSETS = [
    { regex: /^ECHO/i, args: 0 },
    { regex: /^(LPUSH|MSET|PFA|PUBLISH|RPUSH|SADD|SET|SPUBLISH|XADD|ZADD)/i, args: 1 },
    { regex: /^(HSET|HMSET|LSET|LINSERT)/i, args: 2 },
    { regex: /^(ACL|BIT|B[LRZ]|CLIENT|CLUSTER|CONFIG|COMMAND|DECR|DEL|EVAL|EX|FUNCTION|GEO|GET|HINCR|HMGET|HSCAN|INCR|L[TRLM]|MEMORY|P[EFISTU]|RPOP|S[CDIMORSU]|XACK|X[CDGILPRT]|Z[CDILMPRS])/i, args: -1 },
];
/**
 * Sanitizes the arguments of a command to remove sensitive information.
 */
function sanitizeArgs(args) {
    if (args.length === 0)
        return [];
    const commandName = String(args[0]);
    let allowedArgCount = 0; // default: command name only for unlisted commands
    for (const subset of SERIALIZATION_SUBSETS) {
        if (subset.regex.test(commandName)) {
            allowedArgCount = subset.args;
            break;
        }
    }
    // All args are safe (structural/read commands)
    if (allowedArgCount === -1) {
        return args.map(a => String(a));
    }
    const result = [commandName];
    for (let i = 1; i < args.length; i++) {
        if (i <= allowedArgCount) {
            result.push(String(args[i]));
        }
        else {
            result.push('?');
        }
    }
    return result;
}
exports.sanitizeArgs = sanitizeArgs;
// Eagerly resolve tracing channels at module load time.
// Check explicitly for `false` rather than truthiness because `hasSubscribers`
// is not available on all Node.js versions that support TracingChannel.
// When `hasSubscribers` is `undefined` (older Node), we assume there are
// subscribers and trace unconditionally, keeping the zero-cost optimization
// only for versions where we can reliably check.
const tracingChannels = hasTracingChannel ? {
    [exports.CHANNELS.TRACE_COMMAND]: dc.tracingChannel(exports.CHANNELS.TRACE_COMMAND),
    [exports.CHANNELS.TRACE_BATCH]: dc.tracingChannel(exports.CHANNELS.TRACE_BATCH),
    [exports.CHANNELS.TRACE_CONNECT]: dc.tracingChannel(exports.CHANNELS.TRACE_CONNECT),
} : undefined;
function getTracingChannel(name) {
    return tracingChannels?.[name];
}
exports.getTracingChannel = getTracingChannel;
function trace(name, fn, contextFactory) {
    const channel = tracingChannels?.[name];
    if (channel && channel.hasSubscribers !== false) {
        return channel.tracePromise(fn, contextFactory());
    }
    return fn();
}
exports.trace = trace;
// Eagerly resolve point-event channels at module load time
const pointChannels = dc?.channel ? {
    [exports.CHANNELS.CONNECTION_READY]: dc.channel(exports.CHANNELS.CONNECTION_READY),
    [exports.CHANNELS.CONNECTION_CLOSED]: dc.channel(exports.CHANNELS.CONNECTION_CLOSED),
    [exports.CHANNELS.CONNECTION_RELAXED_TIMEOUT]: dc.channel(exports.CHANNELS.CONNECTION_RELAXED_TIMEOUT),
    [exports.CHANNELS.CONNECTION_HANDOFF]: dc.channel(exports.CHANNELS.CONNECTION_HANDOFF),
    [exports.CHANNELS.ERROR]: dc.channel(exports.CHANNELS.ERROR),
    [exports.CHANNELS.MAINTENANCE]: dc.channel(exports.CHANNELS.MAINTENANCE),
    [exports.CHANNELS.PUBSUB]: dc.channel(exports.CHANNELS.PUBSUB),
    [exports.CHANNELS.CACHE_REQUEST]: dc.channel(exports.CHANNELS.CACHE_REQUEST),
    [exports.CHANNELS.CACHE_EVICTION]: dc.channel(exports.CHANNELS.CACHE_EVICTION),
    [exports.CHANNELS.COMMAND_REPLY]: dc.channel(exports.CHANNELS.COMMAND_REPLY),
    [exports.CHANNELS.POOL_CONNECTION_WAIT]: dc.channel(exports.CHANNELS.POOL_CONNECTION_WAIT),
} : undefined;
function getChannel(name) {
    return pointChannels?.[name];
}
exports.getChannel = getChannel;
function publish(name, factory) {
    const ch = pointChannels?.[name];
    if (ch?.hasSubscribers) {
        ch.publish(factory());
    }
}
exports.publish = publish;
//# sourceMappingURL=tracing.js.map