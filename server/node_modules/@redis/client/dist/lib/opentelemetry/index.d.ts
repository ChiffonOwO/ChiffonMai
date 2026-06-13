import { ObservabilityConfig } from "./types";
export declare class OpenTelemetry {
    private static _instance;
    private constructor();
    /**
     * Initializes node-redis OpenTelemetry observability.
     *
     * This bootstraps node-redis metrics instrumentation and registers the
     * internal client registry used by metric collectors.
     *
     * Call this once during application startup, before creating Redis clients
     * you want to observe.
     *
     * @param config - Observability configuration.
     *
     * @remarks Requires Node.js >= 18.19.0.
     *
     * @throws {OpenTelemetryError} If OpenTelemetry is already initialized.
     * @throws {OpenTelemetryError} If `@opentelemetry/api` is not installed.
     *
     * @example
     * ```ts
     * import { metrics } from "@opentelemetry/api";
     * import {
     *   ConsoleMetricExporter,
     *   MeterProvider,
     *   PeriodicExportingMetricReader
     * } from "@opentelemetry/sdk-metrics";
     * import { OpenTelemetry } from "redis";
     *
     * const reader = new PeriodicExportingMetricReader({
     *   exporter: new ConsoleMetricExporter()
     * });
     *
     * const provider = new MeterProvider({ readers: [reader] });
     * metrics.setGlobalMeterProvider(provider);
     *
     * OpenTelemetry.init({
     *   metrics: {
     *     enabled: true,
     *     enabledMetricGroups: ["pubsub", "connection-basic", "resiliency"],
     *     includeCommands: ["GET", "SET"],
     *     hidePubSubChannelNames: true
     *   }
     * });
     * ```
     */
    static init(config: ObservabilityConfig): void;
}
export { OTelClientAttributes, OTEL_ATTRIBUTES, CONNECTION_CLOSE_REASON, CSC_RESULT, CSC_EVICTION_REASON, } from "./types";
export { OTelMetrics } from "./metrics";
export { ClientRegistry, ClientMetricsHandle, IClientRegistry, } from "./client-registry";
//# sourceMappingURL=index.d.ts.map