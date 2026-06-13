import { CommandParser } from '../client/parser';
import { RedisArgument, BlobStringReply } from '../RESP/types';
declare const _default: {
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key1: RedisArgument, key2: RedisArgument) => void;
    readonly transformReply: () => BlobStringReply;
};
export default _default;
//# sourceMappingURL=LCS.d.ts.map