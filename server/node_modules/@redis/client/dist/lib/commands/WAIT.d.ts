import { CommandParser } from '../client/parser';
import { NumberReply } from '../RESP/types';
declare const _default: {
    readonly NOT_KEYED_COMMAND: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, numberOfReplicas: number, timeout: number) => void;
    readonly transformReply: () => NumberReply;
};
export default _default;
//# sourceMappingURL=WAIT.d.ts.map