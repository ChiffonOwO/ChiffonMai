import { CommandParser } from "@redis/client/dist/lib/client/parser";
import { RedisArgument } from "@redis/client/dist/lib/RESP/types";
type RESPReply = Array<string | number | RESPReply>;
declare const _default: {
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, path?: string) => void;
    readonly transformReply: () => RESPReply;
};
export default _default;
//# sourceMappingURL=RESP.d.ts.map