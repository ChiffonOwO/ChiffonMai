import { CommandParser } from '../client/parser';
import { RedisArgument, ArrayReply, BlobStringReply, NullReply } from '../RESP/types';
import { RedisVariadicArgument } from './generic-transformers';
declare const _default: {
    readonly CACHEABLE: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, fields: RedisVariadicArgument) => void;
    readonly transformReply: () => ArrayReply<BlobStringReply | NullReply>;
};
export default _default;
//# sourceMappingURL=HMGET.d.ts.map