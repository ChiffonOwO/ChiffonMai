import { CommandParser } from '../client/parser';
import { SimpleStringReply } from '../RESP/types';
export interface ClusterResetOptions {
    mode?: 'HARD' | 'SOFT';
}
declare const _default: {
    readonly NOT_KEYED_COMMAND: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, options?: ClusterResetOptions) => void;
    readonly transformReply: () => SimpleStringReply<'OK'>;
};
export default _default;
//# sourceMappingURL=CLUSTER_RESET.d.ts.map