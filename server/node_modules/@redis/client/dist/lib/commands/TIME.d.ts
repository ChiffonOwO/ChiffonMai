import { CommandParser } from '../client/parser';
import { BlobStringReply } from '../RESP/types';
declare const _default: {
    readonly NOT_KEYED_COMMAND: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser) => void;
    readonly transformReply: () => [
        unixTimestamp: BlobStringReply<`${number}`>,
        microseconds: BlobStringReply<`${number}`>
    ];
};
export default _default;
//# sourceMappingURL=TIME.d.ts.map