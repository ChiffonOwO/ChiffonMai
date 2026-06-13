import { CommandParser } from '../client/parser';
import { UnwrapReply, NullReply, TuplesReply, BlobStringReply } from '../RESP/types';
import { RedisVariadicArgument } from './generic-transformers';
declare const _default: {
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisVariadicArgument, timeout: number) => void;
    readonly transformReply: (this: void, reply: UnwrapReply<NullReply | TuplesReply<[BlobStringReply, BlobStringReply]>>) => {
        key: BlobStringReply<string>;
        element: BlobStringReply<string>;
    } | null;
};
export default _default;
//# sourceMappingURL=BLPOP.d.ts.map