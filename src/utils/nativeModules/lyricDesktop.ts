import { NativeModules, NativeEventEmitter } from 'react-native'

const LyricModule = NativeModules.LyricModule as undefined | {
  setSendLyricTextEvent: (isSend: boolean) => Promise<void>
  showDesktopLyric: (params: any) => Promise<void>
  hideDesktopLyric: () => Promise<void>
  play: (time: number) => Promise<void>
  pause: () => Promise<void>
  setLyric: (lyric: string, translation: string, romalrc: string) => Promise<void>
  setPlaybackRate: (rate: number) => Promise<void>
  toggleTranslation: (isShowTranslation: boolean) => Promise<void>
  toggleRoma: (isShowRoma: boolean) => Promise<void>
  toggleLock: (isLock: boolean) => Promise<void>
  setColor: (unplayColor: string, playedColor: string, shadowColor: string) => Promise<void>
  setAlpha: (alpha: number) => Promise<void>
  setTextSize: (size: number) => Promise<void>
  setShowToggleAnima: (isShowToggleAnima: boolean) => Promise<void>
  setSingleLine: (isSingleLine: boolean) => Promise<void>
  setPosition: (x: number, y: number) => Promise<void>
  setMaxLineNum: (maxLineNum: number) => Promise<void>
  setWidth: (width: number) => Promise<void>
  setLyricTextPosition: (textX: string, textY: string) => Promise<void>
  checkOverlayPermission: () => Promise<void>
  openOverlayPermissionActivity: () => Promise<void>
}

const getAlpha = (num: number) => num / 100
const getTextSize = (num: number) => num / 10

export const isDesktopLyricModuleAvailable = !!LyricModule

export const setSendLyricTextEvent = async(isSend: boolean) => {
  if (!LyricModule?.setSendLyricTextEvent) return
  return LyricModule.setSendLyricTextEvent(isSend)
}

export const showDesktopLyricView = async({
  isShowToggleAnima,
  isSingleLine,
  width,
  maxLineNum,
  isLock,
  unplayColor,
  playedColor,
  shadowColor,
  opacity,
  textSize,
  positionX,
  positionY,
  textPositionX,
  textPositionY,
}: {
  isShowToggleAnima: boolean
  isSingleLine: boolean
  width: number
  maxLineNum: number
  isLock: boolean
  unplayColor: string
  playedColor: string
  shadowColor: string
  opacity: number
  textSize: number
  positionX: number
  positionY: number
  textPositionX: LX.AppSetting['desktopLyric.textPosition.x']
  textPositionY: LX.AppSetting['desktopLyric.textPosition.y']
}): Promise<void> => {
  if (!LyricModule?.showDesktopLyric) return Promise.reject(new Error('LyricModule.showDesktopLyric is not available on current platform'))
  return LyricModule.showDesktopLyric({
    isSingleLine,
    isShowToggleAnima,
    isLock,
    unplayColor,
    playedColor,
    shadowColor,
    alpha: getAlpha(opacity),
    textSize: getTextSize(textSize),
    lyricViewX: positionX,
    lyricViewY: positionY,
    textX: textPositionX.toUpperCase(),
    textY: textPositionY.toUpperCase(),
    width,
    maxLineNum,
  })
}

export const hideDesktopLyricView = async(): Promise<void> => {
  if (!LyricModule?.hideDesktopLyric) return
  return LyricModule.hideDesktopLyric()
}

export const play = async(time: number): Promise<void> => {
  if (!LyricModule?.play) return
  return LyricModule.play(time)
}

export const pause = async(): Promise<void> => {
  if (!LyricModule?.pause) return
  return LyricModule.pause()
}

export const setLyric = async(lyric: string, translation: string, romalrc: string): Promise<void> => {
  if (!LyricModule?.setLyric) return
  return LyricModule.setLyric(lyric, translation || '', romalrc || '')
}

export const setPlaybackRate = async(rate: number): Promise<void> => {
  if (!LyricModule?.setPlaybackRate) return
  return LyricModule.setPlaybackRate(rate)
}

export const toggleTranslation = async(isShowTranslation: boolean): Promise<void> => {
  if (!LyricModule?.toggleTranslation) return
  return LyricModule.toggleTranslation(isShowTranslation)
}

export const toggleRoma = async(isShowRoma: boolean): Promise<void> => {
  if (!LyricModule?.toggleRoma) return
  return LyricModule.toggleRoma(isShowRoma)
}

export const toggleLock = async(isLock: boolean): Promise<void> => {
  if (!LyricModule?.toggleLock) return
  return LyricModule.toggleLock(isLock)
}

export const setColor = async(unplayColor: string, playedColor: string, shadowColor: string): Promise<void> => {
  if (!LyricModule?.setColor) return
  return LyricModule.setColor(unplayColor, playedColor, shadowColor)
}

export const setAlpha = async(alpha: number): Promise<void> => {
  if (!LyricModule?.setAlpha) return
  return LyricModule.setAlpha(getAlpha(alpha))
}

export const setTextSize = async(size: number): Promise<void> => {
  if (!LyricModule?.setTextSize) return
  return LyricModule.setTextSize(getTextSize(size))
}

export const setShowToggleAnima = async(isShowToggleAnima: boolean): Promise<void> => {
  if (!LyricModule?.setShowToggleAnima) return
  return LyricModule.setShowToggleAnima(isShowToggleAnima)
}

export const setSingleLine = async(isSingleLine: boolean): Promise<void> => {
  if (!LyricModule?.setSingleLine) return
  return LyricModule.setSingleLine(isSingleLine)
}

export const setPosition = async(x: number, y: number): Promise<void> => {
  if (!LyricModule?.setPosition) return
  return LyricModule.setPosition(x, y)
}

export const setMaxLineNum = async(maxLineNum: number): Promise<void> => {
  if (!LyricModule?.setMaxLineNum) return
  return LyricModule.setMaxLineNum(maxLineNum)
}

export const setWidth = async(width: number): Promise<void> => {
  if (!LyricModule?.setWidth) return
  return LyricModule.setWidth(width)
}

export const setLyricTextPosition = async(textX: LX.AppSetting['desktopLyric.textPosition.x'], textY: LX.AppSetting['desktopLyric.textPosition.y']): Promise<void> => {
  if (!LyricModule?.setLyricTextPosition) return
  return LyricModule.setLyricTextPosition(textX.toUpperCase(), textY.toUpperCase())
}

export const checkOverlayPermission = async(): Promise<void> => {
  if (!LyricModule?.checkOverlayPermission) return Promise.reject(new Error('LyricModule.checkOverlayPermission is not available on current platform'))
  return LyricModule.checkOverlayPermission()
}

export const openOverlayPermissionActivity = async(): Promise<void> => {
  if (!LyricModule?.openOverlayPermissionActivity) return Promise.reject(new Error('LyricModule.openOverlayPermissionActivity is not available on current platform'))
  return LyricModule.openOverlayPermissionActivity()
}

export const onPositionChange = (handler: (position: { x: number, y: number }) => void): () => void => {
  if (!LyricModule) return () => {}
  const eventEmitter = new NativeEventEmitter()
  const eventListener = eventEmitter.addListener('set-position', event => {
    handler(event as { x: number, y: number })
  })

  return () => {
    eventListener.remove()
  }
}

export const onLyricLinePlay = (handler: (lineInfo: { text: string, extendedLyrics: string[] }) => void): () => void => {
  if (!LyricModule) return () => {}
  const eventEmitter = new NativeEventEmitter()
  const eventListener = eventEmitter.addListener('lyric-line-play', event => {
    handler(event as { text: string, extendedLyrics: string[] })
  })

  return () => {
    eventListener.remove()
  }
}
