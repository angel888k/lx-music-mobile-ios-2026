import TrackPlayer from 'react-native-track-player'
import { NativeModules, Platform } from 'react-native'

interface NativeTrackPlayerModule {
  getDuration?: () => Promise<number>
  getPosition?: () => Promise<number>
  getBufferedPosition?: () => Promise<number>
}

const nativeTrackPlayer = NativeModules.TrackPlayerModule as NativeTrackPlayerModule

const callNativeTime = async(method: keyof NativeTrackPlayerModule, fallback: () => Promise<number>) => {
  if (Platform.OS != 'ios') return fallback()
  const handler = nativeTrackPlayer[method]
  if (typeof handler != 'function') return fallback()
  return handler.call(nativeTrackPlayer)
}

export const getDuration = async() => callNativeTime('getDuration', async() => TrackPlayer.getDuration())
export const getPosition = async() => callNativeTime('getPosition', async() => TrackPlayer.getPosition())
export const getBufferedPosition = async() => callNativeTime('getBufferedPosition', async() => TrackPlayer.getBufferedPosition())
