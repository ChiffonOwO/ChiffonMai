import { CommandParser } from '../client/parser';
import { RedisArgument, BlobStringReply, NullReply } from '../RESP/types';
declare const _default: {
    readonly parseCommand: (this: void, parser: CommandParser, source: RedisArgument, destination: RedisArgument) => void;
    readonly transformReply: () => BlobStringReply | NullReply;
};
export default _default;
//# sourceMappingURL=RPOPLPUSH.d.ts.map