import {loadStdlib} from '@reach-sh/stdlib';
import * as backend from './build/index.main.mjs';

const numOfBobs = 10;

(async () => {
  const stdlib = await loadStdlib();
  const startingBalance = stdlib.parseCurrency(100);
  const getBalance = async (who) => stdlib.formatCurrency(await stdlib.balanceOf(who), 4);

  // 1. Establish the Alice and Bob accounts
  const accAlice = await stdlib.newTestAccount(startingBalance);
  const accBobArray = await Promise.all(
    Array.from({ length: numOfBobs }, () => stdlib.newTestAccount(startingBalance))
  );

  // 2. Deploy
  const ctcAlice = accAlice.deploy(backend);
  const ctcInfo = ctcAlice.getInfo();
  const contractParams = {
    signupFee : stdlib.parseCurrency(5),
    deadline: 50,
  };

  // initial 'empty' array
  const funderAddress = accAlice.getAddress();
  let currentRoster = Array.from({length: numOfBobs}, () => funderAddress) 

  // 3. Declare interact interfaces
  await Promise.all([
    backend.Alice(ctcAlice, {
      showOutcome: (addr) => {
        console.log(`Funder: sees the current roster`);
        console.log(`Alice shows current roster: ${currentRoster}`);
      },
      getRoster: () => {
        console.log(`Alice shows current roster: ${currentRoster}`);
        return currentRoster
      },
      getParams: () => contractParams,
      roster: currentRoster,
    }),
  ].concat(accBobArray.map((accBob, i) => {
    const ctcBob = accBob.attach(backend, ctcInfo);
    return backend.Bob(ctcBob, {
      showOutcome: (addr) => {
        let isMember = currentRoster.includes(addr) ? 'a member' : 'Not a Member';
        console.log(`Address: ${addr} sees that they are ${isMember}`);
      },
      isMember: (addr) => currentRoster.includes(addr),
      shouldGetMembership: (addr, membershipFee) => !currentRoster.includes(addr) && Math.random() < 0.7,
      addToRoster: (addr) => {
        // user already on roster
        if (currentRoster.includes(addr)) {
          console.log(`User already on the roster`)
          return
        }
        
        if (stdlib.addressEq(addr, accBob)) {
          console.log(`Address ${accBob.getAddress()} - Added to roster`);
          const funderIndex = currentRoster.indexOf(funderAddress);
          currentRoster = currentRoster.map((elem, i) => i == funderIndex ? accBob.getAddress() : elem);
        }
      }
    })
  }))
  );

  // 4. Print the final balances for the consensus
  for(const [who, acc] of ([['Alice', accAlice]].concat(currentRoster.map((accBob) => ['Bob', accBob])))) {

    if (who === 'Alice') {
      console.log(`${who} has a balance of ${await getBalance(acc)}`);
    }
    else {
      // console.log(`${acc} has a balance of ${await stdlib.balanceOf(acc)}`);
      console.log(`${acc} has a balance of ${typeof acc}`);
    }
  }
  console.log(`\n`);
})();
