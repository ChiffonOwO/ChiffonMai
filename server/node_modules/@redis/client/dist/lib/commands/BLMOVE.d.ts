import { CommandParser } from '../client/parser';
import { RedisArgument, BlobStringReply, NullReply } from '../RESP/types';
import { ListSide } from './generic-transformers';
declare const _default: {
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, source: RedisArgument, destination: RedisArgument, sourceSide: ListSide, destinationSide: ListSide, timeout: number) => void;
    readonly transformReply: () => BlobStringReply | NullReply;
};
export default _default;
//# sourceMappingURL=BLMOVE.d.ts.map