import {
  PublicClient,
  encodeFunctionData,
  EncodeFunctionDataParameters,
  Address,
  Chain,
  Transport,
} from 'viem';

import { arbOwnerABI, arbOwnerAddress } from './contracts/ArbOwner';
import { upgradeExecutorEncodeFunctionData } from './upgradeExecutorEncodeFunctionData';
import { GetFunctionName } from './types/utils';

type ArbOwnerAbi = typeof arbOwnerABI;
export type ArbOwnerPrepareTransactionRequestFunctionName = GetFunctionName<ArbOwnerAbi>;
export type ArbOwnerEncodeFunctionDataParameters<
  TFunctionName extends ArbOwnerPrepareTransactionRequestFunctionName,
> = EncodeFunctionDataParameters<ArbOwnerAbi, TFunctionName>;

function arbOwnerEncodeFunctionData<
  TFunctionName extends ArbOwnerPrepareTransactionRequestFunctionName,
>({ functionName, abi, args }: ArbOwnerEncodeFunctionDataParameters<TFunctionName>) {
  return encodeFunctionData({
    abi,
    functionName,
    args,
  });
}

export type ArbOwnerPrepareFunctionDataParameters<
  TFunctionName extends ArbOwnerPrepareTransactionRequestFunctionName,
> = ArbOwnerEncodeFunctionDataParameters<TFunctionName> & {
  upgradeExecutor: Address | false;
  abi: ArbOwnerAbi;
};

export function arbOwnerPrepareFunctionData<
  TFunctionName extends ArbOwnerPrepareTransactionRequestFunctionName,
>(params: ArbOwnerPrepareFunctionDataParameters<TFunctionName>) {
  const { upgradeExecutor } = params;

  if (!upgradeExecutor) {
    return {
      to: arbOwnerAddress,
      data: arbOwnerEncodeFunctionData(
        params as ArbOwnerEncodeFunctionDataParameters<TFunctionName>,
      ),
      value: BigInt(0),
    };
  }

  return {
    to: upgradeExecutor,
    data: upgradeExecutorEncodeFunctionData({
      functionName: 'executeCall',
      args: [
        arbOwnerAddress, // target
        arbOwnerEncodeFunctionData(params as ArbOwnerEncodeFunctionDataParameters<TFunctionName>), // targetCallData
      ],
    }),
    value: BigInt(0),
  };
}

export type ArbOwnerPrepareTransactionRequestParameters<
  TFunctionName extends ArbOwnerPrepareTransactionRequestFunctionName,
> = Omit<ArbOwnerPrepareFunctionDataParameters<TFunctionName>, 'abi'> & {
  account: Address;
};

export async function arbOwnerPrepareTransactionRequest<
  TFunctionName extends ArbOwnerPrepareTransactionRequestFunctionName,
  TChain extends Chain | undefined,
>(
  client: PublicClient<Transport, TChain>,
  params: ArbOwnerPrepareTransactionRequestParameters<TFunctionName>,
) {
  if (typeof client.chain === 'undefined') {
    throw new Error('[arbOwnerPrepareTransactionRequest] client.chain is undefined');
  }

  // params is extending ArbOwnerPrepareFunctionDataParameters, it's safe to cast
  const { to, data, value } = arbOwnerPrepareFunctionData({
    ...params,
    abi: arbOwnerABI,
  } as unknown as ArbOwnerPrepareFunctionDataParameters<TFunctionName>);

  // @ts-ignore (todo: fix viem type issue)
  const request = await client.prepareTransactionRequest({
    chain: client.chain,
    to,
    data,
    value,
    account: params.account,
  });

  return { ...request, chainId: client.chain.id };
}
