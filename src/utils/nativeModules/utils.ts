import { AppState, Dimensions, NativeEventEmitter, NativeModules } from 'react-native'

type UtilsNativeModule = Record<string, ((...args: unknown[]) => unknown) | undefined>

const UtilsModule = NativeModules.UtilsModule as undefined | UtilsNativeModule

const callUtils = <T>(method: string, fallback: T, ...args: unknown[]): T => {
  const handler = UtilsModule?.[method]
  if (typeof handler == 'function') return handler(...args) as T
  return fallback
}

const getFallbackWindowSize = () => {
  const { width, height, scale } = Dimensions.get('window')
  return {
    width: Math.round(width * scale),
    height: Math.round(height * scale),
  }
}

export const exitApp = () => {
  callUtils('exitApp', undefined)
}

export const getSupportedAbis = async(): Promise<string[]> => {
  return callUtils('getSupportedAbis', Promise.resolve([]))
}

export const installApk = async(filePath: string, fileProviderAuthority: string) => {
  return callUtils('installApk', Promise.resolve(false), filePath, fileProviderAuthority)
}

export const screenkeepAwake = () => {
  if (global.lx.isScreenKeepAwake) return
  global.lx.isScreenKeepAwake = true
  callUtils('screenkeepAwake', undefined)
}
export const screenUnkeepAwake = () => {
  if (!global.lx.isScreenKeepAwake) return
  global.lx.isScreenKeepAwake = false
  callUtils('screenUnkeepAwake', undefined)
}

export const getWIFIIPV4Address = async(): Promise<string> => {
  return callUtils('getWIFIIPV4Address', Promise.resolve(''))
}

export const getDeviceName = async(): Promise<string> => {
  return callUtils('getDeviceName', Promise.resolve('Unknown')).then((deviceName: string) => deviceName || 'Unknown')
}

export const isNotificationsEnabled = async(): Promise<boolean> => {
  return callUtils('isNotificationsEnabled', Promise.resolve(false))
}

export const requestNotificationPermission = async() => new Promise<boolean>((resolve) => {
  let subscription = AppState.addEventListener('change', (state) => {
    if (state != 'active') return
    subscription.remove()
    setTimeout(() => {
      void isNotificationsEnabled().then(resolve)
    }, 1000)
  })
  void callUtils('openNotificationPermissionActivity', Promise.resolve(false)).then((result: boolean) => {
    if (result) return
    subscription.remove()
    resolve(false)
  })
})

export const shareText = async(shareTitle: string, title: string, text: string): Promise<void> => {
  callUtils('shareText', undefined, shareTitle, title, text)
}

export const getSystemLocales = async(): Promise<string> => {
  return callUtils('getSystemLocales', Promise.resolve(Intl.DateTimeFormat().resolvedOptions().locale.toLowerCase()))
}

export const onScreenStateChange = (handler: (state: 'ON' | 'OFF') => void): () => void => {
  if (!UtilsModule) return () => {}
  const eventEmitter = new NativeEventEmitter()
  const eventListener = eventEmitter.addListener('screen-state', event => {
    handler(event.state as 'ON' | 'OFF')
  })

  return () => {
    eventListener.remove()
  }
}

export const getWindowSize = async(): Promise<{ width: number, height: number }> => {
  return callUtils('getWindowSize', Promise.resolve(getFallbackWindowSize()))
}

export const onWindowSizeChange = (handler: (size: { width: number, height: number }) => void): () => void => {
  if (!UtilsModule) return () => {}
  callUtils('listenWindowSizeChanged', undefined)
  const eventEmitter = new NativeEventEmitter()
  const eventListener = eventEmitter.addListener('screen-size-changed', event => {
    handler(event as { width: number, height: number })
  })

  return () => {
    eventListener.remove()
  }
}

export const isIgnoringBatteryOptimization = async(): Promise<boolean> => {
  return callUtils('isIgnoringBatteryOptimization', Promise.resolve(false))
}

export const requestIgnoreBatteryOptimization = async() => new Promise<boolean>((resolve) => {
  let subscription = AppState.addEventListener('change', (state) => {
    if (state != 'active') return
    subscription.remove()
    setTimeout(() => {
      void isIgnoringBatteryOptimization().then(resolve)
    }, 1000)
  })
  void callUtils('requestIgnoreBatteryOptimization', Promise.resolve(false)).then((result: boolean) => {
    if (result) return
    subscription.remove()
    resolve(false)
  })
})
