import { CommandParser } from '../client/parser';
import { RedisVariadicArgument } from './generic-transformers';
import { ArrayReply, BlobStringReply, NullReply, RedisArgument } from '../RESP/types';
export interface HGetExOptions {
    expiration?: {
        type: 'EX' | 'PX' | 'EXAT' | 'PXAT';
        value: number;
    } | {
        type: 'PERSIST';
    } | 'PERSIST';
}
declare const _default: {
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, fields: RedisVariadicArgument, options?: HGetExOptions) => void;
    readonly transformReply: () => ArrayReply<BlobStringReply | NullReply>;
};
export default _default;
//# sourceMappingURL=HGETEX.d.ts.map