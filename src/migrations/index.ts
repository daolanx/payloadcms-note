import * as migration_20260701_090906_init from './20260701_090906_init';

export const migrations = [
  {
    up: migration_20260701_090906_init.up,
    down: migration_20260701_090906_init.down,
    name: '20260701_090906_init'
  },
];
