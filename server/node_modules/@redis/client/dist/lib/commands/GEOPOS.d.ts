import { CommandParser } from '../client/parser';
import { RedisArgument, ArrayReply, TuplesReply, BlobStringReply, NullReply, UnwrapReply } from '../RESP/types';
import { RedisVariadicArgument } from './generic-transformers';
declare const _default: {
    readonly CACHEABLE: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, member: RedisVariadicArgument) => void;
    readonly transformReply: (this: void, reply: UnwrapReply<ArrayReply<TuplesReply<[BlobStringReply, BlobStringReply]> | NullReply>>) => ({
        longitude: BlobStringReply<string>;
        latitude: BlobStringReply<string>;
    } | null)[];
};
export default _default;
//# sourceMappingURL=GEOPOS.d.ts.map