/// <reference types="node" />
import type * as DC from 'node:diagnostics_channel';
export declare const CHANNELS: {
    readonly TRACE_COMMAND: "node-redis:command";
    readonly TRACE_BATCH: "node-redis:batch";
    readonly TRACE_CONNECT: "node-redis:connect";
    readonly CONNECTION_READY: "node-redis:connection:ready";
    readonly CONNECTION_CLOSED: "node-redis:connection:closed";
    readonly CONNECTION_RELAXED_TIMEOUT: "node-redis:connection:relaxed-timeout";
    readonly CONNECTION_HANDOFF: "node-redis:connection:handoff";
    readonly ERROR: "node-redis:error";
    readonly MAINTENANCE: "node-redis:maintenance";
    readonly PUBSUB: "node-redis:pubsub";
    readonly CACHE_REQUEST: "node-redis:cache:request";
    readonly CACHE_EVICTION: "node-redis:cache:eviction";
    readonly COMMAND_REPLY: "node-redis:command:reply";
    readonly POOL_CONNECTION_WAIT: "node-redis:pool:connection-wait";
};
/**
 * Sanitizes the arguments of a command to remove sensitive information.
 */
export declare function sanitizeArgs(args: ReadonlyArray<unknown>): ReadonlyArray<string>;
export interface CommandTraceContext {
    command: string;
    args: ReadonlyArray<string>;
    database: number;
    serverAddress: string;
    serverPort: number | undefined;
    clientId: string;
}
export interface BatchCommandTraceContext extends CommandTraceContext {
    batchMode: 'MULTI' | 'PIPELINE';
    batchSize: number;
}
export interface ConnectTraceContext {
    serverAddress: string;
    serverPort: number | undefined;
    clientId: string;
}
export interface BatchOperationContext {
    batchMode: 'MULTI' | 'PIPELINE';
    batchSize: number;
    database: number;
    serverAddress: string;
    serverPort: number | undefined;
    clientId: string;
}
type CommandContext = CommandTraceContext | BatchCommandTraceContext;
interface TracingChannelContextMap {
    [CHANNELS.TRACE_COMMAND]: CommandContext;
    [CHANNELS.TRACE_BATCH]: BatchOperationContext;
    [CHANNELS.TRACE_CONNECT]: ConnectTraceContext;
}
export declare function getTracingChannel<K extends keyof TracingChannelContextMap>(name: K): DC.TracingChannel<TracingChannelContextMap[K]> | undefined;
export declare function trace<K extends keyof TracingChannelContextMap, T>(name: K, fn: () => Promise<T>, contextFactory: () => TracingChannelContextMap[K]): Promise<T>;
export interface ConnectionReadyEvent {
    clientId: string;
    serverAddress: string | undefined;
    serverPort: number | undefined;
    createTimeMs: number;
}
export interface ConnectionClosedEvent {
    clientId: string;
    reason: string;
    wasConnected: boolean;
}
export interface ConnectionRelaxedTimeoutEvent {
    clientId: string;
    value: number;
}
export interface ConnectionHandoffEvent {
    clientId: string;
}
export interface ClientErrorEvent {
    error: Error;
    origin: string;
    internal: boolean;
    clientId?: string;
    retryCount?: number;
}
export interface MaintenanceNotificationEvent {
    notification: string;
    clientId?: string;
}
export interface PubSubMessageEvent {
    direction: 'in' | 'out';
    clientId: string;
    channel?: unknown;
    sharded?: boolean;
}
export interface CacheRequestEvent {
    result: string;
    clientId?: string;
}
export interface CacheEvictionEvent {
    reason: string;
    count: number;
    clientId?: string;
}
export interface CommandReplyEvent {
    args: ReadonlyArray<unknown>;
    reply: unknown;
    clientId: string;
}
export interface PoolConnectionWaitEvent {
    clientId: string;
    waitStartTimestamp: number;
}
export interface ChannelEvents {
    [CHANNELS.CONNECTION_READY]: ConnectionReadyEvent;
    [CHANNELS.CONNECTION_CLOSED]: ConnectionClosedEvent;
    [CHANNELS.CONNECTION_RELAXED_TIMEOUT]: ConnectionRelaxedTimeoutEvent;
    [CHANNELS.CONNECTION_HANDOFF]: ConnectionHandoffEvent;
    [CHANNELS.ERROR]: ClientErrorEvent;
    [CHANNELS.MAINTENANCE]: MaintenanceNotificationEvent;
    [CHANNELS.PUBSUB]: PubSubMessageEvent;
    [CHANNELS.CACHE_REQUEST]: CacheRequestEvent;
    [CHANNELS.CACHE_EVICTION]: CacheEvictionEvent;
    [CHANNELS.COMMAND_REPLY]: CommandReplyEvent;
    [CHANNELS.POOL_CONNECTION_WAIT]: PoolConnectionWaitEvent;
}
interface Channel {
    readonly hasSubscribers: boolean;
    publish(message: unknown): void;
    subscribe(handler: (message: any) => void): void;
    unsubscribe(handler: (message: any) => void): void;
}
export declare function getChannel(name: string): Channel | undefined;
export declare function publish<K extends keyof ChannelEvents>(name: K, factory: () => ChannelEvents[K]): void;
export {};
//# sourceMappingURL=tracing.d.ts.map