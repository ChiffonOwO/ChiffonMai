"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ClientRegistry = exports.OTelMetrics = exports.CSC_EVICTION_REASON = exports.CSC_RESULT = exports.CONNECTION_CLOSE_REASON = exports.OTEL_ATTRIBUTES = exports.OpenTelemetry = void 0;
const errors_1 = require("../errors");
const client_registry_1 = require("./client-registry");
const metrics_1 = require("./metrics");
class OpenTelemetry {
    static _instance = null;
    // Make sure it's a singleton
    constructor() { }
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
    static init(config) {
        if (OpenTelemetry._instance) {
            throw new errors_1.OpenTelemetryError("OpenTelemetry already initialized");
        }
        const api = (() => {
            try {
                return require("@opentelemetry/api");
            }
            catch {
                throw new errors_1.OpenTelemetryError("@opentelemetry/api not found");
            }
        })();
        OpenTelemetry._instance = new OpenTelemetry();
        client_registry_1.ClientRegistry.init();
        metrics_1.OTelMetrics.init({ api, config });
    }
}
exports.OpenTelemetry = OpenTelemetry;
var types_1 = require("./types");
Object.defineProperty(exports, "OTEL_ATTRIBUTES", { enumerable: true, get: function () { return types_1.OTEL_ATTRIBUTES; } });
Object.defineProperty(exports, "CONNECTION_CLOSE_REASON", { enumerable: true, get: function () { return types_1.CONNECTION_CLOSE_REASON; } });
Object.defineProperty(exports, "CSC_RESULT", { enumerable: true, get: function () { return types_1.CSC_RESULT; } });
Object.defineProperty(exports, "CSC_EVICTION_REASON", { enumerable: true, get: function () { return types_1.CSC_EVICTION_REASON; } });
var metrics_2 = require("./metrics");
Object.defineProperty(exports, "OTelMetrics", { enumerable: true, get: function () { return metrics_2.OTelMetrics; } });
var client_registry_2 = require("./client-registry");
Object.defineProperty(exports, "ClientRegistry", { enumerable: true, get: function () { return client_registry_2.ClientRegistry; } });
//# sourceMappingURL=index.js.map