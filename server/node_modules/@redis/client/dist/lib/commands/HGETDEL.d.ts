import { CommandParser } from '../client/parser';
import { RedisVariadicArgument } from './generic-transformers';
import { RedisArgument, ArrayReply, BlobStringReply, NullReply } from '../RESP/types';
declare const _default: {
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, fields: RedisVariadicArgument) => void;
    readonly transformReply: () => ArrayReply<BlobStringReply | NullReply>;
};
export default _default;
//# sourceMappingURL=HGETDEL.d.ts.map