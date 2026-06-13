import { OTelClientAttributes } from "../types";
export { getErrorInfo, isRedirectionError } from "./error.util";
export type { ErrorInfo } from "./error.util";
export declare function noopFunction(): void;
export declare const parseClientAttributes: (clientAttributes?: OTelClientAttributes) => {
    "redis.client.parent.id"?: string | undefined;
    "db.client.connection.pool.name"?: string | undefined;
    "server.port"?: string | undefined;
    "server.address"?: string | undefined;
    "db.namespace"?: string | undefined;
};
//# sourceMappingURL=index.d.ts.map