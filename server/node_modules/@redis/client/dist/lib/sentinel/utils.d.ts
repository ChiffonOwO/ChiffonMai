import { ArrayReply, Command, RedisFunction, RedisScript, RespVersions, UnwrapReply } from '../RESP/types';
import { RedisSocketOptions } from '../client/socket';
import { NamespaceProxySentinel, NamespaceProxySentinelClient, NodeAddressMap, ProxySentinel, ProxySentinelClient, RedisNode } from './types';
export declare function parseNode(node: Record<string, string>): RedisNode | undefined;
export declare function createNodeList(nodes: UnwrapReply<ArrayReply<Record<string, string>>>): RedisNode[];
export declare function clientSocketToNode(socket: RedisSocketOptions): RedisNode;
export declare function createCommand<T extends ProxySentinel | ProxySentinelClient>(command: Command, resp: RespVersions): (this: T, ...args: Array<unknown>) => Promise<any>;
export declare function createFunctionCommand<T extends NamespaceProxySentinel | NamespaceProxySentinelClient>(name: string, fn: RedisFunction, resp: RespVersions): (this: T, ...args: Array<unknown>) => Promise<any>;
export declare function createModuleCommand<T extends NamespaceProxySentinel | NamespaceProxySentinelClient>(command: Command, resp: RespVersions): (this: T, ...args: Array<unknown>) => Promise<any>;
export declare function createScriptCommand<T extends ProxySentinel | ProxySentinelClient>(script: RedisScript, resp: RespVersions): (this: T, ...args: Array<unknown>) => Promise<any>;
/**
 * Returns the mapped node address for the given host and port using the nodeAddressMap.
 * If no mapping exists, returns the original host and port.
 *
 * @param host The original host
 * @param port The original port
 * @param nodeAddressMap The node address map (object or function)
 * @returns The mapped node or the original node if no mapping exists
 */
export declare function getMappedNode(host: string, port: number, nodeAddressMap: NodeAddressMap | undefined): RedisNode;
//# sourceMappingURL=utils.d.ts.map