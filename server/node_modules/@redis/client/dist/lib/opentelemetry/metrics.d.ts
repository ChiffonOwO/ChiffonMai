import { ObservabilityConfig, OpenTelemetryApiModule, IOTelCommandMetrics } from "./types";
export declare class OTelMetrics {
    #private;
    readonly commandMetrics: IOTelCommandMetrics;
    private constructor();
    static init({ api, config, }: {
        api: OpenTelemetryApiModule;
        config?: ObservabilityConfig;
    }): void;
    /**
     * Reset the instance to noop. Used for testing.
     *
     * @internal
     */
    static reset(): void;
    static isInitialized(): boolean;
    static get instance(): OTelMetrics;
    private parseOptions;
    private createHistogram;
    private createCounter;
    private createUpDownCounter;
    private createObservableGaugeWithCallback;
    private registerInstruments;
}
//# sourceMappingURL=metrics.d.ts.map