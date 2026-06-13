import { NullReply, ArrayReply, BlobStringReply, UnwrapReply } from '@redis/client/dist/lib/RESP/types';
declare const _default: {
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: import("@redis/client").CommandParser, key: import("@redis/client/dist/lib/RESP/types").RedisArgument, prefix: import("@redis/client/dist/lib/RESP/types").RedisArgument, options?: import("./SUGGET").FtSugGetOptions | undefined) => void;
    readonly transformReply: (this: void, reply: NullReply | UnwrapReply<ArrayReply<BlobStringReply>>) => {
        suggestion: BlobStringReply;
        payload: BlobStringReply;
    }[] | null;
};
export default _default;
//# sourceMappingURL=SUGGET_WITHPAYLOADS.d.ts.map