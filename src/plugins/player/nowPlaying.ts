import TrackPlayer from 'react-native-track-player'
import { NativeModules, Platform } from 'react-native'

interface NowPlayingMetadata {
  title?: string
  artist?: string
  album?: string
  artwork?: string | number
  duration?: number
  elapsedTime?: number
  isLiveStream?: boolean
}

interface NativeTrackPlayerModule {
  updateNowPlayingMetadata?: (metadata: NowPlayingMetadata) => Promise<void>
}

const nativeTrackPlayer = NativeModules.TrackPlayerModule as NativeTrackPlayerModule

export const updateNowPlayingMetadata = async(metadata: NowPlayingMetadata) => {
  if (Platform.OS == 'ios' && typeof nativeTrackPlayer.updateNowPlayingMetadata == 'function') {
    return nativeTrackPlayer.updateNowPlayingMetadata(metadata)
  }
  return TrackPlayer.updateNowPlayingMetadata(metadata, true)
}

export const updateNowPlayingTitles = async(duration: number, title: string, artist: string, album: string) => {
  return updateNowPlayingMetadata({
    title,
    artist,
    album,
    duration,
  })
}
