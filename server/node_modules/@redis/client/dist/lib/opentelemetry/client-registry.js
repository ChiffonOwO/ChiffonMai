"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ClientRegistry = void 0;
/**
 * No-op implementation of the client registry.
 * Used when OpenTelemetry is not initialized to avoid overhead.
 */
class NoOpClientRegistry {
    register(_handle) {
        // No-op
    }
    unregister(_clientId) {
        // No-op
    }
    getById(_clientId) {
        return undefined;
    }
    getAll() {
        return [];
    }
}
/**
 * Real implementation of the client registry.
 * Tracks all registered clients in a Map keyed by client ID.
 */
class ClientRegistryImpl {
    #clients = new Map();
    register(handle) {
        this.#clients.set(handle.identity.id, handle);
    }
    unregister(clientId) {
        this.#clients.delete(clientId);
    }
    getById(clientId) {
        return this.#clients.get(clientId);
    }
    getAll() {
        return this.#clients.values();
    }
}
/**
 * Singleton manager for the client registry.
 * Starts with a NoOp registry and can be initialized to use the real implementation.
 */
class ClientRegistry {
    static #instance = new NoOpClientRegistry();
    static #initialized = false;
    constructor() { }
    /**
     * Initialize the client registry with the real implementation.
     * Should be called from OpenTelemetry.init().
     */
    static init() {
        if (ClientRegistry.#initialized) {
            return;
        }
        ClientRegistry.#instance = new ClientRegistryImpl();
        ClientRegistry.#initialized = true;
    }
    /**
     * Get the current registry instance.
     * Returns NoOp registry if not initialized, real registry otherwise.
     */
    static get instance() {
        return ClientRegistry.#instance;
    }
    /**
     * Check if the registry has been initialized.
     */
    static isInitialized() {
        return ClientRegistry.#initialized;
    }
    /**
     * Reset the registry to its initial state (NoOp).
     * Only for testing purposes.
     * @internal
     */
    static reset() {
        ClientRegistry.#instance = new NoOpClientRegistry();
        ClientRegistry.#initialized = false;
    }
}
exports.ClientRegistry = ClientRegistry;
//# sourceMappingURL=client-registry.js.map