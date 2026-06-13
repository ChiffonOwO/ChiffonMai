import { CommandParser } from '../client/parser';
import { NullReply, TuplesReply, BlobStringReply } from '../RESP/types';
import { ListSide, RedisVariadicArgument, Tail } from './generic-transformers';
export interface LMPopOptions {
    COUNT?: number;
}
export declare function parseLMPopArguments(parser: CommandParser, keys: RedisVariadicArgument, side: ListSide, options?: LMPopOptions): void;
export type LMPopArguments = Tail<Parameters<typeof parseLMPopArguments>>;
declare const _default: {
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, keys: RedisVariadicArgument, side: ListSide, options?: LMPopOptions | undefined) => void;
    readonly transformReply: () => NullReply | TuplesReply<[
        key: BlobStringReply,
        elements: Array<BlobStringReply>
    ]>;
};
export default _default;
//# sourceMappingURL=LMPOP.d.ts.map