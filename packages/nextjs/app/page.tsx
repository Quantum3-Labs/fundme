"use client";

import Link from "next/link";
import type { NextPage } from "next";
import { BugAntIcon, MagnifyingGlassIcon } from "@heroicons/react/24/outline";
import { Address } from "~~/components/scaffold-stark";
import { useAccount } from "@starknet-react/core";
import { Address as AddressType } from "@starknet-react/chains";
import { createContractCall, useScaffoldMultiWriteContract } from "~~/hooks/scaffold-stark/useScaffoldMultiWriteContract";
import { useState } from "react";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-stark/useScaffoldWriteContract";
import { useScaffoldReadContract } from "~~/hooks/scaffold-stark/useScaffoldReadContract";
import { formatEther } from "ethers";
import { useDeployedContractInfo } from "~~/hooks/scaffold-stark";

const Home: NextPage = () => {
  const connectedAddress = useAccount();
  const [amount, setAmount] = useState("0");
  const { data: contract } = useDeployedContractInfo("FundMe");
  const { writeAsync } = useScaffoldMultiWriteContract({
    calls: [
      createContractCall("Eth", "approve", [contract?.address, Number(amount) * (10 ** 18)]),
      createContractCall("FundMe", "fund", [Number(amount) * (10 ** 18)])
    ]
  });
  const {writeAsync: withdraw} = useScaffoldWriteContract({
    contractName: "FundMe",
    functionName: "withdraw",
  });

  const {data: funders} = useScaffoldReadContract({
    contractName: "FundMe",
    functionName: "funders_length",
  });

  const {data: myContribution} = useScaffoldReadContract({
    contractName: "FundMe",
    functionName: "address_to_amount_funded",
    args: [connectedAddress.address ?? ""]
  });

  return (
    <>
      <div className="flex items-center flex-col flex-grow pt-10">
        <div className="px-5">
          <h1 className="text-center">
            <span className="block text-4xl font-bold">Fund Me</span>
          </h1>
          <div className="flex justify-center items-center space-x-2">
            <p className="my-2 font-medium">Connected Address:</p>
            <Address address={connectedAddress.address as AddressType} />
          </div>
            
        </div>

        <div className="flex-grow bg-base-300 w-full mt-16 px-8 py-12">
          <div className="flex justify-center items-center gap-12 flex-col sm:flex-row">
            <div className="flex flex-col bg-base-100 px-10 py-10 text-center items-center max-w-xs rounded-3xl">
              <p>Amount</p>
              <input className="input input-bordered input-sm" type="number" value={amount} onChange={(e) => setAmount(e.target.value)} />
              <div className="mt-4">
                <button className="btn btn-primary btn-sm font-normal gap-1 cursor-auto" onClick={() => writeAsync()}>
                  Fund
                </button>
              </div>
            </div>
            <div className="flex flex-col bg-base-100 px-10 py-10 text-center items-center max-w-xs rounded-3xl">
              <button className="btn btn-primary btn-sm font-normal gap-1 cursor-auto" onClick={() => withdraw()}>Withdraw</button>
              <div>
                <div>
                  <p>{`Funders: ${funders}`}</p>
                </div>
                <div>
                  <p>My contribution: {formatEther(myContribution?.toString() ?? "0")}</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </>
  );
};

export default Home;
