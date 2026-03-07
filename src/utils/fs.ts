import { Platform } from 'react-native'
import RNFS from 'react-native-fs'
import type {
  FileType,
  OpenDocumentOptions,
  Encoding,
  HashAlgorithm,
} from 'react-native-file-system'

const isIOS = Platform.OS == 'ios'
const fsModule = isIOS ? null : require('react-native-file-system')
const Dirs = fsModule?.Dirs
const FileSystem = fsModule?.FileSystem
const AndroidScoped = fsModule?.AndroidScoped
const _getExternalStoragePaths = fsModule?.getExternalStoragePaths as undefined | ((is_removable?: boolean) => Promise<string[]>)

export type {
  FileType,
}

// export const externalDirectoryPath = RNFS.ExternalDirectoryPath

export const extname = (name: string) => name.lastIndexOf('.') > 0 ? name.substring(name.lastIndexOf('.') + 1) : ''

export const temporaryDirectoryPath = isIOS ? RNFS.CachesDirectoryPath : Dirs.CacheDir
export const externalStorageDirectoryPath = isIOS ? RNFS.DocumentDirectoryPath : Dirs.SDCardDir
export const privateStorageDirectoryPath = isIOS ? RNFS.DocumentDirectoryPath : Dirs.DocumentDir

export const getExternalStoragePaths = async(is_removable?: boolean) => {
  if (!_getExternalStoragePaths) return [RNFS.DocumentDirectoryPath]
  return _getExternalStoragePaths(is_removable)
}

export const selectManagedFolder = async(isPersist: boolean = false) => {
  if (!AndroidScoped?.openDocumentTree) return null
  return AndroidScoped.openDocumentTree(isPersist)
}
export const selectFile = async(options: OpenDocumentOptions) => {
  if (!AndroidScoped?.openDocument) return null
  return AndroidScoped.openDocument(options)
}
export const removeManagedFolder = async(path: string) => {
  if (!AndroidScoped?.releasePersistableUriPermission) return
  return AndroidScoped.releasePersistableUriPermission(path)
}
export const getManagedFolders = async() => {
  if (!AndroidScoped?.getPersistedUriPermissions) return []
  return AndroidScoped.getPersistedUriPermissions()
}

export const getPersistedUriList = async() => {
  if (!AndroidScoped?.getPersistedUriPermissions) return []
  return AndroidScoped.getPersistedUriPermissions()
}


export const readDir = async(path: string) => {
  if (isIOS) return RNFS.readDir(path)
  return FileSystem.ls(path)
}

export const unlink = async(path: string) => {
  if (isIOS) {
    const exists = await RNFS.exists(path)
    if (!exists) return
    await RNFS.unlink(path)
    return
  }
  return FileSystem.unlink(path)
}

export const mkdir = async(path: string) => {
  if (isIOS) {
    await RNFS.mkdir(path)
    return
  }
  return FileSystem.mkdir(path)
}

export const stat = async(path: string) => {
  if (isIOS) return RNFS.stat(path)
  return FileSystem.stat(path)
}
export const hash = async(path: string, algorithm: HashAlgorithm) => {
  if (isIOS) return RNFS.hash(path, algorithm)
  return FileSystem.hash(path, algorithm)
}

export const readFile = async(path: string, encoding?: Encoding) => {
  if (isIOS) return RNFS.readFile(path, encoding as string | undefined)
  return FileSystem.readFile(path, encoding)
}


// export const copyFile = async(fromPath: string, toPath: string) => FileSystem.cp(fromPath, toPath)

export const moveFile = async(fromPath: string, toPath: string) => {
  if (isIOS) {
    await RNFS.moveFile(fromPath, toPath)
    return
  }
  return FileSystem.mv(fromPath, toPath)
}
export const gzipFile = async(fromPath: string, toPath: string) => {
  if (isIOS) throw new Error('gzipFile is not supported on iOS')
  return FileSystem.gzipFile(fromPath, toPath)
}
export const unGzipFile = async(fromPath: string, toPath: string) => {
  if (isIOS) throw new Error('unGzipFile is not supported on iOS')
  return FileSystem.unGzipFile(fromPath, toPath)
}
export const gzipString = async(data: string, encoding?: Encoding) => {
  if (isIOS) throw new Error('gzipString is not supported on iOS')
  return FileSystem.gzipString(data, encoding)
}
export const unGzipString = async(data: string, encoding?: Encoding) => {
  if (isIOS) throw new Error('unGzipString is not supported on iOS')
  return FileSystem.unGzipString(data, encoding)
}

export const existsFile = async(path: string) => {
  if (isIOS) return RNFS.exists(path)
  return FileSystem.exists(path)
}

export const rename = async(path: string, name: string) => {
  if (isIOS) {
    const parts = path.split('/')
    parts.pop()
    const targetPath = `${parts.join('/')}/${name}`
    await RNFS.moveFile(path, targetPath)
    return
  }
  return FileSystem.rename(path, name)
}

export const writeFile = async(path: string, data: string, encoding?: Encoding) => {
  if (isIOS) {
    await RNFS.writeFile(path, data, encoding as string | undefined)
    return
  }
  return FileSystem.writeFile(path, data, encoding)
}

export const appendFile = async(path: string, data: string, encoding?: Encoding) => {
  if (isIOS) {
    await RNFS.appendFile(path, data, encoding as string | undefined)
    return
  }
  return FileSystem.appendFile(path, data, encoding)
}

export const downloadFile = (url: string, path: string, options: Omit<RNFS.DownloadFileOptions, 'fromUrl' | 'toFile'> = {}) => {
  if (!options.headers) {
    options.headers = {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; Pixel 3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.79 Mobile Safari/537.36',
    }
  }
  return RNFS.downloadFile({
    fromUrl: url, // URL to download file from
    toFile: path, // Local filesystem path to save the file to
    ...options,
    // headers: options.headers, // An object of headers to be passed to the server
    // // background?: boolean;     // Continue the download in the background after the app terminates (iOS only)
    // // discretionary?: boolean;  // Allow the OS to control the timing and speed of the download to improve perceived performance  (iOS only)
    // // cacheable?: boolean;      // Whether the download can be stored in the shared NSURLCache (iOS only, defaults to true)
    // progressInterval: options.progressInterval,
    // progressDivider: options.progressDivider,
    // begin: (res: DownloadBeginCallbackResult) => void;
    // progress?: (res: DownloadProgressCallbackResult) => void;
    // // resumable?: () => void;    // only supported on iOS yet
    // connectionTimeout?: number // only supported on Android yet
    // readTimeout?: number       // supported on Android and iOS
    // // backgroundTimeout?: number // Maximum time (in milliseconds) to download an entire resource (iOS only, useful for timing out background downloads)
  })
}

export const stopDownload = (jobId: number) => {
  RNFS.stopDownload(jobId)
}
