import { ClientIdentity } from '../client/identity';
import { OTelClientAttributes } from './types';
/**
 * Handle representing a client for metrics collection.
 * Each registered client provides this interface to expose its identity and attributes.
 */
export interface ClientMetricsHandle {
    /**
     * The client's identity (id, role, parentId).
     */
    readonly identity: ClientIdentity;
    /**
     * Returns the current client attributes (host, port, db).
     * Called dynamically to get up-to-date values.
     */
    getAttributes(): OTelClientAttributes;
    /**
     * Returns the current number of pending requests (commands waiting to write + waiting for reply).
     */
    getPendingRequests(): number;
    /**
     * Returns the current number of items in the client-side cache.
     * Returns 0 if client-side caching is not enabled.
     */
    getCacheItemCount(): number;
    /**
     * Returns whether the client has an active connection.
     * Used to determine if metrics should be recorded for this client.
     */
    isConnected(): boolean;
}
/**
 * Registry interface for tracking Redis clients.
 * Used by observable gauge callbacks to iterate over all registered clients.
 */
export interface IClientRegistry {
    /**
     * Register a client for metrics tracking.
     */
    register(handle: ClientMetricsHandle): void;
    /**
     * Unregister a client by its ID.
     */
    unregister(clientId: string): void;
    /**
     * Get a registered client handle by ID.
     */
    getById(clientId: string): ClientMetricsHandle | undefined;
    /**
     * Get all registered client handles.
     */
    getAll(): Iterable<ClientMetricsHandle>;
}
/**
 * Singleton manager for the client registry.
 * Starts with a NoOp registry and can be initialized to use the real implementation.
 */
export declare class ClientRegistry {
    #private;
    private constructor();
    /**
     * Initialize the client registry with the real implementation.
     * Should be called from OpenTelemetry.init().
     */
    static init(): void;
    /**
     * Get the current registry instance.
     * Returns NoOp registry if not initialized, real registry otherwise.
     */
    static get instance(): IClientRegistry;
    /**
     * Check if the registry has been initialized.
     */
    static isInitialized(): boolean;
    /**
     * Reset the registry to its initial state (NoOp).
     * Only for testing purposes.
     * @internal
     */
    static reset(): void;
}
//# sourceMappingURL=client-registry.d.ts.map