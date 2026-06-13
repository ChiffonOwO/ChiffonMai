import { CommandParser } from '../client/parser';
import { SimpleStringReply } from '../RESP/types';
import { SlotRange } from './generic-transformers';
declare const _default: {
    readonly NOT_KEYED_COMMAND: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, ranges: SlotRange | Array<SlotRange>) => void;
    readonly transformReply: () => SimpleStringReply<'OK'>;
};
export default _default;
//# sourceMappingURL=CLUSTER_DELSLOTSRANGE.d.ts.map