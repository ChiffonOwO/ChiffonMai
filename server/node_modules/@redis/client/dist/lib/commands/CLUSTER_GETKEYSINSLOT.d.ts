import { CommandParser } from '../client/parser';
import { ArrayReply, BlobStringReply } from '../RESP/types';
declare const _default: {
    readonly NOT_KEYED_COMMAND: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, slot: number, count: number) => void;
    readonly transformReply: () => ArrayReply<BlobStringReply>;
};
export default _default;
//# sourceMappingURL=CLUSTER_GETKEYSINSLOT.d.ts.map