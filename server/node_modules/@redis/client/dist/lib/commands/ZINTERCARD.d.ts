import { CommandParser } from '../client/parser';
import { NumberReply } from '../RESP/types';
import { RedisVariadicArgument } from './generic-transformers';
export interface ZInterCardOptions {
    LIMIT?: number;
}
declare const _default: {
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, keys: RedisVariadicArgument, options?: ZInterCardOptions['LIMIT'] | ZInterCardOptions) => void;
    readonly transformReply: () => NumberReply;
};
export default _default;
//# sourceMappingURL=ZINTERCARD.d.ts.map