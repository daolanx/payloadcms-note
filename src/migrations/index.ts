import * as migration_20260701_090906_init from './20260701_090906_init';
import * as migration_20260702_061347 from './20260702_061347';

export const migrations = [
  {
    up: migration_20260701_090906_init.up,
    down: migration_20260701_090906_init.down,
    name: '20260701_090906_init',
  },
  {
    up: migration_20260702_061347.up,
    down: migration_20260702_061347.down,
    name: '20260702_061347'
  },
];
