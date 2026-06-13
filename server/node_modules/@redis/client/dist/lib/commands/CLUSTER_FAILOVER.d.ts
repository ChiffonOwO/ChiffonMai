import { CommandParser } from '../client/parser';
import { SimpleStringReply } from '../RESP/types';
export declare const FAILOVER_MODES: {
    readonly FORCE: "FORCE";
    readonly TAKEOVER: "TAKEOVER";
};
export type FailoverMode = typeof FAILOVER_MODES[keyof typeof FAILOVER_MODES];
export interface ClusterFailoverOptions {
    mode?: FailoverMode;
}
declare const _default: {
    readonly NOT_KEYED_COMMAND: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, options?: ClusterFailoverOptions) => void;
    readonly transformReply: () => SimpleStringReply<'OK'>;
};
export default _default;
//# sourceMappingURL=CLUSTER_FAILOVER.d.ts.map