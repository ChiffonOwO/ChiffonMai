import { CommandParser } from '../client/parser';
import { RedisArgument, SimpleStringReply } from '../RESP/types';
import { RedisVariadicArgument } from './generic-transformers';
declare const _default: {
    readonly parseCommand: (this: void, parser: CommandParser, destination: RedisArgument, sources?: RedisVariadicArgument) => void;
    readonly transformReply: () => SimpleStringReply;
};
export default _default;
//# sourceMappingURL=PFMERGE.d.ts.map