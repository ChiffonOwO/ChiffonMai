import { CommandParser } from '../client/parser';
import { RedisArgument, SimpleStringReply } from '../RESP/types';
export declare const CLUSTER_SLOT_STATES: {
    readonly IMPORTING: "IMPORTING";
    readonly MIGRATING: "MIGRATING";
    readonly STABLE: "STABLE";
    readonly NODE: "NODE";
};
export type ClusterSlotState = typeof CLUSTER_SLOT_STATES[keyof typeof CLUSTER_SLOT_STATES];
declare const _default: {
    readonly NOT_KEYED_COMMAND: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, slot: number, state: ClusterSlotState, nodeId?: RedisArgument) => void;
    readonly transformReply: () => SimpleStringReply<'OK'>;
};
export default _default;
//# sourceMappingURL=CLUSTER_SETSLOT.d.ts.map