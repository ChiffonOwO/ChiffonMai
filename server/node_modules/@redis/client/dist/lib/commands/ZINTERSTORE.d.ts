import { CommandParser } from '../client/parser';
import { RedisArgument, NumberReply } from '../RESP/types';
import { ZKeys } from './generic-transformers';
import { ZInterOptions } from './ZINTER';
declare const _default: {
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, destination: RedisArgument, keys: ZKeys, options?: ZInterOptions) => void;
    readonly transformReply: () => NumberReply;
};
export default _default;
//# sourceMappingURL=ZINTERSTORE.d.ts.map