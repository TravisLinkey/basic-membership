import {loadStdlib} from '@reach-sh/stdlib';
import * as backend from './build/index.main.mjs';

const numOfBobs = 10;

(async () => {
  const stdlib = await loadStdlib();
  const assertEq = (expected, actual) => {
    const exps = JSON.stringify(expected);
    const acts = JSON.stringify(actual);
    console.log('assertEq', {expected, actual}, {exps, acts});
    stdlib.assert(exps === acts) };
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

  const tokenParams = {
    name: `Gil`, symbol: `GIL`,
    url: `https://tinyurl.com/4nd2faer`,
    metadata: `It's shiny!`,
    supply: stdlib.parseCurrency(1000),
    amt: stdlib.parseCurrency(10),
  }

  // helper functions
  let amt = null;
  let tok = null;
  let me = null;
  let acc = null;
  const fmt = (x) => stdlib.formatCurrency(x, 4);
  const showBalance = async () => {
    console.log(`${me}: Checking ${tok} balance:`);
    console.log(`${me}: ${tok} balance: ${fmt(await stdlib.balanceOf(acc, tok))}`);
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
      getTokenParams: () => tokenParams,
      roster: currentRoster,
      didTransfer: async (did, _amt) => {
        if ( did ) {
          amt = _amt;
          console.log(`${me}: Received transfer of ${fmt(amt)} for ${tok}`);
        }
        await showBalance();
      },
      showToken: async (_tok, cmd) => {
        tok = _tok;
        acc = accAlice;
        me = funderAddress;
        console.log(`${me}: The token is: ${tok}`);
        await showBalance();
        console.log(`${me}: The token computed metadata is:`, cmd);
        const omd = await acc.tokenMetadata(tok);
        console.log(`${me}: The token on-chain metadata is:`, omd);
        for ( const f in cmd ) {
          assertEq(cmd[f], omd[f]);
        }
        console.log(`${me}: Opt-in to ${tok}:`);
        await acc.tokenAccept(tok);
        await showBalance();
      },
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
