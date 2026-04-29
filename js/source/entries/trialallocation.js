import '../legacy/jquery.js';
import '../legacy/d3/d3v4Min.js';
import { initTrialAllocation } from './trialallocation/app.js';

let trialAllocationStarted = false;

function startTrialAllocation() {
  if (trialAllocationStarted) return;
  trialAllocationStarted = true;
  initTrialAllocation();
}

export function init() {
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', startTrialAllocation, { once: true });
  } else {
    startTrialAllocation();
  }
}

init();
