import { CommandParser } from '../client/parser';
import { RedisVariadicArgument } from './generic-transformers';
declare const _default: {
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisVariadicArgument, timeout: number) => void;
    readonly transformReply: (this: void, reply: import("../RESP/types").UnwrapReply<import("../RESP/types").NullReply | import("../RESP/types").TuplesReply<[import("../RESP/types").BlobStringReply<string>, import("../RESP/types").BlobStringReply<string>]>>) => {
        key: import("../RESP/types").BlobStringReply<string>;
        element: import("../RESP/types").BlobStringReply<string>;
    } | null;
};
export default _default;
//# sourceMappingURL=BRPOP.d.ts.map