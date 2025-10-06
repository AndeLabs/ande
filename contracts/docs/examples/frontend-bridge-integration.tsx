/**
 * Frontend Bridge Integration Example
 * Complete implementation for AndeChain xERC20 bridge
 */

import { useState } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useReadContract, useSwitchChain } from 'wagmi';
import { parseEther, formatEther, Address } from 'viem';
import { toast } from 'sonner';

// Configuration
const BRIDGE_CONFIG = {
  andechain: {
    chainId: 999,
    bridge: '0x...' as Address,
    tokens: { xANDE: '0x...' as Address, AUSD: '0x...' as Address, ABOB: '0x...' as Address },
  },
  ethereum: {
    chainId: 1,
    bridge: '0x...' as Address,
    tokens: { xANDE: '0x...' as Address, AUSD: '0x...' as Address, ABOB: '0x...' as Address },
  },
};

const XERC20_ABI = [
  { inputs: [{ name: 'spender', type: 'address' }, { name: 'amount', type: 'uint256' }], name: 'approve', outputs: [{ name: '', type: 'bool' }], stateMutability: 'nonpayable', type: 'function' },
  { inputs: [{ name: 'account', type: 'address' }], name: 'balanceOf', outputs: [{ name: '', type: 'uint256' }], stateMutability: 'view', type: 'function' },
  { inputs: [{ name: 'owner', type: 'address' }, { name: 'spender', type: 'address' }], name: 'allowance', outputs: [{ name: '', type: 'uint256' }], stateMutability: 'view', type: 'function' },
] as const;

const BRIDGE_ABI = [
  { inputs: [{ name: 'token', type: 'address' }, { name: 'recipient', type: 'address' }, { name: 'amount', type: 'uint256' }, { name: 'destinationChain', type: 'uint256' }], name: 'bridgeTokens', outputs: [], stateMutability: 'nonpayable', type: 'function' },
  { inputs: [{ name: 'bridge', type: 'address' }], name: 'mintingCurrentLimitOf', outputs: [{ name: '', type: 'uint256' }], stateMutability: 'view', type: 'function' },
] as const;

export function BridgeWidget() {
  const { address, chain } = useAccount();
  const { switchChain } = useSwitchChain();
  const [formData, setFormData] = useState({ sourceChain: 'andechain' as const, destinationChain: 'ethereum' as const, token: 'xANDE' as const, amount: '', recipient: address || '0x' as Address });

  const { data: tokenBalance } = useReadContract({ address: BRIDGE_CONFIG[formData.sourceChain].tokens[formData.token], abi: XERC20_ABI, functionName: 'balanceOf', args: [address!], query: { enabled: !!address } });
  const { data: currentAllowance } = useReadContract({ address: BRIDGE_CONFIG[formData.sourceChain].tokens[formData.token], abi: XERC20_ABI, functionName: 'allowance', args: [address!, BRIDGE_CONFIG[formData.sourceChain].bridge], query: { enabled: !!address } });
  const { data: rateLimit } = useReadContract({ address: BRIDGE_CONFIG[formData.destinationChain].tokens[formData.token], abi: BRIDGE_ABI, functionName: 'mintingCurrentLimitOf', args: [BRIDGE_CONFIG[formData.destinationChain].bridge] });

  const { writeContract: approve, data: approveHash, isPending: isApprovePending } = useWriteContract();
  const { isLoading: isApproveConfirming } = useWaitForTransactionReceipt({ hash: approveHash });
  const { writeContract: bridge, data: bridgeHash, isPending: isBridgePending } = useWriteContract();
  const { isLoading: isBridgeConfirming } = useWaitForTransactionReceipt({ hash: bridgeHash });

  const handleApprove = async () => {
    if (!address) return toast.error('Connect wallet');
    approve({ address: BRIDGE_CONFIG[formData.sourceChain].tokens[formData.token], abi: XERC20_ABI, functionName: 'approve', args: [BRIDGE_CONFIG[formData.sourceChain].bridge, parseEther(formData.amount)] });
    toast.success('Approval submitted');
  };

  const handleBridge = async () => {
    if (!address) return toast.error('Connect wallet');
    if (chain?.id !== BRIDGE_CONFIG[formData.sourceChain].chainId) { await switchChain({ chainId: BRIDGE_CONFIG[formData.sourceChain].chainId }); return; }
    bridge({ address: BRIDGE_CONFIG[formData.sourceChain].bridge, abi: BRIDGE_ABI, functionName: 'bridgeTokens', args: [BRIDGE_CONFIG[formData.sourceChain].tokens[formData.token], formData.recipient, parseEther(formData.amount), BigInt(BRIDGE_CONFIG[formData.destinationChain].chainId)] });
    toast.success('Bridge submitted');
  };

  const needsApproval = currentAllowance && formData.amount ? currentAllowance < parseEther(formData.amount) : false;
  const isInsufficientBalance = tokenBalance && formData.amount ? tokenBalance < parseEther(formData.amount) : false;
  const isExceedsRateLimit = rateLimit && formData.amount ? parseEther(formData.amount) > rateLimit : false;

  return (
    <div className="w-full max-w-md mx-auto p-6 bg-white rounded-lg shadow-lg">
      <h2 className="text-2xl font-bold mb-6">Bridge Tokens</h2>
      <div className="mb-4"><label className="block text-sm font-medium mb-2">From</label><select className="w-full p-2 border rounded" value={formData.sourceChain} onChange={(e) => setFormData((p) => ({ ...p, sourceChain: e.target.value as any }))}><option value="andechain">AndeChain</option><option value="ethereum">Ethereum</option></select></div>
      <div className="mb-4"><label className="block text-sm font-medium mb-2">To</label><select className="w-full p-2 border rounded" value={formData.destinationChain} onChange={(e) => setFormData((p) => ({ ...p, destinationChain: e.target.value as any }))}><option value="andechain">AndeChain</option><option value="ethereum">Ethereum</option></select></div>
      <div className="mb-4"><label className="block text-sm font-medium mb-2">Token</label><select className="w-full p-2 border rounded" value={formData.token} onChange={(e) => setFormData((p) => ({ ...p, token: e.target.value as any }))}><option value="xANDE">xANDE</option><option value="AUSD">AUSD</option><option value="ABOB">ABOB</option></select></div>
      <div className="mb-4"><label className="block text-sm font-medium mb-2">Amount</label><input type="number" className="w-full p-2 border rounded" placeholder="0.0" value={formData.amount} onChange={(e) => setFormData((p) => ({ ...p, amount: e.target.value }))} />{tokenBalance && <p className="text-xs text-gray-600 mt-1">Balance: {formatEther(tokenBalance)} {formData.token}</p>}</div>
      <div className="mb-4"><label className="block text-sm font-medium mb-2">Recipient</label><input type="text" className="w-full p-2 border rounded font-mono text-sm" placeholder="0x..." value={formData.recipient} onChange={(e) => setFormData((p) => ({ ...p, recipient: e.target.value as Address }))} /></div>
      {rateLimit && <div className="mb-4 p-3 bg-blue-50 border border-blue-200 rounded"><p className="text-sm text-blue-800">Rate limit: {formatEther(rateLimit)} {formData.token}</p></div>}
      {isInsufficientBalance && <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded"><p className="text-sm text-red-800">Insufficient balance</p></div>}
      {isExceedsRateLimit && <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded"><p className="text-sm text-red-800">Exceeds rate limit</p></div>}
      <div className="space-y-2">{needsApproval ? <button className="w-full p-3 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:opacity-50" onClick={handleApprove} disabled={isApprovePending || isApproveConfirming || isInsufficientBalance}>{isApprovePending || isApproveConfirming ? 'Approving...' : 'Approve'}</button> : <button className="w-full p-3 bg-green-600 text-white rounded hover:bg-green-700 disabled:opacity-50" onClick={handleBridge} disabled={isBridgePending || isBridgeConfirming || isInsufficientBalance || isExceedsRateLimit || !formData.amount}>{isBridgePending || isBridgeConfirming ? 'Bridging...' : 'Bridge'}</button>}</div>
      {(approveHash || bridgeHash) && <div className="mt-4 p-3 bg-gray-50 border rounded"><p className="text-sm font-medium mb-2">Transactions</p>{approveHash && <p className="text-xs mb-1"><a href={`https://explorer.andechain.io/tx/${approveHash}`} target="_blank" className="text-blue-600">Approval</a></p>}{bridgeHash && <p className="text-xs"><a href={`https://explorer.andechain.io/tx/${bridgeHash}`} target="_blank" className="text-blue-600">Bridge</a></p>}</div>}
      <div className="mt-6 p-4 bg-gray-50 rounded text-sm text-gray-600"><p className="font-medium mb-2">Info</p><ul className="space-y-1"><li>• Time: 5-10 min</li><li>• Confirmations: 6</li><li>• Fee: 0.1%</li></ul></div>
    </div>
  );
}
