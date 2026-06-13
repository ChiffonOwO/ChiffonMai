import { CommandParser } from '../client/parser';
import { RedisArgument, BlobStringReply } from '../RESP/types';
declare const _default: {
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, increment: number) => void;
    readonly transformReply: () => BlobStringReply;
};
export default _default;
//# sourceMappingURL=INCRBYFLOAT.d.ts.map