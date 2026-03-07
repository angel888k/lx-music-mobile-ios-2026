import { NativeEventEmitter, NativeModules } from 'react-native'

const UserApiModule = NativeModules.UserApiModule as undefined | {
  loadScript: (info: LX.UserApi.UserApiInfo & { script: string }) => void
  sendAction: (action: string, data: string) => void
  destroy: () => void
}

export const isUserApiModuleAvailable = !!UserApiModule

let loadScriptInfo: LX.UserApi.UserApiInfo | null = null
export const loadScript = (info: LX.UserApi.UserApiInfo & { script: string }) => {
  loadScriptInfo = info
  if (!UserApiModule?.loadScript) return
  UserApiModule.loadScript(info)
}

export interface SendResponseParams {
  requestKey: string
  error: string | null
  response: {
    statusCode: number
    statusMessage: string
    headers: Record<string, string>
    body: any
  } | null
}
export interface SendActions {
  request: LX.UserApi.UserApiRequestParams
  response: SendResponseParams
}
export const sendAction = <T extends keyof SendActions>(action: T, data: SendActions[T]) => {
  if (!UserApiModule?.sendAction) return
  UserApiModule.sendAction(action, JSON.stringify(data))
}

export interface InitParams {
  status: boolean
  errorMessage: string
  info: LX.UserApi.UserApiInfo
}

export interface ResponseParams {
  status: boolean
  errorMessage?: string
  requestKey: string
  result: any
}
export interface UpdateInfoParams {
  name: string
  log: string
  updateUrl: string
}
export interface RequestParams {
  requestKey: string
  url: string
  options: {
    method: string
    data: any
    timeout: number
    headers: any
    binary: boolean
  }
}
export type CancelRequestParams = string

export interface Actions {
  init: InitParams
  request: RequestParams
  cancelRequest: CancelRequestParams
  response: ResponseParams
  showUpdateAlert: UpdateInfoParams
  log: string
}
export type ActionsEvent = { [K in keyof Actions]: { action: K, data: Actions[K] } }[keyof Actions]

export const onScriptAction = (handler: (event: ActionsEvent) => void): () => void => {
  if (!UserApiModule) return () => {}
  const eventEmitter = new NativeEventEmitter(UserApiModule as never)
  const eventListener = eventEmitter.addListener('api-action', event => {
    if (event.data) event.data = JSON.parse(event.data as string)
    if (event.action == 'init') {
      if (event.data.info) event.data.info = { ...loadScriptInfo, ...event.data.info }
      else event.data.info = { ...loadScriptInfo }
    } else if (event.action == 'showUpdateAlert') {
      if (!loadScriptInfo?.allowShowUpdateAlert) return
    }
    handler(event as ActionsEvent)
  })

  return () => {
    eventListener.remove()
  }
}

export const destroy = () => {
  UserApiModule?.destroy?.()
}
