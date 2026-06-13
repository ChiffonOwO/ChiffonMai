import { CommandParser } from '@redis/client/dist/lib/client/parser';
import { NullReply, BlobStringReply, ArrayReply, RedisArgument, UnwrapReply } from '@redis/client/dist/lib/RESP/types';
export interface JsonTypeOptions {
    path?: RedisArgument;
}
declare const _default: {
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, options?: JsonTypeOptions) => void;
    readonly transformReply: {
        readonly 2: () => NullReply | BlobStringReply | ArrayReply<BlobStringReply | NullReply>;
        readonly 3: (reply: UnwrapReply<ArrayReply<NullReply | BlobStringReply | ArrayReply<BlobStringReply | NullReply>>>) => NullReply | BlobStringReply<string> | ArrayReply<NullReply | BlobStringReply<string>>;
    };
};
export default _default;
//# sourceMappingURL=TYPE.d.ts.map