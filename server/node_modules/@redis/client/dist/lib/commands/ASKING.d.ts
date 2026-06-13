import { CommandParser } from '../client/parser';
import { SimpleStringReply } from '../RESP/types';
export declare const ASKING_CMD = "ASKING";
declare const _default: {
    readonly NOT_KEYED_COMMAND: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser) => void;
    readonly transformReply: () => SimpleStringReply<'OK'>;
};
export default _default;
//# sourceMappingURL=ASKING.d.ts.map