import { NativeModules } from 'react-native'

const CacheModule = NativeModules.CacheModule as undefined | {
  getAppCacheSize: () => Promise<number>
  clearAppCache: () => Promise<void>
}

export const getAppCacheSize = async(): Promise<number> => {
  if (!CacheModule?.getAppCacheSize) return 0
  return CacheModule.getAppCacheSize().then((size: number) => Math.trunc(size))
}
export const clearAppCache = async(): Promise<void> => {
  if (!CacheModule?.clearAppCache) return
  return CacheModule.clearAppCache()
}
