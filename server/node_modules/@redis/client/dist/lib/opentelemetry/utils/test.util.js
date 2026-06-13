"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getMetricDataPoints = exports.waitForMetrics = void 0;
/**
 * Waits for a given metric to be exported.
 * Returns the first metric data if the metrics is found, undefined otherwise.
 */
const waitForMetrics = async (meterProvider, exporter, metricName, timeoutMs = 1000) => {
    const startTime = performance.now();
    while (performance.now() - startTime < timeoutMs) {
        await meterProvider.forceFlush();
        const resourceMetrics = exporter.getMetrics();
        const metric = resourceMetrics
            .flatMap((rm) => rm.scopeMetrics)
            .flatMap((sm) => sm.metrics)
            .find((m) => m.descriptor.name === metricName);
        if (metric) {
            return metric;
        }
        await new Promise((resolve) => setTimeout(resolve, 100));
    }
};
exports.waitForMetrics = waitForMetrics;
/**
 * Returns the data points for a given metric name.
 *
 * @throws Error if metric is not found
 */
const getMetricDataPoints = (resourceMetrics, metricName) => {
    const metric = resourceMetrics
        .flatMap((rm) => rm.scopeMetrics)
        .flatMap((sm) => sm.metrics)
        .find((m) => m.descriptor.name === metricName);
    if (!metric) {
        throw new Error(`expected ${metricName} metric to be present`);
    }
    return metric.dataPoints;
};
exports.getMetricDataPoints = getMetricDataPoints;
//# sourceMappingURL=test.util.js.map