import { MeterProvider, InMemoryMetricExporter, DataPoint } from "@opentelemetry/sdk-metrics";
/**
 * Waits for a given metric to be exported.
 * Returns the first metric data if the metrics is found, undefined otherwise.
 */
export declare const waitForMetrics: (meterProvider: MeterProvider, exporter: InMemoryMetricExporter, metricName: string, timeoutMs?: number) => Promise<import("@opentelemetry/sdk-metrics").MetricData | undefined>;
/**
 * Returns the data points for a given metric name.
 *
 * @throws Error if metric is not found
 */
export declare const getMetricDataPoints: <T>(resourceMetrics: ReturnType<InMemoryMetricExporter["getMetrics"]>, metricName: string) => DataPoint<T>[];
//# sourceMappingURL=test.util.d.ts.map