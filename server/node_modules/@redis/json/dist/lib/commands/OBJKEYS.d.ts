import { CommandParser } from '@redis/client/dist/lib/client/parser';
import { RedisArgument, ArrayReply, BlobStringReply, NullReply } from '@redis/client/dist/lib/RESP/types';
export interface JsonObjKeysOptions {
    path?: RedisArgument;
}
declare const _default: {
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, options?: JsonObjKeysOptions) => void;
    readonly transformReply: () => ArrayReply<BlobStringReply> | ArrayReply<ArrayReply<BlobStringReply> | NullReply>;
};
export default _default;
//# sourceMappingURL=OBJKEYS.d.ts.map