import { CommandParser } from '../client/parser';
import { BlobStringReply } from '../RESP/types';
declare const _default: {
    readonly NOT_KEYED_COMMAND: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, version?: number, ...optionalArguments: Array<number>) => void;
    readonly transformReply: () => BlobStringReply;
};
export default _default;
//# sourceMappingURL=LOLWUT.d.ts.map