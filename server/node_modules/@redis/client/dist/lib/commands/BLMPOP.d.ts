import { CommandParser } from '../client/parser';
declare const _default: {
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, timeout: number, keys: import("./generic-transformers").RedisVariadicArgument, side: import("./generic-transformers").ListSide, options?: import("./LMPOP").LMPopOptions | undefined) => void;
    readonly transformReply: () => import("../RESP/types").NullReply | import("../RESP/types").TuplesReply<[key: import("../RESP/types").BlobStringReply<string>, elements: import("../RESP/types").BlobStringReply<string>[]]>;
};
export default _default;
//# sourceMappingURL=BLMPOP.d.ts.map