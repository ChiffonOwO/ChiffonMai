import { CommandParser } from '../client/parser';
import { SimpleStringReply } from '../RESP/types';
import { MSetArguments } from './MSET';
declare const _default: {
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, toSet: MSetArguments) => void;
    readonly transformReply: () => SimpleStringReply<'OK'>;
};
export default _default;
//# sourceMappingURL=MSETNX.d.ts.map