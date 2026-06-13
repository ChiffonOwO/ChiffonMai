import { CommandParser } from '../client/parser';
import { SimpleStringReply } from '../RESP/types';
declare const _default: {
    readonly NOT_KEYED_COMMAND: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser) => void;
    readonly transformReply: () => SimpleStringReply<'BUMPED' | 'STILL'>;
};
export default _default;
//# sourceMappingURL=CLUSTER_BUMPEPOCH.d.ts.map